# Net-mux S3 -- UDP on the kernel stack Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Every AF_INET UDP socket is a 2.11BSD `struct socket` on the kernel stack, on the wire and over `lo0`: dhclient, ntpd, `ntpdc 127.0.0.1` and `syslogd -u` run on it, the machine has a default route, the network modules load at every boot, and the chip's UDP core is gone.

**Architecture:** net.mod stays the system-call router.  A UDP descriptor carries a new transport tag whose record holds a pointer to the kernel `struct socket`, and every net.mod operation on that tag forwards through one entry in bsdnetd's vtable to 2.11BSD's `uipc_syscalls.c` and `sys_socket.c` bodies.  The core kernel's seams (read, write, ioctl, select, close) do not change.  TCP stays on the chip's sockets 1-3 until S4 (spec 4.4.1).

**Tech Stack:** fcc, Merlin32, `tools/build_bsdnet.py`, net.mod (`src/modules/net/`), MAME via `tools/mame_test/`.

**Spec:** `docs/history/plans/2026-11-03-net-multiplex-design.md`, sections 3, 4.1, 4.4, 4.4.1, 4.5, 4.7, 5 and 7.  Read them, and the S2 plan beside this one.

## Calls this plan makes that the spec does not

For the maintainer's review.  Task 8 writes the accepted ones into the spec.

1. **net.mod routes, through its existing descriptor.**  A UDP socket keeps a net.mod descriptor (tag `XPORT_KSO`) whose record holds the `struct socket` pointer, so read, write, ioctl, select and close reach the kernel stack through the paths that already exist.  The alternative, a new FCB kind that the core kernel dispatches itself, is S4's end state, but every core-bank seam would branch on it, and the core bank has 6 bytes free.  Cost: the 12-descriptor cap (`SOCKD_MAX`) stays until S4 retires the table, and the forwarding code is deleted then.
2. **A blocking UDP receive blocks.**  Today an idle UDP `recvfrom` answers EAGAIN whether or not the socket is non-blocking, which no BSD does: 2.11BSD's `soreceive` sleeps in `sbwait` unless `SS_NBIO` is set (`sys/uipc_socket.c`).  Every UDP program in the tree was checked: ntpd, ntp and syslogd use `select`, and ntpdc uses `select` under `alarm`.  dhclient's wait loop and `unixprobe`'s idle check rely on the EAGAIN; both change (Tasks 4 and 5).
3. **DHCP through an address of 0.0.0.0, as early BOOTP clients did** (spec 4.7, first option).  With no address in the chip, the driver gives `w5` 0.0.0.0, and `in_ifinit` (`netinet/in.c`) adds a route for network 0.  `rtalloc` (`net/route.c`) falls back to network 0 ("Check for wildcard gateway, by convention network 0"), so a send to 255.255.255.255 leaves through `w5`, from 0.0.0.0.  No bpf, no `SO_DONTROUTE`, and no change to 2.11BSD's files.
4. **The stack's EWOULDBLOCK is EAGAIN.**  FGX userland has one would-block errno, 11 (`toolchain/include/errno.h`, `include/errno.s`), and 2.11BSD's is 35.  The port's `sys/errno.h` takes FGX's value, with a PROVENANCE note.  The socket errnos FGX userland lacks entirely (ENETUNREACH, EHOSTUNREACH, ENETDOWN, EINPROGRESS, EALREADY, EPROTONOSUPPORT, ESOCKTNOSUPPORT, ECONNABORTED, ESHUTDOWN, among others) go into libc with 2.11BSD's numbers and strings, toolchain first.
5. **The modules load at every boot, card or not.**  With the chip's UDP retired, a machine without them has no AF_INET UDP at all, and `lo0` is what gives a cardless machine `syslogd -u` and `ntpdc 127.0.0.1`.  Spec 3 accepted the 4-5 banks.  The gate machine then pays them too, which may move the capacity tests (Task 4).
6. **`MSG_DONTWAIT` is honored on a UDP socket** by setting `SS_NBIO` for that call.  2.11BSD has no such flag; FGX's `<sys/socket.h>` defines it and net.mod honors it on its other sockets.  It is a divergence, noted in the BUGS section of `recv(2)` and in PROVENANCE.
7. **A UDP send with no route answers ENETUNREACH, not EADDRNOTAVAIL.**  With `lo0` always present, `in_ifaddr` is never empty, so `in_pcbconnect` no longer refuses, and `ip_output` reports the missing route.  `unixprobe`'s no-card case changes to that (Task 5).

