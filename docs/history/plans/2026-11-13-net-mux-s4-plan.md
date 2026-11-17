# Net-mux S4 -- TCP and AF_UNIX on the kernel stack Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Every socket a process opens -- TCP, UDP and AF_UNIX, on the wire and over `lo0` -- is a 2.11BSD `struct socket` on the kernel stack, reached from the process's file table, so the only limit on sockets is memory; telnet/telnetd, inetd, ftp, nc and syslog's `/dev/log` run on it unchanged, and the chip's TCP, `net_loop.s`, `unp.s` and net.mod's descriptor table are gone.

**Architecture:** The FCB holds the socket.  A socket FCB carries the `struct socket` offset in bsdnetd's bank in two bytes of its private area, and net.mod, still the system-call router, reads it there and forwards through `_Kso_Do` to `bn_sys.c` as S3 does for UDP.  TCP needs two new forwards (listen, accept); AF_UNIX links 2.11BSD's `uipc_usrreq.c`, with the file-system name kept in the kernel's existing `unp_nameop`.  Once nothing uses them, the chip's sockets 1-3 and every FGX-written transport retire, and socket 0 gets the chip's whole 8 KB each way.

**Tech Stack:** fcc, Merlin32, `tools/build_bsdnet.py`, `tools/net_stack_depth.py`, net.mod (`src/modules/net/`), the kernel VFS (`src/kernel/vfs/`), MAME via `tools/mame_test/`.

**Spec:** `docs/history/plans/2026-11-03-net-multiplex-design.md`, sections 2, 3, 4.2-4.6, 5, 6 and 7 (S4 inherits, the kernel stack, and "Before the campaign PR").  Read them, and the S3 plan beside this one.

## Calls this plan makes that the spec does not

For the maintainer's review.  Task 8 writes the accepted ones into the spec.

