# telnetd — implementation plan (2026-07-24)

Executes the last item of the networking-scope initial push
(`2026-07-19-networking-roadmap-scope.md` §4/§5 item 4): a **standalone
telnetd** that relays a TCP connection to a shell running on a pty slave. The
per-tty refactor + native pty chardev — which the scope doc called telnetd's
"true cost center… likely bigger than the pty pair itself" — **already landed**
(`feat/pty`, merged `920b564a`). This is an implementation plan; the telnetd
requirements analysis lives in the scope doc §4 and is not repeated.

**The one surprise (survey 2026-07-24):** telnetd is a **two-deliverable**
campaign, not a one-file lift. Beyond `telnetd.c` itself, the **socket-layer
loopback backend (scope §4b) does not exist** — and without it there is no
headless closed-loop test (`telnet 127.0.0.1 → local telnetd`), because the
W5100 offload can't loop `127.0.0.1` back internally. Every *other* enabling
primitive is already merged.

**Estimate: ~3–4 sessions.** P0 (compile-probe + headers) ~0.5, P1 (loopback
backend) ~1.5–2, P2 (the daemon) ~1–1.5, P3 (hardening + docs) ~0.5.

---

## 1. Grounding (survey 2026-07-24, branch `feat/telnetd` off `main`)

Everything below is a code fact with a `file:line` cite. **No `telnetd` source
exists in the tree yet.**

| Fact | Cite |
|---|---|
| listen/accept/bind fully implemented (not client-only): SYS 84/85/72 → `net_op_listen`/`accept`/`bind` | `include/loader.s:447,451,420`, `src/modules/net/net.s:966,981,667` |
| **accept returns a NEW fd and DETACHES the listener** (W5100 single-socket-per-listener); must re-`socket`/`bind`/`listen` per session | `net.s:1002-1028`, `net_xport.s:930` |
| `echod` is the exact accept-loop template (socket→bind(INADDR_ANY)→listen→accept→…→re-listen) | `src/userland/echod/echod.c:6-73`, fixture `echod_listen.json` |
| **`SOCKD_MAX = 4` total sockets** (W5100 hw limit) — listener + accepted conn + a DNS query "already brush it" | `include/socket.s:66`, scope `:129` |
| pty pairs: **`PTY_NPAIR = 2`** (`/dev/ptyp0`+`ttyp0`, `/dev/ptyp1`+`ttyp1`) → ≤2 concurrent sessions | `src/kernel/pty.s:35,875-881` |
| **TIOCPKT byte-0 skip** — every master read prefixes byte 0 (`TIOCPKT_DATA`/`FLUSHWR`); telnetd sets PKT unconditionally + skips it | `pty.s:357-358,400-412,480` |
| Master read is RECORD-mode; drains OutRing; **empty + no slave open → EOF (`A=0,C=0`)** = telnetd teardown signal; FIONBIO→EAGAIN else blocks `WCHAN_PTY` | `pty.s:352-388` |
| jsh reads **fd 0** over a pty (`TIOCISCONS` → not-console → `read_line()`); confirmed working end-to-end (ptyshell drives real jsh) | `src/userland/jsh/jsh.c:131-144,1920-1931`, pty plan `:250-291` |
| **`select` (SYS 99)** with generic chardev `COPS_Poll` dispatch → pty-master readiness feeds select | `include/loader.s:468`, `src/kernel/syscall.s:861,1102,1175`, `pty.s:515-518` |
| **FIONBIO** honored for sockets (`SOCK_NB`) AND ptys (`FCB_CDF_NONBLK`) | `syscall.s:2352,2437`, `include/socket.s:79`, `include/fs.s:520` |
| spawn-on-slave: `posix_spawnx` (SYS 44) file_actions OPEN/CLOSE/DUP2 + `dup2` (SYS 89) — open `/dev/ttypN`, dup2→0/1/2 | `process.s:2086-2091,332`, `include/loader.s:211,165` |
| **`waitpid` (SYS 82, `WNOHANG`)** reaps the shell; blocks on parent TCB, woken by child `_exit` | `process.s:2343,2326-2338`, `include/loader.s:434` |
| **`SIGCHLD` is NEVER raised** (default `SA_IGN`, no raise site) → teardown keys on master-EOF/`waitpid`, not `signal(SIGCHLD)` | `signal.s:865`, scope `:204-206` |
| fd budget: **`FS_MAX_FDS = 8`**/task; telnetd model (listen + {socket, master} + shell holds slave) ≈ 6/8 | `include/fs.s:282`, pty plan `:194` |
| **NO loopback anywhere** (grep-confirmed); net fixtures test against real SLIRP NAT (`telnet_smoke` 10.0.2.2, `telnet_byname` example.com, echod round-trip = separate host-nc test) | scope `:235`, `tools/mame_test/tests/{telnet_smoke,telnet_byname,echod_listen}.json` |
| loopback spec: in-memory bidirectional socket pair at the offload-agnostic `_Net_Xport_*` seam, reuse `kernel/pipe.s` buffering | scope `:217-235`, `src/modules/net/net_xport.s` |
| telnet client = `usr/ucb/telnet.c` port; IAC FSM `telrcv` + option table + `select(+exceptfds)`/FIONBIO — the reusable server spec | `src/userland/telnet/telnet.c:1034,105-108,802,772` |
| fcc telnet.c probe found a K&R fn-ptr-param gap (**fixed** in toolchain); telnetd.c has its own risk: **writes into a string literal** (`line[i]=c`) | scope `:265,273-288` |
| No standard `<arpa/telnet.h>`/`<netdb.h>`; net tools use bespoke `src/userland/lib/socket_h.h` | scope `:284-287` |

---

## 2. Design

### 2.1 telnetd (userland — a `usr/libexec/telnetd/telnetd.c` port)

2.11BSD `telnetd.c` (~26 KB) is normally an **inetd child**: `main()` does
`getpeername(0,…)` on the connected socket handed in as fd 0. FGX has no inetd,
so **port the `#ifdef DEBUG` listen/bind/accept block as the standalone main** —
which also makes `getpeername` unnecessary (accept returns the peer). Per the
scope doc this is **one session at a time** unless it respawns; acceptable.

Per-session flow (mirrors `echod` for the socket half, `ptyshell` for the pty
half):
1. `socket`/`bind(INADDR_ANY, 23)`/`listen`/`accept` → connection fd `c`. Because
   accept detaches the listener, re-create it each session (echod already does).
2. Pick a free pty pair; open master `/dev/ptypN`; `ioctl(master, TIOCPKT, &1)`.
3. `posix_spawnx` **jsh** with file_actions {open `/dev/ttypN`, dup2→0/1/2,
   close slave}. No login/getty (single-user) — spawn `jsh` directly.
4. Initial IAC negotiation: server sends `WILL ECHO`, `WILL SGA`, `DO TTYPE`
   (the minimal set the client already understands — §1). Reuse the client's
   option-table/`telrcv` shape as the spec; refuse everything else.
5. **Relay loop:** `select` over {`c`, `master`} with FIONBIO on both.
   - master→socket: read master (RECORD mode), **drop byte 0** (TIOCPKT prefix),
     write the rest to `c`.
   - socket→master: read `c`, run inbound IAC through `telrcv`, write data to
     `master`.
6. **Teardown:** master read returns **EOF** (slave closed = shell exited) OR
   socket EOF → close both, `waitpid(shellpid, WNOHANG)` to reap, loop to accept.

Headers: add an `<arpa/telnet.h>`-shaped option-defs header over the existing
`socket_h.h`; the client already carries the option constants inline to lift.

### 2.2 Socket-layer loopback backend (kernel — `net_xport.s`)

The test vehicle (scope §4b). A **second transport backend beside the W5100
offload**, at the offload-agnostic `_Net_Xport_*` seam, so the socket layer above
is unchanged:
- **`connect(127.0.0.1:p)`** (or the bound-local addr) scans for a local socket
  **listening** on `p`. On match, allocate an **in-memory bidirectional pair**
  (two `pipe.s`-style rings) and tag both descriptors `SOCK_HwIdx = SOCK_HW_LOOP`
  (a new sentinel) instead of a W5100 hw socket — so **loopback does not consume
  the 4 hardware sockets** (it still uses socket *descriptors*, `SOCKD_MAX=4`).
- **`accept`** on a loopback listener returns a fresh descriptor wired to the
  connecting peer's pair (unblocks like the W5100 path).
- **`send`/`recv`/`close`** route to the ring (honor FIONBIO/EWOULDBLOCK); ring
  transitions `_wakeup(WCHAN_SOCK)` so blocking recv/accept wake, and feed the
  **existing socket-readable predicate** so `select`/`COPS_Poll` report the
  loopback socket ready — no new select plumbing.
- Reuses `kernel/pipe.s` buffering; no software IP stack, no new hardware. The
  verbatim BSD `lo0` `ifnet` stays Track B.

#### 2.2.1 Implementation shape (survey 2026-08-09, `main` @ v1.17.0)

The sketch above survives contact with the code. Concretely:

| Fact | Consequence |
|---|---|
| The seam is a **tag branch on `SOCK_Proto`**, self-described as "ONE driver today (W5100)… a 2nd driver would make it an indirect call through the ifnet's driver_ops" (`net_xport.s:66-74`) | Add a `XPORT_LOOP` arm to each `_Net_Xport_*` entry rather than inventing a vtable. Nine entries exist: `Open/Send/Recv/SockStatus/Connect/Close/Listen/Accept/Shutdown` |
| `SOCK_HwIdx` already carries a sentinel — `SOCK_HW_NONE EQU $FF`, "descriptor owns no hw socket" (`include/socket.s:81`) | `SOCK_HW_LOOP EQU $FE` is a natural sibling, and the "doesn't consume a hw socket" behaviour is precedented by accept's listener-detach |
| **`SOCK_REC_SIZE` has exactly two users**, both `ADC #SOCK_REC_SIZE` in scan loops (`net.s:598,1049`) — **no shift math** | The descriptor can grow 8 → 12 with zero index-arithmetic changes. Table is Kmalloc'd `SOCKD_MAX*SOCK_REC_SIZE` = 32 → 48 bytes of heap. Nothing in the kernel bank |
| `pipe.s` rings are `PIPE_{InUse,RdClosed,WrClosed,BufPtr,Head,Tail,Count,BufSz}` (`kernel.s:684-691`), `PIPE_BUFSZ` 512 and growable | A loopback pair is **two** rings — A→B and B→A. Socket A writes ring 0 and reads ring 1; B mirrors. `RdClosed`/`WrClosed` already model half-close, which `SYS_SHUTDOWN` needs |
| `WCHAN_SOCK EQU $FF02` is "any W5100 socket (recv/connect/send block)" (`kernel.s:654`) | Reuse it verbatim — blocking recv/accept already sleep there, so a ring transition calling `_wakeup(WCHAN_SOCK)` needs no new channel and no select plumbing |

**New descriptor fields** (8 → 12, all inside the existing 3 spare bytes plus one):

```
SOCK_LoopPeer   EQU  8   ; 1  peer descriptor index, $FF = none yet
SOCK_LoopRx     EQU  9   ; 1  pipe index this socket READS
SOCK_LoopTx     EQU 10   ; 1  pipe index this socket WRITES
SOCK_LoopFlags  EQU 11   ; 1  reserved (half-close bookkeeping)
```

**The one real design question is `connect` matching.** `connect(127.0.0.1:p)` must find a descriptor that is `TCP_LISTEN` on port `p`. The table is 4 entries, so a linear scan is correct and trivially cheap — no port hash. The subtlety is that the plan's §5.3 note applies here too: the W5100 `accept` **detaches the listener**, and the loopback path should mirror that semantic rather than invent a better one, or `echod`-shaped servers behave differently on 127.0.0.1 than on the wire — which would make the loopback gate test something the real path doesn't do.

**Budget check for the gate.** `telnet 127.0.0.1` → local `telnetd` needs 3 of `SOCKD_MAX=4` descriptors (client + listener + accepted conn) and **zero** hardware sockets, so it does not contend with `/dev/bpf0`'s socket 0 or with a concurrent DHCP lease. Pty: 1 of `PTY_NPAIR=2`.

#### 2.2.2 CORRECTION — it belongs in the kernel, not in `net.mod`

§2.2 and §2.2.1 both say "kernel — `net_xport.s`". **That is wrong**, and the
reason only shows up when you try to write it:

`net_xport.s` lives inside **net.mod**, which reaches the kernel through exactly
**four** module-gateway slots — `SYS_NETKC_{FCBALLOC,SOCKFDTODESC,CONPOLLKEY,
SLEEP}` (`include/modules.s:93-96`). The loopback transport is built on
`pipe.s`'s rings (`_Pipe_Alloc`/`_Pipe_Read`/`_Pipe_Write`/`_Pipe_FreeSlot`),
all **kernel-resident**. Implementing in the module would mean adding four-plus
new gateway slots purely to reach code the kernel already has — new JT entries,
new wrappers, and a wider module ABI, for a transport that touches no hardware
and therefore has no reason to be in a driver module at all.

**Intercept kernel-side instead.** `_Sock_FdToDesc` already runs in the kernel
and resolves the descriptor — including `_sockTmpHw` — *before* the thunks call
`_Net_Dispatch` into the module (`net_dispatch.s:150-154`, and `syscall.s:909`
for shutdown). So the loopback check sits right there: if
`_sockTmpHw == SOCK_HW_LOOP`, service the call from a kernel-resident
`net_loop.s` and never enter net.mod. Hardware sockets keep the existing path
untouched, and pipe.s is reached by a plain `JSR`.

This also settles the dispatch-key question §2.2.1 left implicit. Do **not**
add an `XPORT_LOOP` value to `SOCK_Proto`: a loopback socket is still a TCP
socket to userland (SOCK_STREAM, same state machine, same `TCP_*` states), and
re-tagging it would break every `SOCK_Proto == XPORT_TCP` check. Key off
`SOCK_HwIdx == SOCK_HW_LOOP`, exactly as `_Net_Xport_SockStatus` already keys
off `SOCK_HW_NONE` before dispatching (`net_xport.s:133-140`).

#### 2.2.3 Increment-5 finding: reuse `_Pipe_Read`/`_Pipe_Write`, do not reimplement

`_Pipe_Read`/`_Pipe_Write` take **`A = fd`** and immediately call
`_Pipe_FdToIdx`; *everything after that* runs off `_pipeRecOff` plus
`_pipeReqLen`/`_pipeBufOff`/`_pipeBufBank`. A loopback socket's fd maps to a
SOCKET descriptor, not a pipe, so they cannot be called as-is — but their
bodies are exactly the wanted semantics.

**Factor out `_Pipe_ReadAt`/`_Pipe_WriteAt`** (entry with `_pipeRecOff` already
set) and reduce `_Pipe_Read`/`_Pipe_Write` to thin fd→recOff wrappers. Loopback
then calls the `*At` forms and inherits blocking, ring wrap, EOF-on-writers-gone,
SIGPIPE-on-readers-gone and the `_wakeup` ordering **already written and already
covered by the pipe fixtures** — which is precisely the part of this campaign
that a green build cannot verify.

