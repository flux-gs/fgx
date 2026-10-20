# Networking roadmap — scope & prioritization (2026-07-19)

Scopes the networking portion of `docs/ROADMAP.md` (§Networking) into a
sequenced plan. The **architecture** is already designed —
`docs/superpowers/specs/2026-06-24-net-driver-architecture-design.md` (the
`ifnet`/`protosw` re-arch, P1–P6). This doc does NOT redo that; it reconciles
current state, separates the two tracks, and recommends what to build next and
what to defer. It is a scoping doc, not an implementation.

**First concrete targets (the maintainer, 2026-07-19): `telnet` + `telnetd`.** These pin
the initial push (§4): the critical spine is **socket-readiness sleep/wakeup
(preemption P4 core) → `select`/`poll` → DNS → a PTY subsystem** (lifted from
2.11BSD `tty_pty.c`, the one real gap — telnetd is a pty↔socket relay). telnet
client ships on select+DNS alone; telnetd needs the ptys.

**Bottom line:** the near-term value is in **completing the socket API on the
existing W5100-offload stack** (the readiness wait primitive → select/poll → DNS,
plus the pty subsystem for telnetd) — all now unblocked by the shipped preemption
scheduler, all modest effort, high user value. The **stack re-architecture (P1–P6)** is a large foundational
campaign whose payoff (multi-NIC, non-W5100 links, software stack, IPv6/AppleTalk)
is real but **conditional on a driving need** that doesn't exist yet on a
single-W5100 IIgs. Defer it — but when it lands, build it as a **faithful
2.11BSD `netinet`/`net` PORT**, not a from-scratch reimplementation.

**Governing principle (the maintainer, 2026-07-19): lift directly from 2.11BSD wherever
possible.** This is the userland port policy applied to the network stack —
2.11BSD's `netinet/` (IP/ICMP/UDP/TCP), `net/` (`ifnet`, `if_loop.c`, `if_sl.c`
SLIP), `h/protosw.h`, and `libc/net` (the resolver, `gethostbyname`) are
16-bit-int K&R C — fcc's proven path (same lineage as sed/elvis). Port them
**verbatim** and reimplement only the thin **machine/scheduling seam** that can't
lift: `spl()`/softint → FGX cooperative-MT + a network timer task; the mbuf pool
sizing; the IP checksum inner loop in 65816 asm; byte-order (`htons`/`ntohs`).
This **reverses the 2026-06-24 design spec's "adapt to FGX-native" leaning** on
the parts that are liftable (esp. full BSD TCP over a hand-rolled simplified FSM,
and — pending a memory check — mbufs over flat buffers): a verbatim port of
battle-tested BSD TCP is *more* correct than a bespoke FSM, and cheaper. Adapt
only where the port genuinely can't follow (the machine layer). Every item below
is tagged with its BSD lift source.

---

## 1. Where we are (grounded, 2026-07-19)

- **W5100/Uthernet II offload stack**, mostly in `net.mod` (`src/modules/net/`:
  `net.s` socket layer ~50 KB, `net_xport.s` transport ~52 KB) with the
  in-kernel boot probe/DHCP/MACRAW + shared ISR still in `src/kernel/uthernet.s`.
  **The chip IS the stack** — no software IP/TCP/UDP; `net.mod` maps the BSD
  socket API onto W5100 socket registers via the offload-agnostic `_Net_Xport_*`
  seam (Open/Close/Connect/Listen/Accept/Send/Recv).
- **Shipped:** UDP + `dhclient`; **ICMP** (ping, hardware auto-reply);
  **TCP client AND server** (`connect`/`send`/`recv`/`close`, `listen`/`accept`
  + `echod`); `netdump` MACRAW capture; `ifconfig`/`route`; **slotscan**.
  Syscalls: SOCKET/BIND/CONNECT/LISTEN/ACCEPT/SEND/RECV/SENDTO/RECVFROM/SETSOCKOPT.
  Tools: ping, nc, dhclient, ifconfig, route, netdump, echod, slotscan.
