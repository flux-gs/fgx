# FGX Networking

> Source of truth: `src/modules/net/{net,net_xport,net_loop,unp}.s` (the
> socket layer and transports, in net.mod), `src/kernel/{net_dispatch,uthernet,
> socket,ifconfig_sys}.s` (the kernel dispatch seam, the W5100 boot/ISR residue
> and interface config), `src/modules/bpf/bpf.s`,
> `include/{socket,ifnet,loader,errno}.s`, `toolchain/lib/libc_c/{socket,
> socket_srv,netdb}.c`, and the userland tools under `src/userland/`.  Where
> this doc and the code disagree, the code wins.

The socket layer, the transports and the W5100 driver are the loadable
**`net.mod`** ([modules.md](modules.md)); the kernel keeps the W5100 boot
bring-up and ISR (`uthernet.s`) and the `_Net_Dispatch` NETOP seam.

FGX talks to the network through an **Uthernet II** card (a WIZnet **W5100**
Ethernet controller). The W5100 does **TCP/UDP/IP/ARP offload in hardware**; FGX
does not run a software IP stack for the wire. The kernel exposes a **BSD socket layer** (sockets
are first-class Unix fds) over a transport-agnostic seam, with BSD-shaped
semantics so ported clients need few edits. What's shipped:

- **UDP** datagrams (`socket(AF_INET, SOCK_DGRAM, 0)`)
- **TCP** client *and* server (`SOCK_STREAM`; `connect` / `listen` / `accept`)
- **ICMP / raw IP** (`socket(AF_INET, SOCK_RAW, IPPROTO_ICMP)`) — used by `ping`
- **DHCP** (userland `dhclient`)
- **raw frame capture** via `/dev/bpf0` (W5100 MACRAW) — used by `netdump`
- **127.0.0.1 loopback** TCP (`net_loop.s`): a `SOCK_STREAM` socket to
  127/8 is serviced in software and never touches the chip
- **AF_UNIX** datagram sockets (`unp.s`, `SOCK_DGRAM` only)
- **name lookup** in libc: `gethostbyname` / `gethostbyaddr` read `/etc/hosts`,
  then send one DNS query over UDP to the nameserver in `/etc/resolv.conf`
  (`toolchain/lib/libc_c/netdb.c`)

## The hardware (W5100 over the indirect bus)

The boot card scan (`_ScanSlots`, `src/kernel/uthernet.s`) finds the first
W5100 in slots 1-7 and records it in `_u2Slot`; `_W5_PatchSlot` binds the
kernel's `U2_*` access sites to that slot, and net.mod and bpf.mod patch their
own in `mod_init`.  FGX reaches the W5100 through its **indirect-bus** register
window at `$E0C084 + slot*16` in bank `$E0` (the FGX I/O rule: bank `$E0`,
never `$00`).  For slot 1:

| Reg | Addr | Role |
|-----|------|------|
| `U2_MR`  | `$E0C094` | Mode Register (`$03` = indirect + address auto-increment) |
| `U2_ARH` | `$E0C095` | indirect address, high byte |
| `U2_ARL` | `$E0C096` | indirect address, low byte |
| `U2_DAT` | `$E0C097` | data port — **auto-increments the address** after each access |
| `SLTROMSEL` | `$E0C02D` | slot routing; bit *n* must be set to reach the card in slot *n* |

Every register or ring byte is a 3-write address-set plus a data cycle over a
~1 MHz cardbus — there is no DMA, so the driver is written for small packets and
masks IRQs around each multi-step sequence (see *U2_LOCK* below). Detection
(`_ProbeUthernet2`) writes `MR=$80` (reset → chip auto-clears to `$00`) then
`MR=$03` (reads back `$03`), logging `uthernet2: W5100 @ slot 1` or `… absent`.

The W5100 has **four hardware sockets**, each with a 2 KB TX and 2 KB RX ring.
**Socket 0 is permanently reserved** for `/dev/bpf0` MACRAW capture (the W5100
only does MACRAW on socket 0); `_W5_SockAlloc` hands out sockets **1–3** to UDP /
TCP / ICMP (`W5_NSOCK EQU 4`). So there are at most **3 concurrent** sockets on
the wire; loopback and AF_UNIX sockets do not count against them.

## Sockets are fds

