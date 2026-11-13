# Networking without a socket limit -- 2.11BSD TCP/IP over the W5100's MACRAW socket

Status: APPROVED by the maintainer 2026-11-03.  Built and tuned locally on
`feat/net-mux` before any upstream PR.  It replaces
sub-projects S1-S3 of `2026-09-27-trackb-s0-fcc-design.md` (Track B); that
document's S0 fcc list stands and is folded in here.

## 1. Intent

FGX is a multiuser BSD system, so any process -- a system daemon or one a
user wrote -- must be able to open, connect, listen on and accept as many
sockets as it wants.  The machine's limits should be the ones a real 2.11BSD
host has (memory), never the network card's.

Today they are the card's.  The Uthernet II's W5100 runs TCP, UDP and ICMP in
hardware and has four sockets, so the whole machine can hold four endpoints
at once.  Socket 0 was held back for packet capture until #46; with it given
back, inetd's telnet listener, ntpd and an ftp control connection still use
three of the four, and ftp's data connection was the one that failed
(ENOBUFS).  The workload the maintainer named for a busy moment -- a few
telnet logins, inetd, ntpd, ftp and wget, httpd and ftpd, and users' own
daemons -- is roughly 15 to 25 endpoints.

### Why connections cannot be multiplexed onto the chip

The obvious design -- queue or swap connections in and out of the four
hardware sockets -- does not work for TCP, and the reason is the chip's, not
a choice:

- The W5100 keeps each TCP connection's state (sequence numbers, window,
  timers) inside the chip.  Its socket registers expose mode, command,
  status, ports, peer address and buffer pointers only
  (`include/socket.s`, "W5100 socket-register offsets"); nothing would let a
  driver save a connection and restore it.  Freeing a hardware socket means
  closing the connection.
- An idle telnet session therefore holds its socket for hours, and a
  listener must sit in the chip to receive a connection at all; while one is
  swapped out, the chip itself refuses the connection.
- Queueing `connect()` until a socket frees deadlocks: ftp's data connection
  waits forever while its own control connection holds a socket.

So the multiplexing has to happen per PACKET, which means the connection
state machines move into the kernel and the chip becomes a packet carrier.
That is 2.11BSD's own networking code, which Track B was already porting.

## 2. Goals, non-goals, anti-goals

Goals:

- No limit on sockets other than memory: TCP and UDP sockets, listeners,
  loopback and the wire, for every process.
- 2.11BSD's networking code (`sys/uipc_*`, `net/`, `netinet/`), ported
  verbatim behind provenance headers, with only the machine seam written for
  FGX -- the same rule as the rest of the system.
- Loopback through 2.11BSD's own `lo0` (the 2026-07-20 decision), retiring
  the hand-built rings in `net_loop.s`.
- Existing programs keep working unchanged: telnet/telnetd, inetd, ntp,
  ftp, ping, dhclient, nc, syslogd -u, and everything the gate tests.
- Nothing above the interface driver knows which card is fitted.  The
  Uthernet II becomes one `ifnet` driver, so another network interface --
  a different Ethernet card, SLIP over the serial port, LocalTalk -- needs
  only a driver of its own.

Non-goals (here):

- Multi-NIC, IPv6, AppleTalk, SLIP.  The `ifnet` this builds is what they
  would attach to, but none is in scope.
- Raising other system limits (NPROC, the stack arena).  Only the
  networking-specific ones are in scope (section 4.6).

Anti-goals -- these would make it a failure even if it ran:

- Any fixed cap on sockets that is not memory: a table sized to the card, a
  descriptor index that has to fit a byte, a queue that makes `connect()`
  wait for hardware.
- An FGX-invented protocol implementation where 2.11BSD has one.
- Two TCP implementations kept side by side (a hardware "fast lane" next to
  the kernel's).  The measured cost does not justify it (section 5).
- Uthernet II specifics anywhere but its driver: per-card behavior in the
  socket layer, the protocols or the system calls would tie the stack to
  this one card.

## 3. Decisions

The maintainer decided:

- **The kernel takes the connections.**  Accepted cost: roughly 10% slower
  transfers to disk and perhaps a third slower network-to-memory, measured
  and estimated in section 5.
- **This replaces Track B's first slice.**  The first working slice is UDP
  on the real network as well as loopback, not loopback only.
- **No artificial limits** unless absolutely necessary.
- **The stack's memory comes from the bank pool.**  About 4-5 banks (code
  plus mbufs) out of the 56 that processes draw from at 2 each, so roughly
  2-3 fewer processes at once; accepted.