- **What EXISTS (corrected per Fable review 2026-07-19):** recv/accept already
  **WCHAN-sleep**, not spin-poll — `_Sock_PollIntr` (`net_xport.s:981-1040`)
  `_sleep`s on `WCHAN_SOCK` and the CPU idles until woken; the wake plumbing is
  real (`uthernet.s:343` ISR sets `_kSockWakePending` → `sched.s:172-177` swtch
  drains it → `_wakeup(WCHAN_SOCK)`, + a 60 Hz idle re-poll). So the **readiness
  sleep/wakeup primitive already works** (coarse single-wchan broadcast +
  condition re-check). Blocking recv/accept are effectively there; **`select` is
  the real work** (per-fd predicates + multi-fd wait), NOT a primitive under it.
- **Gaps (the backlog):** **No `select`/`poll`** (no `SYS_SELECT`). **No FIONBIO**
  (nonblocking fds — grep: zero hits; the single biggest omission for telnet).
  **No DNS**. No connected-UDP / `shutdown` / `getpeername`/`getsockname` syscalls.
  No ptys. No `MSG_OOB`/`SO_OOBINLINE`. No software stack → no SLIP/other-NIC/IPv6,
  and `netdump` can't see offloaded ICMP.

## 2. What changed since the 2026-06-24 design spec

The **preemption campaign P0–P3 shipped** (FGX v1.10.0): the scheduler now has
real timer-quantum preemption + sleep/wakeup. Two roadmap items that were
explicitly gated "needs the scheduler" — **`select`/`poll`** and **blocking I/O**
— are now **unblocked**. Preemption **P4 (blocking-I/O completion)** is the open
train and is *literally* networking's next step (sleep-not-poll for
`recv`/`accept`). TCP server (`listen`/`accept`) also landed since the spec.

## 3. The two tracks

### Track A — complete the socket API on the EXISTING offload stack
High value-per-effort, no re-architecture, all on `net.mod` + the `_Net_Xport_*`
seam. Makes the existing stack POSIX-complete and pleasant for real apps.

| Item | Effort | Value | BSD lift | Notes |
|------|--------|-------|----------|-------|
| **Blocking I/O** (sleep-not-poll for recv/accept, +serial/pipe) | Med | High | FGX-glue (machine layer) | **= preemption P4.** WCHAN sleep on the socket, wake on RX-ready IRQ / accept. Retires the spin-yield. This is the machine seam — not liftable; it's the FGX cooperative-MT analog of BSD `sbwait`/`sowakeup`. |
| **`select`/`poll`** | Med | High | 2.11BSD `sys_generic.c` `select()` semantics | Readiness multiplexing; **now unblocked** by the scheduler. Port the BSD selscan/selwakeup shape onto FGX fds; the socket `soo_select`/can-read/can-write predicates lift. Builds on the blocking-I/O primitive. |
| **DNS resolver** | Small | High | **2.11BSD `libc/net`** (`res_*`, `gethostbyname`, `named/` shape) | Hostname support (`nc <host>`, `ping <host>`). **Best value-per-effort** and a near-**verbatim libc port** — the BSD resolver is a small UDP client; only the socket calls + config (`/etc/resolv.conf`) need FGX wiring. No stack change. |
| **Connected-UDP + `shutdown` + `getpeername`/`getsockname`** | Small | Med | 2.11BSD `netinet/udp_usrreq.c` + `uipc_socket.c` semantics | POSIX completeness; needs per-descriptor peer storage (socket record resize). The `PRU_CONNECT`/`PRU_SHUTDOWN`/`PRU_PEERADDR` request handling lifts. |

### Track B — the software stack as a faithful 2.11BSD port (P1–P6)
Large foundational campaign, but reframed per the governing principle from a
"from-scratch FGX-native stack" to a **verbatim 2.11BSD `netinet`/`net` port**
with a thin FGX machine layer. Phases (per the design spec, retargeted to lifts):
- **P1 — `ifnet`/`protosw` seam.** Lift `net/if.h` (`ifnet`) + `h/protosw.h`
  verbatim as the interface; extract the W5100 driver out of the kernel behind
  it (its `protosw` still drives the chip). Independently useful — decouples
  hardware from the kernel, extends FGXM to net devices — and the correct first
  step whenever Track B starts.
