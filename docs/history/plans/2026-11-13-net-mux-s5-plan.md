# Net-mux S5 -- ifconfig, route, one card name, and the campaign's last debts Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The network is configured the 2.11BSD way: `ifconfig` and `route` are 2.11BSD's, `dhclient` uses the same socket ioctls, the card has one name (`wz0`), and `SYS_IFCONFIG` with its parallel interface table is gone; AF_UNIX passes descriptors and full-length names, the file table no longer runs out before network memory, and the five remaining "Before the campaign PR" items are closed.

**Architecture:** Every interface and route change is an ioctl on a socket, as in 2.11BSD: `bn_sys.c`'s `BNOP_IOCTL` falls through to `soo_ioctl`'s tail (`ifioctl`, `rtioctl`, `PRU_CONTROL` into `in_control`), so upstream's `ifconfig.c` and `route.c` build nearly unchanged.  The MAC reaches userland as 4.3BSD-Reno exposes it, an `AF_LINK` `sockaddr_dl` in `SIOCGIFCONF`.  Descriptor passing follows 2.11BSD's own split-space design (`sys/sys_kern.c`: `fadjust`, `fpfetch`, `fpflags`, `unpdisc`), with the FCB as the `struct file` and the seams as `kc_*` calls into the kernel, like `kc_unpname`.

**Tech Stack:** fcc, Merlin32, `tools/build_bsdnet.py`, net.mod (`src/modules/net/`), the kernel (`src/kernel/`, `src/kernel/vfs/`), libc (`toolchain/lib/libc_c/`), MAME via `tools/mame_test/`.

**Spec:** `docs/history/plans/2026-11-03-net-multiplex-design.md`: the phases table (S5 row), section 7 ("S5 inherits", "Two names for the card until S5", "Before the campaign PR").  Read them, and the S4 plan beside this one.

## Calls this plan makes that the spec does not

For the maintainer's review.  Task 10 writes the accepted ones into the spec.

1. **The one name is `wz0`.**  2.11BSD's `ifunit` (`net/if.c`) reads a name's first digit as its unit, so `u2s1` cannot be a kernel name; `wz0` is what `SIOCGIFCONF` already reports.  `u2s1` leaves every program, script, page and test.
2. **The MAC comes from 4.3BSD-Reno's `AF_LINK` address.**  2.11BSD has no ioctl that answers an interface's hardware address, and dhclient needs one.  Reno's `if_attach` gives every interface a `sockaddr_dl` (`examples/4.3BSD-Reno/net/if.c`, `net/if_dl.h`) and `ifconf` returns it with the others; that is ported, and nothing else of Reno's routing changes.  `ifconfig` prints it as an `ether` line, which 2.11BSD's does not: an FGX addition, in PROVENANCE and the page.
3. **`route -f` answers an error.**  2.11BSD's `flushroutes` reads the routing hash tables through `/dev/mem` and `nlist`, and FGX has no `/dev/kmem` and no name list of the stack's banks.  `route -f` prints `route: -f needs /dev/kmem` and exits 1; BUGS in `route(8)`; a ROADMAP item for `/dev/kmem`, which `netstat` also wants.  **The maintainer may instead want `/dev/kmem` in S5**: say so and Task 3 grows.
4. **The FCB is the `struct file` that rights carry.**  A rights record holds FCB offsets, two bytes each, as 2.11BSD's holds two-byte `struct file` pointers, so `m_len / sizeof (int)` counts them unchanged.  The FCB gains two common bytes, `FCB_MsgCount` and `FCB_GcFlags` (`FMARK`, `FDEFER`), which takes `FCB_SIZE` from 38 to its soft cap of 40 (`include/fs.s`).
5. **`NFILE` goes from 64 to 128.**  1,536 bytes of the far kernel bank (5,598 free).  2.11BSD's formula (`conf/param.c`: `NINODE = NPROC + 16 + MAXUSERS + 22`, `NFILE = 8 * NINODE / 10 + 20`) gives about 79 for 32 processes, but upstream counts no socket-heavy load; 128 puts the mbuf pool, not the file table, first to run out.
6. **`MSG_DONTWAIT` is per call.**  No BSD source in the tree has it (checked: 2.11BSD, 4.3BSD-Reno, netbsd-0-9); it is FGX's.  `sosend` and `soreceive` test `(so->so_state & SS_NBIO) || (flags & MSG_DONTWAIT)`, `sblock` under it returns EWOULDBLOCK rather than sleeping, and `bn_sys.c` stops setting `SS_NBIO` for the call.  PROVENANCE says where it comes from.
7. **ntpd's stratum is fixed; ntpdc's wrap is a BUGS line.**  A new peer's stratum read uninitialized is a wrong answer on the wire, and the fix is one assignment; ntpdc's 32-bit milliseconds wrapping past 24.8 days needs 64-bit arithmetic for a display.
8. **The driver keeps its `255.255.255.255` host route.**  `in_pcbconnect` sends `INADDR_BROADCAST` to the primary interface's broadcast address, and the primary is `lo0`, so a DHCP broadcast needs that host route to leave through `wz0`.  It moves from `w5setaddr` into `w5ioctl`'s `SIOCSIFADDR` arm; the default route becomes `route`'s and `dhclient`'s.