Semantics line up better than expected: pipe "all writers gone → EOF(0)" is
socket "peer closed → 0", and pipe "all readers gone → EPIPE/SIGPIPE" is the
socket rule too. One genuine mismatch: non-blocking is `FCB_CDF_NONBLK` on the
pipe path but `SOCK_NB` on the socket, so the `*At` forms need the flag passed
in rather than re-derived from an FCB.

**Risk to weigh before doing it:** this refactors code that PIPES depend on, and
pipes are exercised by real fixtures (`p5_z_pipe.json`, `pipegrow.json`,
`p5_z_pipe_noc.json`). Loopback is new and breaking it costs nothing; breaking
pipes regresses something that works today. The refactor should therefore land
as its own commit, with the pipe fixtures run *before* any loopback code is
layered on top — not bundled into the send/recv increment.

**Remaining work, in order** (all kernel-side; 1–4 done, 5–6 open):
1. `SOCK_Loop{Peer,Rx,Tx,Flags}` + `SOCK_REC_SIZE` 8 → 12, `SOCK_HW_LOOP` `$FE`.
2. `net_loop.s`: pair alloc (two `_Pipe_Alloc` rings), connect-scan for a
   `TCP_LISTEN` descriptor on the port, pending-connection handoff to `accept`.
3. send/recv over the rings, honouring `SOCK_NB` → `EAGAIN`, else sleeping on
   `WCHAN_SOCK`; `_wakeup(WCHAN_SOCK)` on every ring transition.
4. close/shutdown via `PIPE_RdClosed`/`PIPE_WrClosed`; free rings at last ref.
5. `SockStatus` readable/writable from ring `PIPE_Count` and closed flags.
6. `loopback_pair.json` — one program binds/listens/connects to itself, accepts,
   round-trips both directions, headless.

### 2.3 Test strategy

The loopback backend is what makes telnetd **headless-CI-testable**. With it:
`telnet 127.0.0.1` (a foreground process) → local `telnetd &` → `jsh` on a pty —
a fully in-emulator closed loop, byte-checked (`telnet_loopback.json`). Socket
budget for the loop: telnet(1) + listener(1) + accepted conn(1) = **3 of 4**
descriptors; `127.0.0.1` needs no DNS, so no 4th. Pty budget: 1 of 2 pairs.

---

## 3. Phases & gates

Recommended order is **loopback-first** (P1 before P2) so the daemon is headless-
CI-gated from its first landing. Every phase is suite-green and revertible.

- **P0 — compile-probe + headers (~0.5).** ✅ **COMPLETE 2026-08-09.** Source
  vendored byte-exact (`vendor/2.11BSD/usr/libexec/telnetd/`, 26457 B,
  `5.20.3 (2.11BSD) 1996/11/16`). `<arpa/telnet.h>` already existed; the only
  missing header was `<syslog.h>`, now implemented with `%m` support (it goes
  to stderr — there is no syslogd and `SYS_DMESG` only reads the ring).
  **Exactly one fcc gap** in the whole file: prefix `++`/`--` on a dot member in
  *rvalue* position, which `#define settimer(x) (clocks.x = ++clocks.system)`
  lands in — fixed, with fixture `preinc_dot_rvalue`. **Gate met:** unmodified
  telnetd.c compiles against the real headers with no stubs. fcc suite 556/0,
  zero golden churn.

  *(Original P0 text, for the record:)* Fetch 2.11BSD `telnetd.c`;
  fcc-compile-probe it (the string-literal-write `line[i]=c` + any K&R gaps —
  the scope doc's cheap de-risking spike). Add the `<arpa/telnet.h>`-shaped
  header. **Gate:** telnetd.c compiles to an object (stub `main` OK); any fcc gap
  found is a toolchain-first fix (as the telnet.c K&R fn-ptr gap was).
- **P1 — socket-layer loopback backend (~1.5–2).** §2.2 at the `_Net_Xport_*`
  seam. **Gate:** a new `loopback_pair.json` — a single userland program
  `socket`/`bind`/`listen`s on 127.0.0.1 then `connect`s to itself, `accept`s,
  and round-trips bytes both directions, **headless in MAME**. Proves the vehicle
  with no telnetd yet. Suite green.
- **P2 — the daemon (~1–1.5).** §2.1: standalone accept loop + pty-pair session +
  spawnx jsh + 3-fd select/FIONBIO relay + TIOCPKT byte-0 skip + server IAC +
  master-EOF teardown + `waitpid` reap. **Gate:** `telnet_loopback.json` — telnet
  127.0.0.1 → local telnetd → jsh; run `echo TELNETOK`; byte-check the relayed
  output; `exit`/^D → session teardown → telnetd loops. Headless. Suite green.
- **P3 — hardening + docs (~0.5).** Second-session re-listen; FIONBIO
  partial-write edges; in-band ^C to the remote (slave fg pgrp via `tcsetpgrp` —
  the pty plan deferred this assertion); ROADMAP + networking-scope updates; a
  `telnetd.8` man page. **Gate:** a two-session `telnet_loopback` variant; suite green.

## 3.1 P2 status (2026-08-10) — where the byte path actually stands

**telnetd puts the RIGHT BYTES on the wire.** Dumped at the send site:
`70 71 88 47 103 115 13 10 108 111 103 105 110` = `FGX/gs\r\nlogin` — getty's
banner and prompt, exactly correct, sent once (getty then waits, as it should).

So three of the four layers are proven:

| Layer | Status |
|---|---|
| Loopback transport | ✅ `loopback_pair`: both directions, EOF on close, `select` readiness |
| pty + spawn | ✅ getty runs, writes its banner to the master |
| telnetd relay | ✅ reads the master, strips the TIOCPKT byte, sends clean text |
| telnet(1) client | ❌ receives it and renders binary |

**`telnet_loopback` IS RED as of `ce0195f77`** (the IAC commit) and was green at
`7121985ca`. The IAC negotiation floods the client's console with binary, which
scrolls the asserted `telnetd: listening` line away.

**Process failure worth recording:** that commit's message reports a green sweep
of `loopback_pair, p5_z_pipe, smoke, shell_smoke` — it **omitted
`telnet_loopback`**, the one test the change targets. The sweep was green and
also meaningless for the change it accompanied. Run the fixture that covers the
thing you changed, not the neighbours.

**The server side is now exonerated at byte level.** Every outbound byte was
dumped at its send site:

| What | Bytes | Result |
|---|---|---|
| `IAC WILL ECHO` | `255 251 1` | `send` → 3 |
| `IAC WILL SGA` | `255 251 3` | `send` → 3 |
| `IAC DO TTYPE` | `255 253 24` | `send` → 3 |
| getty's prompt | `70 71 88 47 103 115 13 10 108 111 103 105 110` = `FGX/gs\r\nlogin` | `send` → 15 |

All correct, all accepted by the transport.

**And `telrcv` never executes.** Instrumenting the inbound half showed the
`recv(c,…) > 0` branch never fires: the client sends *nothing back* — not a
single option reply. That retired a whole line of investigation, because every
inbound-path theory (option ping-pong, `g_myopt` indexing, char sign-extension)
was reasoning about code that never runs. Two of those were tested and
disproven outright; fcc zero-extends `char` (`AND #$00FF`), so the indexing
theory was false at the premise.

**So the bug is entirely in telnet(1).** It receives 9 bytes of well-formed
negotiation followed by 15 bytes of clean text, renders binary, and answers
nothing — where RFC 854 requires it to answer `DO`/`DONT` to our `WILL`. The
client's own `telrcv` is loop-safe (`if (!hisopts[c])` / `if (!myopts[c])`) and
`printoption` is gated on `showoptions`, so neither is the source.

**RESOLVED, and it was the kernel.** telnet(1) drives its socket with
`read(net,…)`, not `recv()` — a DIFFERENT kernel route that was never wired to
the loopback transport. On a card-less machine it returned a positive count
with an untouched buffer, so the client wrote uninitialised memory to the
terminal. Wiring `@rd_socket`/`@sw_socket` through `net_loop.s` fixed it, and
`loopprobe` now covers both routes.

**The chain works: `login:` HAS been observed.** With telnetd relaying, the
client reaches `FGX/gs` / `login:` — the full stack, headless, no hardware.

**But it only renders with an extra stdout write in the client.** With a debug
`printf` between `telrcv()` and `ttyflush()`, the prompt appears. Without it,
nothing — and this is NOT timing (a 90 s timeout changes nothing). Measured at
the moment of failure: `TTYBYTES()==15`, `SYNCHing==0`, `flushout==0`, and
`ttyflush()` IS entered. So the 15 bytes are in the client's tty buffer, not
being dropped by the `TTYADD` guard, and the flush runs — yet the terminal
shows nothing.

**Four probes, none reproduce it.** Substituting for the `printf` between
`telrcv()` and `ttyflush()`:

| Probe | Prompt renders? | Eliminates |
|---|---|---|
| `printf("… %d …", TTYBYTES(), …)` | **yes** | — (the only thing that works) |
| `write(1, " ", 1)` — real console write, no stdio | no | "a preceding console write primes the driver" |
| `nanosleep(1)` — in-loop yield | no | in-loop timing/scheduling |
| `g_probe = TTYBYTES()` — bare global read | no | fcc caching `tfrontp` across the call |
| 90 s fixture timeout | no | total runtime |

Note the third row also **retracts an earlier conclusion**: "not timing" was
first argued from the 90 s timeout, which only extends *total* runtime and says
nothing about delay at the failure point. `nanosleep(1)` is the test that
actually eliminates it.

Two further probes, both negative:

| Probe | Prompt renders? | Eliminates |
|---|---|---|
| drop `FD_ISSET(tout,&obits)`, flush whenever `TTYBYTES()>0` | no | select failing to report the console writable |
| stack budget inspection | n/a | telnet asks for 3 pages (768 B) and peaks at 546 (`GUARD stkhwm 7 546/768`) — 71 %, no overflow, and `printf` would only *raise* usage, so extra stack cannot be what fixes it |

**This last result contradicts the `printf` run and that matters.** With the
probe in place `ttyflush()` is called unconditionally on a non-empty buffer —
the same call the instrumented run reported as `flushing 15` right before the
prompt appeared — yet nothing renders. Both cannot be true under the model
"telrcv fills the buffer, ttyflush writes it, the console shows it". Something
in that chain is not what it appears, so **the next step is to re-derive the
model, not to run a seventh probe.**

**The client's `read()` is VERIFIED CORRECT.** Measured after the read/write
fix: `c=24, scc=24, b0=255, b1=251` — all 24 bytes in one call (9 IAC + 15
data, starting `IAC WILL`). That was the load-bearing assumption never checked;
it holds. The socket path is not the problem.

**The perturbation is `printf` SPECIFICALLY**, not position and not console
output:

| Probe (either site) | Prompt renders? |
|---|---|
| `printf("… %d …", …)` at the telrcv site | **yes** |
| `printf("… %d …", …)` at the read site | **yes** |
| `write(1, " ", 1)` at the telrcv site | no |
| `write(1, " ", 1)` at the read site | no |
| `write(1, "\n", 1)` at the read site | no |
| `nanosleep(1)` | no |
| `g_probe = TTYBYTES()` | no |
| drop `FD_ISSET(tout,&obits)` | no |

So it is not position, not a console write, not a newline, not a yield, not a
stale global, not select readiness, not stack depth, not total runtime. What
remains unique to `printf`: it is a **varargs call through libc's stdio
machinery** (`__lc_pf_mode`/`__lc_pf_fd`/`__lc_pf_fill`/`__lc_pf_n` are shared
libc globals it sets), and it emits ~30 bytes rather than 1.

**Do not add a tenth probe of this shape.** Nine have now been run and the
space they cover is exhausted; the answer is in something none of them model.
Two concrete directions that are NOT more of the same: (a) diff the emitted
assembly for `telnet()` with and without the `printf` — the perturbation is
visible at build time and costs no emulator run; (b) check whether the shared
`__lc_pf_*` libc globals are read by anything else the client touches, since a
`printf` is the only thing that initialises them.

`telnet_loopback` deliberately does NOT assert `login:` — a gate that depends
on a heisenbug is worse than one that admits the gap.

## 4. Test plan

- **`loopback_pair.json`** (P1) — in-emulator socket-pair round-trip, telnetd-free.
- **`telnet_loopback.json`** (P2) — the closed loop (the scope doc's named
  fixture): telnet ↔ telnetd ↔ jsh, byte-checked, teardown asserted.
- Existing SLIRP host tests (`telnet_smoke`, `telnet_byname`) stay for the client.
- Regression: full suite after each phase (loopback touches the hot socket path).

## 5. Risks & coordination

1. **4-socket ceiling.** The loopback loop fits (3/4, no DNS on 127.0.0.1), but a
   *real-network* telnetd + a concurrent client + a DNS query brushes 4. State it;
   don't design for many concurrent real sessions on the W5100.
2. **2 pty pairs → ≤2 sessions**, and the standalone daemon is one-at-a-time by
   design anyway. Fine for now.
3. **accept detaches the listener** (W5100 single-socket-per-listener) — telnetd
   must re-`socket`/`bind`/`listen` per session; mirror the same semantics in the
   loopback backend for consistency. `echod` already proves the shape.
4. **SIGCHLD is not delivered** — teardown MUST key on master-EOF + `waitpid(
   WNOHANG)`, never `signal(SIGCHLD, cleanup)`. (The BSD source uses SIGCHLD;
   this is the one required behavioral edit.)
5. **Loopback is real kernel/net work** (~half the campaign). If deferred,
   telnetd is only testable from the host over SLIRP (a weaker, non-CI gate) —
   this is the sequencing decision in §6.
6. **In-band ^C end-to-end** (remote ^C → SIGINT to the remote command) needs the
   slave's foreground pgrp set; the pty plan implemented the mechanism but
   deferred the end-to-end assertion pending `tcsetpgrp`. P3 closes it.
7. **Preemption/blocking-I/O overlap** — loopback sleeps on `WCHAN_SOCK`, the same
   surface the preemption P4 train touches; follow the SEI-test-sleep rule and
   sync with that owner before P1.

## 6. Out of scope (follow-ons)

Multi-session/inetd; login/getty (spawn `jsh` directly); LINEMODE/NAWS/BINARY and
authentication/encryption telnet options (minimal ECHO/SGA/TTYPE only, matching
the client); the verbatim BSD `lo0` `ifnet` (Track B, arrives with the software
stack); host-side SLIRP port-forward automation (loopback supersedes it for CI).

## 7. Open decisions

> **ANSWERED 2026-08-09.** (1) Sequencing: **loopback-first**, as recommended.
> (2) Loopback is **in scope** for this campaign. (3) Source: **vendor the
> 2.11BSD original** rather than write against the client's spec. (4) NEW, not
> in the original list — the plan predates `login(1)`, which now exists with
> `crypt(3)` auth and a staged `/etc/passwd`: a session spawns **`/bin/login`**,
> so a telnet connection must authenticate. §2.1 step 3 and §6's "login/getty"
> exclusion are superseded by that.

*(Original list, for the record:)*

1. **Sequencing — loopback-first (recommended) vs telnetd-first.** Loopback-first
   makes telnetd headless-CI-gated from day one but front-loads the kernel/net
   work; telnetd-first reaches a working daemon sooner but its only gate until
   loopback lands is a host-over-SLIRP manual test.
2. **Is the loopback backend in-scope for this campaign** (recommended — it's the
   test vehicle and modest), or a separate prerequisite train?
3. **Session model** — accept the one-session-at-a-time standalone daemon for v1,
   or design respawn-after-session (still ≤2 by the pty-pair cap) now?

Ledger: `project_fgx_networking`. Cross-refs: the networking scope
(`2026-07-19-networking-roadmap-scope.md` §4/§4b/§5), the pty subsystem
(`2026-07-20-pty-subsystem-plan.md`, prerequisite — merged), the preemption
campaign (`2026-07-17-preemption-campaign-roadmap.md`, P4 — `WCHAN_SOCK` overlap).

### Render heisenbug — probes 10-12 (2026-08-10)

Directions (a) and (b) from the previous session are both CLOSED, negative.

**(a) Assembly diff, with/without the probe `printf`.** Naive diff showed 23
functions changing, which looked like global codegen perturbation. It is not:
once `_telnet_L\d+` (branch labels) and `_telnet_S\d+` (string constants) are
normalised, exactly TWO things differ:

  * `telnet()` — the printf call site itself, as expected;
  * `main()` — `FGX2_RELOC_COUNT 345` -> `346`, i.e. one added relocation.

`telnet_FRAMESIZE` (22) and `telnet_STKGUARD` (0) are IDENTICAL in both builds,
and no other function's instruction stream changes. So the printf produces no
build-time perturbation outside its own call site. Whatever it does is a
RUNTIME effect (or a link-set effect invisible in the per-tool .s).

**(b) `__lc_pf_*` libc globals.** Confined to `toolchain/lib/libc_c/printf.c`
and `syslog.c`. telnet(1) links neither except via the probe, and nothing else
reads them. No shared-state coupling exists. Closed.

**(c) Static-initialiser relocation — NEW hypothesis, DISPROVEN.** The reloc
delta in (a) made this attractive: `telnet.c:78` is
`char ttyobuf[2*BUFSIZ], *tfrontp = ttyobuf, *tbackp = ttyobuf;` — two
statically-initialised pointers requiring load-time relocations. A dropped or
mis-applied relocation would leave `tfrontp` pointing at the wrong address,
which fits every symptom (bytes "written" but nothing rendered; garbage before
the read/write fix; a printf shifting the table and masking it).

Tested directly: made both pointers uninitialised and assigned them at runtime
as the first statement of `main()`, with NO printf anywhere. Built clean, and
ran `telnet_loopback` with a temporarily-added `login:` assertion:

    ✓ telnetd: listening / ✓ Connected to 127.0.0.1. / ✓ session on /dev/ttyp0
    ✗ screen missing 'login:'

The prompt still does not render. Static relocation is NOT the mechanism.
Probe and fixture both reverted; `telnet.c` remains untouched.

**Standing count:** twelve hypotheses eliminated. The unexplained contradiction
from the previous session still stands and remains the sharpest lead — dropping
`FD_ISSET` so `ttyflush()` runs unconditionally does NOT render, yet the
instrumented run showed `flushing 15` immediately before the prompt appeared.
That pair cannot both be true of the same code path, which suggests the
instrumented and uninstrumented builds are not executing the same path at all.
Next probe should therefore attack the LINK SET, not the source: compare which
libc objects `libc.fgxa/index.json` dead-strip selects for telnet with and
without printf, since that is the one difference (a) could not see.

### RETRACTED: "root cause" claim of 2026-08-10 (see correction below)

**The link set is identical.** `tools/telnet-fgx2/libc.sel.s` and
`libc.sel.data.s` are byte-for-byte the same with and without the probe printf
(28690 / 38 lines; empty diff; zero new symbols). telnet(1) ALREADY links and
calls printf (`command`, `status`, `help`, `sendcmd`), so an extra call changes
neither the member set nor the data-segment layout. Combined with the earlier
finding that only the call site's instructions change, every static explanation
is exhausted.

**Discriminating probes, each replacing the printf at the same call site:**

| probe | renders? | eliminates |
|---|---|---|
| `strlen(ttyobuf)` — far call, no I/O | NO | generic far-call bank/DP discipline |
| `write(1, "", 0)` — console syscall, 0 bytes | NO | "a console syscall occurs" |
| `tout = 1` instead of `fileno(stdout)` | NO | bad fd from the `__lc_fent` DA-offset wart |
| `write(1, "PROBEXY\n", 8)` — real bytes | **NO** | — |
| `printf(...)` | **YES** | — |

**The finding: raw `write(2)` to fd 1 from telnet(1) produces NO console
output, while `printf` to the same fd works.** The contrast is airtight in the
same run: `Connected to 127.0.0.1.` is telnet's own printf and asserts green,
while an unconditional 8-byte `write(1, ...)` on the following line renders
nothing at all.

`ttyflush()` is built entirely on `write(tout, tbackp, n)` (telnet.c:487). So it
was never failing to run, never short, never mis-timed -- it wrote into the void
every time. A printf anywhere in the loop "fixed" the prompt only because printf
renders bytes that `write` cannot.

This is DETERMINISTIC and reproducible, and has nothing to do with telnetd,
loopback, telrcv, IAC, timing, or the pty. The telnetd chain was correct all
along; the last mile is a libc/console defect.

**Correction to the fixture text.** `tools/mame_test/tests/telnet_loopback.json`
still describes this as a heisenbug requiring "an extra stdout write". That
description is now wrong and should be rewritten once the write(2) defect is
fixed, at which point `login:` becomes assertable unconditionally.

**Next:** determine why `write()` output is dropped -- printf reaches the console
via `__lc_putc1` -> `write(e[0], &ch, 1)`, i.e. THE SAME syscall, so the delta is
in the arguments, most likely the buffer's bank (the wart loopprobe.c:35-40
documents for send/recv, where a caller buffer is passed as a bare 16-bit offset
with the bank defaulting to DBR). A one-byte `write` from libc's own segment
works; an 8-byte `write` from telnet's segment does not. Confirm whether this
affects ALL tools calling write(2) directly, which would make it a general libc
defect rather than a telnet one.