- **P2 — software L3 + `lo0`.** Port `netinet/{in,ip_input,ip_output}.c`,
  ARP (`netinet/if_ether.c`), ICMP (`netinet/ip_icmp.c`), and `net/if_loop.c`
  (`lo0`). Loopback-first: ping over `lo0`, no hardware.
- **P3 — software UDP.** Port `netinet/udp_usrreq.c`.
- **P4 — software TCP.** Port `netinet/tcp_{input,output,usrreq,timer,subr}.c`
  — the **whole battle-tested FSM**, not a bespoke simplified one. This is the
  single biggest reason to lift rather than reimplement: BSD TCP's retransmit /
  FIN-RST / window-edge correctness is exactly what a hand-rolled FSM gets wrong.
- **P5 — real links.** `net/if_sl.c` (SLIP, verbatim) over a serial chardev,
  and/or the W5100 MACRAW frame `ifnet`. First off-box via the software stack.
- **P6 — offload routing** — capability-based `protosw`/PCB routing so W5100
  offload and the software stack coexist; more drivers.

**Port set is bigger than P1–P6 implies (Fable):** `tcp_input.c` alone has ~47
mbuf-op references plus `sbappend`/`sorwakeup`/`sonewconn`, so the mandatory port
set also includes **`uipc_socket2.c`** (socket buffers), **`in_pcb.c`** (PCBs),
and **domain/`protosw` init** — none were listed. **`uipc_mbuf.c` is MANDATORY,
not "if memory allows":** the flat-buffer "shim behind the same API" is illusory
— `m_pullup`/`m_adj`/`m_copy` chain semantics *are* mbufs, so a shim implementing
them *is* an mbuf implementation. Budget it.

**What must be reimplemented (the non-liftable seam):** `spl()`/softint → FGX
cooperative-MT + a network timer task driving `pr_fasttimo`/`pr_slowtimo`; the
mbuf pool sizing; the IP/TCP checksum inner loop in 65816 asm; `htons`/`ntohs`;
bank-aware pointer/DBR glue. **Bitfields are confirmed** in `ip.h` (12 sites) and
`tcp.h` (6) — the fcc-capability audit is genuinely load-bearing; run it before
any Track B commitment. **Hardware ceiling:** the W5100 has only **4 hardware
sockets** — telnetd (listen+conn) + a DNS query already brush it; a software
stack over MACRAW would relieve this, but note it. (Good news: no
`SUPERVISOR`/supervisor-space macros leak into `netinet/*.c` — the K&R protocol
code really does lift cleanly once the socket/mbuf/pcb substrate is present.)

**Prerequisite spike (before committing to P2+): an fcc-capability audit** — can
fcc compile 2.11BSD `netinet/` as-is? It is 16-bit-int K&R (the good path), but
check for bitfields, K&R constructs, and capacity ceilings the stack trips.
Cheap to measure, de-risks the whole port. (Same discipline as the elvis TU
audit.)

Payoff: hardware-agnostic networking, non-W5100 links (SLIP = off-box with no
Ethernet card), other cards, `netdump`-sees-ICMP, and the substrate for **IPv6**
and **AppleTalk**.

## 4. First targets: telnet + telnetd — what the initial push MUST cover

The maintainer (2026-07-19): the first tools are **telnet** and **telnetd**. Both are
single-file 2.11BSD C — `usr/ucb/telnet.c` and `usr/libexec/telnetd/telnetd.c`
(26 KB) — so they lift (IAC option negotiation and the relay loop come with the
source). What they *demand* from the platform, mapped to the push:

**telnet (client) — Track A + existing tty, but MORE than "DNS + select"
(corrected per Fable, from reading `usr/ucb/telnet.c`, 2364 lines):**
- multiplex keyboard(stdin) + socket → **`select`/`poll`**. *Required, and it is
  the true center of the push.* Must accept **`exceptfds` + a `{0}` timeout** even
  with SYNCH stubbed: `stilloob()` (telnet.c:282-304) selects on exceptfds and is
  reachable **without any OOB** via in-band IAC `DM` (telnet.c:1096-1106); if
  select `EINVAL`s on exceptfds, telnet `quit()`s.