## Global Constraints

- Branch `feat/net-mux` in `~/apple/fgx`.  Commit there; never push, never open a PR.
- Announce every checkout and rebuild of the tree.
- Toolchain first: an fcc or libc gap is fixed there, with a fixture that fails first.  Quote K&R before an fcc change; name the BSD file and function in every seam commit.
- Every FGX-written file has its `docs/PROVENANCE.md` row and header; every divergence from a 2.11BSD file is a BUGS and PROVENANCE note.
- Nothing Uthernet-specific above the driver: only `net/if_w5.c` and `machine/w5_asm.s` name the chip.
- Protocol code never runs from an interrupt.  It runs at syscall level or in `netintr`, and `netintr` never sleeps.
- The core bank has 6 bytes free.  S3 spends none.  The tty bank and the modules are the places for code.
- Commit bodies are informational, American spelling, ASCII only, no Co-Authored-By or session trailers.  Comments describe the current state only.
- MAME runs headless (`SDL_VIDEODRIVER=dummy`), and a passing run must not be marked `(cached)`.  Never `git stash`.
- Every new test gets a mutation or control that shows it can fail, recorded in the ledger.
- No new test goes in `tools/gate.sh`.  `tools/gate.sh` is green at the end of every task that changes code, built at `kernel.netprobe = 0`.

## Review Focus

1. **A blocking receive interrupted by a signal**: ntpdc's `alarm` firing while `recvfrom` sleeps.  Expect -1 with EINTR, the handler run, and the process able to keep using the socket.  Task 5 case `-u eintr`.
2. **Two processes inside the stack at once**: one asleep in `recvfrom` while another sends and errs.  Each gets its own errno and count, never the other's.  Task 5 case `-u two`.
3. **A UDP socket shared across fork**: the child closes it and the parent keeps using it.  Expect `soclose` only at the last reference.  Task 5 case `-u fork`.
4. **A datagram larger than the reader's buffer, and a send larger than the send buffer.**  Expect the excess discarded (2.11BSD's `soreceive` for an atomic protocol) and EMSGSIZE from `sosend`.  Task 5 case `-u size`.
5. **The address changing under bound sockets**: dhclient run again, or ifconfig.  Expect exactly one default route afterward, through the new gateway, and sockets bound to the wildcard still receiving.  Task 4 case 55.

---

### Task 1: How deep a socket call runs

**Files:**
- Modify: `tools/net_stack_depth.py`, `docs/history/plans/2026-11-03-net-multiplex-design.md`

A socket call runs the stack's C on the calling task's kernel stack, `kernel.kstk` = 1024 bytes in a slot of the flat `$E000` region (`include/kernel.s`, "THE KERNEL-IMAGE SLOTS").  That stack cannot be switched the way `netintr`'s was, because `sbwait` sleeps on it.  Seven slots of 1024 already fill 7 KB of the 8 KB region, so it cannot simply grow.  This question decides whether the plan's shape works, so it is answered first.