`socket()` allocates an FCB tagged `FCB_FL_SOCKET` whose `FCB_SockIdx` holds a
byte offset into the kernel **socket descriptor table** — a Kmalloc'd soft-global
(`_sockTablePtr`, `SOCKD_MAX = 12` records of `SOCK_REC_SIZE` = 20 bytes;
`include/socket.s`). A descriptor records `SOCK_HwIdx` (the W5100 socket, or the
sentinels `SOCK_HW_UNCLAIMED` / `SOCK_HW_LOOP`), `SOCK_Proto` (a transport tag),
`SOCK_Bound`, `SOCK_LPort`, `SOCK_Flags` (`SO_BROADCAST`, `SO_REUSEADDR`,
`SOCK_NB`), and `SOCK_State` (TCP state). Because a socket is an FCB, `read`/`write`, `close`, and
fd inheritance all work on it; `Fs_Close` routes `FCB_FL_SOCKET` through
`NETOP_SockTeardown` to net.mod's `net_op_sockteardown` (chip CLOSE + free hw
socket + free descriptor).

`socket()` flow: validate the family → map `(type, proto)` to a transport tag
(`SOCK_DGRAM`→UDP, `SOCK_STREAM`→TCP, `SOCK_RAW`+`IPPROTO_ICMP`→ICMP, AF_UNIX
→`XPORT_UNIX`, else `EINVAL`) → grab a descriptor → `_Fcb_Alloc` a real fd. Any
failure rolls the whole thing back.  The W5100 socket is claimed later, when
the descriptor first needs the wire -- a UDP/ICMP `bind`, a TCP `connect` or
`listen` (`_Xport_Claim`, `net_xport.s`) -- and exhaustion is `ENOBUFS` from
that call.  (2.11BSD's `socket()` likewise allocates no interface resource: UDP's
`PRU_ATTACH` only calls `in_pcballoc`, `vendor/2.11BSD/usr/sys/netinet/udp_usrreq.c`.)

## The transport seam (XPORT)

The socket core (`net.s`) **never touches a W5100 register**. It dispatches
through a transport seam (`net_xport.s`) keyed on `SOCK_Proto`; loopback is
selected first by `SOCK_HwIdx == SOCK_HW_LOOP` and AF_UNIX by `XPORT_UNIX`:

```
net.s     ──_Net_Xport_{Open,Send,Recv,Connect,Close,Listen,Accept}──▶  _Xport_LoadTag
                                                                         │ branch on tag
                  ┌──────────────────────┬───────────────────┬──────────┘
              XPORT_UDP              XPORT_ICMP           XPORT_TCP
            _Udp_*Core             _Icmp_*Core          _Tcp_*Core
```

| Verb | UDP | ICMP/IPRAW | TCP |
|------|-----|------------|-----|
| Open | `_Udp_OpenAt` | `_Icmp_OpenAt` | `_Tcp_BindAt` (bind only) |
| Connect | — | — | `_Tcp_Connect` (auto ephemeral local port) |
| Send | `_Udp_SendCore` | `_Icmp_SendCore` | `_Tcp_SendCore` |
| Recv | `_Udp_RecvCore` | `_Icmp_RecvCore` | `_Tcp_RecvCore` |
| Listen / Accept | — | — | `_Tcp_Listen` / `_Tcp_Accept` |
| Close | nop | nop | `_Tcp_Close` (graceful FIN) |

All three wire transports are **shipped and wired**; TCP client *and* server are
live. Adding a second NIC driver later would turn the
tag branch into an indirect call through the ifnet's driver ops; today there is
one driver, so it's a branch.

Shared W5100 plumbing lives in `net_xport.s`: `_W5_SetSnAR` (point the indirect
address at a socket register), `_W5_TxStream` (stream the TX ring, issue SEND,
wait SEND_OK), and `_W5_RxSetup`/`_W5_RxCopy`/`_W5_RxAdvance` (RX ring, ring-wrap
aware). The W5100's per-packet receive headers differ by transport: UDP prepends
`[srcIP(4) srcPort(2) len(2)]`, IPRAW prepends `[srcIP(4) len(2)]`, TCP is a raw
byte stream with no header.

## Syscalls and wire formats