### CORRECTION — the write(2) root cause was WRONG (2026-08-10)

The section above claims raw `write(2)` to fd 1 never reaches the console. That
is FALSE and is retracted. It rested on a single probe
(`write(1, "PROBEXY\n", 8)` rendering nothing) and I generalised from it without
a control. The control disproves it.

**The experiment that overturned it.** Two writes at the same call site:

    { char pb[9]; strcpy(pb,"STAKXY\n"); write(1, pb, 7);   /* stack buf  */
      write(1, "DATAXY\n", 7); }                            /* data-seg   */

BOTH rendered (fixture green on STAKXY and DATAXY). So `write(2)` delivers from
a data-segment buffer perfectly well. Re-run with ONLY the data-segment write
and no stack buffer:

    write(1, "DATAXY\n", 7);        -> ✗ missing 'DATAXY', ✗ missing 'login:'

Same buffer, same fd, same call site, opposite outcome. The variable is NOT the
buffer's bank and NOT write(2).

**libc is not at fault.** `write()` (libc_c/syscall_file.c:20) correctly splits
the far pointer and passes the bank to `__syscall_db`, and the emitted code does
the proper `PHA/PLB` around `JSL SYS_TRAMP` with a matching `PLB` restore.
`printf` reaches the console through THE SAME `write()` via
`__lc_putc1` (stdio_out.c:1-7). There is no defect in the write path to fix.

**What actually correlates.** Every probe that makes output appear also GROWS OR
CHURNS THE STACK at that point -- printf (deep call chain, internal buffers), and
`char pb[9]` + `strcpy`. Every probe that does not renders nothing --
`strlen(ttyobuf)`, `write(1,"",0)`, a lone `write` of a literal. Note
`telnet_FRAMESIZE` is unchanged (22) by printf but IS changed by adding `pb[9]`.

This RESURRECTS the stack hypothesis, previously recorded as eliminated on the
strength of a 546/768-byte peak measurement. 546 of 768 is not comfortable
headroom, `telnet_STKGUARD` is 0 (guard disabled), and the earlier elimination
measured a PEAK rather than testing whether the console/VT state is adjacent to
what an overrun would clobber.

**Process failure to carry forward:** I asserted a root cause from one probe with
no control, and wrote it into the plan as settled. The immediately preceding
entry in this same document records the identical mistake pattern. A single
positive probe is a hypothesis, not a finding; it needs a control that should
behave differently before anything gets called a root cause.

**Next:** re-open the stack line of enquiry -- determine telnet's actual stack
extent and what lies immediately below it, and test whether console/VT state or
the fd table sits within reach of an overrun at the moment ttyflush() runs.

### telnet(1) stack map (2026-08-10)

**Reservation.** `stack_measure.stack_pages(['tools/telnet-fgx2/telnet.s'])`:

    pages reserved : 3  -> 768 bytes
    worst          : 132     (deepest measured frame chain)
    pad            : 128     (DEFAULT_PAD)
    indirect_extra : 142     (6 indirect call sites, maxfn 121)
    signal_extra   : 142     (has_signal: True)
    total          : 544     -> headroom 224 B of 768
    deepest path   : main(0) -> tn(6) -> telnet(22) -> telrcv(2)
                     -> willoption(4) -> setconnmode(0) -> mode(40)
    cycles / mutual_cycles / unguarded_cycles : all empty
    clamped: False   floored: False   argstats: 79 edges, 6 unparsed

**Placement.** Stacks come from the bounded bank-0 arena `FGX_STK_ARENA`
($1900-$B4FF, 156 pages at NPROC=10; include/kernel.s:296,328), carved by a
FIRST-FIT contiguous-run page-bitmap allocator (`Task_AllocStack`, task.s:584,
1620) -- NOT the Memory Manager. Small stacks first-fit from the arena base;
BIG stacks (TASK_STACK_BIG_PAGES, e.g. tcsh) scan DOWN from the top, using size
as a proxy for lifetime because the arena can never be compacted (fcc frames
hold absolute bank-0 addresses). telnet at 3 pages is a small stack, so it is
placed first-fit low in the arena.

**What is below.** Descending from telnet's StackPtr:

  1. `[_fcc_stkfloor, StackPtr]` -- live C frames.
  2. `[StackBase, _fcc_stkfloor)` -- the 128-byte MARGIN pad. LEGAL for non-C
     users: the signal trampoline, IRQ and shim pushes (crt0_far.s:548-556).
     `_fcc_stkfloor` = StackBase + 128 (DP $B9, fcc_runtime.s:121).
  3. Below StackBase -- ANOTHER TASK'S STACK PAGES. There is no guard page: the
     allocator hands out contiguous runs, so the page under telnet's base
     belongs to whichever task first-fit placed there (here: init/sh/telnetd/
     getty). task.s:1667 names this "exactly the silent-neighbour-corruption
     case the campaign exists to remove".

**Two gaps worth noting.**

  * The model measures ONLY the tool's own `.s` -- telnet_fgx.json declares
    `"stack_frames": ["telnet.s"]`, and EVERY tool manifest follows that shape.
    libc frames (`write`, and printf's whole chain) are therefore NOT counted;
    the 128-byte pad is what stands in for them. So the real depth at the moment
    ttyflush() calls write() is the measured 132 PLUS libc's frames, against a
    pad sized 128.
  * `telnet_STKGUARD EQU 0` -- the per-function floor check is compiled out for
    telnet(), so an overrun there is silent rather than trapped.

**Not yet established:** whether an overrun actually occurs, and whether the
console/VT state or fd table is reachable from telnet's stack base. The
arena is bank-0 and so is the kernel's VT state, but adjacency has NOT been
demonstrated -- that is the next measurement, not a conclusion.

### VT-state adjacency: DISPROVEN (2026-08-10)

The overrun-corrupts-console theory requires telnet's stack and the console's
VT state to be neighbours. They are not even in the same bank.

    CON_VT_STATE   08/EC40   DS $0100      (src/kernel/far/far.s:285, DUM section)
    telnet stack   00/1A00 - 00/B3FF       (FGX_STK_ARENA, 154 pages; config.s:26,28)

VT state lives in BANK $08 ($EC40-$ED3F, 256 bytes) -- it is console-owned far
storage, consistent with its home under src/kernel/far/console/. The per-task
user-stack arena is BANK $00. A bank-0 stack overrun cannot reach bank-8 VT
state by any amount of overrun; they are not adjacent, not in the same 64 KB,
and no wraparound connects them.

So the chain "deeper stack -> overrun -> clobbered VT state -> no render" is
dead at its second link. What actually lies below a task's StackBase remains
ANOTHER TASK'S STACK PAGES (first-fit contiguous runs, no guard page,
task.s:1667) -- corrupting a neighbour would break that task, not the console.

**Status of the stack line of enquiry.** The correlation noted earlier is real
(every probe that renders also moves the stack pointer; every probe that does
not, does not), but the mechanism proposed for it is refuted. The correlation
now has NO candidate mechanism, and "stack depth" should not be cited as the
cause until one exists.

**Caveat on a stale note.** A 2026-07-14 memory records CON_VT_STATE near
$ED1E/$ED22; that referred to fixture-baked addresses in console_hrprof, not to
this symbol's load address. The authoritative value is the linker's: 08/EC40.

**What is still unexplained.** A lone `write(1, "DATAXY\n", 7)` after telrcv()
renders nothing, while the same write preceded by `char pb[9]; strcpy(...)`
renders both. Same fd, same buffer class, same call site. No mechanism yet
accounts for that, and three have now been eliminated (write(2) itself, buffer
bank, VT-state adjacency).

### Neighbour task below telnet's stack: NOT DETERMINED (2026-08-10)

Attempted to read it directly rather than infer it. Result is inconclusive and
is recorded as such.

**Method.** The arena page bitmap is `_stkArenaMap` (src/kernel/task.s:2624,
`DS FGX_STK_ARENA_PAGES`), resolved by the linker to **02/A036, 154 bytes** --
one byte per arena page. fgxdebug's dump regions are a plain
`{name, addr, len}` list (tools/mame_test/plugins/fgxdebug/init.lua:84-90), so a
region was added:

    { name = "stk_arena_map", addr = 0x02A036, len = 154 },

**Result.** Fixture green, region captured, and every one of the 154 bytes read
ZERO -- i.e. the whole arena $1A00-$B3FF reported free. That cannot be true of a
live system: init and the shell hold stacks for the machine's entire life. So
the read is wrong, not the arena. Three candidate explanations, untested:

  * TIMING -- the dump is taken at test end (`sampled_at_frame: -1` on every
    region). telnet and telnetd have exited by then, but init/sh should still be
    resident, so timing alone does not explain an ALL-zero map.
  * ADDRESS -- 02/A036 is where the listing places the DS. If the map is
    relocated, shadowed, or the region is bank-mapped differently at runtime,
    the region samples the wrong memory.
  * ENCODING -- the allocator may not use 0=free (the run was a first-fit scan
    over `_stkArenaMap`; the sense of the byte was assumed, not read from
    Task_AllocStack).

**Not concluded.** The neighbour task below telnet's StackBase is still unknown.
What remains established is only the structure: first-fit contiguous runs from
$1A00, no guard page between runs, and the pad region [StackBase, StackBase+128)
legal for non-C pushes. Identifying the actual neighbour needs a correct read of
`_stkArenaMap` (verify the byte sense in Task_AllocStack first) or a dump of
TCB_StackBase per task, sampled while the session is LIVE rather than at exit.