- [ ] **Step 1: Add the syscall roots** to `net_stack_depth.py`: `sendto`, `recvfrom`, `connect`, `bind`, `soo_close`, `soo_ioctl` and `soo_select`, from `sys/uipc_syscalls.c` and `sys/sys_socket.c`.  Report each chain's static worst case.  Add the frames below them: the dispatcher's high-water at net.mod's op entry, read from the slot paint after a `loopprobe` run (the slots are painted at boot), plus 64 bytes for an interrupt frame.
- [ ] **Step 2: Decide.**  If the worst root plus the entry depth plus 64 fits in 1024 with 128 bytes to spare, record the figure in spec section 7 and go on.  If not, STOP and report the figures and the deepest chain.  The options then are the maintainer's, because each costs bank-0 space or changes the stack's shape.
- [ ] **Step 3: Commit.**

### Task 2: The stack inside a process: `u`, sleep, signals and errno

**Files:**
- Modify: `src/kernel/bsdnet/sys/user.h`, `machine/net_kern.c`, `machine/net_asm.s`, `src/kernel/bsdnet/sys/errno.h`, `toolchain/include/errno.h`, libc's error strings (`toolchain/lib/`, wherever `sys_errlist` lives), `netprobe6.c`, `docs/PROVENANCE.md`
- Vendor: `pdp/mch_xxx.s` from `examples/2.11BSD/usr/sys/pdp/` if it is not already in `vendor/`

**Interfaces:**
- Produces: kernel `setjmp(label_t *)` and `longjmp(label_t *, int)`, matching fcc's builtin call shape (`emit_libc_call`; env address in X; for longjmp, the value in A); `label_t` sized to what they save; `sleep()` that keeps `u` across the sleep and longjmps to `u.u_qsave` when a pri > PZERO sleep is broken by a signal.

`uipc_syscalls.c` already does 2.11BSD's `setjmp(&u.u_qsave)` around `sosend`, `soreceive` and the connect wait.  2.11BSD's kernel `sleep()` longjmps there on a signal (`sys/kern_synch.c`; the kernel's `setjmp` is in `pdp/mch_xxx.s`).  Read both before writing.

- [ ] **Step 1: Write the failing probe cases** in `netprobe6.c`.  Case 51: `setjmp` returns 0, `longjmp(…, 7)` from a nested call returns 7 to it, and a register local set before the `setjmp` survives.  Case 52: `EWOULDBLOCK == EAGAIN` in the stack's headers, a compile-time check.  In the toolchain, extend the `M11/lc_errno` fixture: `strerror(ENETUNREACH)` is "Network is unreachable", not 2.11BSD's "Unknown error: 51"; goldens green.
- [ ] **Step 2: Run them.**  Expected: fail to build or FAIL.
- [ ] **Step 3: Implement.**  Kernel `setjmp`/`longjmp` go in `machine/net_asm.s`, after `mch_xxx.s`: S, DP, DBR, the return PB:PC, and fcc's callee-saved direct-page band, with no signal mask (that is libc's).  `user.h` drops `u_ofile`, since `getsock` is FGX's (Task 3).  `sleep()` copies `u` to a local before `kc_sleepi`/`kc_sleep` and back after.  On a signal at pri > PZERO it does `longjmp(&u.u_qsave, 1)`, after the copy back.  Add the errnos to libc; set EWOULDBLOCK to EAGAIN in the port's `errno.h`.
- [ ] **Step 4: Run them.**  Expected: PASS.  Mutation: skip the restore of the direct-page band and see case 51's register local go wrong.
- [ ] **Step 5: Run `tools/gate.sh`; commit** the errnos (toolchain) separately from the kernel half.

### Task 3: The seam: net.mod forwards, uipc_syscalls answers

**Files:**
- Create: `src/kernel/bsdnet/machine/bn_sys.c`, `src/modules/net/net_kso.s`, `src/userland/loopprobe/` additions for `-u`, `tools/mame_test/tests/netudp.json`
- Modify: `src/kernel/bsdnet/split.list` (link `sys/uipc_syscalls`, add `sys/sys_socket`), `machine/s2_stubs.c` (remove what this task implements), `machine/net_asm.s`, `tools/build_bsdnet.py` (the vtable slot), `include/socket.s`, `include/modules.s`, `src/modules/net/net.s`, `docs/PROVENANCE.md`
- Vendor: `sys/sys_socket.c` into `src/kernel/bsdnet/sys/` from `vendor/2.11BSD/usr/sys/sys/sys_socket.c`