- **No hardware fallback.**  If S4's throughput disappoints, the answer is
  not to bring the chip's TCP back beside the kernel's: that would put
  Uthernet II specifics back above the driver, against the goal of a stack
  any network interface can sit under.
- **Real hardware checks the chip.**  The maintainer has a real IIgs with
  an Uthernet II and runs S2's probe on it (section 7).

Made in this design (the designer's calls, open to the maintainer):

- **MACRAW on socket 0, the full 2.11BSD stack including `if_ether.c`
  (ARP).**  The alternative, IPRAW sockets per protocol with the chip still
  doing ARP and IP headers, does not work: the chip never delivers TCP or
  UDP to an IPRAW socket (section 4.1).
- **No hardware TCP or UDP in the end state.**  Sockets 1-3 stay unused, and
  socket 0 gets the chip's whole 8 KB of receive buffer and 8 KB of transmit
  buffer.  Why that loses nothing:
  - A hardware socket is the chip running one TCP or UDP endpoint itself.
    With the kernel running TCP and UDP, there is nothing left for sockets
    1-3 to do, and MACRAW exists only on socket 0, so the stack has to sit
    there.
  - What the idle sockets give back is buffer memory, which is what
    matters.  The chip's 8 KB of receive and 8 KB of transmit buffer are
    divided among its four sockets, 2 KB each today.  With 1-3 unused,
    socket 0 can have all of it.  Today's 2 KB receive buffer is the likely
    reason a transfer runs at 99 KB/s (section 5), so the larger buffer is
    where some of the cost of a kernel TCP may be won back.
  - During the migration (S3) sockets 1-3 still carry the chip's TCP; they
    retire in S4.
- **bpf becomes a software tap** on the interface (2.11BSD's model) rather
  than a second owner of socket 0.
- **The checksum is hand-written 65816 assembly, folded into the copy from
  the chip**, which measured at about 7% over today's drain (section 5).
- **Several code banks over one data bank.**  A module's C runs with DBR on its
  own bank, so it cannot name another module's global, and 2.11BSD's layers
  share theirs throughout.  DBR is one data bank in all of them, so those stay
  plain globals and no BSD source changes.  Far-pointer externs in fcc were
  rejected: they touch every global-addressing path and slow every crossing
  access.
- **`fgx`, not `pdp11`.**  With 4-byte pointers the pdp11 arm is wrong: its pads
  (`netinet/ip_var.h`) would misplace every overlaid IP header.  `fgx` takes the
  VAX layout and the pdp11 word-size choices, site by site (`docs/PROVENANCE.md`).
- **`splnet` masks nothing; `splimp` and `splhigh` set the I flag.**  `netintr`
  runs only at the kernel's deferred-work drain, which kernel code reaches only
  by sleeping, as upstream allows.  This holds only while no protocol code runs
  from an interrupt: the driver's interrupt path may only queue.
- **`netintr` has a 1024-byte stack of its own** (`FGX_STK_NET`, section 7).
- **The modules stay out of `/etc/rc.in` until S3.**  Loading them takes socket 0
  for good, and nothing yet uses the kernel stack.  The shipping `rc.local` starts
  no daemon, so ftp still fits; with inetd and ntpd it does not.  S3 adds them when
  UDP moves and a socket comes back.
- **The drain copies plainly, and `ip_input` checksums.**  Folding the checksum into
  the copy means changing ported code with no measured need yet; section 5's numbers
  decide it at S4.
- **The callout list is private to the network modules** (`machine/net_callout.c`,
  20 entries), and `net_charge` brings it up to date before each insertion, since no
  clock interrupt charges each tick.  A second user moves it.
- **The driver addresses the chip through X, long-indexed from slot 0,** with no
  patch table.  Not checked against a 65816 cycle table.
- **The heartbeat marks the drain every 8th tick**, 11 core bytes, for timers and as
  the driver's backstop poll.  It is unconditional: a kernel with no network modules
  pays a `kc_ttdrain` scan 7.5 times a second, and section 5 measures that as nothing
  visible.  A 2-byte mask cell the modules set is the fallback if that changes.
- **bpf reads a ring in the network modules' data while the stack is attached,**
  found through bsdnetd's vtable, so a boot without them pays 2 bytes of heap.
- **`netintr_enter` opens interrupts.**  The idle site drains with I set, and protocol
  code must not hold off the VBL.
- **`netintr` shares `_Tty_DrainOutPend`'s drain.**  The cost is latency: about
  67 ms past a compute-bound C program, and until the next system call past an
  assembly or `goto` loop.

## 4. Design

### 4.1 What the chip does in MACRAW mode

Verified against the W5100 emulation the tests run on (Ample's MAME, source
`ksherlock/mame` branch `a2uthernet2`, `src/devices/machine/w5100.cpp`),
not yet against real hardware (section 7).  WIZnet's W5100 datasheet v1.1.6
agrees on `Sn_MR` 0x04, socket 0 only, the 2-byte header and `MR_PB`, and is silent
on MACRAW beside open sockets and on the MAC filter bit, which comes from Linux's
`w5100.c` and the W5100S manual:

- An incoming UDP or TCP packet goes to a hardware socket that claims its
  port; failing that, to the MACRAW socket if one is open; only failing
  that does the chip answer it itself (ICMP port unreachable for UDP, a
  reset for TCP).  (`recv_cb`, `w5100.cpp:974-1003`.)
- IPRAW sockets receive only protocols other than TCP and UDP (`:1012`).
- Every frame reaches the MACRAW socket at the end of receive processing,
  after the chip's own handling (`:1066`): ARP is answered by the chip AND
  passed up; an ICMP echo is answered by the chip unless the ping-block bit
  is set (`MR_PB`, `:1024`) AND passed up.
- MACRAW frames carry a 2-byte length header (`process_macraw`,
  `w5100_socket.cpp:1210`).  Transmit is a whole Ethernet frame; the chip
  resolves nothing, so the stack does ARP (`if_ether.c`).

Consequences the port must handle: set `MR_PB` so the kernel's `icmp_input`
answers pings rather than both answering; and expect the chip's own ARP
reply alongside the kernel's (harmless duplicates; the builder decides
whether `if_ether.c`'s reply path needs an FGX note).

Because hardware sockets claim their ports first, the kernel stack can
coexist with the chip's TCP during migration: UDP moves to the kernel while
TCP stays on the chip, then TCP moves.

### 4.2 The stack

2.11BSD's networking, from `vendor/2.11BSD/usr/sys` (copy in from
`examples/2.11BSD/usr/sys` as files are ported, per the vendoring rule),
roughly 9,000 lines:

| Layer | Files |
|---|---|
| sockets, buffers | `sys/uipc_socket.c`, `uipc_socket2.c`, `uipc_mbuf.c`, `uipc_domain.c` |
| TCP | `netinet/tcp_input.c`, `tcp_output.c`, `tcp_subr.c`, `tcp_timer.c`, `tcp_usrreq.c` |
| UDP, PCBs, ICMP, raw | `netinet/udp_usrreq.c`, `in_pcb.c`, `in.c`, `in_proto.c`, `ip_icmp.c`, `raw_ip.c` |
| IP | `netinet/ip_input.c`, `ip_output.c` |
| ARP, Ethernet | `netinet/if_ether.c` |
| interfaces, routes, loopback | `net/if.c`, `route.c`, `if_loop.c` |
| AF_UNIX | `sys/uipc_usrreq.c` |
| socket system calls | `sys/uipc_syscalls.c` (the bodies; see 4.5) |

The Track B S0 audit compiled the UDP-loopback subset under fcc: about 55k
instructions (140-150 KB, several module banks) and a 36 KB mbuf pool.  TCP
and ARP add to that.

### 4.3 The machine seam (FGX-written)

What Track B's S1 described, unchanged in substance: `netparam.h`/`mbuf.h`
for 4-byte pointers and a banked mbuf pool; `spl*` and the network software
interrupt (`setsoftnet`/`netisr`) mapped onto FGX's scheduling; the
supervisor-space and PDP-specific macros in `pdp/net_mac.h`; a multi-module
split over one data bank (section 3, `tools/build_bsdnet.py`).  Plus, new here:

- **The W5100 MACRAW interface driver** (`if_w5` or similar): an `ifnet`
  whose output writes a frame to socket 0's transmit buffer and whose
  receive path, woken by the existing W5100 interrupt, drains frames from
  socket 0 into mbufs and hands them to `ether_input`.  It takes over socket
  0 permanently; `_W5_SockAlloc` and the hardware TCP/UDP cores retire at
  the end.
- **The checksum** (`in_cksum`): 65816 assembly.  On receive it is computed
  while draining the chip; the fused loop measured at 229 KB/s against
  today's 246 KB/s drain.
- **bpf** re-attached as a tap in the interface's input and output paths,
  in S2, when the stack takes socket 0 -- so packet capture keeps working
  at every phase.
- **A callout facility** (`timeout()`/`untimeout()`).  The kernel has none
  today (`src/kernel/tty/tty.c` says so), and TCP's timers, ARP's entry
  aging and IP reassembly all need it.  2.11BSD's is the model.

### 4.4 Phases

Each phase ends with the system working and the gate green.

| | Phase | Delivers |
|---|---|---|
| S0 | fcc prerequisites | the remaining items of the Track B S0 document: 3.2 `##`, 3.4 extern of an incomplete struct, 3.5 struct assignment into an array element, 3.6 address constants in static initializers, 3.7 `&` of any lvalue, 3.8 struct return by value.  3.1 landed in !399; 3.3 landed in #46 (`b2305ec`, the block-scope extern fix).  **Done** on feat/net-mux (`46dba3b`..`084ecce`), with three items the S0 audit found: a call through a function pointer at the end of a member chain, a typedef of a sized array, and `sizeof` of `*` applied to a member chain.  All 23 files of the port set then compile, under `-Dpdp11`, which S1 found to be the wrong arm (section 3); all of them, with the `net/` files added, compile under `fgx`.  Left for S1, all seams: `h/signal.h:129` lacks a `;`; `FMARK`/`FDEFER` and `FREAD`/`FWRITE` are defined nowhere in 2.11BSD's `h/` (4.3BSD-Reno `sys/file.h` has them); `uipc_domain.c`'s `ADDDOMAIN` pastes with the Reiser `x/**/domain`, which the port writes as `##`; and the PDP arms of `h/types.h` and `pdp/seg.h`. |
| S1 | machine seam + packaging | section 4.3 minus the driver: mbufs, spl/netisr, module split.  **Done** on feat/net-mux (`f07f1da`..): `bsdnetd` and `bsdnet0`-`3` are built and staged, and no boot loads them; `modload` of all five on a `kernel.netprobe = 1` kernel runs the probe.  182 KB of code and a 41 KB data image, 35 KB of that the mbuf pool: five banks.  Callout and bpf stay in S2, as this table says; `in_cksum` landed here, since IP cannot link without it.  S2 inherits `machine/s2_stubs.c` (`timeout` does nothing, so no timer fires), one global `u`, which is not safe across a sleep and is S3's to fix, `printf` that logs only its format, C byte loops for `bcopy`, `sleep()` discarding `kc_sleepi`'s signal answer, which is S3's with `u`, and adding the modules to `/etc/rc.in`. |
| S2 | substrate running | mbufs, domains/protosw, sockbufs, `in_pcb`, `lo0`, `ip_input`/`ip_output`, ARP, the callout facility, the MACRAW driver on socket 0 and bpf as its tap, proven by an in-kernel probe: ARP resolves the gateway, an ICMP echo goes out and the reply comes back; netdump still captures.  **Done** on feat/net-mux under MAME (`d8cad04`..), and the maintainer's run on real hardware decides S3 (section 7); the modules stay out of `/etc/rc.in` until S3 |
| S3 | UDP | every AF_INET UDP socket is a BSD socket on the kernel stack, wire and loopback; ntpd, ntpdc 127.0.0.1, dhclient (4.7) and syslogd -u on it; the chip's UDP core retires.  **Done** on feat/net-mux under MAME (`6905dc6`..), the modules loading at boot from `/etc/rc.in`; the maintainer's run on real hardware is next (`docs/history/2026-11-10-net-mux-s3-hardware-run.md`).  A process's `u` is saved per pid across `sleep`, which longjmps with EINTR as 2.11BSD's does; net.mod hands a datagram socket's every call to the stack through `net_kso.s` and `bn_sys.c`; dhclient takes its lease through the stack from 0.0.0.0 and the address it sets reaches the stack (`BNOP_IFCHANGED`); a default route goes through the gateway.  Found on the way: fcc pushed one word for a struct argument `*p` and could not store through `a[i]->f`; a pointer's pad byte broke every UDP checksum over 255 bytes; `ifioctl` passed its command as an int where `pr_usrreq` reads a pointer; the interface's name `w5` has a digit, which `ifunit` reads as the unit.  Without the modules `socket(AF_INET, SOCK_DGRAM)` is EPROTONOSUPPORT. |
| S4 | TCP + AF_UNIX | `tcp_*` on the wire and loopback; AF_UNIX on `uipc_usrreq.c`; telnet/telnetd, inetd, ftp, nc and the unixdgram users on it; `net_loop.s` rings, `unp.s`, the old descriptor table and the chip's TCP core retire; socket count limited by memory.  Raw sockets and ping moved in from S5 (the maintainer's call).  **Done** on feat/net-mux under MAME (`f14ee1c`..): a socket is its FCB's struct socket (`FCB_SockSo`); TCP, UDP, raw and AF_UNIX all run on the stack, and net.mod forwards; `NMBUFS` 280 carries sixteen connections; AF_UNIX names go through 2.11BSD's `UNPBIND`/`UNPCONN`/`UNPDET` seam onto the VFS; ping is setuid, as upstream installs it; socket 0 takes all 8 KB of the chip's buffer each way.  Found on the way: libc's listen dropped the backlog, accept never named the peer, bind and connect passed no length (an AF_UNIX path over 13 characters bound a different name), and the resolver set the address family in the wrong byte.  The maintainer's run on real hardware is next (`docs/history/2026-11-13-net-mux-s4-hardware-run.md`). |
| S5 | the rest | `ifconfig`/`route` ported from 2.11BSD against the real `ifnet`, the bespoke `SYS_IFCONFIG` retired |

