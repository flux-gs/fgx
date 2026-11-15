# FGX Networking

> Source of truth: `src/kernel/bsdnet/` (the network stack, 2.11BSD's, in the
> modules `bsdnetd` and `bsdnet0`-`bsdnet3`), `src/modules/net/{net,net_kso}.s`
> (the socket calls' entry, in net.mod), `src/kernel/{net_dispatch,uthernet,
> socket}.s` (the kernel's dispatch seam, the W5100 probe and ISR, and the
> socket fd lookup), `src/modules/bpf/bpf.s`, `include/{socket,loader,errno}.s`,
> `toolchain/lib/libc_c/{socket,socket_srv,netdb}.c`, and the userland tools
> under `src/userland/`.  Where this doc and the code disagree, the code wins.
> The design and its history are in
> `docs/history/plans/2026-11-03-net-multiplex-design.md`.

FGX talks to the network through an **Uthernet II** card (a WIZnet **W5100**
Ethernet controller).  The chip carries frames and nothing else: its socket 0
runs in **MACRAW** mode with all 8 KB of its buffer memory each way, and
**2.11BSD's TCP/IP runs in the kernel** above it -- ARP, IP, ICMP, UDP, TCP, raw
sockets, routing and AF_UNIX, in the network modules (`bsdnetd`,
`bsdnet0`-`bsdnet3`), which `/etc/rc` loads at boot.  Sockets are Unix fds with
2.11BSD's semantics, and their number is limited by memory, not by the chip.
What's shipped:

- **TCP** client and server (`SOCK_STREAM`), on the wire and over `lo0`
- **UDP** (`SOCK_DGRAM`), including broadcast
- **raw IP** (`SOCK_RAW`), which `ping` uses
- **AF_UNIX** stream and datagram sockets, named in the file system, passing
  descriptors with `sendmsg(2)` and `recvmsg(2)`
- **interfaces and routes** configured by 2.11BSD's `ifconfig(8)` and `route(8)`,
  through socket ioctls
- **DHCP** (userland `dhclient`)
- **raw frame capture** via `/dev/bpf0` -- used by `netdump`
- **name lookup** in libc: `gethostbyname` / `gethostbyaddr` read `/etc/hosts`,
  then ask the nameserver in `/etc/resolv.conf` over UDP, each try bounded by a
  1.5 s deadline (`toolchain/lib/libc_c/netdb.c`)

Without the network modules, `socket(AF_INET, ...)` answers `EPROTONOSUPPORT`, as
2.11BSD's `socreate` does when no protocol matches; so does a socket call made
while the modules are still loading.

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
| `U2_DAT` | `$E0C097` | data port -- **auto-increments the address** after each access |
| `SLTROMSEL` | `$E0C02D` | slot routing; bit *n* must be set to reach the card in slot *n* |

Every register or ring byte is a 3-write address-set plus a data cycle over a
~1 MHz cardbus -- there is no DMA, so the driver is written for small packets and
masks IRQs around each multi-step sequence (see *U2_LOCK* below). Detection
(`_ProbeUthernet2`) writes `MR=$80` (reset -> chip auto-clears to `$00`) then
`MR=$03` (reads back `$03`), logging `uthernet2: W5100 @ slot 1` or `... absent`.

The W5100 has four hardware sockets; MACRAW exists only on socket 0, and the
stack's driver (`src/kernel/bsdnet/net/if_w5.c`, after 2.11BSD's `if_de.c`)
takes it, with the chip's whole receive and transmit buffer.  Sockets 1-3 are
unused.

## Sockets are fds

A socket is a 2.11BSD `struct socket` in the stack's data bank.  `socket()`
allocates an FCB tagged `FCB_FL_SOCKET`, and the FCB names its socket
(`FCB_SockSo`, the socket's offset in that bank).  Because a socket is an FCB,
`read`/`write`, `close`, `select`, `dup` and fd inheritance all work on it.  The
system file table holds `NFILE` = 128 entries, so a socket-heavy load meets the
mbuf pool before it: `socreate` then waits for a free mbuf, as 2.11BSD's does.

Every socket call goes the same way: the kernel's syscall thunk
(`net_dispatch.s`) reaches net.mod, which resolves the fd and hands the call to
the stack (`net_kso.s`); the stack's `bn_sys.c` fetches the arguments and runs
2.11BSD's `uipc_syscalls.c` body -- `bind`, `connect`, `sendto` and the rest turning
into `sobind`, `soconnect`, `sosend`.  The call runs on the calling process's
kernel stack slot and may sleep there.  The FGX-written part is the argument
fetch.

## The stack

The stack is 2.11BSD's `sys/uipc_*.c`, `net/` and `netinet/`, built with fcc
into five banks of module code over one data bank, with a machine seam written
for FGX in `src/kernel/bsdnet/machine/`: mbufs, `spl`, the callout list, the
kernel `printf` (2.11BSD's `prf`), `bcopy` in assembly, and the drain.
`docs/PROVENANCE.md` names the upstream file of each, and every divergence.

Received frames are drained by `netintr`, which runs at the kernel's
deferred-work point, never from an interrupt, on a 1024-byte stack of its own.
The heartbeat marks the drain every 8th tick, so a lost interrupt costs at most
133 ms.  The interfaces are `wz0`, the card, and `lo0`.

## Syscalls and wire formats

| # | Syscall | Notes |
|---|---------|-------|
| 71 | `SYS_SOCKET` | `A=domain X=type Y=proto -> fd` |
| 72 | `SYS_BIND` | `bind(fd, name, len)` |
| 73 | `SYS_SENDTO` | `sendto(fd, argblk*)` |
| 74 | `SYS_RECVFROM` | `recvfrom(fd, argblk*)` |
| 75 | `SYS_SETSOCKOPT` | 2.11BSD's `sosetopt` |
| 76 | `SYS_CONNECT` | `connect(fd, name, len)` |
| 77 | `SYS_SEND` | `send(fd, argblk*)` |
| 78 | `SYS_RECV` | `recv(fd, argblk*)` |
| 84 | `SYS_LISTEN` | `listen(fd, backlog)` |
| 85 | `SYS_ACCEPT` | `accept(fd)`; libc names the peer through `getpeername` |
| 99 | `SYS_SELECT` | works on socket fds |
| 100 | `SYS_SHUTDOWN` | `shutdown(fd, how)`, 2.11BSD's `soshutdown` |
| 108 | `SYS_GETPEERNAME` | copies `min(len, the name's length)` bytes |
| 109 | `SYS_GETSOCKNAME` | likewise; an unbound socket is not an error |
| 131 | `SYS_SENDMSG` | `sendmsg(fd, msg, flags)`; `msg_accrights` passes descriptors over AF_UNIX |
| 132 | `SYS_RECVMSG` | `recvmsg(fd, msg, flags)` |

Interface and route changes are `ioctl(2)`s on a socket, as in 2.11BSD.

The libc wrappers pack send, recv, sendto and recvfrom into an **argblk**
(`_sock_argblk`) in the program's data bank (offsets in bytes).  All four share
the first four words; the buffer's bank rides in the block, so the buffer may be
in any bank:

```
all four : +0 buf offset  +2 len  +4 MSG_* flags  +6 buf bank
sendto   : +8 dstIP(4)  +12 dstPort(2), then the name: +14 offset  +16 bank  +18 length
recvfrom : +8 the source name's offset  +10 bank  +12 length, written back
```

`tools/check_sock_argblk.py` holds this layout against `bn_sys.c`'s reads.

`sockaddr_in` is the 16-byte 2.11BSD layout: `SIN_FAMILY` at +0 (a 2-byte short), `SIN_PORT` at +2
(2 bytes, **big-endian / network order**), `SIN_ADDR` at +4 (4 bytes, network
order).  An AF_UNIX name is as long as its path.  The flags are 2.11BSD's
`MSG_OOB` and `MSG_PEEK`, and FGX's `MSG_DONTWAIT` = `$80`.  Errnos use 4.3BSD
values (`include/errno.s`).

The full generated syscall catalog is in
[userland-abi.md](userland-abi.md); the libc wrappers (`socket`, `connect`,
`sendto`, ...) are in `toolchain/lib/libc_c/socket.c` and `socket_srv.c`.

## Blocking and concurrency

BSD semantics: `connect`, `accept`, `recv` and a `send` into a full buffer block,
and a signal interrupts them with `EINTR`.  Non-blocking I/O is per descriptor
(`ioctl(FIONBIO)`, or `fcntl(F_SETFL)`, which issues `FIONBIO` as 4.3BSD-Reno's
does) or per call (`MSG_DONTWAIT`, which affects only that call); either answers
`EWOULDBLOCK`.  `read`/`write` on a socket fd are `recv`/`send`.

A blocked call sleeps in the stack (`sbwait`) on its own kernel stack slot.  The
stack saves a process's `u` across the sleep, so any number of processes can
block in socket calls at once.

**`U2_LOCK` / `U2_UNLOCK`** bracket every foreground indirect-bus sequence
(`include/macros.s`, copied into `bpf.s`). They `SEI`, set a `_u2Locked` flag, and
**mask the W5100 IRQ (chip IMR <- 0)**; UNLOCK restores the IMR shadow. This is
mandatory: the indirect **address register is a single shared resource**, so an
ISR firing mid-sequence would move the AR and corrupt the in-flight transfer. The
ISR also checks `_u2Locked` and bails if foreground owns the bus.

## The W5100 interrupt handler

`_Net_BringUp` calls `_ArmUthernet2` once at boot to register `_Uthernet2_ISR` as
a SIM generic (non-SCC) IRQ source and arm the chip IMR.  The handler does no
heavy work in interrupt context: it records the event, write-1-clears the
W5100's interrupt bits, and returns; the drain does the rest.

Two IIgs-specific hazards shaped the ISR:

- **SLTROMSEL reset on IRQ entry.** IIgs IRQ entry can flip slot 1 back to the
  internal port, so the ISR's `$E0C09x` reads would hit internal ROM (garbage)
  and falsely claim *every* interrupt -> a storm. The ISR **saves SLTROMSEL,
  routes the card's slot to the card for its reads, and restores it at every exit** before
  chaining the firmware.
- **Lazy ISR.** On a RECV the handler sets a per-socket ready bit and **disarms
  IMR** so the level-triggered RECV can't re-fire before foreground drains the
  ring (the capture "firehose" guard).

## Interface configuration

The card is the interface **`wz0`**: 2.11BSD's `struct ifnet`, attached by the
W5100 driver (`src/kernel/bsdnet/net/if_w5.c`). Its link-level address comes
from the chip's SHAR, which the kernel writes at the card's probe
(`src/kernel/hwaddr.s`): `00:08:DC:F6:00:<slot>` by default, overridable per
slot via `/etc/hwaddr.conf`. The loopback interface is `lo0`.

Interfaces and routes are configured as in 2.11BSD, through socket ioctls:
`SIOCGIFCONF` lists the interfaces (each with an `AF_LINK` entry carrying the
Ethernet address), `SIOCSIFADDR`/`SIOCSIFNETMASK`/`SIOCSIFBRDADDR`/`SIOCSIFFLAGS`
set them (`ifioctl`), and `SIOCADDRT`/`SIOCDELRT` edit the routing table
(`rtioctl`). `ifconfig(8)` and `route(8)` are 2.11BSD's. `/etc/netstart`,
sourced by `/etc/rc` -- which `init` runs to completion **before** the login
shell appears -- runs `dhclient` and sets `INET` for the network daemons; a
static-address template (`ifconfig wz0 inet ...`, `route add default ... 1`) is
commented out there.

## DHCP (userland)

DHCP is a **userland** program (`src/userland/dhclient`), not kernel code. It finds the Ethernet interface and its
MAC through `SIOCGIFCONF`, runs the lease protocol over a UDP socket (broadcast to
`255.255.255.255:67` from `:68`), and installs the result with the same ioctls
`ifconfig` and `route` use (`SIOCSIFADDR`, `SIOCSIFNETMASK`, `SIOCADDRT` for the
default route):

- **INIT-REBOOT** -- if `/etc/dhcp.lease` exists, re-REQUEST that exact IP; on ACK,
  reuse it.
- **DISCOVER** -- otherwise DISCOVER -> OFFER -> REQUEST -> ACK with 2/4/8/16 s
  backoff.

On bind it writes `/etc/dhcp.lease` and `/etc/resolv.conf` (from the DHCP DNS
option). There is **no background renew daemon**; to renew, run `dhclient` again.

## Packet capture -- `/dev/bpf0`

`/dev/bpf0` is a character device backed by the loadable **`bpf.mod`** module.
While the stack holds socket 0, bpf is a tap on the interface, as in 2.11BSD:
the driver copies each frame into a ring in the network modules' data, and bpf
reads it from there.  Without the network modules, bpf puts socket 0 into MACRAW
itself.  It is **single-opener** (a second `open` returns `EBUSY`), and a capture
that holds socket 0 before the modules load makes the driver log `w5: socket 0
busy` and leave the stack with `lo0` alone.

Each `read()` returns **one record** --
`[caplen.w LE][datalen.w LE][frame bytes...]` -- snaplen 60 (Ethernet + IP + L4
headers). A saturation sentinel (`caplen = 0`) is surfaced in-band when the ring
nears full, so a dropped-packet burst is visible rather than silent.
`netdump` is the consumer: it reads records, dissects Ethernet -> ARP / IPv4 ->
ICMP/UDP/TCP, and prints a tcpdump-style line per frame.

## Userland tools

| Tool | What it does | Exercises |
|------|--------------|-----------|
| `nc` | minimal netcat TCP client (`-g` sends `GET / HTTP/1.0`); a host name is resolved through `gethostbyname` | socket/connect/send/recv, read/write |
| `ping` | ICMP echo; software-checksums, verifies id/seq + payload; min/avg/max | socket(RAW)/sendto/recvfrom |
| `dhclient` | DHCP client (above) | socket/bind/sendto/recvfrom + SIOC ioctls |
| `ifconfig` | 2.11BSD ifconfig(8) | SIOCGIFCONF, SIOCSIF* |
| `netdump` | tcpdump-like observer over `/dev/bpf0` | open/read on the bpf chardev |
| `echod` | TCP **echo server** (re-listens per connection) | socket/bind/listen/accept |
| `telnet` | 2.11BSD telnet(1) client | connect, select |
| `telnetd` | 2.11BSD telnetd(8): relays a TCP connection to a login on a pty; started by `inetd` (`/etc/inetd.conf`) | accept via inetd, pty |
| `inetd` | 2.11BSD inetd(8); honours `stream tcp nowait` lines | listen/accept |
| `ntpd`, `ntpdc`, `ntp` | 2.11BSD's UMD NTP 3.4 daemon, its query tool, and the one-shot client | UDP port 123 |
| `host` | look up names and addresses through the libc resolver | gethostbyname/gethostbyaddr |
| `route` | 2.11BSD route(8); `-f` reads the table through `/dev/kmem` | SIOCADDRT/SIOCDELRT, nlist |
| `syslogd`, `logger` | system log daemon (`-u` for UDP) and its client | AF_UNIX `/dev/log`, UDP |

## Limits and caveats

- **Memory, not the chip, bounds the sockets.**  The mbuf pool (`NMBUFS` 280 and
  12 clusters) holds about ninety TCP sockets that are not connected, or some
  thirty connections (an idle one holds eight mbufs, four at each end); past that
  `socket(2)` waits for a free mbuf.
- **~1 MHz indirect cardbus, no DMA.**  Every frame byte crosses the card's
  register window.  The stack itself moves 1 MB over `lo0` in about 28 s under
  MAME, about 37 KB/s.
- **BSD subset.**  There is no `getsockopt(2)`, no `socketpair(2)` and no
  `poll(2)`.  A datagram sender's AF_UNIX name is cut to 16 bytes, as 2.11BSD's
  `sbappendaddr` cuts it (unix(4) BUGS).  `ifconfig wz0 down` does not stop
  output, as 2.11BSD's `ip_output` does not test `IFF_UP` (ifconfig(8) BUGS).

## Source map

| Area | File |
|------|------|
| The socket calls' entry | `src/modules/net/net.s`, `src/modules/net/net_kso.s` (kernel thunks: `src/kernel/net_dispatch.s`; fd lookup: `src/kernel/socket.s`) |
| The network stack | `src/kernel/bsdnet/{sys,net,netinet}/`; the machine seam `src/kernel/bsdnet/machine/` (`bn_sys.c` takes the calls) |
| W5100 driver (`wz0`) | `src/kernel/bsdnet/net/if_w5.c`, `src/kernel/bsdnet/machine/w5_asm.s` |
| W5100 probe, bring-up, ISR | `src/kernel/uthernet.s` |
| `/dev/mem`, `/dev/kmem` (for `route -f`) | `mem.mod`; the stack's name list `/netnix` |
| `/dev/bpf0` capture module | `src/modules/bpf/bpf.s` (block alloc: `src/kernel/bpf.s`) |
| Resolver | `toolchain/lib/libc_c/netdb.c` |
| Structs / constants | `include/socket.s`, `include/errno.s` |
| Syscall numbers | `include/loader.s` |
| Userland | `src/userland/{nc,ping,dhclient,ifconfig,netdump,echod,telnet,telnetd,inetd,ntpd,ntpdc,ntp,host,route,syslogd,logger}/` |