- **`FIONBIO`** (nonblocking) on tty AND socket, with `EWOULDBLOCK`/partial-write
  semantics (telnet.c:678-679,753) — **FGX has none; add it.** *Hard requirement.*
- `gethostbyname` → **DNS** — but **DNS depends on select** (`res_send.c:249`
  selects on the query socket), so DNS follows select, it is NOT independent.
- **`getservbyname`** — telnet **exits at startup** without it (telnet.c:2318);
  add `getservent`/`getservbyname` + `/etc/services`. *Hard gate.*
- **`shutdown(net,2)`** in `bye()` (telnet.c:1966) — on the path; return unchecked,
  so a libc **ENOSYS stub is enough**, but it must link.
- `SO_OOBINLINE` **defined in headers** (selects telnet's simple compiled path,
  avoiding `SIOCATMARK`); `send(...,MSG_OOB)` degrades to in-band (OK fallback).
- local raw/cbreak → mostly present, but telnet also uses **`TIOCGLTC`/`TIOCSLTC`**
  (`mode()`) and **`TIOCFLUSH`** (telnet.c:470) — **absent** from FGX ioctl; add or
  no-op. Plus `sigblock`/`sigsetmask` (telnet.c:684) — **absent** from libc.
→ **telnet client = select(+exceptfds) + FIONBIO + DNS + getservbyname + a few
tty/sig stubs; no pty. Still ships FIRST, but the checklist is bigger than "DNS +
select".**

**telnetd (server) — needs a PTY subsystem, RE-SCOPED (Fable: not a one-file
lift):**
- **It's an inetd child.** Production `main()` does `getpeername(0,…)` — the
  connected socket arrives as **fd 0** from inetd (telnetd.c:155-165); the
  listen/bind/accept path exists only under `#ifdef DEBUG` (114-154). FGX has no
  inetd → the port adds a **standalone accept loop** (the DEBUG block is the
  template), which also makes `getpeername` avoidable (accept returns the peer).
  BSD is fork-per-connection; a standalone FGX telnetd is **one session at a time**
  unless it respawns — acceptable, state it.
- **PTY: re-scoped from "lift `tty_pty.c` (12 KB)" to a per-tty refactor + a
  native pty chardev.** `tty_pty.c` (570 lines) is welded to the BSD tty subsystem
  FGX lacks — `linesw[]`, `ttyinput`/`ttioctl`, clists (`getc`/`putc`/`b_to_q`),
  `selwakeup`, `spltty`, `uio` (~50 call sites). And FGX has **exactly one tty**
  (`_ttyTable`, `main.s:186-227`) with the cook/CBREAK/RAW discipline **inlined**
  in `_Sys_Read` against absolute `_ttyTable+` addresses + the keyboard ring, and
  ioctl hardwired to tty[0] (`syscall.s:1511-1547`). So the real work is: (1)
  **make tty state per-instance** and refactor the cook path to take a tty
  pointer; (2) a **pty chardev pair** in FGX's chardev registry (`chardev.s` —
  per-device ioctl vtable, `/dev/` resolve) using **`tty_pty.c` as a behavioral
  spec**, not a verbatim lift; (3) **`TIOCPKT` packet mode** — telnetd enables it
  unconditionally and **skips byte 0 of every pty read** (telnetd.c:389,568-576);
  a pty without it silently eats the first data byte; (4) per-tty `FgPgrp` + ^C→
  SIGINT so a remote ^C interrupts the remote command. **This per-tty refactor is
  the true cost center — likely bigger than the pty pair itself.**
- relay socket ↔ pty-master → **`select`** + **FIONBIO** on all three fds
  (telnetd.c:387-388).
- `fork`+`exec` shell → **`SYS_FORK` is a stub**; adapt to **`spawnve` launching
  `jsh` on the pty slave**. **VERIFIED it works (Fable):** `SYS_POSIX_SPAWNX`
  file_actions supports `FA_OP_OPEN`/`CLOSE`/`DUP2` on the child fd table
  (`process.s:670-830`) + `SYS_DUP2` (89) — open the slave, DUP2 onto child 0/1/2.
  No hedge. Single-user → no `login`/`getty`; spawn `jsh` directly.