## Global Constraints

- Branch `feat/net-mux` in `~/apple/fgx`.  Commit there; never push, never open a PR.
- Announce every checkout and rebuild of the tree.
- Toolchain first: an fcc or libc gap is fixed there, with a fixture that fails first.  Quote K&R before an fcc change; name the BSD file and function in every port and seam commit.
- Port from `vendor/2.11BSD/` (`usr/sbin/ifconfig/ifconfig.c`, `usr/sbin/route/route.c`); anything taken from `examples/` is vendored in the same commit.  Every port and FGX-written file has its `docs/PROVENANCE.md` row and header; every divergence is a BUGS and PROVENANCE note.
- Nothing Uthernet-specific above the driver: only `net/if_w5.c`, `machine/w5_asm.s` and the kernel's card probe name the chip.
- The core bank has 514 bytes free and the far bank 5,598 (`tools/check_kernel_ceiling.py`); each task that moves them records the new figures in the ledger.
- Commit bodies are informational, American spelling, ASCII only, no Co-Authored-By or session trailers.  Comments describe the current state only.
- MAME runs headless (`SDL_VIDEODRIVER=dummy`), and a passing run must not be `(cached)`.  Never `git stash`.  Uthernet tests run alone.
- Every new test gets a mutation or control that shows it can fail, recorded in the ledger.  No new test goes in `tools/gate.sh`; `tools/gate.sh` is green at the end of every task that changes code, built at `kernel.netprobe = 0`.
- Each spec 7 item is ticked off there when it lands.

## Review Focus

1. **dhclient renewing a lease that changed address**: the old address's routes (the default route, the broadcast host route) are deleted and the new ones added, with no stale route left pointing at the old gateway.  Task 4 case: a second `SIOCSIFADDR` with a different address, then `route` shows one default.
2. **`ifconfig wz0 down` while connections are open**: output stops (`if_down` purges the queue), and `ifconfig wz0 up` brings traffic back without reattaching the card.  Task 2 case on `lo0`: down, a UDP send answers ENETDOWN or is dropped, up, the send arrives.
3. **A passed descriptor whose socket is closed in flight**: the receiver never reads the message; `unp_gc` must close the in-flight FCB when its last reference is the message.  Task 6 case `-r gc`: FCB count back to its idle value.
4. **A long AF_UNIX path passed to a buffer shorter than it**: `recvfrom` with `*fromlen` 16 on a 40-character sender gets 16 bytes and the length the kernel wrote, never an overrun.  Task 7 case.
5. **The file table full with sockets**: socket 120 of 128 answers ENFILE cleanly, not a hang, and closing one lets the next succeed.  Task 8 case.

---

### Task 1: Interface and route ioctls reach the stack

**Files:**
- Modify: `src/kernel/bsdnet/machine/bn_sys.c` (`BNOP_IOCTL`), `src/kernel/bsdnet/net/if.c` (`if_attach`, `ifconf`), `src/kernel/bsdnet/net/if_dl.h` (create, from Reno), `src/userland/ifcprobe/ifcprobe.c`, `docs/PROVENANCE.md`

**Interfaces:**
- Produces: every ioctl on a socket that `BNOP_IOCTL` does not answer itself goes to `soo_ioctl`, so `SIOCGIFCONF`, `SIOCGIFFLAGS`, `SIOCSIFFLAGS`, `SIOCGIFADDR`, `SIOCSIFADDR`, `SIOCSIFNETMASK`, `SIOCGIFNETMASK`, `SIOCSIFBRDADDR`, `SIOCGIFBRDADDR`, `SIOCADDRT` and `SIOCDELRT` behave as 2.11BSD's.  `SIOCGIFCONF` returns, per interface, its `AF_LINK` `struct sockaddr_dl` (`sdl_alen` 6 and the MAC for `wz0`; `sdl_alen` 0 for `lo0`) after its `AF_INET` address.