**Interfaces:**
- Produces, in bsdnetd's vtable after `bn_tap`: `bn_sysent`, an assembly jump table in `machine/net_asm.s`.  It is entered by JSL with A = `BNOP_*` byte offset, X = the descriptor's socket pointer (an offset in bsdnetd's bank; 0 for `BNOP_SOCKET`), and Y = the offset of a 2.11BSD-shaped argument block (`u.u_ap`) that net.mod built in the kernel bank.  It sets DBR to bsdnetd's bank and enters C.  It returns C=1 with A = `u.u_r.r_val1`, or C=0 with A = errno.  `BNOP_*` are in `include/modules.s`, in the table's order: SOCKET, BIND, CONNECT, SENDTO, RECVFROM, SEND, RECV, SETSOCKOPT, GETSOCKNAME, GETPEERNAME, SHUTDOWN, READ, WRITE, IOCTL, SELECT, CLOSE, IFCHANGED.
- Produces: `XPORT_KSO` (5) in `include/socket.s`, and `SOCK_KsoSo`, the 2-byte socket pointer, overlaying `SOCK_FAddr`, which only the chip's UDP used.
- Consumes: `kc_wakeup`, `KSVC_SIGRAISE`, `KSVC_CURUID`, FGX's `struct uio` (`src/kernel/vfs/uio.h`; iov bases are far pointers).

The FGX-written part is the argument fetch, as spec 4.5 says.  `bn_sys.c` sets `u.u_ap`, `u.u_error`, `u.u_uid` (from `KSVC_CURUID`) and `u.u_procp`, then calls the 2.11BSD body.  `getsock`/`gtsockf` return a static `struct file` whose `f_socket` is the pointer net.mod passed.  For `BNOP_SOCKET`, it returns the new socket's pointer in A for net.mod to store.

`s2_stubs.c`'s socket-call stubs become real:
- `uiomove` copies through the far iov.
- `copyin`/`copyout` copy through far pointers built from the caller's bank.
- `selwakeup` is `kc_wakeup(WCHAN_SELECT)`, as `_FarSh_SelWakeup` explains.
- `netpsignal(u.u_procp, sig)` is `KSVC_SIGRAISE`, which `sosend` reaches with SIGPIPE after `shutdown`.
- `gsignal` and `netpfind` stay panics.  They are reachable only through SIOCSPGRP or FIOASYNC, which `_IoOp_Socket` refuses with ENOTTY.  The commit says so.

net.mod's side, in `net_kso.s`:
- `net_op_socket` sends AF_INET/SOCK_DGRAM to `BNOP_SOCKET` when `VT_BSDNET` is registered, and still to the chip otherwise until Task 6.
- Every other op on an `XPORT_KSO` descriptor tail-calls `_Kso_Forward`.  It builds the argument block from `_Sys_Saved*`, the caller's arg block and `_sockUio`.  It passes `SOCK_NB` and `MSG_DONTWAIT` as one non-blocking bit, which `bn_sys.c` turns into `SS_NBIO` for the call.
- The select and FIONREAD status (`NETOP_SockStatus`) maps to `BNOP_SELECT`: soreadable and sowriteable, never sleeping.  `_sockRxLen` gets `so_rcv.sb_cc`.
- `SIOCGIF*` on a KSO socket goes to `BNOP_IOCTL`, which is `ifioctl`.
- Teardown is `BNOP_CLOSE`.
- Nothing in net.mod reads its `_sock*` scratch after the forward returns, because the forward may have slept.

- [ ] **Step 1: Write the failing test.**  `loopprobe -u` runs these cases on `lo0`, each printing `UDP FAIL <case>` or nothing, then `UDP OK`:
  - `pair`: two sockets on 127.0.0.1 exchange a datagram both ways, and `recvfrom` names the sender's port.
  - `zero`: a bind to port 0 picks a port, and `getsockname` reports it.
  - `conn`: after `connect`, `send` works, and a datagram from a third socket is not delivered.
  - `sel`: `select` says readable only once a datagram is queued, and FIONREAD gives its length.
  - `nbio`: FIONBIO, then `read` on an empty socket answers EAGAIN, and so does `recv` with `MSG_DONTWAIT`.
  - `inuse`: a second bind to the same port answers EADDRINUSE, and SO_REUSEADDR allows it as `in_pcbbind` says.
  - `oob`: `sendto` with MSG_OOB answers EOPNOTSUPP (loopprobe's existing `dgram` case).
  - `closed`: a send on a closed descriptor answers EBADF.

  `netudp.json` runs `modload bsdnetd bsdnet0 bsdnet1 bsdnet2 bsdnet3; /testbin/loopprobe -u`.
- [ ] **Step 2: Run it.**  Expected: FAIL; the datagrams go to the chip's core, which has no `lo0`.
- [ ] **Step 3: Implement** bsdnet's side, then net.mod's.  A defect found in ported code goes in its own commit with the BSD reference.
- [ ] **Step 4: Run it.**  Expected: `UDP OK`, not cached.  Controls: make `_Kso_Forward` drop the non-blocking bit and see `nbio` hang until its timeout; send `BNOP_SELECT` to a stub that always answers ready and see `sel` fail.
- [ ] **Step 5: Run `tools/gate.sh`** (no modules loaded at boot yet, so the chip's UDP still carries the gate); **commit** bsdnet's half and net.mod's separately.

### Task 4: Every boot, an address, and a default route

**Files:**
- Modify: `disk_src/etc/rc.in`, `src/kernel/bsdnet/net/if_w5.c`, `machine/bn_sys.c`, `src/modules/net/net.s` (the IFC_SET path), `src/userland/dhclient/dhclient.c`, `netprobe6.c`, `tools/mame_test/tests/boot_netstart.json` (description only)

**Interfaces:**
- Consumes: `BNOP_IFCHANGED` (Task 3); `rtrequest` and `in_control` (upstream).
- Produces: `w5address()` that gives `w5` 0.0.0.0 when the chip has no address, and otherwise the chip's address and mask, then replaces the default route with one through the chip's gateway register (GAR), or none when GAR is 0.

`/etc/rc.in` loads `bsdnetd bsdnet0 bsdnet1 bsdnet2 bsdnet3` on the same `modload` line as `net`, before `/etc/netstart`, so dhclient's socket is already the kernel's.  net.mod's `IFC_SET`/`IFC_SETDHCP` path writes the chip as today, then calls `BNOP_IFCHANGED`, which re-runs `w5address()`.  The chip registers stay the source of truth until S5 retires `SYS_IFCONFIG`.  `w5ioctl` sends no gratuitous ARP for 0.0.0.0.

dhclient waits with `select` and the remaining timeout instead of spinning on EAGAIN.

- [ ] **Step 1: Write the failing cases.**  Probe case 54: with GAR set, `rtalloc` for an address off the local net returns an `RTF_GATEWAY` route to GAR.  Case 55: after two IFC_SETs with different gateways, exactly one default route exists, through the second gateway, and a socket bound to the wildcard before them still receives over `lo0`.  `boot_netstart.json` (real DHCP, not in the gate), with rc.in now loading the modules: `bound to` appears.  `netftp` still passes with the modules loaded at boot, which proves the chip's TCP beside them.
- [ ] **Step 2: Run them.**  Expected: FAIL.  `boot_netstart` fails because dhclient's socket now blocks in `recvfrom` and its DISCOVER finds no route.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run them.**  Expected: PASS, not cached.  Control: skip the network-0 route and see `boot_netstart` fail with `no DHCPOFFER`.
- [ ] **Step 5: Run `tools/gate.sh`.**  The gate now boots with the modules, 4-5 fewer pool banks, and the kernel carrying UDP over `lo0`.  If a capacity test goes red (`heapcap`, `mallocmax`, `bigfork`, `bigforkx`), STOP and report its numbers: re-baselining a capacity test is the maintainer's call, not a ruling.  Otherwise commit.

### Task 5: The programs on it

**Files:**
- Modify: `src/userland/unixprobe/unixprobe.c`, `src/userland/loopprobe/` (`-u` cases below), `tools/mame_test/tests/ntpd.json`, `tools/mame_test/tests/netudp.json`, the man pages of `recv(2)` (BUGS), `docs/CONFIGURING.md` if it says UDP is the chip's

The regression floor (spec 6) runs on the kernel's UDP from Task 4 on: `sockleak`, `sockemfile` and `unixdgram` in the gate; `ifcprobe`, `bindzero`, `ntpd` and `netudp` outside it.

- [ ] **Step 1: Write the failing cases.**  More `loopprobe -u` cases:
  - `eintr`: `alarm(1)` with a handler, then a blocking `recvfrom` on an empty socket, returns -1 with EINTR, the handler ran, and a datagram sent afterward is still received.
  - `two`: a child blocks in `recvfrom` while the parent sends to a closed port and gets ECONNREFUSED from the ICMP error if 2.11BSD's `udp_ctlinput` reports it on a connected socket, or a successful count otherwise.  The child's datagram arrives with its own length.  Read `udp_usrreq.c`'s `udp_ctlinput` before writing the expectation.
  - `fork`: the child closes an inherited socket and the parent still sends and receives on it.
  - `size`: a 200-byte datagram read with a 50-byte buffer returns 50, and the next read gets the next datagram, not the rest.  A send over the send buffer's high water mark answers EMSGSIZE.

  `ntpd.json` starts ntpd and runs `ntpdc -n 127.0.0.1`, expecting its peer table rather than a timeout.  Change its description, which says the loopback carries TCP only.
- [ ] **Step 2: Run them.**  Expected: `eintr` hangs to its timeout or FAILs until Task 2's longjmp reaches it; `ntpd` fails.  If either passes first, the case is not reaching the kernel path: fix the test.
- [ ] **Step 3: Change `unixprobe` as calls 2 and 7 say:**
  - The idle-socket check sets FIONBIO before its `recvfrom` (it already does for `read`).
  - The no-card send expects ENETUNREACH.
  - "All three W5100 slots free" no longer involves UDP, since a UDP socket claims no chip socket; it asserts the AF_UNIX half alone.

  Cite the 2.11BSD lines in the commit.
- [ ] **Step 4: Fix what the cases find,** each in its own commit.
- [ ] **Step 5: Run them.**  Expected: PASS, not cached; `syslogd -u` receives a line sent by `logger` over `lo0` to 127.0.0.1:514 (add it to `netudp.json`).  Control for `two`: make `sleep()` skip the copy back of `u` and see one process report the other's errno.
- [ ] **Step 6: Run `tools/gate.sh`; commit.**

### Task 6: The chip's UDP core retires

**Files:**
- Modify: `src/modules/net/net_xport.s`, `src/modules/net/net.s`, `include/socket.s`, `src/kernel/uthernet.s` and the regenerated `w5100_patchsites.s` files if anything there serves only UDP

Spec 4.4.1: "A UDP socket must never open a hardware UDP socket after S3."  Delete `_Udp_OpenAt`, `_Udp_SendCore`, `_Udp_RecvCore`, `_Udp_PortShare` and `_Udp_Connect`, the `XPORT_UDP` arms of the `_Net_Xport_*` seams and `_So_Send`/`_So_Recv`, `_So_UdpPeer*` and `_So_UdpFrom`, and the comments that describe them.  `XPORT_UDP` goes; `socket(AF_INET, SOCK_DGRAM)` without the modules answers EPROTONOSUPPORT, which is what 2.11BSD's `socreate` answers when no protosw matches.  Search with counts, not `head`, for every user of each symbol.

- [ ] **Step 1: Write the failing check:** `netudp.json` gains a run with the modules not loaded that expects `socket: Protocol not supported` from a one-line UDP client in `loopprobe -u`.
- [ ] **Step 2: Run it.**  Expected: FAIL; the chip core still answers.
- [ ] **Step 3: Delete.**  Regenerate the patch-site files if W5100 sites moved.
- [ ] **Step 4: Run** `netudp`, `netw5`, `netftp`, `boot_netstart`, `netdumptap`.  Expected: PASS, not cached.
- [ ] **Step 5: Run `tools/gate.sh`; check `tools/check_kernel_ceiling.py`; commit.**

### Task 7: Frames back to back

**Files:**
- Modify: `src/kernel/bsdnet/net/if_w5.c`, `netprobe6.c`

S2 left the transmit path sending one frame per `netintr` pass when the previous one is still going out, so a second frame can wait up to 133 ms (spec 7, "S3 inherits").  UDP makes that common: a DHCP reply and ARP, ntpd's poll of three servers.

- [ ] **Step 1: Write the failing case.**  Probe case 56: five echo requests queued to the gateway in one call leave within 2 ticks, counted by `if_opackets`.
- [ ] **Step 2: Run it.**  Expected: FAIL (about 5 x 8 ticks).
- [ ] **Step 3: Implement.**  `w5start` waits for the chip to finish the frame it sent, bounded by a poll count worth about 3 ms (a full frame is 1.2 ms on the wire), and defers to the next pass only past that bound.  `ponytail:` comment naming the bound and that S4 revisits it with 8 KB buffers.
- [ ] **Step 4: Run it.**  Expected: PASS.  Control: set the bound to 0 and see case 56 fail.
- [ ] **Step 5: Run `tools/gate.sh`; commit.**

### Task 8: Measure, hand over, stop

**Files:**
- Modify: `docs/history/plans/2026-11-03-net-multiplex-design.md`, `docs/CHANGELOG.md` if the branch's convention wants it
- Create: `docs/history/2026-11-NN-net-mux-s3-hardware-run.md`

- [ ] **Step 1: Measure and record in spec sections 5 and 7:**
  - the task kernel stack's high-water during `loopprobe -u`, read from the slot paint, against Task 1's static figure;
  - the module footprint;
  - the pool banks the gate machine has left;
  - the echo round trip, with and without Task 7.
- [ ] **Step 2: Update the spec.**  S3 done, with its commit range; the calls above that were accepted; what S4 inherits: the descriptor table and its 12-slot cap, `net_kso.s`, `gsignal`/`netpfind`, and the chip's TCP.
- [ ] **Step 3: Verify.**  Expected: `tools/gate.sh` green at `kernel.netprobe = 0`.  Green at 1 and not cached: `netprobe`, `netudp`, `netw5`, `netftp`, `netdumptap`, `boot_netstart`, `ntpd`, `ntpnet`.
- [ ] **Step 4: Leave a hardware image and STOP.**  Build the shipping configuration to `disk/fgxroot-s3.fs`.  Write one page naming what to check on the real IIgs and what each should show:
  - the boot's `bound to` line;
  - `ntpdc -n 127.0.0.1` and ntpd setting the clock;
  - `logger` to `syslogd -u` from another machine;
  - ping from another subnet, now that there is a default route;
  - an ftp `get` checked with `sum`, and its rate against S2's 9.6 KB/s (spec 6 re-measures throughput at S3);
  - netdump.

  Report and wait.
- [ ] **Step 5: Leave the tree** on `feat/net-mux`, built at `kernel.netprobe = 0`, and say so.  Commit.