| # | Syscall | Notes |
|---|---------|-------|
| 70 | `SYS_IFCONFIG` | interface get/set (see below) |
| 71 | `SYS_SOCKET` | `A=domain X=type Y=proto → fd` |
| 72 | `SYS_BIND` | `bind(fd, sockaddr_in*, len)` (UDP/ICMP; TCP server) |
| 73 | `SYS_SENDTO` | `sendto(fd, argblk*)` |
| 74 | `SYS_RECVFROM` | `recvfrom(fd, argblk*)` (non-blocking) |
| 75 | `SYS_SETSOCKOPT` | `SOL_SOCKET`: `SO_BROADCAST` and `SO_REUSEADDR` honoured; 2.11BSD's other boolean options accepted, not stored; `SO_LINGER` refused |
| 76 | `SYS_CONNECT` | `connect(fd, sockaddr_in*, len)` (TCP) |
| 77 | `SYS_SEND` | `send(fd, argblk*)` |
| 78 | `SYS_RECV` | `recv(fd, argblk*)` (TCP: blocking) |
| 84 | `SYS_LISTEN` | `listen(fd, backlog)` (backlog ignored) |
| 85 | `SYS_ACCEPT` | `accept(fd)` (blocks for a peer) |
| 99 | `SYS_SELECT` | works on socket fds (`NETOP_SockStatus`) |
| 100 | `SYS_SHUTDOWN` | `shutdown(fd, how)` |
| 108 | `SYS_GETPEERNAME` | |
| 109 | `SYS_GETSOCKNAME` | an unbound socket answers `0.0.0.0:0` |

The libc wrappers pack the multi-argument calls into an **argblk**
(`_sock_argblk`) in the program's data bank (offsets in bytes).  All four
share the first four words; the buffer's bank rides in the block, so the
buffer may be in any bank:

```
all four : +0 buf offset  +2 len  +4 MSG_* flags  +6 buf bank
sendto   : +8 dstIP(4, net order)  +12 dstPort(2, net order)
recvfrom : +8 offset of the 16-byte source-address staging
```

`tools/check_sock_argblk.py` holds this layout against net.mod's reads.

`sockaddr_in` is the 16-byte 2.11BSD layout: `SIN_FAMILY` at +0 (a 2-byte short), `SIN_PORT` at +2
(2 bytes, **big-endian / network order**), `SIN_ADDR` at +4 (4 bytes, network
order). The flags are `MSG_DONTWAIT = $80` and `MSG_OOB`, which the socket
layer refuses (no transport carries urgent data). Errnos use 4.3BSD values
(`include/errno.s`): `EINTR=4`, `EBADF=9`, `EAGAIN=11`, `EINVAL=22`, `EMFILE=24`,
`EPIPE=32`, `ENOTSUP=45`, `ENOTCONN=57`, `ETIMEDOUT=60`, `ECONNREFUSED=61`.

The full generated syscall catalog is in
[userland-abi.md](userland-abi.md); the libc wrappers (`socket`, `connect`,
`sendto`, ...) are in `toolchain/lib/libc_c/socket.c` and `socket_srv.c`.

## Blocking and concurrency