- [ ] **Step 1: Write the failing probe.**  `ifcprobe -l` (on `lo0`, no card): `SIOCGIFFLAGS lo0` has `IFF_UP|IFF_LOOPBACK|IFF_RUNNING`; `SIOCADDRT` a host route 10.9.9.9 via 127.0.0.1, then a UDP `sendto` 10.9.9.9 arrives on a socket bound to 0.0.0.0 on that port; `SIOCDELRT` it, and the send answers ENETUNREACH; `SIOCGIFCONF` lists `lo0` with an `AF_LINK` entry.  Prints `IFC L ok` or `IFC L FAIL <step>`.  A MAME manifest `ifcroute` runs it (not in the gate).
- [ ] **Step 2: Run it.**  Expected: `IFC L FAIL addrt` (`ifioctl` answers EINVAL for a route ioctl).
- [ ] **Step 3: Implement.**  `BNOP_IOCTL`'s default arm calls `soo_ioctl`, keeping the FIONREAD int width and the ENOTTY arms ahead of it.  Port Reno's link address: `if_dl.h`, the `sockaddr_dl` `if_attach` builds (name, index, type, MAC from `ac_enaddr` for an `arpcom`), and `ifconf`'s loop over `if_addrlist` returning it.  `rtioctl`'s `suser` sees the caller's uid (bn_sys sets `u.u_uid` from `kc_curuid`).
- [ ] **Step 4: Run it, and its control.**  Expected: `IFC L ok`.  Control: with `rtioctl`'s `SIOCADDRT` arm made to return 0 without adding, the probe prints `IFC L FAIL route`.
- [ ] **Step 5: Gate, commit.**  `tools/gate.sh` green.  Commit `net: interface and route ioctls reach the stack, and an interface has a link address`.

### Task 2: ifconfig is 2.11BSD's

**Files:**
- Replace: `src/userland/ifconfig/ifconfig.c` (from `vendor/2.11BSD/usr/sbin/ifconfig/ifconfig.c`), `src/userland/man/pages/cat8/ifconfig.0`
- Modify: `docs/PROVENANCE.md`; manifest `ifcroute`

**Interfaces:**
- Consumes: Task 1's ioctls and `AF_LINK` entry.
- Produces: `ifconfig [-a] [name [af] [address [dest_addr]] [params]]` as 2.11BSD's, printing `<name>: flags=<hex><UP,...>` and `inet A.B.C.D netmask 0xMMMMMMMM broadcast A.B.C.D`, plus `ether xx:xx:xx:xx:xx:xx` from the link address (call 2).

- [ ] **Step 1: Extend the manifest.**  `ifcroute` also runs `ifconfig lo0; ifconfig lo0 down; ifconfig lo0; ifconfig lo0 up; ifconfig -a` and expects `lo0: flags=49<UP,LOOPBACK,RUNNING>`, `inet 127.0.0.1 netmask 0xff000000`, a line `lo0: flags=48<LOOPBACK,RUNNING>` after `down`, and no `u2s1`.  A UDP send on `lo0` while it is down does not arrive and one after `up` does (Review Focus 2), through `ifcprobe -d`.
- [ ] **Step 2: Run it.**  Expected: FAIL, the old ifconfig's `SYS_IFCONFIG` output.
- [ ] **Step 3: Port.**  2.11BSD's `ifconfig.c` verbatim but for: the `ether` line, the `AF_NS` arm (no XNS in the stack: compiled out and stated), and whatever fcc cannot take, fixed in fcc first.  The page is 2.11BSD's ifconfig(8) text with the `ether` line and the missing `ns` family noted under BUGS.
- [ ] **Step 4: Run it.**  Expected: PASS.  Control: the manifest's `flags=48` line, mutated to `flags=49`, fails.
- [ ] **Step 5: Gate, commit.**  Commit `ifconfig: 2.11BSD's, on the kernel stack's interfaces`.

### Task 3: route is 2.11BSD's (call 3)