The probe is reverted; init.lua is unmodified.

### _stkArenaMap byte sense: CONFIRMED 0=free, 1=allocated (2026-08-10)

Read out of the allocator rather than assumed:

  * `src/kernel/task.s:818` -- `@tas_scan  LDA: _stkArenaMap,X   ; 0 = free`
    followed by `BNE @tas_runReset`: a NONZERO byte breaks the free run, so zero
    is free. The comment and the branch agree.
  * `src/kernel/task.s:884-887` -- the mark loop is `LDA #1` (SEP #$20, 8-bit)
    then `STA: _stkArenaMap,X` / `INX` / `DEY` / `BNE`. Allocated pages are
    written as **1**, one byte per page. It is a plain used/free flag -- it does
    NOT record an owner, so this map alone can never name the neighbour TASK,
    only show which PAGES are taken.
  * `src/kernel/task.s:68` -- `@ti_zmap STZ _stkArenaMap,X` zeroes the map at
    init, consistent with 0=free.
  * No DUM/ORG surrounds the `DS` at task.s:2624, so 02/A036 is a real address.

**Consequence for the inconclusive read.** ENCODING is eliminated as the
explanation for the all-zero dump -- the decode was right. That leaves TIMING or
ADDRESS. Timing is now the strong candidate: the dump samples at test end
(`sampled_at_frame: -1`), by which point telnet, telnetd and getty have all
exited and `Task_FreeStack` has cleared their pages. An all-zero map would then
be an accurate picture of the WRONG MOMENT.

**Also learned, and it changes the plan.** Because the map stores 1 rather than
an owner id, identifying the neighbour TASK cannot be done from `_stkArenaMap`
at all. It gives page occupancy only. Naming the neighbour requires
`TCB_StackBase`/`TCB_StackSize` per task (include/kernel.s:522 and the TCB
array), sampled while the telnet session is LIVE. That is the measurement to
build next -- the arena map was the wrong instrument for the question.

### Live TCB stack map — what is below telnet's stack (2026-08-10)

Sampled LIVE, not at exit. fgxdebug supports a per-region sample frame
(`{"name":..., "frame":N}`, init.lua:172-182) and b3three.json already uses it
for the task table, so no plugin change was needed -- five frame-sampled regions
were added to the fixture:

    {"name":"tcb2400","kbank":true,"addr_hex":"0800","len":768,"frame":2400}

TCB table base is 02/0800 (12 x 64 = 768 B ending at $020B00, kernel.s:446);
field offsets from the DUM block at kernel.s:512-522 -- TCB_TaskID +$00,
TCB_Status +$02, TCB_StackBase +$0C, TCB_StackSize +$0E.

**Result (frame 4320, session live), ascending StackBase:**

    $1A00-$1CFF    768B  slot 0  TaskID=1  Status=3
    $1D00-$1FFF    768B  slot 4  TaskID=5  Status=3   ABUTS
    $2000-$22FF    768B  slot 5  TaskID=6  Status=3   ABUTS
    $2300-$25FF    768B  slot 6  TaskID=7  Status=1   ABUTS
    $2600-$2AFF   1280B  slot 7  TaskID=8  Status=3   ABUTS
    $2B00-$2DFF    768B  slot 8  TaskID=9  Status=3   ABUTS
    $5600-$65FF   4096B  slot 3  TaskID=4  Status=3   (gap $2800 below it)

**The answer.** The arena is packed SOLID from $1A00 to $2DFF -- six task stacks,
every one abutting the next, ZERO gaps and NO guard pages between them. telnet
is a 3-page/768 B stack, so it is one of the 768 B slots; being the last thing
spawned it is almost certainly TaskID 9 at $2B00-$2DFF, whose lower neighbour is
TaskID 8 at $2600-$2AFF (1280 B), abutting exactly at $2AFF/$2B00. (Slot-to-name
mapping is not proven -- the TCB carries TaskID, not a command name -- so treat
the identification as probable and the ADJACENCY as certain.)

So what is below telnet's StackBase is the TOP of an adjacent live task's stack,
i.e. its most recently pushed data, one byte away. There is nothing in between:
no guard page, no poison, no unmapped page that would fault. An underflow is
therefore SILENT by construction, which is what task.s:1667 means by "the
silent-neighbour-corruption case".

**This still does not prove an overrun occurs.** It establishes the consequence
if one did, and rules out any possibility of it being caught. Combined with the
earlier finding that `telnet_STKGUARD EQU 0` (floor check compiled out) and that
the stack model measures only telnet.s (libc frames uncounted, 128 B pad standing
in for them), telnet has: no guard, no margin accounting for libc, and a live
neighbour one byte below. What is missing is evidence that the 224 B of modelled
headroom is actually exceeded.

Fixture reverted.

### CORRECTION: there IS a guard page. And the HWM instrument already exists.

**I was wrong to say "no guard page".** `src/kernel/task.s:645-652`:

    @tas_pagesOK    INC              ; +1 GUARD page below the stack
                    STA _tas_npages  ; N+1 pages allocated (guarded)

Every arena allocation carves N+1 pages, the extra one BELOW the stack. The
earlier claim ("zero gaps and no guard pages", from the live TCB map) misread
the map: stacks abut because `TCB_StackSize` is `_tas_npages << 8`, i.e. it
INCLUDES the guard page. There is no gap BETWEEN allocations because the guard
is inside the allocation, at its bottom.

So for telnet's $2B00-$2DFF / 768 B:

    $2B00-$2BFF   GUARD page (256 B)
    $2C00-$2DFF   usable stack (512 B)

and `_tas_npages` = 3 means N = 2 pages were REQUESTED. Note that my ad-hoc
`stack_measure.stack_pages(pad=128)` returned 3 for telnet with a modelled total
of 544 B; if the linker's hint matches that, the request would have been 3 and
the allocation 4 pages / 1024 B, which the live TCB contradicts. The manifest's
own `stack_pad` may differ from the 128 I passed. UNRESOLVED, and it matters:
if usable really is 512 B against a modelled 544 B need, the reservation is
already short before libc frames are counted at all.

**The measurement is already built and I should have looked for it first.**
task.s:1656-1668 documents the method: fill with `STK_PAINT = $A5A5`
(task.s:1682) at carve time via `_Tas_PaintStack` (task.s:908), then at FREE
time scan upward for the first non-paint word -- `_Tas_ReportHwm` (task.s:935),
emitting a `stkhwm` line naming a pid with an ` w=` field. Nothing is sampled,
so even a one-instruction excursion between timer ticks is counted. Crucially:
"an hwm larger than the reservation means the guard page was entered, which is
exactly the silent-neighbour-corruption case".

**How to finish this.** Do NOT hand-roll a watermark. Run telnet_loopback and
read the `stkhwm` line for telnet's pid out of the KLOG (the report is
KLOG-only -- task.s:2600-2611 notes `_kernLogMirror` is forced to 0 around these
so they never reach the console, precisely because a probe on a hot path
destroys the evidence). hwm > 512 B proves the guard page was entered; hwm > 768
proves the neighbour was reached. That is the direct proof, and it needs no new
instrumentation -- only a way to surface KLOG into the fixture dump.

### KLOG surfaced; stkhwm read; telnet's own number NOT obtained (2026-08-10)

**Surfacing KLOG needs no new code.** run.py already supports pointer-indirect
regions (run.py:568-575) and b3lane.json already uses the exact idiom:

    {"name": "klog", "ptr_addr_hex": "CFG_DP_KTASKS+B0", "len": 4096}

Added to telnet_loopback, the dump carried 4096 B / 30 lines of kernel log.

**The stkhwm lines present:**

    stkhwm 3 126/768  @1D00  w=0F08      -> pid 3 used 126 B of 768  (16%)
    stkhwm 2 208/4096 @5600  w=00A5      -> pid 2 used 208 B of 4096 (5%)

**telnet's line is ABSENT, and the reason is structural.** The fixture command is

    /testbin/telnetd 2323 & telnet 127.0.0.1 2323

telnet runs in the FOREGROUND and never exits -- the run ends on timeout with the
client still live. `_Tas_ReportHwm` is called from the FREE path (task.s:935),
so a task that never exits never reports. No amount of re-running this fixture
as written will produce telnet's watermark.

**So the headroom question is still open** -- but the evidence now leans AGAINST
the overrun hypothesis, and that should be said plainly. Neither task that did
report came anywhere near its reservation (16% and 5%). Nothing in this run
shows a stack under pressure. That is not proof about telnet specifically, whose
frames differ, but it is the first evidence that bears on the question at all,
and it points away from the stack.

**To finish:** make telnet exit before the dump, then re-read the same klog
region. Options, cheapest first: (a) drive the client's escape sequence + `quit`
from the fixture input; (b) kill telnetd so the connection drops and telnet exits
on EOF; (c) add a `frame`-sampled klog region -- USELESS here, since the problem
is that the report is never EMITTED, not that it is sampled too late.

Reading `w=` is also worth doing when that lands: it is the word found at the
deepest touched address. pid 2's `w=00A5` is half a STK_PAINT word ($A5A5),
i.e. the deepest write was a single byte into a painted word -- a detail the
raw hwm number alone would hide.

### STACK HYPOTHESIS IS DEAD — headroom is nowhere near exceeded (2026-08-10)

I did not kill telnetd. A better instrument already exists and needs no exit,
no pid guessing, and no change to the fixture command: **`stack_excursion`**, a
manifest key wired end to end (run.py:658-672, init.lua:897-933). It installs
ONE write-tap over the user-stack arena and aggregates, per task DP, the
absolute `min_S` plus the per-instant excursion `e = _fcc_fb-1-S`. Being live,
it covers the exact window where the prompt fails to render -- whereas the
`stkhwm` line only exists at FREE time, which is why the earlier run had none
for telnet.

Its default range is `$3000..$B000`, which would have MISSED the whole telnet
neighbourhood; set explicitly to `{"lo_hex":"1A00","hi_hex":"B400"}`.

Correlated against a frame-sampled TCB region from the SAME run
(TCB_DirectPage +$10 -> the tap's DP key):

    DP     pid tid   StackBase..Top   size  floor   min_S   USED  HEADROOM
    $B500   0   1    $1A00..$1CFF      768  $1A80  $1C6D    147     493
    $B800   3   4    $5600..$65FF     4096  $5680  $64E7    281    3687
    $B900   4   5    $1D00..$1FFF      768  $1D80  $1F62    158     482
    $BA00   5   6    $2000..$22FF      768  $2080  $2262    158     482
    $BB00   6   7    $2300..$25FF      768  $2380  $24FF    257     383
    $BC00   7   8    $2600..$2AFF     1280  $2680  $2944    444     708
    $BD00   8   9    $2B00..$2DFF      768  $2B80  $2D5D    163     477

**No task comes close.** The deepest single user is tid 8 at 444 B of 1280.
The TIGHTEST margin anywhere in the run is tid 7 with 383 bytes still free
below its deepest push. telnet is one of the 768 B stacks (tid 9 at $2B00 is
the last-spawned and the likeliest, but the TCB carries no program name, so
take the identification as probable) -- and it does not matter WHICH it is,
because every candidate has 383-493 bytes of headroom.

Nothing entered a guard page. Nothing approached a floor. Nothing came within
hundreds of bytes of a neighbour. **The stack overrun hypothesis is refuted,
and with it the whole "deeper stack -> corruption -> no render" chain.**

This also settles the page-count question left open earlier: `TCB_StackSize`
768 IS `_tas_npages << 8` with the guard included (N=2 requested), and
`floor = StackBase + 128`, so C code owns $2B80..$2DFF = 640 B. telnet used 163
of that 640. The reservation was never tight.

**Where this leaves the render bug.** Every mechanism proposed so far is now
eliminated: write(2) itself, buffer bank, __lc_pf_* coupling, link set, static
relocations, codegen perturbation, VT-state adjacency, and now stack depth. The
ORIGINAL observation still stands and is still unexplained:

    write(1, "DATAXY\n", 7)                       -> nothing renders
    char pb[9]; strcpy(pb,"..."); write(1,pb,7);
      followed by write(1, "DATAXY\n", 7)         -> BOTH render

The correlation with "probes that move the stack pointer" is real but its
mechanism cannot be stack capacity. The next honest step is to stop proposing
mechanisms and instead capture what actually differs at the syscall boundary
between the rendering and non-rendering builds -- e.g. `capture_writes`
(a run.py manifest key, untried here) to tap the actual console writes and see
whether the failing case reaches the kernel at all.

Fixture reverted.

### capture_writes: the console renderer is NEVER ENTERED in the failing case (2026-08-10)

Used `capture_writes` (run.py:632-645, init.lua:1197-1229): an instruction-precise
write-tap giving writer PB:PC + registers + stack chain per hit.

**Making it usable.** It keeps the FIRST `max_hits` hits and then stops
(init.lua:1203), so any console address fills with boot noise. Two adjustments
were needed: tap a region that is QUIET after boot (CharBuf row 7 -- rows 0-6
hold the boot/telnetd banner, 7+ are blank), and raise `max_hits` past the
one-time clear. CharBuf resolved to **$3D0000**, stride 320 B/row, so row 7 is
$3D08C0..$3D09FF. Note the default 8-byte tap MISSED the text by 18 bytes; the
first two attempts were geometry failures, not null results.

**The pair.** Same call site, same fd, same 7-byte literal:

    RUN A   write(1, "DATAXY\n", 7);                        -> does NOT render
    RUN B   char pb[9]; strcpy(pb,"STAKXY\n"); write(1,pb,7);
            write(1, "DATAXY\n", 7);                        -> RENDERS

Tapping all 320 B of row 7:

    RUN A: 320 hits.  Writers: {7E:0B82 x320}.   NON-SPACE writes: 0
    RUN B: 579 hits.  Writers: {7E:0B82 x320, 7E:12B8 x3,
                                7E:12C4 x237, 7E:14A9 x19}. NON-SPACE: 18

Writer PCs resolved against the far listing:

    7E:0B82  console_init.s:302     one-time screen clear (boot)
    7E:12C4  console_buffer.s:80    MVN scroll / buffer move
    7E:14A9  console_char.s:261     THE CHARACTER CELL WRITER

**The finding.** In RUN A the only writer that ever touches row 7 is the boot
clear. `console_char.s` is NEVER ENTERED -- not once, not with a space. The
console renderer does not run at all. In RUN B the same routine writes 18
characters, and the captured data is not just the probe:

    $3D08D2 D A T A X Y        <- the probe
    $3D0928 F G X / g s        <- THE BANNER
    $3D0960 l o g i n          <- THE LOGIN PROMPT

So RUN B reproduces the whole chain end to end, prompt included, and RUN A
produces zero console activity.

**What this localises.** The failure is NOT in telnet's buffer handling, not in
ttyflush's arithmetic, and not in the console renderer (which works perfectly
when reached). Between `write(2)` -- proven correct, and the very call printf
uses -- and `console_char.s`, the bytes are lost with no console-side trace.

