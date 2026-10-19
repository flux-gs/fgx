# Design -- syslog(3)/syslogd(8) over AF_UNIX SOCK_DGRAM

Date: 2026-09-19.  Decided by the maintainer this session: path C (AF_UNIX in the
kernel first, then syslogd), SOCK_DGRAM only, no GitLab issue for the
symptom -- the reasoning goes in the commit body.

## 1. The problem

Log messages have no fixed sink.  `toolchain/lib/libc_c/syslog.c` formats
correctly -- ident, `[pid]`, and the BSD `%m` conversion -- and then writes to
**stderr**.  So the sink is whatever fd 2 happened to be when the process
started: `su` run on ttyv2 prints its `BAD SU` line onto ttyv2, and a daemon
that has done TIOCNOTTY has nowhere for it to go at all.
`src/userland/su/su.c:21` already admits this in BUGS.

Five callers today: `su`, `inetd`, `telnetd`, `reboot`, `slogprobe`.

`toolchain/include/syslog.h` promises the interface will not change when a
real sink arrives.  This design keeps that promise: no port changes.

## 2. What upstream actually does

`syslog(3)` sends a formatted line to an **AF_UNIX SOCK_DGRAM** socket bound
at `/dev/log`; `syslogd` reads it, reads kernel messages from `/dev/klog`,
and routes per `/etc/syslog.conf` to files, `/dev/console`, named users,
wall, or UDP 514.

Two readings that changed this design, both from the source rather than from
memory:

**(a) bind uses VOP_CREATE, not VOP_MKNOD.**  From
`examples/4.3BSD-Reno/kern/uipc_usrreq.c`, `unp_bind`:

    VATTR_NULL(&vattr);
    vattr.va_type = VSOCK;
    vattr.va_mode = 0777;
    if (error = VOP_CREATE(ndp, &vattr))

That is the same vnode slot `open(O_CREAT)` already uses.  FGX needs no
`mknod(2)` and no on-disk format change, and `src/kernel/vfs/ufs_inode.c:1325`
already maps `IFSOCK` to `VSOCK`.