**Files:**
- Replace: `src/userland/route/route.c` (from `vendor/2.11BSD/usr/sbin/route/route.c`); create `src/userland/man/pages/cat8/route.0`
- Modify: `docs/PROVENANCE.md`, `docs/ROADMAP.md` (the `/dev/kmem` item), manifest `ifcroute`

**Interfaces:**
- Consumes: Task 1's `SIOCADDRT`/`SIOCDELRT`.
- Produces: `route [-n] add|delete [host|net] destination gateway [metric]` as 2.11BSD's; `route -f` prints `route: -f needs /dev/kmem` and exits 1.

- [ ] **Step 1: Extend the manifest.**  `route add 10.9.9.9 127.0.0.1` prints `add host 10.9.9.9: gateway 127.0.0.1`, `ifcprobe -s 10.9.9.9` then reaches `lo0`, `route delete 10.9.9.9 127.0.0.1` prints `delete host 10.9.9.9: gateway 127.0.0.1`, and `route -f` prints its error.
- [ ] **Step 2: Run it.**  Expected: FAIL (the old route only stores a gateway).
- [ ] **Step 3: Port.**  Upstream's `route.c` with `flushroutes` replaced by the error and nothing else changed.
- [ ] **Step 4: Run it.**  Expected: PASS.  Control: `route delete` with a wrong gateway prints upstream's `not in table` error.
- [ ] **Step 5: Gate, commit.**  Commit `route: 2.11BSD's; -f waits for /dev/kmem`.

### Task 4: dhclient configures through the ioctls

**Files:**
- Modify: `src/userland/dhclient/dhclient.c`, `src/kernel/bsdnet/net/if_w5.c` (`w5ioctl`, `w5setaddr`, `w5address`), `src/kernel/bsdnet/machine/bn_sys.c` (`BNOP_IFCHANGED` goes), `docs/PROVENANCE.md`