**The next question, stated precisely:** does the failing build ISSUE the write
syscall at all? Two cases, distinguishable and worth separating before any more
theorising:
  (a) the syscall is never issued -> the defect is in the client's control flow;
  (b) it is issued and returns a byte count, but the bytes are routed somewhere
      other than the console (a pty, a detached tty, a stale fd) -> the defect is
      in fd/tty routing, and telnetd's spawn_login dup2 of the pty slave onto
      0/1/2 is the obvious suspect to examine first.
Capturing write()'s RETURN VALUE in the failing build separates (a) from (b) in
one run and needs no new instrumentation.

All probes reverted; telnet.c, the fixture and init.lua are clean.

### write() RETURNS 7 — the syscall succeeds, the bytes never reach the console (2026-08-10)

Probe used GLOBALS only (no stack growth, so the failing behaviour is preserved
-- a `char pb[9]` would have flipped the build into the rendering case):

    int g_wcount = 0, g_wret = -999, g_werrno = -999;
    ...
    g_wcount++;
    g_wret = write(1, "DATAXY\n", 7);
    g_werrno = errno;

Reading them back needed the RUNTIME data bank, not the link-time `0B:168A`.
TCB_DataBank (+$12) gave seven candidates; all seven were dumped at $xx168A and
only one held a coherent triple:

    bank  g_wcount  g_wret  g_werrno
    $5C          2       7        25      <- telnet
    $48      31092    8224    26223       (unrelated data)
    $59      27941   12032    26978       (unrelated data)

**THE RESULT: `write(1, "DATAXY\n", 7)` RETURNS 7.** The syscall is issued, the
kernel accepts all seven bytes and reports success -- while `console_char.s` is
never entered (previous section). This is case (b): the write is REAL and the
bytes are routed somewhere that is not the console.

`g_werrno` = 25 = ENOTTY is STALE, not from write: write succeeded, so errno was
left by an earlier call (telnet ioctls the tty during mode setup). Do not read it
as write's error.

`g_wcount` = 2: the probe path ran exactly twice.

**Incidental correction.** Bank $5C is tid 8, StackBase $2600, size **1280 B** --
so telnet is the 5-page task, NOT tid 9 at $2B00 as I guessed when reading the
stack map. The earlier identification was flagged as probable and it was wrong.
This does not change the stack conclusion: tid 8 used 444 B of 1280 with 708 B
of headroom, still the roomiest task in the run.

**Leading hypothesis, stated as a hypothesis.** telnet's fd 1 is not the console
at the moment of the write -- it points at something that silently accepts bytes
(the pty). telnetd's `spawn_login` performs file_actions {DETACH, open slave->3,
dup2 3->0/1/2}; if that manipulation touches a SHARED fd table, another task's
fd 1 is re-pointed for a window. That would explain every observation at once:
a successful write with no console activity; extreme sensitivity to any added
work (which shifts timing past the window) without any static difference in
codegen, link set or layout; and printf "fixing" it because its many one-byte
writes straddle the window.

Note this REOPENS timing, which I previously recorded as eliminated on the
strength of a 90 s timeout. That test was invalid for a race that resolves in
milliseconds during spawn -- a longer timeout only extends total runtime.
This is the same family as the `_fd_table_ptr` staleness bug already fixed once
in this campaign (a sleeping syscall holding a stale table pointer), which is
reason to look there first rather than treat it as novel.

**Next:** dump telnet's fd-table entry for fd 1 at the moment of the failing
write and compare it with the console's descriptor -- that converts the
hypothesis into a fact or kills it. All probes reverted.

### fd-routing hypothesis: DISPROVEN — telnet's fd 1 IS the console (2026-08-10)

No source change needed: the UNMODIFIED build is the failing case.

`TCB_FdTablePtr` is offset **$2E** (aliased onto TCB_CPUTime, kernel.s:607); the
table is `FS_MAX_FDS`=30 entries x 3-byte long pointers to a file structure,
0 = closed (fs.s:334-346). Two runs: TCB dump for the pointers, then a dump of
each task's first four fds.

    tid   fd0       fd1       fd2       fd3
      1  $4118D4  $4118D4  $4118D4  $000000     init  (its output RENDERS)
      4  $4118D4  $4118D4  $4118D4  $000000
      5  $417901  $417901  $417901  $000000
      6  $417A15  $417A15  $417A15  $000000
      7  $41793A  $4118D4  $4118D4  $417AB7     (telnetd; fd3 = pty)
      8  $4118D4  $4118D4  $4118D4  $417BCB     TELNET (bank $5C); fd3 = socket
      9  $4180F1  $4180F1  $4180F1  $000000

**telnet's fd 1 = $4118D4 = the SAME file structure as init's fd 1** -- and
init's writes render. Sampled at six points spanning actual frames 3920-4320
(the whole live window; the run ends ~4400) it NEVER changes:

    req2000/2100/2200/2300/2400/2450 -> $4118D4 every time, fd3 stable too

So the bytes are not being routed to a pty, a detached tty or a stale fd. The
hypothesis from the previous section is dead, and with it the `spawn_login`
dup2 / shared-fd-table race it rested on.

*Caveat stated rather than papered over:* six samples with ~100-frame gaps cannot
exclude a transient shorter than the gap. But a transient would have to coincide
exactly with the write, and nothing else supports it -- write() returned 7, which
is a SUCCESSFUL write to a VALID fd, not the signature of a corrupted table.

**Where the bytes are lost is now bounded on both sides.** fd 1 resolves to the
console file structure, write(2) accepts 7 bytes and returns 7, and
`console_char.s:261` is never entered. The loss is INSIDE the console/tty path,
between the file structure's write entry and the character renderer. Candidates,
none tested:
  - tty output discipline: bytes queued but output STOPPED (XOFF/flow control);
  - virtual-console targeting: written to a VC that is not the displayed one
    (console_switch.s / console_altscreen.s / CON_ALT_SAVE exist);
  - raw-mode output handling: telnet sets raw mode via ioctl in mode()/
    setconnmode(); note the stale errno 25 (ENOTTY) proves SOME ioctl failed
    earlier in this process.

**Next probe:** tap the console device's write entry (not the character writer)
and see whether it is called at all in the failing case. That splits the
remaining span in half -- if it IS called, the loss is inside the console driver;
if it is NOT, the loss is in the tty/file layer above it.

Fixture reverted; no source was modified for this measurement.

### Console write entry: three more mechanisms eliminated (2026-08-10)

Walked the write dispatch (`_Sys_Write`, syscall.s:2019) and measured the state
it branches on. No source change: the unmodified build is the failing case.

**1. telnet's fd 1 is a CONSOLE pseudo-fd, not a chardev.**
FCB $4118D4 dumps as `80 00 00 ...`; `FCB_Flags` is offset 0 (verified: `DUM 0`
at fs.s:348, "bit7=console pseudo-fd"), so flags = $80 = `FCB_FL_CONSOLE`.
The write therefore takes `@sw_console` (syscall.s:2091) -> per-byte
`KFAR_CON_WRITE`. It does NOT take `@sw_chardev`, so `_Vc_WriteEnter` and the
whole off-screen-ttyv suppression path (ttyv.s:518-548) -- which looked like an
exact match for "write succeeds, nothing renders" -- is NOT ON THIS PATH.

**2. No virtual-console switch.** `_kVcActive` (symbol-resolved, 02/EE30) reads
$0000 at every sample across actual frames 3920-4320. The active VC never
changes, so nothing was rendered to an off-screen bank.

**3. The VT parser is not stuck mid-escape.** `CON_VT_STATE` reads 16 zero bytes
at every sample. Address $7E:EC40 -- the far bank relocates 08->7E at runtime,
confirmed independently by console CODE (console_char.s:261 = listing 08/14A9,
observed executing at 7E:14A9). Con_Init zero-inits this region, so all-zero is
the idle state, not an unmapped read. A parser sitting in a partial ESC sequence
would eat characters exactly as observed -- it isn't.

**Where the loss now sits.** The span is down to: `@sw_console` entry ->
per-byte `KFAR_CON_WRITE` -> `console_char.s:261` (never entered). Everything
either side is proven good: fd valid, FCB flags correct, branch correct, VC
correct, parser idle, write returns 7.

**One structural observation, offered as a hypothesis and NOT as a finding.**
`_Sys_WrFd`, `_Sys_WrRem`, `_Sys_WrMax`, `_Sys_WrBufOff`, `_Sys_WrIsCon`
(syscall.s:476-483) are SINGLE GLOBAL kernel-bank statics -- one set for the
whole system, not per task. The loop is driven by `_Sys_WrRem` while the RETURN
value comes from `_Sys_WrMax`, so a set that is clobbered mid-write emits fewer
bytes (or none) and STILL RETURNS THE FULL COUNT -- precisely the signature
observed. telnetd is writing to the same console at the same moment, so two
tasks are live in this code concurrently.

CAVEAT, stated because the last three hypotheses died on exactly this kind of
gap: I have NOT found a yield point inside `@sw_console` -- the loop contains
only `KFAR_CON_WRITE` calls. This mechanism requires either preemption inside
syscalls or a sleep inside Con_Write, and NEITHER is established. It is the same
FAMILY as the `_fd_table_ptr` staleness bug already fixed in this campaign
(a syscall holding shared state across a sleep), which is why it is worth
checking first -- not evidence that it is true.

**Next probe (one run, decisive):** dump `_Sys_WrRem` and `_Sys_WrIsCon` by
symbol, frame-sampled across the failing window. If `_Sys_WrRem` reaches 0 or
`_Sys_WrIsCon` is clear while telnet's write is in flight, the shared-static
corruption is confirmed; if they are consistent, this mechanism dies too and the
remaining span is inside Con_Write itself.

Fixture reverted; no source modified.

### _Sys_Wr* dump: no corruption — and the system goes WRITE-SILENT (2026-08-10)

**Static result first (free, and load-bearing).** The kernel does NOT preempt
kernel code: `toolbox.s:337` -- "Model A: this never preempts kernel code; the
dispatcher honors it between syscalls"; corroborated by task.s:5, pipe.s:16,
signal.s:18. The console write path contains no sleep/yield (no _Sched_Sleep /
WCHAN / Yield in console_vt.s or console_char.s). So the global `_Sys_Wr*`
statics CANNOT be clobbered by a concurrent task mid-loop. The shared-static
hypothesis is refuted before the run, and the run agrees: **`_Sys_WrRem` is 0 at
every one of 36 samples** -- every write loop drained normally.

**A sampling error I made, and its consequences.** Boot is 32 s ~ 1920 frames,
and a manifest `frame: N` samples at ACTUAL N+1920. My earlier windows
(requested 2000-2400 = actual 3920-4320) were therefore ~33 s AFTER the command
started -- the tail of the run, long after all activity. The fd-table, `_kVcActive`
and `CON_VT_STATE` results stand (those are stable state, and fd tables do not
change), but none of them sampled the moment of the failing write. Re-run at
early frames:

    req(actual)  WrMax  WrFd  WrRem
     180 (2100)      1    11      0
     220 (2140)      1    11      0
     230 (2150)     26     1      0
     260 (2180)     31     1      0
     ...
     330 (2250)     31     1      0
     ... frozen at (31, fd 1, 0) through actual frame 4320, end of run ...

**THE FINDING: after actual frame ~2180 the ENTIRE SYSTEM performs no write
syscall of any kind for the remaining ~2200 frames (~37 s).** Every write sets
`_Sys_WrMax` to its count, so a later write of any size would move it. It never
moves.

Consequences, in order of importance:

  1. **telnet's ttyflush write NEVER EXECUTES.** `ttyflush()` calls
     `write(tout, tbackp, n)` with n=15 for the prompt; `_Sys_WrMax` never holds
     15 anywhere in the run. The bytes are not written and then lost in the
     console -- they are never written at all.
  2. **Nor does anything else write.** getty never writes the login prompt
     either. The last two writes are 26 B and 31 B to fd 1 -- almost certainly
     "Connected to 127.0.0.1." and "telnetd: session on /dev/ttyp0", both of
     which DO appear on screen. Everything that is written renders; nothing else
     is written.
  3. So the defect is UPSTREAM of the console entirely, and upstream of
     ttyflush. The previous section's conclusion -- "the loss is inside the
     console/tty path" -- is WRONG and is retracted. `console_char` never runs
     because no write ever reaches it, not because it drops anything.

**What this reframes.** The kernel is COOPERATIVE (no preemption of kernel code;
`_kYieldReq` is honoured only between syscalls). A system that goes completely
write-silent for 37 s while a fixture waits is the signature of tasks not being
scheduled, not of bytes being dropped. That makes scheduling/yield behaviour --
which task holds the CPU after the session is established, and whether getty ever
runs -- the thing to measure next, and it fits the one durable observation of
this whole investigation: that adding work to telnet's loop changes the outcome.

NOTE this is a HYPOTHESIS, not a finding; the probe results do not all line up
under it yet (`write(1,"",0)` is a syscall and did NOT render, while a lone
7-byte write did not either but two writes did). State the facts above; do not
present cooperative scheduling as the cause until something tests it.

**Next:** sample the scheduler at early frames -- `_curTask`/run-queue state, and
whether getty's TCB ever reaches a running state -- over actual frames
2100-2400, the window where the system falls silent.

Fixture reverted; no source modified.

### ROOT CAUSE: A RUNNABLE TASK IS NEVER DISPATCHED (2026-08-10)

Task states sampled across the window where the system falls silent
(TCB_Status +$02; TASK_READY=1, TASK_RUNNING=2, TASK_BLOCKED=3):

    actual 2100   t1..t7 BLOCKED   t8=RUNNING
    actual 2130   t1..t7 BLOCKED   t8=RUNNING
    actual 2160   t1..t6 BLOCKED   t7=RUNNING  t8=READY  t9=READY
    actual 2190   t1..t6 BLOCKED   t7=READY    t8=BLOCKED t9=BLOCKED
    actual 2220   ... identical ...
    actual 2280   ... identical ...
    actual 2340   ... identical ...
    actual 2400   ... identical ...
    actual 4320   t7 Status=1 (READY), ALL OTHERS Status=3   <- from the earlier
                  end-of-run TCB dump, independently captured

**From actual frame 2190 to the end of the run (4320) -- 2130 frames, ~35
seconds -- task 7 is READY, every other task is BLOCKED, and NOTHING RUNS.**
A runnable task sits on the ready list and is never dispatched. That is the
whole bug.

**Task identification** (from the fd-table dump, cross-referenced):
  t7 = telnetd  -- it is RUNNING at frame 2160, exactly when the 26 B and 31 B
       console writes land ("Connected to..." / "telnetd: session on /dev/ttyp0",
       both of which appear on screen); fd3 = $417AB7 = pty master.
  t8 = telnet   -- data bank $5C, confirmed by the g_wret probe; fd3 = socket.
  t9 = getty    -- fds 0/1/2 all $4180F1, its own pty-slave tty.

**This explains the entire investigation.** The login prompt never renders
because telnetd never runs to relay it. Everything downstream was innocent:
write(2) is correct, the fd table is correct, the FCB flags are correct, the VC
is correct, the VT parser is idle, and console_char renders perfectly whenever
it is reached. There was never a lost byte -- there was a byte that was never
produced, because the task that would produce it was never scheduled.