- **`SIGCHLD` is never raised** in FGX (in the default table, `signal.s:849`, but
  no raise site) — telnetd's `signal(SIGCHLD, cleanup)` won't fire; teardown must
  key on **pty-master read EOF** (slave closed) or `waitpid`, not SIGCHLD.
→ **telnetd = per-tty refactor + native pty chardev (TIOCPKT) + select/FIONBIO +
spawnve-on-pty + accept-loop + EOF-teardown. Ship SECOND. Bigger than the doc
first implied.**

**Initial push, corrected spine:** **`select`(+exceptfds) + FIONBIO → DNS →
per-tty/pty subsystem.** `select` is the center (the WCHAN_SOCK sleep primitive
already exists, §1); DNS strictly follows select (`res_send` selects); the pty
work is a subsystem refactor, not a lift. Not the full Track A list (connected-UDP
is off-path), and none of Track B.

## 4b. Loopback — the telnet/telnetd test vehicle (the maintainer, 2026-07-19)

telnet↔telnetd needs a way to talk **to itself** for headless MAME testing
(telnet 127.0.0.1 → a local telnetd, no second machine). The current stack is
W5100 **offload** — the chip won't loop 127.0.0.1 back internally — and the full
BSD `lo0` `ifnet` (`net/if_loop.c`) needs the software stack (Track B P2). So add
a **near-term socket-layer loopback backend** at the offload-agnostic
`_Net_Xport_*` seam (`src/modules/net/net_xport.s`): a `connect` to `127.0.0.1`
(or the bound-local addr) matches a local **listening** socket and wires an
**in-memory bidirectional socket pair** (pipe-like — reuse FGX's `kernel/pipe.s`
buffering) instead of going to the W5100. `listen`/`accept`/`send`/`recv`/`close`
route through the loopback path; the socket layer is unchanged above the seam. No
software IP stack, no new hardware — it's a second transport backend beside the
W5100 offload, and directly unblocks a `telnet_loopback.json` closed-loop MAME
fixture (telnet drives a local telnetd through a pty, byte-checked). **Sequence
it EARLY** (alongside select/FIONBIO) — it's how every telnet/telnetd increment
gets tested. The verbatim BSD `lo0` `ifnet` remains Track B, arriving with the
software stack as the clean form; the socket-layer loopback is the offload-era
pragmatic form. No existing loopback in the tree today (grep-confirmed).

## 5. Recommendation & sequence

**Near-term (Track A, driven by telnet + telnetd; corrected per Fable):**
1. **`select`/`poll` (+`exceptfds`, `{0}` timeout) — the true center.** The
   readiness sleep/wakeup primitive **already exists** (`WCHAN_SOCK` broadcast +
   condition re-check, §1); `select` adds per-fd predicates + multi-fd wait over
   it. P4's remaining networking debt is small; `select` is the work. Prototype
   it over the existing `WCHAN_SOCK` + `_kKbdRingCount` predicates first.
2. **`FIONBIO`** (nonblocking fds + `EWOULDBLOCK`) — both tools require it; FGX
   has none. Pairs with #1.
2b. **Socket-layer loopback backend** (§4b) — connect-to-127.0.0.1 wires an
   in-memory local socket pair at the `_Net_Xport_*` seam. The **test vehicle**
   for telnet↔telnetd; sequence it early with select/FIONBIO.
3. **DNS resolver** (lift 2.11BSD `libc/net` `res_*`, ~1700 lines) **+
   `getservbyname`/`/etc/services`**. **Follows #1** (`res_send` selects). →
   **telnet client ships here** (+ the tty/sig/`shutdown` stubs from §4).
4. **Per-tty refactor + native pty chardev** (`tty_pty.c` as spec, not lift; per-
   instance tty state, cook-path-by-pointer, `TIOCPKT`, per-tty pgrp/^C) +
   `spawnve`-on-pty (verified OK) + a standalone accept loop + EOF teardown. →
   **telnetd ships here.** *This is the largest single item; scope its shape
   (chardev-native vs tty-subsystem port) before estimating.*