**(b) a datagram lands in the RECEIVER's buffer, as a record.**  Cited from
**2.11BSD**, `usr/sys/sys/uipc_usrreq.c`, `PRU_SEND`, `SOCK_DGRAM` arm -- not
Reno, because 2.11BSD carries a clause Reno drops and that clause decides the
implementation:

    so2 = unp->unp_conn->unp_socket;
    if (unp->unp_addr)
            from = mtod(unp->unp_addr, struct sockaddr *);
    else
            from = &sun_noname;
    if (sbspace(&so2->so_rcv) > 0 &&
        sbappendaddr(&so2->so_rcv, from, m, rights)) {

Reno has only the `sbappendaddr` call, which it can afford: that routine totals
the whole record and refuses before copying a byte.  `_Pipe_WriteAt` makes no
such promise -- it writes in chunks, grows the ring, and returns a PARTIAL count
rather than failing -- so FGX needs the explicit space test, and 2.11BSD is
where it is written down.

So the buffer belongs to the **bound** socket, not to the connection, and one
`send` is one record carrying the sender's address.  A client that never
bound -- which is every `syslog(3)` client -- sends `sun_noname`.

This is why the FGX design needs ONE ring for the whole syslog path rather
than one per client, and why the ring is framed rather than a byte stream.
A per-connection design would have been wrong on both counts.

## 3. What FGX has, and what it lacks

Lacks:

- **AF_UNIX entirely.**  `net_op_socket` (`src/modules/net/net.s:624`) is
  `CMP #AF_INET` / `BNE @ss_einval`, then `_W5_SockAlloc` -- a W5100
  hardware socket.  `tools/check_bsd_enforcement.py:165` records the absence
  as a deliberate `n/a`.
- **The Reno socket framework.**  `uipc_usrreq.c` (741 lines) sits on
  `uipc_socket.c` (962) + `uipc_socket2.c` (758) + `uipc_mbuf.c` (508).
  There is no `struct socket`, no `sockbuf`, no mbuf in FGX.  Porting
  AF_UNIX literally means porting ~3,000 lines of framework into a kernel
  whose bank-0 residency is under a live ratchet.  This design does not.
- **libc:** `strftime` (absent -- the `"%h %e %T "` prefix needs it),
  `setlogmask`, `vsyslog`, `writev` (header only, `sys/uio.h`), and the
  `LOG_PERROR`/`LOG_PRIMASK`/`LOG_FACMASK`/`LOG_MASK`/`LOG_NFACILITIES`
  macros plus `LOG_CRON`/`LOG_NEWS`/`LOG_UUCP`/`LOG_LOCAL1-7`.
- **For syslogd:** `sigaction`, `sigprocmask`, `setitimer`,
  `getservbyname`, `daemon(3)`.
- **A userland path into the kernel log ring.**  `SYS_KERNLOG` is a module
  jump-table slot (jumptable.s slot 16), not a syscall; `SYS_DMESG` (#60)
  copies the ring out only.  There is no `/dev/klog`.

Has, and this is what the design is built from:

- **`src/modules/net/net_loop.s`** (1787 lines): the 127.0.0.1 loopback
  transport -- a socket with no hardware behind it, delivering through
  `_Pipe_*` rings.  The worked precedent.
- **`src/modules/net/pipe.s`** (936 lines): ring alloc/read/write/teardown,
  blocking via `_Pipe_PollIntr`, grow-on-full.
- **`include/socket.s`**: `SOCK_Proto` is already a transport tag
  (`XPORT_NONE/UDP/ICMP/TCP`), and `SOCK_HwIdx` already carries sentinels
  (`SOCK_HW_NONE $FF`, `SOCK_HW_LOOP $FE`).
- **VFS:** `VOP_CREATE` (`ufs_create`), `namei`, `VOP_ACCESS`, and
  `IFSOCK -> VSOCK`.  `ls -l` already prints `S_IFSOCK`.
- **Syscalls:** `SYS_SOCKET` 71, `SYS_BIND` 72, `SYS_CONNECT` 76,
  `SYS_SEND` 77, `SYS_RECV` 78, `SYS_SENDTO` 73, `SYS_RECVFROM` 74,
  `SYS_SELECT` 99, `SYS_FSYNC` 97, `SYS_SIGNAL` 48, `SYS_SIGSETMASK` 102,
  `SYS_ALARM` 64.  No new syscall is needed.
- **libc:** `utmp`, `ttyname`, `localtime` (`ctime.c`), `select`.

## 4. The design

### 4.1 A fourth transport tag, XPORT_UNIX

`XPORT_UNIX EQU 4` in `include/socket.s`, with `net_op_socket` gaining an
`AF_UNIX` arm that resolves `(AF_UNIX, SOCK_DGRAM, 0) -> XPORT_UNIX`.

**Why a new tag and not a SOCK_HwIdx sentinel like loopback's.**  Loopback
deliberately kept `SOCK_Proto == XPORT_TCP` and used `SOCK_HW_LOOP` instead,
because to userland it IS an ordinary SOCK_STREAM and "re-tagging the proto
would break every `SOCK_Proto == XPORT_TCP` test" (`include/socket.s`).  That
reasoning protects an EXISTING transport's sockets from being re-tagged; it
does not argue against a tag for a genuinely new transport.  AF_UNIX must not
inherit XPORT_UDP's paths, which read `sin_port`/`sin_addr` from a
`sockaddr_in` that an AF_UNIX caller never supplies.  So: new tag, and
`SOCK_HwIdx = SOCK_HW_NONE` from birth.

**The AF_UNIX arm must not call `_W5_SockAlloc` at all.**  Loopback allocates
a hardware socket and gives it back later via `_Loop_ReleaseHw` once bind or
connect proves it is loopback (apple/fgx#132) -- it has to, because it cannot
know at `socket()` time.  AF_UNIX knows at `socket()` time, from the domain
argument.  Taking and returning a W5100 slot would be strictly worse: there
are only three available (socket 0 is reserved for `/dev/bpf0` MACRAW), and
`syslogd` holds its socket for the life of the boot.

### 4.2 One framed receive ring per BOUND socket

Section 2(b) is the rule: the ring belongs to the receiver.

- A **bound** AF_UNIX socket (only `syslogd`, in practice) owns one pipe.s
  ring, reached through a new `SOCK_UnpRx` field.
- A **client** socket owns **no ring**.  It holds only its peer's descriptor
  index in `SOCK_UnpPeer`.  `send()` appends a record to the peer's ring.

This matters for the budget: `NPIPE EQU 8` (`include/kernel.s:809`) is the
whole machine's concurrent-pipe count, shared with real shell pipes.  A
per-connection design would have burned one slot per logging process --
`su`, `inetd`, `telnetd`, `reboot`, `cron` -- and starved the shell.  One
ring for `/dev/log` costs exactly one slot no matter how many clients log.

**Framing renders `sbappendaddr`.**  pipe.s gives a byte stream; a datagram
socket must preserve record boundaries, so each record carries a header:

    +0  2 B  payload length (bytes, host order)
    +2  1 B  sender name length (0 for sun_noname)
    +3  n B  sender name, if any
    +3+n     payload

`send` writes the header and the payload as two `_Pipe_WriteAt` calls, after
proving space for BOTH; `recv` reads the header, then exactly `len` bytes, and
fills `from` from the name field.  Upstream stores a fixed 16-byte
`struct sockaddr` here instead; a length is carried because nothing binds an
AF_UNIX socket until `unp_bind`, so that field would be a constant
(`sun_noname`) in every record -- and a fixed form costs 16 bytes of a 512-byte
ring plus a 16-byte staging buffer in the ratcheted core bank to say it.  What
`recvfrom` hands back is upstream's answer either way.
A datagram that does not fit the ring's free space is **dropped whole** with
ENOBUFS, never truncated -- which is `sbappendaddr` returning 0 and
`PRU_SEND` setting ENOBUFS.  A truncating write would split one message
across two records and corrupt every later boundary.

`PIPE_BUFSZ` is 512 initial and grows to `PIPE_MAX_BUFSZ` 4096; a syslog
line is bounded by the 1024-byte `MAXLINE` syslogd uses, so the grown ring
holds several.

### 4.3 The name in the filesystem

`bind()`, AF_UNIX arm, following `unp_bind`:

1. `namei(CREATE | FOLLOW | LOCKPARENT)` on `sun_path`.
2. If the node exists: EADDRINUSE (upstream's comment marks adopt-and-wakeup
   as a FIFO-style improvement it did not make; neither do we).
3. `VOP_CREATE` with `va_type = VSOCK`, `va_mode = 0777`.  This needs
   `ufs_create`/`ufs_makeinode` to accept `VSOCK` and write `IFSOCK` into
   the mode -- today the create path only ever sees `VREG`.
4. Record the descriptor index on the vnode (`v_socket`'s role upstream) so
   `connect` can find it from the path.

`connect()`, following `unp_connect`:

1. `namei(LOOKUP | FOLLOW | LOCKLEAF)`.
2. `vp->v_type != VSOCK` -> ENOTSOCK.
3. `VOP_ACCESS(vp, VWRITE)` -> EACCES.  FGX is not a secure platform, but
   BSD permission checks still port, and `syslogd` chmods `/dev/log` 0666 on
   purpose.
4. Peer descriptor index into `SOCK_UnpPeer`.

An unlinked-but-open `/dev/log` and a stale node across reboot both behave
as upstream: `syslogd` does `(void) unlink(LogName)` before binding.

### 4.4 libc

Restore the upstream body of `syslog(3)` now that there is a socket to send
to, including the `#ifdef pdp11` fallback, which is upstream 2.11BSD's own
socketless path and becomes FGX's belt-and-braces: if `/dev/log` is not
there yet (single-user, or before `syslogd` starts), append to
`/usr/adm/messages`; if that fails and LOG_CONS is set, `/dev/console`.
Provenance: `examples/2.11BSD/usr/lib/libc/gen/syslog.c`, sccsid 8.4.3
1995/07/15.

Plus `strftime`, `setlogmask`, `vsyslog`, the missing `LOG_*` macros, and
either `writev` or two `write`s for LOG_PERROR.

### 4.5 /dev/klog and syslogd

`/dev/klog` is a read-only chardev view of the 4 KB kernel ring
(`KMEM_LOGBUF_SIZE $1000`, `include/memmap.s:641`), registered through the
existing chardev framework with a `CDF_FIXED` number in
`include/devnodes.s` -- which is generated by `tools/ninja/gen.py`, so the
number goes in that script's DEV_NODES list, not in the generated file.
Counterpart: `vendor/2.11BSD/usr/sys/sys/subr_log.c` (366 lines, already
vendored).  `SYS_DMESG` stays exactly as it is; `dmesg(1)` does not change.

`syslogd` then ports close to verbatim from
`examples/2.11BSD/usr/usr.sbin/syslogd/syslogd.c` (1102 lines), plus
`/etc/syslog.conf` and `logger(1)`
(`examples/2.11BSD/usr/ucb/logger.c`, 218 lines).  It needs the four missing
libc calls in section 3.  Wall-clock timestamps want the `feat/kernel-clock`
work, which is sub-project 1 of the Kerberos order and in flight; until it
lands the timestamps are boot-relative, which is a visible but harmless
wrongness in `/usr/adm/messages`.

The boot module and daemon list is `/etc/rc.in`, NOT `modload.conf` -- a
daemon added to the wrong file never starts and logs nothing.

## 5. Increments

Each one ends green on `tools/gate.sh` and leaves a probe with a positive
control: a known-bad input the probe must call bad, so a check whose tool
did not run cannot read as a pass.

1. **XPORT_UNIX, unnamed.**  `socket(AF_UNIX, SOCK_DGRAM, 0)` succeeds and
   costs no W5100 slot; a manually paired sender/receiver moves framed
   datagrams through one ring.  Probe: N records in, N records out, boundaries
   intact; positive control: an oversized record must be refused ENOBUFS and
   must not corrupt the next read.
2. **Names.**  `unp_bind` via `VOP_CREATE`+`VSOCK`, `unp_connect` via
   `namei`, `VSOCK` through `ufs_makeinode`.  `/dev/log` is a real bound
   node; `ls -l /dev/log` shows `s`.  Positive control: `connect` to a
   regular file must return ENOTSOCK.
3. **libc.**  Upstream `syslog.c` body, `strftime`, the missing macros.
   `su` on ttyv2 now lands in one deterministic place.  This increment is
   where the reported symptom dies.
4. **/dev/klog.**  Read-only ring view.  Positive control: a reader at EOF
   must block rather than spin, and must not see the ring's pre-wrap bytes
   twice.
5. **syslogd + syslog.conf + logger.**  Routing, and the kernel/user merge.

Increments 1-3 fix the complaint; 4-5 buy the routing.

## 6. Budgets to measure, not assert

- **Bank-0 residency.**  The transport bodies live in `net.mod`, but the
  `_unp*` scratch and table pointer follow the `_sock*`/`_loop*` precedent
  of staying in the core bank, because `_Net_Dispatch` clobbers A on the way
  in and nothing may be passed in a register.  That is a real core-bank cost
  against the residency ratchet and must be reported as a measured number
  per increment, not estimated here.
- **`SOCK_REC_SIZE`.**  Adding `SOCK_UnpRx` and `SOCK_UnpPeer` grows the
  record from 12.  `include/socket.s` notes the 8 -> 12 growth was free
  because the constant has exactly two users, both stride adds; confirm that
  is still true rather than assuming it.
- **`NPIPE 8`.**  One slot for `/dev/log`.  Confirm by counting live pipes
  with `syslogd` running plus a shell pipeline.
- **Gate seconds ratchet.**  `gate_budget.py` has zero headroom: each new
  gate test means retiring one.  Name the retiree in the same commit.

## 7. Divergences to state in BUGS, not leave to be found

- **No SOCK_STREAM.**  `socket(AF_UNIX, SOCK_STREAM, 0)` returns EPROTOTYPE.
  Upstream's SOCK_STREAM AF_UNIX is what `pipe(2)` is built from; FGX has
  real pipes (`DTYPE_PIPE`, 2.11BSD's) and does not need it.  The maintainer scoped
  this out deliberately.
- **No access rights / SCM_RIGHTS.**  `unp_internalize`/`unp_externalize`
  and fd passing are not ported.  `syslogd` does not use them.
- **No `sun_noname` sender names in practice.**  `syslog(3)` never binds, so
  every record carries a zero-length name and `recvfrom`'s `from` is a
  zero-length `sockaddr_un`.  The name field exists so a future named sender
  needs no format change.
- **Ring, not mbuf chain.**  A datagram too large for the ring's free space
  is dropped whole with ENOBUFS.  Upstream's `sbappendaddr` fails the same
  way when the sockbuf is full, but upstream's ceiling is `sb_hiwat` against
  an mbuf pool, and FGX's is a 4 KB grown ring.

## 8. Provenance rows required

`docs/PROVENANCE.md` needs a row per ported file, and
`tools/check_provenance.py` fails the build without one:

| FGX file | Upstream |
|---|---|
| the AF_UNIX transport | `examples/4.3BSD-Reno/kern/uipc_usrreq.c` |
| bind/connect VFS arms | `examples/4.3BSD-Reno/kern/uipc_usrreq.c` (`unp_bind`, `unp_connect`) |
| `toolchain/lib/libc_c/syslog.c` | `examples/2.11BSD/usr/lib/libc/gen/syslog.c` |
| `/dev/klog` chardev | `vendor/2.11BSD/usr/sys/sys/subr_log.c` |
| `syslogd` | `examples/2.11BSD/usr/usr.sbin/syslogd/syslogd.c` |
| `logger(1)` | `examples/2.11BSD/usr/ucb/logger.c` |
| `/etc/syslog.conf` | `examples/2.11BSD/usr/etc/syslog.conf` |

Everything taken from gitignored `examples/` is vendored into `vendor/` in
the same commit.

## 9. Not verified

- **K&R.**  No fcc change is in scope yet.  `strftime` is new libc C, not a
  compiler change, so Appendix A does not govern it -- but if `strftime` or
  the framing header turns up an fcc reject, the toolchain fix comes first
  and the deciding sentence of Appendix A gets quoted in that commit.
- **`__progname`.**  Upstream defaults `LogTag` to it from crt0.  Whether
  FGX's crt0 provides one is unchecked; if not, `openlog(NULL, ...)` needs a
  defined behaviour and that is an increment-3 question.
- **`v_socket` equivalent.**  The design says "record the descriptor index
  on the vnode".  Which field, and whether FGX's vnode has spare room, is
  unchecked and is the first thing increment 2 must establish.

## 10. Increment 5's base, measured (added 2026-09-21)

Section 4.5 names `examples/2.11BSD/usr/usr.sbin/syslogd/syslogd.c` as the
upstream.  That holds, and this section records the measurement that confirms
it, because the cheaper-looking alternative is wrong for a reason that is not
obvious and would otherwise be rediscovered.

Censused by call, all three vendored trees:

| call | 2.11BSD (1102 ln) | Reno (1104 ln) | netbsd-0-9 (1122 ln) |
|---|---|---|---|
| `sigaction` | 6 | -- | -- |
| `sigprocmask` | 4 | -- | -- |
| `setitimer` | 1 | -- | -- |
| `daemon` | 1 | 1 | 1 |
| `writev` | 3 | 1 | 1 |
| `select` / `recvfrom` / `getservbyname` / `wait3` / `fsync` / `ctime` | yes | yes | yes |

2.11BSD's 1999 revision is the only one that uses `sigaction` and
`setitimer`.  Reno and netbsd install every handler with `signal()` and run the
mark timer as `alarm(TIMERINTVL)` re-armed at the end of `domark()`
(`examples/4.3BSD-Reno/usr.sbin/syslogd/syslogd.c:231-232` and `:767-788`).  So
Reno's syslogd would compile against FGX's libc today and 2.11BSD's needs two
syscalls that do not exist.

**Reno is still the wrong base, and its own main loop says why.**  It declares

    int nfds, readfds = FDMASK(funix) | inetm | klogm;
    nfds = select(20, (fd_set *) &readfds, ...);       /* syslogd.c:289-294 */

`int` is 16 bits here and `fd_set` is `struct fd_set { long fds_bits[1]; }`
(`toolchain/include/sys/types.h:62`), so the kernel would read 32 bits out of a
16-bit object.  That is exactly the silent-truncation class the
2.11BSD-preferred port rule exists to avoid, and 2.11BSD declares the same
variable `u_long readfds` precisely because it was written for a 16-bit-int
machine.  This is the first time that rule's stated rationale has turned up
inside the file being ported rather than in the abstract.

Taking Reno's `signal()`/`alarm()` shape into a 2.11BSD body was considered and
rejected: a BSD-source rewrite to dodge a missing toolchain feature is the one
thing `CLAUDE.md`'s toolchain-first rule names outright, and `sigaction` was
already planned work rather than a surprise.

### What increment 5 still needs

**UPDATED 2026-09-21 (later the same day): `setitimer(2)` LANDED.**  It is far
slot 76, seconds in and remaining ticks out, with a 64-byte 16-bit reload table
in KGlobals that fits the 87 bytes measured above because halving the width
halved the table.  The blocker recorded below was real but the reasoning under
"the far bank is not the escape" was wrong, and the correction sits with it.
ITIMER_VIRTUAL/PROF and a non-NULL `oitv` are refused rather than faked, and the
interval stops at 1023 s -- all three stated in BUGS terms in the commit.

**AND IT FOUND apple/fgx#475**, which mattered more than the timer: joining
syscall 102 and 120 into one routine in MR !365 gave #102 a `how` argument it
never had, so crt0's signal trampoline -- which lifts a handler's self-block
through #102 and had no reason to set Y -- sent garbage, got EINVAL, and never
lifted the block.  One SIGALRM, one SIGINT, one SIGCHLD per process, ever, across
merged main.  The probe's `alarm(2)` control is what separated that from the new
call; `setitimer`'s own repeat was unverifiable until it was fixed.

So what remains of increment 5 is `sigaction(2)` and then syslogd itself.

Landed 2026-09-21: the `syslog 514/udp` line in `/etc/services` (without it
`getservbyname` could only return NULL and syslogd `die()`s at startup), and
`readv`/`writev` plus `daemon(3)` in libc.

Remaining, in order:

1. **`setitimer(2)`, ITIMER_REAL only.**  Much smaller than it looks.
   2.11BSD's ITIMER_REAL is WHOLE SECONDS -- `setitimer` stores
   `it_value = aitv.it_value.tv_sec` and only increments it when any `tv_usec`
   is set (`vendor/2.11BSD/usr/sys/sys/kern_time.c:215-223`) -- and the entire
   timer engine is three lines of the once-per-second loop:

       if (p->p_realtimer.it_value && !--p->p_realtimer.it_value) {
               psignal(p, SIGALRM);
               p->p_realtimer.it_value = p->p_realtimer.it_interval;
       }
                       -- vendor/2.11BSD/usr/sys/sys/kern_synch.c:48-51

   FGX already has that countdown: `_kAlarmTicks` (`include/memmap.s:908`,
   NPROC x 4 bytes, ticks = seconds * 60), decremented by
   `_Sys_AlarmTickAll` (`src/kernel/signal.s:1844`), which is where the reload
   belongs because that is where upstream puts it.  What is missing is a
   per-task reload value and the syscall.  The reload is copied
   UNCONDITIONALLY, as upstream copies it: a zero interval reloads zero and
   stays the one-shot `alarm(2)` already is.
   **MEASURED 2026-09-21: IT DOES NOT FIT, AND THAT IS THE BLOCKER.**  The
   obvious home for the reload is a second `DS 128` beside `_kAlarmTicks` in the
   kernel-bank data region, and `memmap.s`'s `ERR KMem_KGlobals_end-1/$02FE00`
   refuses it.  Bisected by assembling: **87 bytes of headroom**, and a table
   indexed by `pid - 1` with NPROC 32 needs 128.  Sizing it for 16 tasks would
   fit and is exactly the `_ttyRowOff` defect (a table indexed by a count needs
   the count's rows), so it is not available.

   The core bank cannot absorb the code either.  Counted against the 51 free
   bytes: the re-arm in `_Sys_AlarmTickAll` (~12), `alarm(2)` zeroing the reload
   (~8, which BSD requires -- `alarm(3)` is `timerclear(&it_interval)` plus
   setitimer, `examples/2.11BSD/usr/lib/libc/gen/alarm.c`), the `Task_Alloc`
   scrub for apple/fgx#474 (~16), and the syscall arm itself (~45 with the
   seconds-to-ticks math, or ~33 as a core store shim with the math in the far
   bank).  That is 70-80 bytes wanted against 51.

   **CORRECTED 2026-09-21, same day: THE FAR BANK IS THE ESCAPE, and the
   paragraph that stood here was wrong.**  It said far-bank code cannot write a
   kernel-bank global, citing `tools/gen_kernel_exports.py`'s warning that its
   `abs24` exports bake the `$02` assembly ORG rather than the relocated kernel
   bank.  That warning is about a MODULE doing `JSL` into relocated kernel
   CODE.  Far-bank data access has its own mechanism and 62 sites already using
   it: a `_cfpNNN`-marked `STAL`/`LDAL` of the memmap symbol, whose bank byte
   `Far_BankInit` rewrites to the live core bank at boot
   (`tools/gen_far_bankpatch.py`, direction `far`; `docs/history/plans/far-kernel-bank.md`
   2.4).  Two of them, verified:

       _cfp472         STAL    _frnDstOff          ; src/kernel/far/loader.s:276
       _cfp991         STAL    _ldPileCorePath,X   ; src/kernel/far/loader.s:352

   `_frnDstOff` is `include/memmap.s:1137`, an ordinary kernel-bank global, and
   `src/kernel/far/far.s:44` PUTs `memmap.s`, so `_kAlarmTicks` resolves in the
   far bank with no export row at all.

   So the CODE cost collapses: a far-bank `setitimer` costs the core bank a
   5-byte thunk, a 2-byte `_FarPatchTbl` row and a 2-byte `_Syscall_Table` row
   -- **9 to 11 bytes, inside the 24 free today.**

   WHAT REMAINS IS THE DATA, and the 87 bytes still bind: the reload table is
   128 bytes of KGlobals whichever bank the code sits in.  The open question for
   the next attempt is whether the table itself can live in the FAR bank's data
   (1,411 free) with the heartbeat reaching it through a patched `LDAL` in the
   `core` direction -- which is the same mechanism pointing the other way, and
   is unverified.

   So the next attempt starts by finding core-bank and KGlobals room, or by
   moving BOTH the counter and the reload into the Kmalloc'd signal block --
   which the heartbeat cannot reach (`include/memmap.s:796`), so the whole
   countdown would have to move out of the heartbeat into `_Sig_AlarmDeliver`'s
   scheduler context.  That is a bigger change than the timer, and it would
   re-arm at the next switch rather than at the expiry instant, which is a drift
   of at most one switch per period and irrelevant to a MARK timer but is a
   divergence to state.

   Two more things to settle: `fork` must NOT inherit the timer, which is
   `kern_fork.c:165` (`rpp->p_realtimer.it_value = 0`) and wants checking
   against FGX's fork; and ITIMER_VIRTUAL/ITIMER_PROF are EINVAL while
   `getitimer(2)` is not ported -- both belong in BUGS.  The `oitv` old-value
   report is free on the value side, since the arm reads `_kAlarmTicks` before
   overwriting it and A + Y already carry a 32-bit return.
2. **`sigaction(2)`.**  Six sites, and all six install a handler, which
   `signal()` already does -- but `sa_mask` (block a set DURING the handler)
   and `SA_NOCLDSTOP` are real fields of what upstream asks for, and FGX's
   syscall-restart story is its own question.  Note that syslogd's `logmsg()`
   already brackets its critical section with `sigprocmask(SIG_BLOCK,
   &block_set)`, which FGX now has, so in THIS program `sa_mask` is a second
   layer over a guard that is already there.
3. **syslogd + `/etc/syslog.conf` + `logger(1)`.**  `writev` has no consumer
   until this lands: syslogd's `logmsg()` writes every line as a six-entry
   vector, so its output file IS the writev assertion, with wrong bytes or
   wrong order as the positive control.