BSD semantics: **`connect` / `accept` / TCP `recv` block by default**, and are
**`^C`-interruptible → `EINTR`**. Non-blocking I/O is per call
(**`MSG_DONTWAIT`**) or per descriptor (**`ioctl(FIONBIO)`**, or
`fcntl(F_SETFL)`, which issues `FIONBIO` as 4.3BSD-Reno's does); either gives
`EAGAIN`. UDP/ICMP `recvfrom` does **not** block — it polls
and returns `EAGAIN` when the ring is empty, so `ping`/`dhclient` poll in a
userland timeout loop. **`read`/`write` work on a socket fd** (`read`≡`recv`,
`write`≡`send`), which is what the shell's redirection and most portable code use.

Blocking goes through `_Sock_PollIntr`: if no `^C` is pending it `_sleep`s on
`WCHAN_SOCK` (the CPU idles) and re-checks its own condition on wake — see
[scheduler.md](scheduler.md). Because several tasks can
hold socket state across a sleep, `_Sock_PollIntr` saves/restores the contiguous
`_sock*` scratch block on the task's kernel stack.

**`U2_LOCK` / `U2_UNLOCK`** bracket every foreground indirect-bus sequence
(`include/macros.s`, copied into `bpf.s`). They `SEI`, set a `_u2Locked` flag, and
**mask the W5100 IRQ (chip IMR ← 0)**; UNLOCK restores the IMR shadow. This is
mandatory: the indirect **address register is a single shared resource**, so an
ISR firing mid-sequence would move the AR and corrupt the in-flight transfer. The
ISR also checks `_u2Locked` and bails if foreground owns the bus.

## The W5100 interrupt handler

Receive and connection events are **IRQ-driven**. `_Net_BringUp` calls
`_ArmUthernet2` once at boot to register `_Uthernet2_ISR` as a SIM generic
(non-SCC) IRQ source and arm the chip IMR. The handler is **armed at boot even
with no socket open**, but socket 0 stays CLOSED so nothing fires until a capture
or connection opens a socket. (netdump's capture *depends* on the ISR being
registered: without it a RECV interrupt goes unhandled and storms.)

Two IIgs-specific hazards shaped the ISR:

- **SLTROMSEL reset on IRQ entry.** IIgs IRQ entry can flip slot 1 back to the
  internal port, so the ISR's `$E0C09x` reads would hit internal ROM (garbage)
  and falsely claim *every* interrupt → a storm. The ISR **saves SLTROMSEL,
  routes the card's slot to the card for its reads, and restores it at every exit** before
  chaining the firmware.
- **Lazy ISR.** On a RECV the handler sets a per-socket ready bit and **disarms
  IMR** so the level-triggered RECV can't re-fire before foreground drains the
  ring (the capture "firehose" guard).

The handler does no heavy work in interrupt context: it sets `_kSockWakePending`,
write-1-clears the W5100 interrupt bits, and returns. The scheduler's `swtch`
checks `_kSockWakePending` and turns it into `_wakeup(WCHAN_SOCK)`, waking the
blocked socket task.

## Interface configuration

An interface is an **ifnet record** (`include/ifnet.s`, Kmalloc'd `_ifTablePtr`,
`IF_MAX = 4`): name (`u2sN`), slot, MAC (→ the W5100 SHAR), flags
(`IFF_LINK_UP`/`IFF_IP_CONF`/`IFF_DHCP`), IP, netmask, broadcast, gateway. The
detected card is registered as **`u2sN`**, N = its slot, at probe
(`_Net_RegPrimary`); on the usual slot-1 card that is `u2s1`. The MAC defaults to
`00:08:DC:F6:00:<slot>`, overridable per slot via `/etc/hwaddr.conf`.

`SYS_IFCONFIG` (#70) takes an `ifreq` pointer + an op:

| Op | Meaning |
|----|---------|
| `IFC_GETN` | look up by index → fill the record (or `ENOENT`) |
| `IFC_GET`  | look up by name → fill the record |
| `IFC_SET`  | set ip/netmask/broadcast/gateway + `IFF_IP_CONF` |
| `IFC_SETMAC` | reserved (defined in `include/ifnet.s`, not used by the tools) |
| `IFC_SETDHCP` | as `IFC_SET`, and also marks the address DHCP-leased (`IFF_DHCP`); plain `IFC_SET` clears that bit |

Setting the address on the primary interface also pushes **GAR/SUBR/SIPR** to the W5100 (so the
chip can ARP for and accept unicast at the configured IP). `/etc/netstart`,
sourced by `/etc/rc` — which `init` runs to completion **before** the login
shell appears — runs `dhclient` and sets `INET` for the network daemons; a
static-address template (`ifconfig u2s1 inet ...`, `route add default ...`) is
commented out there.

## DHCP (userland)

DHCP is a **userland** program (`src/userland/dhclient`), not kernel code. It reads the interface's MAC via
`ifctl(IFC_GET)`, runs the lease protocol over a UDP socket (broadcast to
`255.255.255.255:67` from `:68`), and writes the result back with
`ifctl(IFC_SETDHCP)`, which is `IFC_SET` plus the `IFF_DHCP` flag:

- **INIT-REBOOT** — if `/etc/dhcp.lease` exists, re-REQUEST that exact IP; on ACK,
  reuse it.
- **DISCOVER** — otherwise DISCOVER → OFFER → REQUEST → ACK with 2/4/8/16 s
  backoff.

On bind it writes `/etc/dhcp.lease` and `/etc/resolv.conf` (from the DHCP DNS
option). There is **no background renew daemon**; to renew, run `dhclient` again.

## Packet capture — `/dev/bpf0`

`/dev/bpf0` is a character device backed by the loadable **`bpf.mod`** module
(loaded at boot by the `modload` line in `/etc/rc`). It puts the reserved **socket 0 into MACRAW
promiscuous mode** (`Sn_MR = $44` = MACRAW + MAC filter) and captures raw Ethernet
frames. It is **single-opener** (a second `open` returns `EBUSY`). The capture
block is allocated kernel-side (`_Bpf_AllocBlk`, `src/kernel/bpf.s`) and handed
to the module via DP soft-globals.

Capture is IRQ-driven with a lazy ISR + foreground drain (`_Net_DrainFrame`):
each `read()` returns **one record** —
`[caplen.w LE][datalen.w LE][frame bytes…]` — snaplen 60 (Ethernet + IP + L4
headers). A saturation sentinel (`caplen = 0`) is surfaced in-band when the RX
ring nears full, so a dropped-packet burst is visible rather than silent.
`netdump` is the consumer: it reads records, dissects Ethernet → ARP / IPv4 →
ICMP/UDP/TCP, and prints a tcpdump-style line per frame.

## Userland tools

| Tool | What it does | Exercises |
|------|--------------|-----------|
| `nc` | minimal netcat TCP client (`-g` sends `GET / HTTP/1.0`); a host name is resolved through `gethostbyname` | socket/connect/send/recv, read/write |
| `ping` | ICMP echo; software-checksums, verifies id/seq + payload; min/avg/max | socket(RAW)/sendto/recvfrom |
| `dhclient` | DHCP client (above) | socket/bind/sendto/recvfrom + ifctl |
| `ifconfig` | show/configure interfaces, BSD-style | ifctl (GETN/GET/SET) |
| `netdump` | tcpdump-like observer over `/dev/bpf0` | open/read on the bpf chardev |
| `echod` | TCP **echo server** (re-listens per connection) | socket/bind/listen/accept |
| `telnet` | 2.11BSD telnet(1) client | connect, select |
| `telnetd` | 2.11BSD telnetd(8): relays a TCP connection to a login on a pty; started by `inetd` (`/etc/inetd.conf`) | accept via inetd, pty |
| `inetd` | 2.11BSD inetd(8); honours `stream tcp nowait` lines | listen/accept |
| `ntpd`, `ntpdc`, `ntp` | 2.11BSD's UMD NTP 3.4 daemon, its query tool, and the one-shot client | UDP port 123 |
| `host` | look up names and addresses through the libc resolver | gethostbyname/gethostbyaddr |
| `route` | `route add default A.B.C.D`: stores the default gateway in the primary ifnet | ifctl |
| `syslogd`, `logger` | system log daemon (`-u` for UDP) and its client | AF_UNIX `/dev/log`, UDP |

## Limits and caveats

- **One W5100, three usable sockets.** Socket 0 is reserved for capture, so at
  most three concurrent UDP/TCP/ICMP sockets.
- **Single-socket TCP server.** `listen` ignores its backlog; `accept` hands the
  one hardware socket to the new connection fd and detaches the listener, so a
  server (e.g. `echod`) must re-`socket`/`bind`/`listen` for each connection. This
  is a W5100 constraint, not a software limit.
- **No software IP stack for the wire, no routing.** The W5100 offloads
  TCP/UDP/IP/ARP; FGX does MACRAW (capture), the ICMP checksum in `ping`, and
  the software loopback and AF_UNIX transports.  The gateway is stored in the
  ifnet and pushed to the chip (`GAR`); routing is the chip's job.
- **~1 MHz indirect cardbus, no DMA.** Throughput is modest and the paths are
  small-packet oriented (ring-wrap-aware on the TCP/RX paths).
- **BSD subset.** `select(2)` works on socket fds; there is no `poll(2)`, no
  `getsockopt`, and no out-of-band data.

## Source map

| Area | File |
|------|------|
| BSD socket layer (fds, descriptors, syscalls) | `src/modules/net/net.s` (kernel thunks: `src/kernel/net_dispatch.s`; descriptor table alloc: `src/kernel/socket.s`) |
| Loopback / AF_UNIX transports | `src/modules/net/net_loop.s`, `src/modules/net/unp.s` |
| Resolver | `toolchain/lib/libc_c/netdb.c` |
| W5100 driver, XPORT seam, transport cores | `src/modules/net/net_xport.s` |
| W5100 probe, bring-up, ISR | `src/kernel/uthernet.s` |
| Interface config (ifnet, SYS_IFCONFIG) | `src/kernel/ifconfig_sys.s` |
| `/dev/bpf0` MACRAW capture module | `src/modules/bpf/bpf.s` (block alloc: `src/kernel/bpf.s`) |
| Structs / constants | `include/socket.s`, `include/ifnet.s`, `include/errno.s` |
| Syscall numbers | `include/loader.s` |
| Socket sleep/wake channel | `src/kernel/sched.s` (`WCHAN_SOCK`) |
| Userland | `src/userland/{nc,ping,dhclient,ifconfig,netdump,echod,telnet,telnetd,inetd,ntpd,ntpdc,ntp,host,route,syslogd,logger}/` |