5. **Connected-UDP + `getpeername`/`getsockname`** — cheap POSIX completeness,
   **off the telnet path**, do it after. (`shutdown` is on-path but only as an
   ENOSYS stub — see §4.)

**Cheap de-risking spikes BEFORE executing (Fable):**
- **fcc-compile-probe `telnet.c`** — exercises fn-ptr tables, the K&R
  `call(routine, &args)` varargs class, cast tricks, and (telnetd) writes into a
  string literal (`line[i]=c`). Hours; kills most unknowns for target #1.
- **fcc-compile-probe the resolver trio** (`res_comp`/`res_mkquery`/
  `gethnamadr` — pure C, no kernel deps).
- **`select` prototype** over the existing `WCHAN_SOCK` + kbd-ring predicates —
  proves the "primitive already exists" claim end-to-end.
- **decide the pty shape** (native chardev pair vs tty-subsystem port) — swings
  that item's size several×.

**Probe RUN (2026-07-19) — fcc-compile-probe of telnet.c constructs:** found ONE
hard fcc gap that must land toolchain-first before telnet ports: **K&R
function-pointer parameter declarations** — `int f(routine) int (*routine)(); {…}`
fails with *"expected parameter name in K&R declaration"* for any arg form (`()`,
`(int,char*)`, `(void)`). telnet.c's **central `call()` varargs dispatcher**
(telnet.c:2205) uses exactly this.  **★FIXED 2026-07-19** (toolchain feat/fcc-knr-fnptr-param, held local): route the K&R param-decl path through parse_fn_ptr_declarator; fixture tests/M18/fn_param_knr.c; gate 464/0. **The fix is small + additive:** fcc already
compiles the ANSI form (`int f(int (*g)())`) and struct fn-ptr fields fine, so the
declarator machinery exists — the K&R *param-declaration* path just expects a bare
identifier instead of routing `(*name)(args)` to the declarator parser. Route it
through, add a fixture, done. Other flagged constructs (fn-ptr command tables,
`Ambiguous()` casts, ANSI fn-ptr params) compile clean. Separately confirmed: FGX
has **no standard `<sys/socket.h>`/`<netinet/in.h>`/`<arpa/telnet.h>`/`<netdb.h>`**
(its net tools use a bespoke `src/userland/lib/socket_h.h`), so a verbatim
telnet.c compile needs **BSD-shaped headers provided over the FGX socket API** —
known porting plumbing, part of the telnet-client work item.

**Defer (Track B + AppleTalk):** the software-stack port (P1–P6) and the
AppleTalk driver (LLAP/DDP/NBP — a large separate effort that fits Track B as a
link backend / address family; **not** in 2.11BSD's `netinet`, so far less
liftable — netatalk-era sources are its closest lift, weigh separately). Start
Track B only when a concrete driving need lands: a second NIC, SLIP-over-serial,
IPv6, or AppleTalk. When it does, the entry sequence is **(a) the fcc-capability
audit of 2.11BSD `netinet/`, (b) P1 (`ifnet`/`protosw` seam), then (c) the
loopback-first port P2→P4** — lifting verbatim, adapting only the machine seam.
Until then the W5100-offload stack + a complete socket API (Track A) serves the
single-card IIgs well, and P1's kernel-decoupling value doesn't yet pay its cost.
Because Track B is a *port* (not a from-scratch build), its cost is lower and its
correctness higher than the 2026-06-24 estimate — which lowers the bar for
starting it, but does not by itself supply the driving need.

**Framing note:** blocking I/O is the hinge — it's simultaneously preemption P4
and networking's next step. Build it once, under preemption, and Track A's
select/poll follows naturally from its wait primitive. Track B is a *different
kind* of work (a protocol stack), not a continuation of Track A.

Ledger: `project_fgx_networking`, `project_fgx_net_driver_architecture`.
Cross-ref: the preemption campaign roadmap (P4) —
`history/plans/2026-07-17-preemption-campaign-roadmap.md`.