**Interfaces:**
- Consumes: Tasks 1-3.
- Produces: dhclient finds the first `IFF_BROADCAST` interface through `SIOCGIFCONF`, takes its MAC from the `AF_LINK` entry, and on a lease sets netmask, address and broadcast (`SIOCSIFNETMASK`, `SIOCSIFADDR`, `SIOCSIFBRDADDR`) and the default route (`SIOCDELRT` the old gateway's, `SIOCADDRT` the new).  With no such interface it prints `dhclient: no network interface` as now.  `w5ioctl`'s `SIOCSIFADDR` keeps the `255.255.255.255` host route (call 8).

- [ ] **Step 1: Write the failing check.**  `ifcprobe -r` (no card needed): sets `lo0`'s address twice through `SIOCSIFADDR` with a default route via each, as dhclient's renew does, then reads the route table through `SIOCADDRT` refusals (`EEXIST` for the new default, none for the old): one default, the new one (Review Focus 1).  On the Uthernet: `netw5`'s lease and echo still pass, with dhclient on the ioctls.
- [ ] **Step 2: Run them.**  Expected: `IFC R FAIL` and dhclient still calling `SYS_IFCONFIG`.
- [ ] **Step 3: Implement.**  dhclient as above; `w5setaddr`, `w5address` and `BNOP_IFCHANGED` go, and the chip's SIPR/SUBR/GAR are no longer written (MACRAW does not read them).
- [ ] **Step 4: Run them.**  Expected: PASS; `ufsmodules` still sees `dhclient: no network interface`; `netw5` (alone, `kernel.netprobe = 1`) passes.
- [ ] **Step 5: Gate, commit.**  Commit `dhclient: the lease goes in through ifconfig's and route's ioctls`.

### Task 5: SYS_IFCONFIG retires, and the card has one name

**Files:**
- Delete: `src/kernel/ifconfig_sys.s`, `include/ifnet.s`
- Modify: `src/kernel/uthernet.s` (keep the probe and MAC derivation, drop the interface record and the `u2s1` message), `src/kernel/main.s`, `src/kernel/syscall.s`, `src/kernel/net_dispatch.s`, `include/loader.s`, `include/modules.s`, `src/modules/net/net.s`, `src/modules/net/net_kso.s`, `src/modules/net/net.link.s`, `toolchain/include/fgx.h`, `toolchain/lib/libfgx_c/libfgx.c` (`ifctl`), `tools/check_net_retired.py`, `disk_src/etc/netstart`, `docs/networking.md`, `tools/mame_test/tests/boot_netstart.json` (its description, spec 7 item)

**Interfaces:**
- Produces: `SYS_IFCONFIG`'s slot answers ENOSYS; no `IF_*` record, `_Ifnet_*` routine or `ifctl` remains; `check_net_retired.py` fails the build if one is defined again; `wz0` is the card's only name.

- [ ] **Step 1: Write the failing check.**  Add `ifctl`, `_Ifnet_FindByName`, `Ifc_*`, `IF_REC_SIZE` and the string `u2s1` (outside `docs/history/`) to `check_net_retired.py`.
- [ ] **Step 2: Run it.**  Expected: FAIL, naming each site.
- [ ] **Step 3: Delete and rewire.**  Record the core and far bank bytes returned.
- [ ] **Step 4: Run it.**  Expected: clean; the network tests of S4's Task 7 list pass fresh.
- [ ] **Step 5: Gate, commit.**  Commit `net: SYS_IFCONFIG and its interface table retire; the card is wz0`.

### Task 6: AF_UNIX passes descriptors (call 4)

**Files:**
- Modify: `src/kernel/bsdnet/sys/uipc_usrreq.c` (`unp_internalize`, `unp_externalize`, `unp_dispose`, `unp_gc`, `unp_scan`, `unp_mark`, `unp_discard` as 2.11BSD's), `src/kernel/bsdnet/machine/bn_sys.c` (`getf`, `GETF`, `ufavail`, the seams), `src/kernel/jumptable.s` and a kernel file for the `kc_*` seams, `include/fs.s` (`FCB_MsgCount`, `FCB_GcFlags`), net.mod's forwards for `sendmsg`/`recvmsg` if absent, `toolchain/lib/libc_c/` (`sendmsg`, `recvmsg`), `src/userland/unixprobe/unixprobe.c`, `src/userland/man/pages/cat4/unix.0`, `docs/PROVENANCE.md`

**Interfaces:**
- Produces: the kernel seams, after 2.11BSD `sys/sys_kern.c`: `kc_getf(fd) -> FCB offset or 0` (EBADF), `kc_fadjust(fcb, msgdelta, countdelta)`, `kc_fpfetch(fcb, &xf)` (count, msgcount, gcflags, socket), `kc_fpflags(fcb, set, clear)`, `kc_ufavail() -> int`, `kc_ufinstall(fcb) -> fd`, `kc_unpdisc(fcb)` (closef).  libc `sendmsg(s, msg, flags)` and `recvmsg(s, msg, flags)` with `msg_accrights`, as 2.11BSD's `struct msghdr`.

- [ ] **Step 1: Write the failing probe.**  `unixprobe -r`: a datagram pair over a bound path; the sender opens `/etc/motd`, sends the descriptor, closes its own; the receiver gets a new descriptor and reads the file's first line.  `unixprobe -r gc`: 150 times, open `/etc/motd`, send it over a fresh socket pair, close all three unread; every round must open, which it cannot once 128 unreclaimed FCBs fill the file table (Review Focus 3).  Prints `UNIX R ok` or `UNIX R FAIL <step>`.  Manifest `unixrights`.
- [ ] **Step 2: Run it.**  Expected: FAIL at link (no `sendmsg`) once libc is not yet there, then `EOPNOTSUPP`.
- [ ] **Step 3: Implement** libc first (with a fixture), then the seams, then upstream's routines with `struct file *` as the FCB offset.  `unp_gc` walks the FCB table through `kc_fpfetch`.
- [ ] **Step 4: Run it.**  Expected: `UNIX R ok`.  Control: `unp_externalize` installing nothing fails `-r` with `UNIX R FAIL read`.
- [ ] **Step 5: Gate, commit.**  Commit `unix: descriptors pass over AF_UNIX, as 2.11BSD passes them`.

### Task 7: A sender's AF_UNIX name arrives whole

**Files:**
- Modify: `toolchain/lib/libc_c/socket.c`, `socket_srv.c` (the arg block's name area: `sizeof (struct sockaddr_un)`, 110 bytes, and a length word the kernel writes), `src/kernel/bsdnet/machine/bn_sys.c` (`netcopyout` into it), `src/userland/unixprobe/unixprobe.c`, `src/userland/man/pages/cat4/unix.0` (the 14-character BUGS line goes)

**Interfaces:**
- Produces: `recvfrom`, `accept`, `getsockname` and `getpeername` copy `min(*len, the name's length)` bytes and write back that count, for names up to 110 bytes.

- [ ] **Step 1: Write the failing probe.**  `unixprobe -n`: a sender bound to a 40-character path sends; `recvfrom` with a 110-byte buffer gets the path whole and `fromlen` 42; with `fromlen` 16 it gets 16 bytes and 16 (Review Focus 4).
- [ ] **Step 2: Run it.**  Expected: `UNIX N FAIL` (the path cut to 14).
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run it**, and `unixdgram`, `unixstream`, `netudp`, `nettcp` fresh.  Control: the length word ignored fails the 16-byte case.
- [ ] **Step 5: Gate, commit.**  Commit `libc: a socket name is as long as AF_UNIX's`.

### Task 8: The file table outlasts the mbuf pool (call 5)

**Files:**
- Modify: `src/kernel/vfs/fsparam.h` (`NFILE` 128), regenerated `include/vfs_equ.s`, `tools/mame_test/tests/tcpmany.json` or a loopprobe mode

**Interfaces:**
- Produces: 128 system file table entries; what runs out first under many sockets is the mbuf pool (ENOBUFS).

- [ ] **Step 1: Write the failing check.**  `loopprobe -m 60`: 60 TCP sockets connected over `lo0`; then sockets until one fails, printing the errno.  Expected at 64: ENFILE at about 39.
- [ ] **Step 2: Run it.**  Expected: FAIL with ENFILE.
- [ ] **Step 3: Implement**; record what `UNP_NVNODE` (sized by `NFILE`) and the file arena now cost, and `check_kernel_ceiling.py`'s figures.
- [ ] **Step 4: Run it.**  Expected: 60 connect; the first failure is ENOBUFS, and after closing all, the pool is back to its idle count.  Review Focus 5: with the 60 sockets open, `open` files until ENFILE; closing one lets the next `open` succeed.
- [ ] **Step 5: Gate, commit.**  Commit `vfs: NFILE 128, so sockets meet the mbuf pool first`.

### Task 9: The campaign's remaining debts (spec 7, calls 6 and 7)

**Files:**
- Modify: `toolchain/lib/libc_c/netdb.c` (a deadline), `src/kernel/bsdnet/sys/uipc_socket.c` and `uipc_socket2.c` (`MSG_DONTWAIT`), `src/kernel/bsdnet/machine/bn_sys.c`, `src/kernel/bsdnet/machine/net_kern.c` (`printf` after 2.11BSD `sys/subr_prf.c` `prf`/`printn`), `src/kernel/bsdnet/netprobe.c`, the ntpd source (stratum), ntpdc's page (BUGS), `docs/PROVENANCE.md`

- [ ] **Step 1: Write the four failing checks.**  (a) `gethostbyname` against a `lo0` responder that answers junk every second returns failure within its deadline (`loopprobe -h`, reading `/etc/resolv.conf` staged to 127.0.0.1).  (b) Three processes on one UDP socket: B blocks in `recv`, A calls `recv(MSG_DONTWAIT)`, C calls a plain `recv` and must block, not answer EAGAIN (`loopprobe -w`).  (c) netprobe case 8: `printf("np %s %d %x", "pr", 42, 0x1f)` logs `np pr 42 1f`.  (d) ntpd's new-peer stratum, through `ntpdc` on `ntpnet`, or a unit check in the ntpd test.
- [ ] **Step 2: Run them.**  Expected: each FAILS as spec 7 describes.
- [ ] **Step 3: Implement each**, ported where upstream has it (`subr_prf.c`, dhclient's `wait_reply` deadline pattern for netdb), FGX's where it does not (`MSG_DONTWAIT`, PROVENANCE).  ntpdc's wrap: BUGS line.  `boot_netstart.json`'s description was Task 5's.
- [ ] **Step 4: Run them.**  Expected: PASS each, with a control each.
- [ ] **Step 5: Gate, commit** one commit per item.

### Task 10: Measure, hand over, stop

- [ ] **Step 1:** Core and far bank free, net.mod's size, the stack's footprint, and `loopprobe -b` once more.
- [ ] **Step 2:** The S5 hardware-run page in S4's shape: `ifconfig wz0` (with `ether`), `route add`/`delete`, `dhclient` by hand, a static address from `netstart`'s commented lines, descriptor passing, and S4's steps once more.
- [ ] **Step 3:** The spec: the S5 row done, the accepted calls, every spec 7 item ticked, nothing left inheriting.
- [ ] **Step 4:** `tools/gate.sh`; commit; stop for the maintainer's hardware run, then the final whole-branch review.