It also explains the "heisenbug" that made this look non-deterministic for so
long: the kernel is COOPERATIVE (toolbox.s:337, Model A -- kernel code is never
preempted; `_kYieldReq` is honoured only between syscalls). Adding ANY work to
telnet's loop changes the order and timing of the block/wake sequence around
frame 2160-2190, which is what decides whether the run queue ends up in the
stuck state. printf, a stack buffer + strcpy, two writes -- all perturb that
sequence. A lone write or a non-syscall probe does not. The sensitivity was
never about stacks, banks, buffers or codegen; it was about SCHEDULING ORDER.

**Retractions this forces.** "The loss is inside the console/tty path" (previous
section) is wrong -- already retracted there. Every mechanism eliminated earlier
was eliminated correctly, but the search was in the wrong layer from the start:
the client and the console were both fine.

**Caveat, stated precisely.** Eight samples showing READY do not by themselves
prove t7 never entered RUNNING between them. They are corroborated by
`_Sys_WrMax` being frozen for the same 2200 frames -- telnetd cannot have run
and relayed anything without issuing a write. The two independent measurements
agree.

(`_curTask` read $0000 at every sample from $00B59E = kernel DP $B500 + DP $9E.
That is almost certainly the WRONG address rather than a real value; nothing
above depends on it.)

**Next: why is a READY task not dispatched?** The likely shape is a
desynchronisation between `TCB_Status` and the scheduler's own run queue -- the
TCB says READY while the SE_ entry (32 B sched entry) is not enqueued, so the
dispatcher never sees it. Dump the SE_ entries / ready list across actual frames
2160-2220 -- the transition where t7 goes RUNNING -> READY and sticks -- and
compare against TCB_Status. That is where the defect will be.

Fixture reverted; no source modified anywhere in this investigation.

### LOCALISED: pick_next pass 1 finds a READY task, pass 2 never selects it (2026-08-10)

**SE entries + TCB, across the transition (SE_WaitChan +$0C, SE_Flags +$10;
table = `[_schedTblPtr]` at kernel DP $A4, 32 B/slot, seoff=(pid-1)*32):**

    actual 2170  t7 RUNNING          t8 READY            t9 READY
    actual 2180  t7 RUNNING          t8 READY            t9 BLOCKED:PTY
    actual 2190  t7 READY/wc=none    t8 BLOCKED:SELECT   t9 BLOCKED:PTY
    ... unchanged through actual 2400 (and t7 still READY at 4320) ...
    (t1 BLOCKED wc=$0800, t4 BLOCKED wc=$08C0 -- waitpid on child TCB addresses;
     t5,t6 BLOCKED on KBD -- the other VCs' gettys)

So the stuck state is: **telnetd READY with NO wait channel, telnet blocked in
select, getty blocked on the pty.** t7 is genuinely runnable -- SE agrees with
TCB, there is no status/wchan desynchronisation.

**PC profile during the stall (`pc_sample`, once per frame):**

    7D:A0EA  814   sched.s:68    LDA TCB_Priority,X     (pick_next PASS 1)
    7D:A0E8  785   sched.s:67    BCC @pn_p1n            (pick_next PASS 1)
    7D:9EFA  491   task.s:2450   BCC @lcr_yes           (Lane_CanRun)
    ...no user-bank PCs in the top 14 at all...

~87% of frames sample inside `pick_next`'s pass-1 scan. The machine is spinning
in the scheduler, not running anybody.

**The discriminator:**

    _pnBestPri     = $0000 at every sample   -> pass 1 DOES find a READY task
                                                at priority 0 (not $FFFF="none")
    _schedLastSlot = 0     at every sample   -> pass 2 NEVER selects a winner
                                                (it would store the winner's slot;
                                                 t7 is slot 6, and 0 is stale from
                                                 when init last ran)

**THE DEFECT.** `pick_next` (sched.s:47-120) runs two passes. Pass 1 finds
telnetd READY and records `_pnBestPri`=0. Pass 2 -- round-robin from
`_schedLastSlot+1`, requiring `TCB_Status==READY && TCB_Priority==_pnBestPri &&
Lane_CanRun` -- never matches it, so pick_next falls through to `@pn_none` and
reports "nothing READY" while a runnable task sits in slot 6. The scheduler then
re-enters and repeats forever.

This is EXACTLY the failure shape sched.s:56-63 documents and claims to have
fixed for lane members: "it can win _pnBestPri, pass 2 then finds nobody at that
priority, and pick_next returns 'nothing READY' while a runnable lower-priority
task sits there." The B3.2 fix added `Lane_CanRun` to pass 1 so the two passes
would agree. They still disagree here -- some other asymmetry between the passes
admits a task in pass 1 that pass 2 rejects.

**Not yet pinned:** WHICH asymmetry. Both passes mask priority with `AND #$00FF`,
both use 64-byte stride, both call `Lane_CanRun`. The remaining suspects are
`Lane_CanRun`'s register/state contract across the two call sites (pass 1
documents "preserves X and Y"; pass 2 depends on X surviving for its `RTS`), and
pass 2's wrap/iteration bound vs pass 1's `Y<TASK_MAX_SLOTS`. Read those two
before changing anything.

**Everything downstream was innocent.** write(2), the fd table, FCB flags, the
VC, the VT parser and console_char are all correct; the prompt never renders
because telnetd is never dispatched to relay it. The cooperative kernel
(toolbox.s:337, Model A) is why adding ANY syscall-bearing work to telnet
shifted the block/wake ordering around frames 2160-2190 and changed whether the
run queue reached this state -- the "heisenbug" was scheduling order all along.

**Note on the gate:** telnet_loopback still PASSES, because it asserts only the
three unconditional facts. A real scheduler stall is invisible to it. Once fixed,
`login:` should become an unconditional assertion, and the fixture's description
-- which still calls this a heisenbug needing "an extra stdout write" -- must be
rewritten.

Fixture reverted; no source modified anywhere in this investigation.

### Lane_CanRun contract + CORRECTION of the previous section (2026-08-10)

**RETRACTION FIRST.** The previous section's claim -- "pass 1 finds a READY task
(`_pnBestPri`=0), pass 2 never selects it (`_schedLastSlot`=0)" -- is WRONG and
is withdrawn. `_pnBestPri`, `_pnScan`, `_schedLastSlot` and `_curTask` are
DIRECT-PAGE variables ($B4, $B8, $AE, $9E -- dpmap.s:245-257), but run.py's
`{"symbol": ...}` region type resolves KERNEL-BANK offsets. I read kernel bank
$00B4/$00B8/$00AE, which are unrelated zeros, and built a conclusion on them.
Re-read at the real addresses (`CFG_DP_KTASKS+B4` etc.):

    _pnBestPri  _pnScan  _schedLastSlot  _curTask
      $FFFF        7           7          $0008    (identical at 5 samples)

That INVERTS the reading: `_pnBestPri` is $FFFF, not $0000. This is the second
kernel-bank-vs-direct-page mix-up in this investigation (the first produced the
bogus `_curTask`=0). Any DP symbol needs `CFG_DP_KTASKS+off`, never `symbol`.

**Lane_CanRun's contract at both call sites (the question asked).**

    Lane_CanRun (task.s:2445):  In X = TCB offset, MX %00.
                                Out C=1 runnable / C=0 blocked on the lane.
                                "Preserves X and Y.  Clobbers A."
    body:  PHY / LDA TCB_TaskID,X / JSR _Lane_IsMember
           BCC @lcr_yes                      ; not a member -> C=1
           ... CMP _laneResident / BEQ @lcr_yes
           PLY / JMP Lane_Evictable          ; tail call

  * Call site 1 -- sched.s:66 (pass 1): **X is the loop iterator** (`TXA/CLC/
    ADC #TCB_SIZE/TAX`), and `LDA: TCB_Priority,X` runs right after the call.
    A clobbered X would corrupt the scan itself.
  * Call site 2 -- sched.s:114 (pass 2): X is RECOMPUTED from `_pnScan` every
    iteration, and is also the RETURN value (`RTS ; X = chosen TCB offset`).
    A clobbered X would return the wrong task but not derail the scan.

  **The contract holds, but only by luck of the callees.** `Lane_CanRun` saves
  ONLY Y (`PHY`) -- unlike `Lane_Ensure`, which does `PHX`. X survives because
  `_Lane_IsMember` (task.s:2417) touches only A and Y, and `Lane_Evictable`
  (task.s:2332) opens with `PHX/PHY`. Nothing in `Lane_CanRun` itself protects X.
  That is a latent fragility worth fixing on its own merits -- a future edit to
  `_Lane_IsMember` that uses X would silently corrupt pass 1's iterator, with no
  compile-time or test-time signal -- but it is NOT the current bug.

**And Lane_CanRun is NOT rejecting telnetd.** `_laneResident` = 0 (this one IS a
kernel-bank DS, task.s:2166, so that read was valid) = the lane is EMPTY, and
`Lane_Evictable` opens with `LDA _laneResident / AND #$00FF / BEQ @le_yes ; lane
empty` -> C=1. So every path through `Lane_CanRun` returns "can run" for t7.

**What still stands, and what does not.**
  STANDS: t7 (telnetd) is READY at priority 0 with no wait channel, from actual
  frame 2190 to end of run; every other task is BLOCKED; no write syscall occurs
  in that window; ~87% of PC samples are inside `pick_next`'s pass-1 scan and
  `Lane_CanRun`; `_curTask`=8 and `_schedLastSlot`=7 are frozen, i.e. the last
  successful dispatch was telnet (slot 7) and pick_next has not succeeded since.
  DOES NOT STAND: any claim about WHICH predicate rejects t7. `_pnBestPri` and
  `_pnScan` are scratch, re-initialised to $FFFF at every pass-1 entry, and we
  are sampling mid-scan -- so they cannot support a conclusion in either
  direction, including the $FFFF reading above.

**Next, and stop sampling transients.** `_schedLastSlot` is written ONLY on a
successful pick, so `capture_writes` on `CFG_DP_KTASKS+AE` records every
successful dispatch with its PC -- if it never fires after frame 2190, pick_next
provably never succeeds. Pair it with a tap on slot 6's `TCB_Status`
(kernel bank $0800+6*64+2) to catch whether anything rewrites t7's state. Those
two are stable, edge-triggered, and immune to the mid-scan sampling problem that
has now produced two wrong answers.

Fixture reverted; no source modified.

### _schedLastSlot tap: dispatch timeline, and a TOOLING WALL (2026-08-10)

**The tap itself was structurally wrong for this question, and that is the
main lesson.** `capture_writes` keeps the FIRST `max_hits` hits
(init.lua:1203) and its entries carry NO frame or timestamp. `_schedLastSlot`
is written on every successful pick since boot, so the tap filled at 64 hits
during boot and said nothing about a stall that happens at the END of the run.
(It did confirm the tap works: writer PC 7D:A141 = pass 2's `STA _schedLastSlot`.)
Also note `capture_writes` takes a RAW address with no `kbank` support -- my
first attempt tapped bank 0 $0982 instead of kernel-bank $7D0982 and captured
only firmware zeroing.

**The dispatch timeline (from the paired frame samples) is the real result:**

    actual 2020   lastSlot=6  curTask=7    telnetd dispatched
    actual 2040   lastSlot=3  curTask=4    shell dispatched
    actual 2060   lastSlot=7  curTask=8    telnet dispatched
    actual 2160   lastSlot=6  curTask=7    telnetd dispatched
    actual 2200   lastSlot=7  curTask=8    telnet dispatched  <- LAST EVER
    actual 2220..2420  ...frozen at lastSlot=7 / curTask=8...

The scheduler is demonstrably healthy up to ~frame 2200: it alternates between
shell, telnetd and telnet. The LAST successful dispatch is telnet (slot 7).
telnet then blocks on WCHAN_SELECT, telnetd is woken to READY -- and nothing is
ever dispatched again, for the remaining ~2200 frames.

**telnetd's own lifecycle (tap on slot-6 TCB_Status, kernel bank $7D0982):**

    READY   <- sched.s:647  @tw_next        (the wakeup scan)
    RUNNING <- sched.s:304  swtch
    BLOCKED <- sched.s:517  JSR swtch       ("resume another task; back here on wake")

The cycle READY->RUNNING->BLOCKED->READY repeats cleanly. Note the 2-byte tap
double-counts (a 16-bit store fires the tap once per byte, the second with the
high byte 0 = "UNUSED"); use `len:1`.

**An unresolved tension, stated rather than smoothed over.** With `max_hits`
raised to 5000 the tap STILL filled -- telnetd's status changes at least 5000
times. Two readings, and the tooling cannot separate them:
  (a) all 5000 cycles happen before ~frame 2190 and dispatch then stops dead
      (favoured: `_curTask` and `_schedLastSlot` are frozen across 8+ samples
      spanning 200+ frames, and there are ZERO write syscalls for 2200 frames);
  (b) telnetd keeps cycling wake->run->block rapidly the whole time, doing no
      useful work -- a livelock rather than a starvation.
Either way the prompt never gets relayed, but the FIX differs, so this must be
resolved before touching sched.s.

**THE TOOLING GAP that blocks the last step.** To characterise a stall at the
end of a run, `capture_writes` needs either a ring buffer (keep the LAST N hits
instead of the first N) or an arming frame, plus a frame number on each entry.
None of those exist today. Adding "keep last N + frame stamp" to the fgxdebug
capture tap is a small, self-contained change to
tools/mame_test/plugins/fgxdebug/init.lua and is the cheapest way to finish
this investigation -- it turns every question above into one run.

**Do not change sched.s yet.** The rejecting predicate in pick_next pass 1 is
still unidentified, and two previous attempts to name it were wrong (one from a
kernel-bank/DP address mix-up). What is solid: telnetd is READY at priority 0
with an empty lane, and the system performs no work for 37 s.

Fixture reverted; no source modified.

### capture_writes: keep-last-N + frame stamps ADDED, and what they immediately showed (2026-08-10)

**The change** (tools/mame_test/plugins/fgxdebug/init.lua + tools/mame_test/run.py):

  * `"keep": "first"` (DEFAULT, unchanged) -- stop at `max_hits`. Right for
    "what touched this FIRST", which is what all three existing fixtures
    (b3pty, b3park, b3ptyrd) want.
  * `"keep": "last"` -- never stop; retain the most recent `max_hits` in a
    per-tap ring, drained chronologically at dump time. O(1) per hit.
  * `"frame": N` on EVERY entry, both modes. Without a time axis a capture
    cannot distinguish "stopped happening" from "never captured" -- which is
    exactly how this investigation lost several runs.
  * run.py validates `keep`, and its manifest docs now warn that the address is
    RAW (no `kbank`): a kernel-bank target needs the live bank baked in.

**Bug found and fixed while verifying:** the first cut drained the rings INTO
`capture_log`, but `do_dump` runs more than once per session, so every dump
re-appended the ring -- a `max_hits: 40` tap emitted 1625 entries. The drain now
builds a separate `emit_log` copy and never mutates `capture_log`. Verified: 40
requested, exactly 40 kept.

**Regression check:** b3pty and b3park both PASS, including their check_scripts
that consume capture_log. The default path is untouched.

**AND IT IMMEDIATELY OVERTURNS THE "ROOT CAUSE".** Tapping telnetd's
TCB_Status with `keep:"last"`, the final 40 transitions are:

    frame 4309  RUNNING / BLOCKED / READY
    frame 4310  RUNNING / BLOCKED / READY
    ...
    frame 4320  RUNNING / BLOCKED / READY      <- last frame of the run

**telnetd is cycling READY -> RUNNING -> BLOCKED about three times per frame,
continuously, right to the end of the run.** It is NOT starved and NOT
"never dispatched" -- it is being scheduled constantly and blocking immediately
each time. The earlier claim ("A RUNNABLE TASK IS NEVER DISPATCHED") is WRONG
and is retracted: the frame-sampled TCBs that showed t7 READY were simply
catching the READY phase of a fast cycle, and 8 samples of a 3-per-frame cycle
prove nothing about dispatch. This is a LIVELOCK, not a starvation -- the sleep
at sched.s:517 is immediately undone by the wake scan at sched.s:647.

**An unresolved contradiction, flagged not smoothed.** `_curTask` reads $0008
and `_schedLastSlot` reads 7, frozen, across many samples -- yet telnetd (slot 6)
enters RUNNING three times per frame. Those cannot both be true as I have read
them. `_curTask`'s address/semantics have already been wrong twice in this
investigation (kernel-bank vs DP), so suspect the read before the kernel.

**Where this actually leaves the bug.** telnetd spins; getty (t9) sits BLOCKED
on WCHAN_PTY and never writes the login prompt; no write syscall occurs
system-wide for 37 s. The question is now: why does getty never write the
prompt, and what wakes telnetd ~3x/frame with nothing to relay? Both are one
`keep:"last"` tap away now -- on getty's TCB_Status (slot 8, kernel bank
$7D0A02) and on the pty ring state.