### 4.4.1 Coexistence during S3

Until S4, TCP stays on the chip's sockets 1-3 and the kernel's UDP rides
MACRAW on socket 0; the chip routes by port (section 4.1).  A UDP socket
must therefore never open a hardware UDP socket after S3.

### 4.5 What userland sees

The socket system calls keep their 2.11BSD signatures; programs do not
change.  Error behavior becomes 2.11BSD's: ENOBUFS when mbufs run out,
never because a card slot is busy.

The designer's call: FGX's system call entry and libc's socket wrappers
(`toolchain/lib/libc_c/socket_srv.c`, the `_sock_argblk` argument block,
FGX's call numbers) STAY, so no program or library is relinked for this;
behind that entry, the call bodies are 2.11BSD's `uipc_syscalls.c`
(`bind`, `connect`, `sendto` and the rest turning their arguments into
`sobind`, `soconnect`, `sosend` ...).  The FGX-written part is only the
argument fetch.

### 4.6 Limits that go

- `SOCKD_MAX` (12) and the `FCB_SockIdx` byte offset that bounds it
  (`include/socket.s`): sockets become 2.11BSD `struct socket`s from the
  kernel's allocator, reached from the file table as 2.11BSD reaches them.
- `W5_NSOCK` as a limit on anything a process does.
- AF_UNIX's share of the old table: `src/kernel/unp.s` and its users move
  to `uipc_usrreq.c` in S4, because leaving AF_UNIX on the old table would
  keep a 12-socket cap, which is an anti-goal.
- The `inetd` listener re-arm workaround (ROADMAP, "Who re-arms a TCP
  listener"): a kernel listener stays a listener.

### 4.7 DHCP on a stack that wants an address

2.11BSD has no DHCP client path, and its PCB code assumes an interface
address: `in_pcbbind` refuses with no interface address at all
(`in_pcb.c:62`, which `lo0`'s 127.0.0.1 satisfies once it is configured),
and `in_pcbconnect` sends to `INADDR_BROADCAST` through the FIRST
interface's broadcast address (`in_pcb.c:138-142`), which is wrong while
the Ethernet interface has none.  dhclient must keep working at every
phase, so S3 decides how -- configuring the interface with `INADDR_ANY`
first, as early BOOTP clients did, or sending through bpf -- by reading
`in_pcb.c`, `udp_usrreq.c` and `ip_output.c` before choosing.  Any change
to the 2.11BSD files themselves is a divergence that goes to the
maintainer, with a BUGS and PROVENANCE note.

## 5. Performance

Measured 2026-11-03 under MAME (Uthernet II, real-time pacing), against a
vsftpd 3.0.5 server on the LAN, today's hardware TCP:

| Transfer of 1,110,016 bytes | Time | Rate |
|---|---|---|
| to `/dev/null` | 11 s | 99 KB/s |
| to a file on the UFS root | 38 s | 29 KB/s |

On a real IIgs with an Uthernet II (2026-11-10), the same kind of transfer runs at
9.9 KB/s to `/dev/null` and to a file alike, on `main` and on `feat/net-mux` with the
stack unloaded, and 9.6 KB/s with the stack loaded beside it.  MAME's Uthernet is
about ten times faster than the real card, so throughput measured under MAME says
nothing about hardware; S4 measures on the machine.

Cost per byte on the 65816, 1 MB per loop, timed by the emulator's cycle
markers (a throwaway benchmark, not in the tree):

| Loop | Rate |
|---|---|
| RAM to RAM word copy | 542 KB/s |
| the same with a ones'-complement checksum | 385 KB/s |
| today's drain from the chip (`_W5_RxCopy`'s instruction mix) | 246 KB/s |
| the chip drain with the checksum folded in | 229 KB/s |

Reading: the checksum is nearly free when fused into the drain, because the
chip's data port is slow-bus I/O.  The kernel stack's real additions are the
second copy (kernel buffer to user, about 1.9 s per MB) and TCP's
per-segment work, which is NOT measured (a guess of 2-3 ms per 1,460-byte
segment adds about 2 s per MB).  Estimate: network-to-memory 99 KB/s to
roughly 60-70 KB/s; to disk 29 KB/s to roughly 26 KB/s.  Today's transfer
is not CPU-bound (99 KB/s against a 246 KB/s drain ceiling); the chip's
2 KB receive buffer per socket is a likely limit, and giving socket 0 all
8 KB may win some of the cost back.  S2's probe and S4 must measure these
rather than trust the estimate.

S2, under MAME on `kernel.netprobe = 1`, with 2 KB of socket 0 receive buffer:

| Measure | Result |
|---|---|
| Module footprint | 232,124 bytes in five banks, with the probe |
| `netintr` stack, deepest seen | 332 bytes on a `lo0` echo, 368 after a wire burst, 394 with netdump tapping, of 1024 |
| Static worst case (`net_stack_depth.py`) | 469 bytes |
| ICMP echo round trip | 7-8 ticks, 117-133 ms; the chip's own `ping` answers within a tick |
| A burst of 45 replies into an undrained ring | 33 frames kept, 2 near-full passes counted, machine answers afterward |
| Draining those 33 frames | 18-19 ticks, up to 8 of them waiting for the poll |
| Heartbeat mark with no network modules | 10.4 s against 10.3-10.4 s for 40 shell-run `dd`s |

The round trip is not the poll: with the poll slowed to 64 ticks it stays 8.  Where
those ticks go is not known yet, and real hardware may not show them.  The heartbeat
figure is at `time`'s 0.1 s resolution on an exec-heavy load, so it says "not
visible", not "zero".

S3, under MAME on the shipping configuration (`kernel.netprobe = 0`) unless named:

| Measure | Result |
|---|---|
| Deepest process kernel slot, `netudp` (`loopprobe -u`, syslogd) | 740 of 1024 bytes, 284 spare; 474 with no modules (`netudp_nomod`); ntpd alike, 740.  The static walk said 766 + about 124 |
| Module footprint | 252,325 bytes in five banks, without the probe |
| Pool banks free at idle | 23.2 of 56 with the modules loaded, 28.2 without |
| ICMP echo round trip (`kernel.netprobe = 1`) | 7-8 ticks before the transmit wait and after it |
| A read of the chip's transmit free count | 23 us: 8000 in 11 ticks |
| Five full frames queued together (case 56) | all leave in one `w5start`.  MAME's chip reports its ring free as soon as SEND is issued, so it passes there with no wait at all: only hardware tells |

Throughput through the kernel stack is not measured under MAME: no bulk transfer
uses UDP, and ftp is still the chip's TCP.  The hardware run re-measures ftp
beside the stack.

S4, under MAME on the shipping configuration:

| Measure | Result |
|---|---|
| mbufs an idle TCP connection holds | 8, four at each end (socket, inpcb, tcpcb, header template); a listener 3, an unconnected TCP socket 3 |
| Pool | `NMBUFS` 280 (was 170) and 12 clusters: 16 connections and their listener hold 131.  bsdnetd's data runs to `$E5C2` of its bank |
| What runs out first | the system file table (`NFILE` 64, ENFILE) at 39 TCP sockets beside the test's own; with half the pool (85) ENOBUFS comes at 26, and a socket(2) that meets an empty pool waits in `socreate` (M_WAIT) until a close frees one, as 2.11BSD's does |
| Deepest process kernel slot, `nettcp` and `tcpmany` | 720 of 1024 bytes, 304 spare, in both; the static walk puts TCP's worst `sendto` at 854 with `sendit`'s name and rights in mbufs (it was 996) |
| Module footprint | 278,799 bytes on disk: 275,961 in the stack's five banks (S3's 252,325 plus TCP, raw IP and AF_UNIX) and net.mod's 2,838 |
| Memory at idle, modules loaded | 2,847 KB free of 8,320 (`vmstat -m`, the default test machine); the stack is still five banks, so the bank count S3 measured does not move |
| Core bank | 525 bytes free, from none, once the descriptor table and the chip transports went |
| 1 MB over `lo0` (`loopprobe -b`, a writer and a reader process) | 41.0 s, 25 KB/s |
| Where that transfer's time goes (`pc_sample`, 53,138 samples) | the stack's `bcopy` 30.2%, `in_cksum` 5.7%, `tcp_output` 4.0%, `tcp_input` 3.1%, the rest of the stack under 2% each; the kernel bank, idle included, 38.6% |

THE CHECKSUM IS NOT FOLDED.  Section 3 left S4 to fold it into the copy only if
`in_cksum` took over 15% of a `lo0` transfer; it takes 5.7% of all samples, and
10% of the stack's own.  The cost is the copy: `bcopy` in `net_kern.c` is a
byte loop in C, where 2.11BSD's is machine code.  S5 inherits it.

## 6. Testing

- Every existing gate test keeps passing at every phase; the socket tests
  (`loopprobe` and its tests, `bindzero`, `sockleak`, `sockemfile`,
  `unixdgram`) are the regression floor.
- A test that holds more sockets at once than the chip has -- for example
  sixteen TCP connections over loopback, each carrying data both ways --
  goes red before S4 and green after.  It is the anti-goal check.
- S2's in-kernel probe: ARP and an ICMP echo through MACRAW.
- Network tests that need a real peer (ntpnet-style, not in the gate):
  DHCP, ntp, an ftp `get` checked against the host's copy, and the
  throughput numbers of section 5 re-measured at S3 and S4.

## 7. Risks and unknowns

- **The chip behavior in 4.1 is the emulator's.**  Before S2 commits to it,
  check the WIZnet W5100 datasheet's MACRAW and IPRAW sections, and the
  maintainer runs S2's probe on a real IIgs with an Uthernet II before S3
  starts.  If a real chip does not hand port-unclaimed TCP
  and UDP to MACRAW while other sockets are open, the "UDP first, TCP
  later" phasing goes: S3 and S4 merge into one cutover.
- **TCP's per-segment cost** on this CPU is unmeasured.
- **Receive overrun:** with one 8 KB MACRAW buffer, a burst the kernel does
  not drain in time is dropped by the chip.  TCP recovers by
  retransmission; the driver should drain from the interrupt path promptly.
- **Memory:** 140-150 KB of code before TCP and ARP, plus the mbuf pool,
  in module banks from the process bank pool (accepted, section 3); S2 and
  S4 report the real figure.
- **The chip's duplicate ARP replies** (4.1).
- **The kernel stack.**  `netintr` runs on a 1024-byte stack of its own,
  `FGX_STK_NET`, with fcc's stack floor set so an overflow halts through
  `_fcc_stkoflow`.  Both drain sites share it, since `netintr` never sleeps and the
  drain does not re-enter.  `tools/net_stack_depth.py` (static) puts the deepest
  `netintr` chain at 469 bytes, still counting `sonewconn` -> `tcp_usrreq` chains a
  packet may not take, and with the driver a 40-byte guess.  Measured from the
  stack's paint, a `lo0` echo reaches 330 bytes.  The measured figure on the wire is
  in section 5.
- **A socket call's stack.**  The calls a process makes run the stack's C on that
  process's kernel slot, `kernel.kstk` = 1024 bytes, which cannot switch the way
  `netintr`'s does, because `sbwait` sleeps on it, and cannot grow: seven slots already
  fill 7 KB of the 8 KB `$E000` region.  `tools/net_stack_depth.py`'s static walk puts
  a UDP `sendto` at 766 bytes (`sendto -> sendit -> sosend -> udp_usrreq -> udp_output
  -> ip_output -> w5output -> ...`); with about 60 bytes of entry from the dispatcher
  through net.mod and the vtable, and 64 for an interrupt frame, that is 890, 134
  spare.  `sendit` alone is 300: two mbufs on its stack, `char sabuf[MSIZE],
  ribuf[MSIZE]`, for the address and the access rights.  TCP's worst `sendto` is
  826, 950 with the rest, which does not leave 128 spare: S4's to settle, by
  moving those two off the stack or measuring the real path, before TCP sockets
  reach the stack.  Measured from the slots' paint, a UDP workload reaches 740 of
  1024 (section 5).  S4 settled it: `sendit` takes its name and rights in mbufs, as
  4.3BSD-Reno's `sockargs` does, which puts TCP's worst at 854 bytes static, and a
  TCP workload's paint reaches 720.

- **S3 settled** what S2 left it: the modules load from `/etc/rc.in`; a default route;
  `sleep`'s signal answer; the transmit path waits up to 3 ms for a frame still
  sending (130 reads of the free count) before leaving the rest for the next pass.
  With UDP off the chip, ntpd no longer takes a chip socket, and the suite's
  rc.local no longer starves ftp's data connection.
- **S4 settled** what S3 left it: the descriptor table and its cap are gone (a
  socket is its FCB's struct socket); `net_kso.s` is the one door; `falloc` and
  `ufalloc` return the FCB net.mod allocated before the call; TCP's worst `sendto`
  (above); the chip's TCP and IPRAW, its ARP and routing, retired with the
  loopback and AF_UNIX rings.  `tools/check_net_retired.py` fails the build if one
  of their names is defined again.
- **S5 inherits:** the stack's byte-loop `bcopy` (section 5), which is a third of a
  transfer's time; descriptor passing over AF_UNIX (access rights answer EOPNOTSUPP,
  stated in unix(4)); a sender's AF_UNIX name cut to 14 characters by the 16-byte
  sockaddr libc copies (unix(4) BUGS); `NFILE` 64, which runs out before the mbuf
  pool; and the two names for the card, below.
- **Two names for the card until S5:** the kernel stack calls it `wz0`, which is what
  `SIOCGIFCONF` reports; net.mod's `SYS_IFCONFIG`, `ifconfig` and `dhclient` call it
  `u2s1`.  2.11BSD's `ifunit` reads a name's first digit as its unit, so a kernel
  name cannot carry the `2`.  S5's port of `ifconfig` against the real `ifnet` ends it.

- **Before the campaign PR**, deferred from S3's final review:
  - `gethostbyname`'s receive loop (`toolchain/lib/libc_c/netdb.c`) has no overall
    deadline: a peer sending unparseable datagrams to its port at least every 1.5 s
    keeps it waiting forever.  Bound each try by a deadline, as dhclient's
    `wait_reply` does with `left`.
  - `MSG_DONTWAIT` sets `SS_NBIO` on the shared `struct socket` for the whole call
    (`bn_sys.c`); a third process sharing the socket can get EAGAIN while the call
    sleeps in `sblock`.  2.11BSD has no per-call flag: make it per call, or state the
    divergence in PROVENANCE.
  - DONE in S4 (`f14ee1c`): `bn_sysent` sets `_fcc_stkfloor` to the running task's
    slot base, as `netintr_enter` sets its own; `netkstkovf` proves the halt.
  - The kernel's `printf` prints a format string without its arguments, so the
    stack's console messages read `%s: %s`.
  - `boot_netstart.json`'s description is out of date.
  - ntpd never initializes a new peer's stratum (upstream); ntpdc's offset is 32-bit
    milliseconds and wraps past 24.8 days (upstream).  Decide fix or BUGS entry.

## 8. Left to the builder

The module split and bank placement; mbuf pool size; the driver's name and
its receive scheduling; the order of files within a phase; how `spl` maps
onto FGX's interrupt masking; whether the in-kernel probes stay as tests;
whether S5's `ifconfig`/`route` port lands before or after bpf.