1. **Raw sockets (ping) move to S4, from S5.**  While ping uses the chip's IPRAW socket, net.mod's descriptor table, `_W5_SockAlloc` and the chip's per-socket buffer split all have to stay, so S4 could retire none of them: the 12-descriptor cap (an anti-goal) would survive S4 for raw sockets, socket 0 could not take all 8 KB, and two roads would reach a socket.  `raw_ip.c`, `raw_usrreq.c` and `ip_icmp.c` already link (bank 1 and 2).  S5 keeps `ifconfig`/`route` and the retirement of `SYS_IFCONFIG`.  If the maintainer keeps the spec's phasing, Task 6 is dropped, and Task 7 keeps the descriptor table for `SOCK_RAW` alone and says so in the spec.
2. **The FCB is the file table entry 2.11BSD's `struct file` is.**  `f_data` becomes `FCB_SockSo`, two bytes at `FCB_FstPriv+0` (19 bytes are free there; `FCB_SockIdx`'s byte goes), holding the socket's offset in bsdnetd's bank.  Sharing across `fork` and `dup` is the FCB's `FCB_RefCount`, which already makes close the last reference (`fs.s`, `@fc_sockShared`).  No 2.11BSD `struct file` is built, except the static one `getf` hands `gtsockf`, as in S3.
3. **accept's descriptor is taken before the connection is dequeued, by net.mod.**  2.11BSD's `accept()` calls `falloc` before `soqremque`, so a process out of descriptors gets EMFILE and the connection stays acceptable (`sockemfile`'s assertion).  net.mod keeps that order: it allocates the FCB with `SYS_NETKC_FCBALLOC`, as `net_op_socket` does, then forwards `BNOP_ACCEPT`, which runs the body from the dequeue on (`so_q`, `soqremque`, `soaccept`) and returns the new socket; on the stack's error net.mod frees the FCB.  `falloc` and `ufalloc` stay panics, unreachable.
4. **Socket names leave the kernel stack the way 4.3BSD-Reno moved them, if Task 1 says they must.**  2.11BSD puts each name in an `MSIZE` stack buffer (`sendit`'s `sabuf` and `ribuf`, 256 bytes); 4.3BSD-Reno's `sockargs` (`kern/uipc_syscalls.c`) gets an mbuf with `m_get(M_WAIT, type)`.  Task 1 takes Reno's shape for exactly the calls whose measured depth leaves under 128 bytes spare, each a PROVENANCE divergence.
5. **AF_UNIX's file-system name stays in the kernel's `unp_nameop`**, which is already the Reno-derived vnode code (`src/kernel/vfs/vfs_syscalls.c`).  `uipc_usrreq.c`'s `unp_bind` and `unp_connect` call it through a kernel seam instead of 2.11BSD's `namei`/`maknode`, which name inodes FGX does not have.  The vnode's socket field holds the `struct socket` offset, so `unp_vnodes[UNP_NVNODE]` and its 12-slot cap go.  AF_UNIX `SOCK_STREAM` comes with the port, as upstream has it.
6. **Access rights over AF_UNIX (`msg_accrights`) answer EOPNOTSUPP.**  `unp_internalize`/`unp_externalize` move `struct file` pointers, which FGX does not have; nothing in the tree passes rights (checked: no user of `msg_accrights` or `SCM_RIGHTS` outside the `unix(4)` page).  BUGS in `unix(4)`, a PROVENANCE note, and the page says so.
7. **SIGURG stays unsent.**  `sohasoutofband` signals only a socket with `so_pgrp` set, which SIOCSPGRP sets, and `_IoOp_Socket` still refuses it with ENOTTY, so `gsignal` and `netpfind` stay unreachable panics.  MSG_OOB itself now works on TCP (telnet and ftp send it, `telnet.c:355`, `ftp.c:1062`); only the signal is missing.

## Global Constraints

- Branch `feat/net-mux` in `~/apple/fgx`.  Commit there; never push, never open a PR.
- Announce every checkout and rebuild of the tree.
- Toolchain first: an fcc or libc gap is fixed there, with a fixture that fails first.  Quote K&R before an fcc change; name the BSD file and function in every seam commit.
- Every FGX-written file has its `docs/PROVENANCE.md` row and header; every divergence from a 2.11BSD file is a BUGS and PROVENANCE note.
- Nothing Uthernet-specific above the driver: only `net/if_w5.c` and `machine/w5_asm.s` name the chip.
- Protocol code never runs from an interrupt.  It runs at syscall level or in `netintr`, and `netintr` never sleeps.
- Nothing in net.mod's scratch is read after a forward returns except what `_Kso_Do` restores (`_sockTmpOff`): a forward may sleep.
- The core bank has 33 bytes free.  Tasks 2-5 spend none net; Task 7 reports what the retirements give back.
- The six "Before the campaign PR" items in spec 7 stay on that list; Task 1 takes the stack-floor one, because TCP makes it matter.  Each is ticked off in spec 7 when it lands.
- Commit bodies are informational, American spelling, ASCII only, no Co-Authored-By or session trailers.  Comments describe the current state only.
- MAME runs headless (`SDL_VIDEODRIVER=dummy`), and a passing run must not be marked `(cached)`.  Never `git stash`.  Uthernet tests run alone.
- Every new test gets a mutation or control that shows it can fail, recorded in the ledger.
- No new test goes in `tools/gate.sh`.  `tools/gate.sh` is green at the end of every task that changes code, built at `kernel.netprobe = 0`.

## Review Focus

1. **A close with data still queued**: telnetd's session ends with output unsent, or a client writes and closes at once.  Expect every byte delivered before the FIN (`soclose`'s `sodisconnect`, `tcp_usrclosed`), close returning at once without SO_LINGER, and a SO_LINGER close sleeping until sent or the linger time, interruptible.  Task 3 case `-t drain`.
2. **The peer resets**: a read on a reset connection answers ECONNRESET; a write after the peer has gone answers EPIPE and raises SIGPIPE (`sosend`, `NETPSIGNAL`), which kills a process that did not catch it.  Task 3 case `-t reset`.
3. **A listener's queue fills**: more connects than the backlog while nobody accepts.  Expect the excess SYNs dropped (`sonewconn` refuses past `so_qlimit`), the clients retrying, and every connection accepted once `accept` runs, with no FCB or mbuf leaked.  Task 4 case `-m backlog`.
4. **A process exits holding connections**, including one forked child that shares a listener with its parent (inetd's shape).  Expect each socket closed at its last reference only, the peer seeing EOF, and the listener still accepting for the parent.  Task 3 case `-t fork`.
5. **Mbufs run out**: more connections than the pool holds.  Expect ENOBUFS from `socket`, `connect` or `accept`, never a hang or a panic, and the pool back to its idle count after every socket closes.  Task 4 case `-m exhaust`.

---

### Task 1: How deep a TCP call runs

**Files:**
- Modify: `tools/net_stack_depth.py` (TCP roots), `src/kernel/bsdnet/sys/uipc_syscalls.c` (only if the measure says so), `src/kernel/bsdnet/machine/net_asm.s` (`bn_sysent` sets the stack floor), `docs/PROVENANCE.md`, spec 7

**Interfaces:**
- Produces: the static depth of `connect`, `accept`, `send`/`sendto`/`write`, `recv`/`read`, `close` and `shutdown` on a TCP socket, entry and interrupt allowance included, in the ledger; `bn_sysent` setting `_fcc_stkfloor` to the caller's kernel slot floor, as `netintr_enter` sets it for `FGX_STK_NET`.

- [ ] **Step 1: Write the failing check.**  `net_stack_depth.py --roots tcp` prints each TCP root's depth plus 60 bytes of entry and 64 of interrupt frame, and exits nonzero if any leaves under 128 of the 1024-byte slot.  For the floor: a `kernel.netprobe = 1` case that recurses in C from a socket call (a `BNOP_` probe op) must halt through `_fcc_stkoflow`, not run past the slot.
- [ ] **Step 2: Run them.**  Expected: the depth check FAILS on TCP `sendto` (826 + 124 = 950, spec 7); the floor case runs past the slot (or the ledger records what `_fcc_stkfloor` held, if it halts already, and the case is kept as the control).
- [ ] **Step 3: Implement.**  Read `_fcc_stkfloor`'s users and set it in `bn_sysent` from the current slot.  For each failing root, replace its `MSIZE` stack buffers with 4.3BSD-Reno's `sockargs` (call 4), freeing the mbuf on every return path; quote Reno's lines in the commit.
- [ ] **Step 4: Run them.**  Expected: every TCP root leaves 128 or more; the floor case halts with `_fcc_stkoflow`.  `netudp` still `UDP OK`.
- [ ] **Step 5: Run `tools/gate.sh`; commit** the floor and the buffers separately; tick spec 7's stack-floor item.

### Task 2: A socket is reached from its FCB

**Files:**
- Modify: `include/fs.s` (`FCB_SockSo`), `include/socket.s`, `src/kernel/socket.s` (`_Sock_FdToSo`), `src/kernel/syscall.s` (the socket seams that read the table), `src/drivers/fs/fs.s` (close), `src/kernel/net_dispatch.s`, `src/modules/net/net.s`, `src/modules/net/net_kso.s`

**Interfaces:**
- Produces: `FCB_SockSo EQU FCB_FstPriv+0` (2 bytes), and `FCB_SockIdx` kept only for the old transports until Task 7, at `FCB_FstPriv+2`.  A kernel socket's FCB has `FCB_SockSo` nonzero.
- Produces: `_Sock_FdToSo` (core): A = fd in, C=1 and A = the socket offset (0 for an old-transport socket), Y = the old descriptor offset; C=0 and A = EBADF.  It replaces `_Sock_FdToDesc` at every caller, which keep their contracts for Y.
- Produces: `_Kso_Do` taking the socket in A when it comes from an FCB, rather than from `SOCK_KsoSo`.
- Consumes: `_Kso_Do`, `BNOP_*` (S3).

UDP moves first, with nothing else changing: `net_op_socket` writes the socket into `FCB_SockSo` and allocates no descriptor for it; every op tests `FCB_SockSo` before its descriptor arms (the S3 rule, "the test comes first"); close's `BNOP_CLOSE` reads it from the FCB.  The core seams that poke `SOCK_Flags` (`syscall.s`, FIONBIO) forward to `BNOP_IOCTL` for a kernel socket, which is `soo_ioctl`'s FIONBIO.

- [ ] **Step 1: Write the failing test.**  `loopprobe -u` gains case `many`: one process opens 20 UDP sockets on `lo0` (more than `SOCKD_MAX`), sends one datagram through each to the first, and reads 20.
- [ ] **Step 2: Run `netudp`.**  Expected: FAIL `many` at the 13th `socket`: the descriptor table is full.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** `netudp`, `netudp_nomod`, `sockleak`, `sockemfile`, `bindzero`, `ntpd`, `unixdgram`.  Expected: all PASS, not cached.  Control: make `net_op_socket` allocate a descriptor again for UDP and see `many` fail at 13.
- [ ] **Step 5: Run `tools/gate.sh`; commit.**  The core bank's count is in the commit body.

### Task 3: TCP on the kernel stack

**Files:**
- Modify: `include/modules.s` (`BNOP_LISTEN` 17, `BNOP_ACCEPT` 18), `src/kernel/bsdnet/machine/bn_sys.c`, `src/modules/net/net.s`, `net_kso.s`, `src/userland/loopprobe/loopprobe.c` (`-t`), `src/userland/telnet/telnet.c` (the MSG_OOB comment only), `docs/PROVENANCE.md`
- Create: `tools/mame_test/tests/nettcp.json`, `tools/mame_test/tests/tcpmany.json`

**Interfaces:**
- Consumes: `FCB_SockSo`, `_Sock_FdToSo` (Task 2); Task 1's depth.
- Produces: `BNOP_LISTEN` (2.11BSD `listen()`), `BNOP_ACCEPT` (call 3: entered after net.mod has allocated the FCB; out, A = the new socket for net.mod to store in `FCB_SockSo`, or C=0 and errno, and net.mod frees the FCB); `BNOP_SHUTDOWN` forwarded for every `how`, including SHUT_RD, which the kernel no longer answers itself (S3 ruling, task 3).

`net_op_socket` sends AF_INET/SOCK_STREAM to `BNOP_SOCKET`.  `connect` blocks in 2.11BSD's `connect()` loop (`sleep(&so->so_timeo)`), and a non-blocking one answers EINPROGRESS, then EALREADY, then EISCONN.  `select` on a listener is readable when `so_qlen` is nonzero (`soo_select`).  The chip's TCP and the loopback rings are now unreachable from `socket()`; Task 7 deletes them.

- [ ] **Step 1: Write the failing tests.**  `loopprobe -t` runs these cases over `lo0`, each printing `TCP FAIL <case>` or nothing, then `TCP OK`:
  - `echo`: listen, connect, accept; 10 KB each way, byte-checked.
  - `nb`: a non-blocking connect answers EINPROGRESS, `select` says writable when it completes, a second connect answers EISCONN.
  - `refused`: a connect to a port nobody listens on answers ECONNREFUSED.
  - `drain` (focus 1): the client writes 6 KB and closes at once; the server reads all 6 KB, then 0.
  - `reset` (focus 2): with SO_LINGER 0 the peer's close resets; a read answers ECONNRESET; a write after it answers EPIPE, and a child that does not catch SIGPIPE dies of it (`wait` status).
  - `fork` (focus 4): a listener shared with a child; the child exits; the parent still accepts, and a connection the child held is seen at EOF by its peer.
  - `oob`: `send(..., MSG_OOB)` of one byte is read by `recv(..., MSG_OOB)` on the peer.
  - `name`: `getsockname` and `getpeername` agree on both ends.

  `nettcp.json` runs `loopprobe -t`.  `tcpmany.json` runs `loopprobe -m`: a parent listens with backlog 5 and accepts 16 connections that a forked child makes, each carrying 1 KB both ways while all 16 are open; `MANY OK`.
- [ ] **Step 2: Run them.**  Expected: FAIL.  `tcpmany` fails at the 4th connection or before (NPIPE 8 rings, 12 descriptors); `nettcp` fails `oob` (the old loopback refuses MSG_OOB) and `reset`.
- [ ] **Step 3: Implement** bsdnet's side, then net.mod's, in separate commits.
- [ ] **Step 4: Run** `nettcp`, `tcpmany`, `telnet_loopback`, `telnetiac`, `inetdboot`, `sockleak`, `sockemfile`, `bindzero`, `netudp`.  Expected: all PASS, not cached; `sockemfile` must pass as it stands (call 3).  Controls: make `BNOP_ACCEPT` dequeue before taking the FCB and see `sockemfile` fail; drop `NETPSIGNAL` and see `reset`'s child live.
- [ ] **Step 5: Run `netw5` and `netftp`** (alone, real network): ftp's control and data connections are now the kernel's, and `sum` matches.  **Run `tools/gate.sh`; commit.**

### Task 4: As many sockets as memory holds

**Files:**
- Modify: `src/kernel/bsdnet/sys/mbuf.h` (`NMBUFS`, `NMBCLUSTERS`), `src/userland/loopprobe/loopprobe.c` (`-m` cases), `tools/mame_test/tests/tcpmany.json`, spec 5

**Interfaces:**
- Produces: the pool size, chosen from measurement, and in spec 5 the mbufs one idle TCP connection holds and how many the bank leaves room for.

- [ ] **Step 1: Write the failing cases** in `loopprobe -m`, after the 16:
  - `backlog` (focus 3): 8 connects against backlog 2 with no accept running; then accept all 8 within 30 s.
  - `exhaust` (focus 5): open connected pairs, split across children so the 30-descriptor table is not the limit, until an error, which must be ENOBUFS; close them all; then the same number of pairs opens again, which a leaked mbuf or FCB would stop short.
- [ ] **Step 2: Run `tcpmany`.**  Expected: FAIL, or PASS with the ledger recording why a case cannot fail at the current pool (then its control is the mutation).
- [ ] **Step 3: Size the pool.**  Measure mbufs per idle connection; set `NMBUFS` so 16 idle connections and a listener use under half the pool, within bsdnetd's bank (64 KB less the data image), and record both numbers.  If the bank cannot hold it, STOP and report: a second data bank is the maintainer's call.
- [ ] **Step 4: Run `tcpmany`, `netudp`, `nettcp`.**  Expected: PASS, not cached.  Control: halve `NMBUFS` and see `exhaust` reach ENOBUFS sooner while still cleaning up, and the 16 still pass or fail with ENOBUFS, never hang.
- [ ] **Step 5: Run `tools/gate.sh`.**  If a capacity test goes red, STOP and report its numbers.  **Commit.**

### Task 5: AF_UNIX on `uipc_usrreq.c`

**Files:**
- Modify: `src/kernel/bsdnet/split.list` (link `sys/uipc_usrreq`, `sys/uipc_proto`), `src/kernel/bsdnet/sys/uipc_usrreq.c` (`unp_bind`, `unp_connect`, `unp_detach`, rights), `src/kernel/vfs/vfs_syscalls.c` (`unp_nameop`), `src/kernel/vfs/vnode.h`, `machine/bn_sys.c`, `src/modules/net/net.s`, `src/userland/unixprobe/unixprobe.c`, `src/userland/man/pages/` (`unix(4)` BUGS), `docs/PROVENANCE.md`
- Create: `tools/mame_test/tests/unixstream.json`

**Interfaces:**
- Produces: `unp_nameop(op, path, so, vpp)`: `UNP_OP_BIND` creates the node, sets its socket field to `so` (a bsdnetd offset) and returns the held vnode in `*vpp`; `UNP_OP_LOOKUP` returns the socket field of the named node in `so`'s place, or ECONNREFUSED if none; `UNP_OP_UNBIND` takes the vnode, clears its socket field and releases it.  The `unp_vnodes` table and `UNP_NVNODE` go.  bsdnet reaches it through a kernel seam (`kernel_exports.s`), running in the calling process.
- Consumes: Task 2's FCB path; Task 3's `BNOP_LISTEN`/`BNOP_ACCEPT` for SOCK_STREAM.

`net_op_socket` sends AF_UNIX (DGRAM and STREAM) to `BNOP_SOCKET`.  `unp_bind`/`unp_connect` keep upstream's checks and errnos, with only the name calls replaced (call 5); rights answer EOPNOTSUPP (call 6).

- [ ] **Step 1: Write the failing test.**  `unixprobe` gains stream cases: bind a path, listen, connect from a child, 8 KB each way, EOF at close; a connect to a path with no listener answers ECONNREFUSED; a second bind to a bound path answers EADDRINUSE; and 20 bound DGRAM sockets at once (past `UNP_NVNODE`).  `unixstream.json` runs it.
- [ ] **Step 2: Run it.**  Expected: FAIL (no AF_UNIX SOCK_STREAM; the 13th bind fails).
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** `unixstream`, `unixdgram` and `slogprobe` (syslog(3) through `/dev/log`).  Expected: PASS, not cached.  Control: skip the socket field's clear in UNBIND and see a rebind after close answer EADDRINUSE.
- [ ] **Step 5: Run `tools/gate.sh`; commit.**

### Task 6: Raw sockets and ping (call 1)

**Files:**
- Modify: `src/modules/net/net.s` (SOCK_RAW), `machine/bn_sys.c` if needed, `src/kernel/bsdnet/net/if_w5.c` (nothing should need to), the ping test

**Interfaces:**
- Consumes: Task 2's FCB path.  Raw sockets are root-only (`raw_usrreq`, as 2.11BSD's `socreate` checks `SS_PRIV`).

`net_op_socket` sends AF_INET/SOCK_RAW to `BNOP_SOCKET`; `raw_ip.c` and `icmp_input` carry it.  `ping` is unchanged.

- [ ] **Step 1: Write the failing check.**  `ping -c 3 127.0.0.1` prints three replies (`lo0`), and `netw5`'s wire ping to the gateway still answers.
- [ ] **Step 2: Run it.**  Expected: FAIL for 127.0.0.1 (the chip's IPRAW socket has no `lo0`).
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** it and `netw5` (alone).  Expected: PASS, not cached; replies come from the kernel (`MR_PB` is set, so the chip answers nothing).
- [ ] **Step 5: Run `tools/gate.sh`; commit.**

### Task 7: The chip's transports retire

**Files:**
- Delete: `src/modules/net/net_xport.s`, `net_loop.s`, `unp.s`, `src/kernel/net_loop.s`, `src/kernel/unp.s`, and the chip-socket parts of `src/kernel/uthernet.s` and `src/kernel/socket.s` (`_AllocSockTable`, the `_sock*` scratch nothing reads)
- Modify: `include/socket.s` (the descriptor table, `SOCKD_MAX`, `XPORT_*` but what remains), `include/fs.s` (`FCB_SockIdx` goes), `src/modules/net/net.s`, `net_kso.s`, `src/kernel/uthernet.s` (`_w5InitTbl`: RMSR/TMSR give socket 0 8 KB each way), `src/kernel/bsdnet/net/if_w5.c` (the ring size it assumes), `src/userland/inetd/inetd.c` (the re-arm workaround, spec 4.6), `src/kernel/w5100_patchsites.s` (regenerated), `docs/ROADMAP.md`, `docs/PROVENANCE.md`, man pages naming the old limits

**Interfaces:**
- Consumes: Tasks 2-6, after which every socket is a kernel socket.

- [ ] **Step 1: Write the failing check.**  A `tools/` check (run by ninja, not the gate) that fails while any of `SOCKD_MAX`, `XPORT_TCP`, `XPORT_UNIX`, `_W5_SockAlloc` or `_Loop_` is defined anywhere in `src/` or `include/`; and `netw5` asserts `w5: rx 8192` from the driver's attach line.
- [ ] **Step 2: Run them.**  Expected: FAIL.
- [ ] **Step 3: Delete,** in commits a reviewer can read one at a time: the chip's TCP, the loopback rings, `unp.s`, the descriptor table, the buffer split, inetd's re-arm.  Regenerate the W5100 patch tables (`gen_w5100_patchsites.py`) when kernel code moves.
- [ ] **Step 4: Run** the check, `netw5`, `netftp` (alone), `nettcp`, `tcpmany`, `unixstream`, `netudp`, `netudp_nomod` (without modules, AF_INET and AF_UNIX `socket` both answer EPROTONOSUPPORT; the test's expectation changes for AF_UNIX, and the commit says so), `inetdboot`, `telnet_loopback`.  Expected: PASS, not cached.
- [ ] **Step 5: Run `tools/gate.sh`; commit.**  Record the core, far and tty bytes given back, and net.mod's size before and after.

### Task 8: Measure, hand over, stop

**Files:**
- Modify: spec sections 4.4 (S4 done), 5 (S4's measures), 7 (S5 inherits; the "Before the campaign PR" list); `docs/history/2026-11-13-net-mux-s4-hardware-run.md` (create)

- [ ] **Step 1: Measure under MAME,** shipping configuration: the deepest process slot on `nettcp` and `tcpmany` (paint), the module footprint, pool banks free at idle, mbufs per idle connection, and a 1 MB TCP transfer over `lo0` (time and rate).  Record the checksum-fold decision spec 3 left for S4: fold only if `in_cksum` is over 15% of a `lo0` transfer's profile (`pc_sample`).
- [ ] **Step 2: Write the hardware-run page** in the S3 page's shape: boot and lease; telnet in from the Mac; ftp `get` of 1 MB with `sum` and rate (against S3's 9.9 KB/s on the chip's TCP); 16 telnet sessions or `nc` connections at once from the Mac; ping both ways; syslog over `/dev/log` and UDP; netdump.
- [ ] **Step 3: Update the spec** with the measures, the accepted calls, and what S5 inherits.
- [ ] **Step 4: Run `tools/gate.sh`; commit** (docs only: `FGX_NO_GATE=1` is allowed if no code changed since the last green gate).  Stop for the maintainer's hardware run.