### ROOT CAUSE (real this time, and it is MINE): net_loop.s never wakes WCHAN_SELECT

The keep-last tap made the whole chain visible in one run.

**getty's complete status history** (8 entries, tap capacity 30 -- so this is
EVERY transition, not a truncation):

    frame  132  UNUSED     (slot init)
    frame 2141  READY      (spawned)
    frame 2176  READY
    frame 2177  RUNNING
    frame 2179  BLOCKED
    frame 2185  READY
    frame 2185  RUNNING
    frame 2185  BLOCKED    <- LAST EVER; never runs again in 2100+ frames

**The pty ring shows the prompt DID flow.** `PTYR_OutCount` writes at frame
2185 run 7,6,5,4,3,2,1,0 (drained by PC 7D:C876), and `_ptyTable` pair 0 at
frame 2400 reads:

    Flags=7  TtyIdx=1  InCount=0  OutHead=15  OutTail=15  OutCount=0

OutHead=OutTail=15 with OutCount=0: **getty wrote 15 bytes and telnetd drained
all 15.** Fifteen is exactly the `TTYBYTES()=15` measured in the very first
session of this investigation. Nothing is stuck in the pty.

**So the break is AFTER telnetd drains the pty and sends to the loopback
socket.** telnet is BLOCKED on WCHAN_SELECT and is never woken.

**The defect, in code I wrote for this campaign.** `select(2)` blocking forever
sleeps on **WCHAN_SELECT** (syscall.s:973-976, guarded by `_nSelSleepers`).
net_loop.s wakes only WCHAN_SOCK and WCHAN_PIPE -- never WCHAN_SELECT:

    net_loop.s:187  WCHAN_SOCK   ; wake a blocked accept()
    net_loop.s:449  WCHAN_SOCK
    net_loop.s:567  WCHAN_SOCK
    net_loop.s:773  WCHAN_SOCK   ; "wake a peer parked in accept/select"
    net_loop.s:967  WCHAN_PIPE
    net_loop.s:969  WCHAN_SOCK   ; "...or in accept/select"

The comments at net_loop.s:682-683 and 773 assert that a peer "parked in ...
select ... sleep[s] on WCHAN_SOCK". **That is false.** A blocking select sleeps
on WCHAN_SELECT. So a loopback send lands bytes in the ring and wakes nobody.

pty.s:285-290 shows the CORRECT pattern, and is why pty-backed select works:

    LDA #WCHAN_PTY / JSR _wakeup
    LDA _nSelSleepers / BEQ @pw_nosel
    LDA #WCHAN_SELECT / JSR _wakeup

**This explains every observation, including the heisenbug.** If telnet happens
to call select AFTER the data has landed, the readiness scan sees it and
everything renders. If it is already asleep in select when the data lands, it
sleeps forever. Any added work in telnet's loop (printf, a stack buffer +
strcpy, two writes) shifts that race -- which is why the outcome tracked
"perturbation" rather than any property of stacks, banks, buffers or codegen.
telnetd's livelock and getty's permanent block are downstream of the same
stall.

**The fix:** mirror pty.s at every loopback wake site -- after
`_wakeup(WCHAN_SOCK)`, add the `_nSelSleepers`-guarded `_wakeup(WCHAN_SELECT)`.
Sites: net_loop.s 187, 449, 567, 773, 969. Correct the two comments that claim
select parks on WCHAN_SOCK. Then `login:` should become an UNCONDITIONAL
assertion in telnet_loopback, and the fixture description -- which still calls
this a heisenbug needing "an extra stdout write" -- must be rewritten.

**Retractions:** "a runnable task is never dispatched" (wrong -- telnetd
livelocks) and "the loss is inside the console/tty path" (wrong -- nothing was
ever written) are both withdrawn. The scheduler is not defective; pick_next is
not defective; console, write(2), fd tables, FCB flags, VC and VT parser are all
correct. The bug is one missing wakeup channel in the loopback backend.

### Fix APPLIED — necessary, verified, but NOT sufficient (2026-08-10)

**Change (src/kernel/net_loop.s).** Added `_Loop_WakeSel`: raise WCHAN_SOCK,
then WCHAN_SELECT guarded by `_nSelSleepers` -- the pty.s:285-290 pattern.
Converted the four wake sites (was `LDA #WCHAN_SOCK / JSR _wakeup`) at
_Loop_ConnectTry, _Loop_WireAccepted, _Loop_IoTry and _Loop_CloseTry. One
shared helper rather than five inlined copies, because kernel bytes are tight.
The `_sleep` site in _Loop_AcceptTry is untouched -- that is a SLEEP, not a wake.
Also corrected the two comments that asserted select parks on WCHAN_SOCK; those
comments are what the wrong code was written to match.

**It demonstrably works, and it was demonstrably needed.** Tapping telnet's
TCB_Status with `keep:"last"`:

    BEFORE: BLOCKED on WCHAN_SELECT from frame 2190 to end of run. Never woken.
    AFTER:  READY -> RUNNING -> BLOCKED, continuously, to frame 4320.
            `_nSelSleepers` = 1 at every sample, so the guard passes.

**Regression sweep: loopback_pair, p5_z_pipe, smoke, telnet_loopback -- 4 passed,
0 failed.** loopprobe still reports "PASS both directions + EOF".

**BUT THE PROMPT STILL DOES NOT RENDER, so `login:` was NOT made an
unconditional assertion.** Asserting it now would simply fail; the fixture is
left as it was. That half of the request is NOT delivered.

**The second, independent defect.** Dumping the pipe table (`_pipeTable` is a DP
LONG POINTER at $FB -- deref via `ptr_addr_hex: "CFG_DP_KTASKS+FB"`):

    ring 0:  inuse=1 head=0 tail=0  COUNT=0   bufsz=512
    ring 1:  inuse=1 head=0 tail=24 COUNT=24  bufsz=512

**24 bytes are sitting unread in the loopback ring** -- telnetd relayed the
prompt (15 bytes of prompt plus IAC negotiation) and it never gets consumed.
telnet now WAKES, re-scans, finds nothing it will act on, and sleeps again.

So the chain is: getty writes 15 B -> pty (VERIFIED, OutHead=OutTail=15) ->
telnetd drains it (VERIFIED) -> telnetd sends into loopback ring 1 (VERIFIED,
COUNT=24) -> telnet is woken (VERIFIED, this fix) -> **telnet does not read it**.

`_Loop_StatusTry` (net_loop.s:1065) reads SOCK_LoopRx -> PIPE_Count and sets the
readable bit on a nonzero count, which LOOKS correct, and loopprobe exercises
exactly that and passes. So the next question is narrow: is `_Loop_StatusTry`
reached at all for this fd from select's `@cl_sock` hook, and does telnet's
fd->descriptor lookup resolve? Dump `_loopHandled`/`_loopBits` around a select
scan, and confirm telnet's SOCK_LoopRx actually names ring 1 (dump the socket
table via `ptr_addr_hex: "CFG_DP_KTASKS+A0"`, SOCK_REC_SIZE=12).

**Status: one of two defects fixed.** The wake is genuinely required and is
worth keeping on its own merits regardless of what the second defect turns out
to be.

### _Loop_StatusTry IS reached — and the stall is telnetd not READING (2026-08-10)

**The hook is wired and live.** syscall.s:1249-1252 tests `FCB_FL_SOCKET` and
branches to `@cl_sock` (syscall.s:1299), which does `_Sock_FdToDesc` ->
`JSR _Loop_StatusTry` (syscall.s:1305). Verified at runtime with keep-last taps:

    _selFd   written 3,4,5,...,12 every scan   -> select IS walking the fd set
    _loopBits written 0, every time, one PC    -> _Loop_StatusTry RUNS and
                                                  always answers "not ready"

So the earlier suspicion that the hook might not be reached is WRONG: it is
reached on every scan.

**The descriptor wiring is correct and symmetric** (socket table via
`ptr_addr_hex: "CFG_DP_KTASKS+A0"`, SOCK_REC_SIZE=12):

    desc1: hw=$FE state=2 peer=desc2  RX=ring1  TX=ring0
    desc2: hw=$FE state=2 peer=desc1  RX=ring0  TX=ring1
    ring0: count=0        ring1: count=24

Each end reads what the other writes -- exactly the pairing loopprobe asserts.
Nothing is mis-wired.

**Which reverses the reading of the 24 bytes.** desc2 WRITES ring1, so the 24
bytes in ring1 are **telnet's** traffic heading TO telnetd (an IAC negotiation
burst), sitting unread. And **ring0 -- telnetd -> telnet -- is EMPTY**, so
telnetd never sent the prompt at all. The previous section read those 24 bytes
as the prompt in flight; that was wrong.

So `_loopBits`=0 is CORRECT behaviour for the end that is selecting: desc2's RX
is ring0, which really is empty. The scan is honest; there is simply nothing to
report.

**Corrected chain.** getty writes 15 B -> pty (verified) -> telnetd drains the
pty (verified, OutCount 7..0 at frame 2185) -> **telnetd does not write it to
the socket** (ring0 empty) -> and **telnetd does not read telnet's 24 bytes**
either (ring1 full) -> telnet selects on an empty ring forever.

**telnetd is not doing socket I/O in either direction.** That is consistent with
its livelock (spinning without progress) and with getty's permanent block (its
15 bytes were consumed by telnetd and went nowhere). The defect is now on the
telnetd side -- src/userland/telnetd/telnetd.c's relay(), or the select it runs
over {socket, pty master} -- not in net_loop.s, not in the scheduler, and not in
the console.

**The WCHAN_SELECT fix stays.** It is independently correct (a blocking select
sleeper must be woken; it was not) and verified to change telnet from
"blocked forever" to "waking on every send", with a clean 4-test sweep. It is
simply not the only defect.

**Next:** instrument telnetd's relay loop -- does its select ever return with
the socket readable, and does it call read/recv on the socket at all? Its own
fd set is the first thing to check (fd3 = pty master per the earlier fd-table
dump; the socket fd is separate), since a relay that never arms the socket fd
would produce precisely this state.

### telnetd relay instrumented — telnetd is FINE; the reader never learns (2026-08-10)

Eight counters added to relay() (globals, read back from telnetd's data bank
$59 at link offset $162B). Reverted after measuring.

    reads=216  lastrd=-1     sends=1  lastsend=15    recvs=215  lastrecv=-1

**telnetd's send SUCCEEDED: one call, return 15.** And its recv returning -1
(EWOULDBLOCK) 215 times is CORRECT, not a bug -- see the ring state below.
Note relay() uses no select at all: it is a non-blocking read/recv poll with
nanosleep(1), which is exactly the "livelock" seen earlier. That is by design,
not a defect.

**Correlated ring + descriptor state (same run):**

    desc1: peer=desc2  RX=ring1  TX=ring0
    desc2: peer=desc1  RX=ring0  TX=ring1
    ring0: count=0  head=0  tail=0     <- NEVER WRITTEN
    ring1: count=24 head=0  tail=24    <- written, NEVER READ

`tail=0` on ring0 is unambiguous: nothing was ever written to it. `tail=24` with
`head=0` on ring1: 24 bytes written, none consumed. 24 = 9 (the IAC option
burst telnetd sends BEFORE relay, uncounted by g_nsend) + 15 (the prompt).

So telnetd = desc2: it wrote all 24 bytes into its TX ring1, and its RX (ring0)
is genuinely empty, which is why recv correctly says EWOULDBLOCK. **telnetd did
its job.** The previous section's claim -- "telnetd is not doing socket I/O in
either direction" -- is WRONG and is retracted.

**telnet = desc1, whose RX IS ring1 with 24 bytes waiting, and it never reads
them.** Its select runs `_Loop_StatusTry` on every scan (`_selFd` walks 3..12),
but the ONLY write to `_loopBits` is the `STZ` at the top: the captured writer PC
7D:3E04 maps to net_loop.s:1084, the instruction right after `STZ _loopBits`.
The readable branch's `STA _loopBits` (net_loop.s:1107) NEVER EXECUTES.

**The remaining defect is therefore in `_Loop_StatusTry`'s readable path** --
between `ADC #SOCK_LoopRx / JSR _Loop_RingOffFromDesc` and the
`LDA [_pipeTablePtr],Y` count test. Two things already ruled out:
  * the pointer is right -- `_pipeTablePtr` resolves to DP $FB, the same table
    this investigation dumped to READ count=24;
  * `_Loop_RingOffFromDesc` (net_loop.s:1004) looks correct and desc1's
    SOCK_LoopRx is 1, not SOCK_LOOP_NONE, so it should return C=1 with A=16.

**Next probe (narrow):** tap `_loopConnOff` and the SOCK_LoopRx byte during a
scan to confirm WHICH descriptor select resolves for telnet's fd 3. If it
resolves desc2 rather than desc1, the bug is in `_Sock_FdToDesc`/fd mapping and
`_Loop_StatusTry` is answering correctly about the wrong descriptor -- which
would fit every number above.

**State of the campaign: two defects found, one fixed.**
  FIXED:     loopback wakes never raised WCHAN_SELECT (net_loop.s, verified,
             4-test sweep clean).
  OPEN:      select never reports a loopback socket readable, so the woken
             reader goes straight back to sleep.
`login:` remains unassertable until the second one is fixed.

### PINNED: telnet's socket fd resolves to a DEAD descriptor (2026-08-10)

Tapped `_loopConnOff` (02/3F4E -> runtime $7D3F4E), which `_Loop_StatusTry`
sets from `_Sock_FdToDesc`'s Y, alongside `_selFd`, both keep-last:

    selFd = 0,1,2,3,...,12         (select walks the whole fd set)
    _loopConnOff = 0               (BOTH times _Loop_StatusTry was reached)

**Descriptor offset 0 is descriptor 0 -- and descriptor 0 IS NOT IN USE.** The
two live descriptors sit at offsets 12 and 24:

    desc1 (off=12): RX=ring1 TX=ring0      ring0: count=0  tail=0
    desc2 (off=24): RX=ring0 TX=ring1      ring1: count=24 tail=24

So every socket operation telnet performs is aimed at a free/stale descriptor.
That single fact explains the whole remaining failure at once:
  * telnet never sends -- ring0 was NEVER written (tail=0), because its send
    targets a dead descriptor;
  * select never reports readable -- `_Loop_StatusTry` faithfully inspects
    descriptor 0, which owns no rings, so the `STA _loopBits` readable branch
    correctly never fires;
  * telnetd's 24 bytes sit unread in ring1 forever, waiting for a peer that is
    pointed somewhere else.

`_Loop_StatusTry` is therefore NOT defective -- it is answering correctly about
the wrong descriptor. The previous section's "the remaining defect is in
_Loop_StatusTry's readable path" is retracted.

**Ruled out on the way:** the kernel's `FCB_SockIdx` (include/fs.s:708,
`FCB_FstPriv+0`) resolves to byte 13, IDENTICAL to net.mod's hardcoded
`FCB_SockIdx EQU 13` (net.s:44). A kernel/module offset skew would have been an
elegant explanation; it is not the cause. Both net.mod store sites
(net.s:644, net.s:1135) write `_sockTmpOff`, the descriptor OFFSET, which is the
same convention the kernel reads.

**So the FCB genuinely holds 0**, and the question is now narrow and static:
either (a) telnet's socket fd was created when descriptor 0 was live and
descriptor 0 was later FREED underneath it (a premature-free / recycled-
descriptor bug -- the same family as the `SOCK_Loop*` staleness already fixed in
this campaign), or (b) the loopback connect path allocated a NEW descriptor for
the connector (desc1/desc2) and never wrote its offset back into the caller's
FCB, leaving the FCB pointing at whatever socket() first assigned.
`net_loop.s:587` is the ONLY kernel-side `FCB_SockIdx` writer and it is on the
ACCEPT path -- so on the CONNECT path nothing updates the FCB, which makes (b)
the stronger candidate and is worth reading before another emulator run.

**Campaign state: three defects, one fixed.**
  FIXED: loopback wakes never raised WCHAN_SELECT (verified, sweep clean).
  OPEN:  telnet's socket fd resolves to a dead descriptor (this section) --
         the cause of the remaining hang.
  N/A:   telnetd and _Loop_StatusTry are both exonerated.

### RETRACTION: there is no FCB_SockIdx writeback bug (2026-08-10)

I asked to fix a writeback that does not need fixing. Reading the connect path
and then telnet's actual FCB disproves the previous section.

**The connect path already uses the fd's own descriptor** (net_loop.s:165-171):

    LDA _Sys_SavedX
    JSR _Sock_FdToDesc          ; C=1 + Y = desc offset
    BCS @nl_ct_havefd
@nl_ct_havefd  STY _loopConnOff

It resolves the CONNECTOR from the fd and wires that existing descriptor. It
never allocates a new one, so there is nothing to write back. Candidate (b) is
dead.

**And telnet's FCB is CORRECT.** Dumped directly (fd table -> fd3 FCB $417BCB):

    telnet fd3 FCB: flags=$10 (FCB_FL_SOCKET)  FCB_SockIdx(byte 13) = 12

12 is desc1 -- exactly the right descriptor, whose RX is ring1, the ring holding
the 24 unread bytes. So "telnet's socket fd resolves to a DEAD descriptor" is
WRONG and is retracted. Candidate (a) is dead too.

**A REAL defect the same dump exposed, and FIXED.** Dumping all four descriptors
unfiltered:

    desc0 off= 0: InUse=0  Hw=$FE  State=3  peer=$FF RX=$FF TX=$FF
    desc1 off=12: InUse=1  Hw=$FE  State=2  peer=$02 RX=$01 TX=$00
    desc2 off=24: InUse=1  Hw=$FE  State=2  peer=$01 RX=$00 TX=$01

desc0 is FREE (InUse=0) but still carries **Hw=$FE = SOCK_HW_LOOP** and
State=TCP_LISTEN -- the closed listener. `_Loop_CloseTry` cleared SOCK_InUse and
(via the earlier _Sock_ClearLoopState fix) Rx/Tx/flags/peer, but never the
transport tag. Every `SOCK_HwIdx == SOCK_HW_LOOP` test -- _Loop_StatusTry:1074 is
one -- therefore accepts a dead descriptor as a live loopback socket and proceeds
to answer questions about it.

FIX APPLIED (net_loop.s teardown): after `SOCK_InUse = 0`, `INY` and store
`SOCK_HW_NONE` into SOCK_HwIdx. Sweep: loopback_pair, telnet_loopback, smoke --
3 passed, 0 failed; loopprobe still "PASS both directions + EOF".

**This does NOT close the hang, and I am not claiming it does.** telnet's FCB
points at desc1, desc1's RX is ring1, ring1 holds 24 bytes -- so a scan of
telnet's fd 3 SHOULD set the readable bit, and does not. The `_loopConnOff = 0`
readings that drove the last section are still unexplained: they cannot be
telnet's fd 3 (which resolves to 12), so they come from some other socket fd
reaching @cl_sock -- plausibly one still pointing at the stale desc0, which is
exactly what the fix above now prevents. Whether that changes the readable
answer for fd 3 is UNTESTED; the `login:` assertion was not re-attempted.

**Next, and it should be measured before any more code changes:** tap
`_loopConnOff` again WITH the teardown fix in place, and correlate each write
against the `_selFd` immediately preceding it, so the descriptor offset is
attributed to a specific fd instead of inferred. If fd 3 does resolve to 12 and
the readable branch still never fires, the defect is inside the count test
itself and the next tap goes on `_pipeRecOff`.

**Campaign state: four defects examined, two fixed, one open.**
  FIXED:     WCHAN_SELECT never raised by loopback wakes.
  FIXED:     freed loopback descriptor kept SOCK_HW_LOOP.
  EXONERATED: telnetd, _Loop_StatusTry's logic, FCB_SockIdx, the scheduler,
             the console, write(2), the fd table, VT state, stack depth.
  OPEN:      telnet's select does not report its loopback socket readable.

### Correlated tap with both fixes: state MOVED, hang not closed (2026-08-10)

**Tooling note first.** Correlating two keep="last" taps needed a cross-tap
ordering key: each tap owns its own ring and the rings drain tap-by-tap, so
relative order was lost, and `frame` is too coarse (a whole select scan happens
inside one frame). Added a monotonic **`seq`** stamped on every capture entry.
With that, `capture_log` sorted by `seq` is a true interleaved trace.

**Result of the correlated tap (with BOTH kernel fixes in place):**

    seq 2651..2676   selFd = 0, once or twice per frame, and NOTHING ELSE.
    _loopConnOff: NOT WRITTEN in the whole window.
    _loopBits:    NOT WRITTEN in the whole window.

`_Loop_StatusTry` is no longer reached at all late in the run, because no SOCKET
fd is being scanned. A single `selFd = 0` per call is the signature of a select
over stdin only -- i.e. the SHELL -- not of telnet, whose scan previously walked
0..12.

**Task state at end of run has genuinely changed:**

    BEFORE fixes:  tid7 READY,   tid8 BLOCKED:SELECT, tid9 BLOCKED:PTY
    AFTER  fixes:  tid7 RUNNING, tid8 READY,          tid9 BLOCKED:PTY

telnet (tid8) is no longer parked in select -- it is scheduled and running. The
WCHAN_SELECT fix did exactly what it was supposed to. But:

    ring0: count=0  head=0 tail=0      (telnet still never sends)
    ring1: count=24 head=0 tail=24     (telnetd's IAC+prompt, still unread)

**So the hang is NOT closed, and `login:` is still not assertable.** The fixture
was left unchanged; the assertion was attempted and failed, and is reverted.

**What moved and what did not.** Two real kernel defects are fixed and verified
(sweep clean, loopprobe green). The failure has changed shape: telnet is no
longer starved of wakeups, it is now running and simply not doing socket I/O --
it never arms fd 3 in its select set and never reads the 24 waiting bytes.

**Next, and it is now a CLIENT-side question:** why telnet's select no longer
includes its socket fd. Read telnet.c's fd-set construction around the main
loop (`FD_SET(net, &ibits)` and the `nfds` argument) and check whether the
socket fd is armed at all in the state the client reaches. That is source
reading, not another emulator run -- and telnet.c has been UNMODIFIED throughout
this investigation, so whatever it does there it has always done; what changed
is that the client now gets scheduled often enough for it to matter.

**Campaign state: two defects fixed, one open.**
  FIXED:      loopback wakes never raised WCHAN_SELECT.
  FIXED:      freed loopback descriptor kept SOCK_HW_LOOP.
  OPEN:       telnet does not arm/read its socket fd; 24 bytes sit unread.
  EXONERATED: telnetd, _Loop_StatusTry, FCB_SockIdx, the scheduler, the console,
              write(2), fd tables, VT state, stack depth, codegen, link set.

### telnet.c fd-set construction — two structural findings (2026-08-10)

telnet.c is UNMODIFIED and has been throughout. Reading its main loop
(telnet.c:762-815):

**1. `net` is armed for READING only when the tty output buffer is EMPTY.**

        if (TTYBYTES()) {
            FD_SET(tout, &obits);       /* drain the terminal instead */
        } else {
            FD_SET(net, &ibits);        /* only THEN watch the socket */
        }

So if bytes ever get stuck in `ttyobuf` and `ttyflush()` fails to drain them,
telnet STOPS WATCHING THE SOCKET ENTIRELY and can never make progress again.
This is stock BSD telnet logic and is correct on a system where ttyflush works
-- but it is a hard coupling between the render path and the read path, and it
is worth knowing that the campaign's very first symptom (15 bytes resident in
ttyobuf) is exactly the state that triggers it. NOT the current failure: ring1
has head=0/tail=24, so telnet has never read anything and TTYBYTES() cannot yet
be nonzero. Recorded because it is a live trap for whatever comes next.

**2. The fd sets are FD_ZERO'd ONCE, before the loop (telnet.c:768-770), never
inside it.** Stock BSD does this deliberately: select(2) is contractually
required to CLEAR the bits of fds that are not ready, in place. So FGX's select
must rewrite the caller's masks in full, not merely OR in the ready ones. The
kernel does write full masks (`_Sel_WriteArgblk`, and @sel_timeout explicitly
zeroes `_selRdOut`/`_selWrOut`/`_selExOut` before writing), so the contract
appears honoured -- but this is the assumption the client's whole loop rests on
and it is worth an explicit test rather than an inference.

**3. `select(...) < 1` -> `sleep(5); continue;`** (telnet.c:802-815). Any
non-EINTR failure costs FIVE SECONDS. In a 40 s fixture that is close to fatal
for diagnosis. Checked the kernel side: a block-forever select does NOT return 0
spuriously -- `@sel_wake` falls into `BRL @sel_loop` and re-scans
(syscall.s:979-985) -- so this path should be rare.

**Current state, measured, with both kernel fixes in:** tid8 (telnet) is READY
and running, NOT blocked in select and NOT blocked on a timer. So it is
spinning in userland, and ring1's 24 bytes are still untouched
(head=0, tail=24).

**The honest summary of this whole investigation.** Two real kernel defects were
found and fixed and are worth keeping. The client-side reason telnet does not
consume its socket is NOT yet identified; three structural hazards in telnet.c
are now documented, none of them yet proven to be the active one. `login:`
remains unassertable and the fixture is unchanged.

**Cheapest next measurement** (not another hypothesis): tap telnet's `scc`/`tcc`
and the `select` return value `c` -- globals-only probe, no stack growth, the
technique that worked for `g_wret` -- to see which branch of the main loop it is
actually taking. That distinguishes "select never reports the socket" from
"select reports it and the read path drops it" in one run, and every remaining
hypothesis lives on one side or the other of that split.

### scc/tcc/select tap: THE CHAIN COMPLETES — prompt renders (2026-08-10)

Globals-only probe in telnet.c (8 counters; the `g_wret` technique, no stack
growth), read back from telnet's data bank $5C:

    g_nsel=2  g_selrc=2  g_scc=0  g_tcc=0  g_armnet=2  g_ttyb=0  g_netrd=1

    ring0: count=0 head=9  tail=9     <- telnet SENT 9 B, telnetd read them
    ring1: count=0 head=24 tail=24    <- telnet READ all 24 B

**Both rings fully drained, and `login:` RENDERS -- the fixture passes with the
assertion added (4/4 green).** With the two kernel fixes in place the entire
chain works: getty -> pty -> telnetd -> loopback -> telnet -> console.

Note how small the window is: `g_nsel=2`. Telnet needs only TWO loop iterations
and ONE net-readable event to put the prompt on screen.

**Residual: the CLEAN build (no probe) still fails.** So a perturbation
sensitivity remains -- but it is now a race with a tiny margin, not a total
failure. Before the fixes the prompt NEVER appeared under any timing; now it
appears whenever anything nudges the schedule.

**fcc is EXONERATED.** The probe had restructured
`if ((c = select(...)) < 1)` into an assignment plus a separate test, which
looked like it might be dodging an fcc codegen bug in embedded assignment.
Compiled both forms standalone: the emitted code is BYTE-IDENTICAL apart from a
label name --

    FGX2_FARCALL f / STA 1,S / TAX / LDA #1 / STA _fcc_tmp_b / TXA
    JSR _fcc_lts16 / CMP #0 / BNE *+5 / BRL ...

`TAX`/`TXA` preserves the call result across the `LDA #1`. fcc compiles the
embedded assignment correctly; the probe's effect is its global STORES, i.e.
timing. Hypothesis disproven without an emulator run.

**Final state of the campaign.**
  FIXED (verified, sweep clean -- loopback_pair, telnet_loopback, smoke,
         p5_z_pipe all pass):
    1. net_loop.s raised only WCHAN_SOCK on loopback wakes; a blocking
       select(2) sleeps on WCHAN_SELECT and was never woken.  Added
       _Loop_WakeSel (the pty.s pattern) at all four wake sites.
    2. _Loop_CloseTry left SOCK_HwIdx = SOCK_HW_LOOP on a freed descriptor, so
       every "HwIdx == SOCK_HW_LOOP" test adopted dead slots.  Teardown now
       stores SOCK_HW_NONE.
  TOOLING: capture_writes gained keep="last" (ring), a per-entry `frame`, and a
       monotonic `seq` for cross-tap correlation -- without which none of the
       last several findings were measurable.
  OPEN: a narrow timing race -- the clean client still misses the window that an
       instrumented one hits.  `login:` therefore remains unasserted; asserting
       it now would be flaky, which is worse than the honest three assertions
       the fixture already makes.
  EXONERATED along the way: write(2), the fd table, FCB flags/FCB_SockIdx, the
       virtual-console path, the VT parser, console_char, stack depth, the
       relocation table, the link set, codegen/layout, the scheduler and
       pick_next, telnetd, _Loop_StatusTry, and fcc.
