# /dev/klog Implementation Plan -- syslog campaign increment 4

**Goal:** a read-only character device `/dev/klog` giving a blocking, cursored
view of the kernel log ring, so `syslogd` can merge kernel messages with the
user messages it reads from `/dev/log`.

**Source:** `vendor/2.11BSD/usr/sys/sys/subr_log.c` (2.1, 1999/4/29) -- vendored.
`logopen`, `logclose`, `logread`, `logselect`, `logioctl`.

**Parent design:** `docs/history/plans/2026-09-19-syslog-af-unix-design.md` §4.5.
That document's own plan says increments 4-5 get their own plan and must not be
started from it; this is increment 4 alone.  Increment 5 (`syslogd`, `logger(1)`,
`/etc/syslog.conf`) stays out: it needs `sigaction`, `sigprocmask`, `setitimer`,
`getservbyname` and `daemon(3)` first.

**`SYS_DMESG` and `dmesg(1)` do not change.**

## Rulings taken before starting (the maintainer, 2026-09-20)

1. **A new `klog.mod`.**  The core kernel bank has **5 bytes free** (56,683 of
   56,688), so the driver cannot be core-bank code.  A module costs no new
   core-bank dispatch code because the chardev registry already exists.
2. **A blocked reader sleeps on `WCHAN_LBOLT`**, woken once a second by
   `_Lbolt_Wake` (`src/kernel/sched.s:845`) from the clock.  Upstream is woken
   on the write; that needs ~13 core-bank bytes for a `logwakeup` equivalent and
   they do not exist.  **apple/fgx#461 is filed to evaluate the faithful form
   later**, at the maintainer's instruction.

## The contract, verified against the source rather than assumed

- **Registration**: `JSL MOD_REGISTERCHARDEV` (`MOD_JT_BASE+$62`) with
  A = name offset, X = ops offset (both in the module's own bank, so `PHK/PLB`
  first), Y.lo = minor, Y.hi = `CD_Flags`.  `CDF_FIXED $02` takes a specific
  index from bits 2-7; `CDF_RECORD $01` makes one `read(2)` one record
  (`include/chardev.s:129-135`).
- **The ops vtable is nine 3-byte slots in a locked order**: Open, Close, Getc,
  Putc, Ioctl, Poll, DRead, DWrite, Stop -- `COPS_SIZE` 27 bytes
  (`include/chardev.s:293-324`).  The read body goes in **`COPS_DRead`** -- see
  the finding below; `COPS_Getc` is reached only from the non-vnode road and here
  is a stub answering EIO, which is the kernel's own answer for a driver that
  cannot serve a road (and a zero slot would be a wild JSL, the dispatch not
  being bounds-checked).
- **On entry to any op, DBR = the KERNEL's bank, not the module's**
  (`include/chardev.s:191`), and D = the asm kernel direct page.  So kernel-bank
  statics are plain absolutes and `dpmap.s` cells are plain DP -- which is how
  `bpf_read` reads `_Sys_RdMax` and uses `_libcTmp2` in the same breath.  An op
  touching its OWN module statics must bracket `PHB / PHK / PLB ... PLB`.
- **The caller's buffer** comes from kernel-bank statics `_Sys_RdMax`,
  `_Sys_RdBufOff` and `_Sys_CallerBank`; the copy goes through a long pointer
  built in `_libcTmp2` and stored `[_libcTmp2],Y`.
- **Non-blocking arrives in X** as 0 or `VFS_IO_NDELAY` and must be saved
  immediately -- X does not survive a nested call, let alone a sleep.  It must
  NOT be re-read from `[_fcbPtr]` afterwards: that was apple/fgx#198, where the
  FCB pointer belonged to a different descriptor by the time a slept op looked
  again.
- **The sleep**: `LDX #KSVC_SLEEP / JSL SYS_KCALL` with A = channel.  Carry is
  always set ("service dispatched"); **the verdict is in A** -- 0 woken, 1 an
  actionable signal is pending, so return `EINTR` and do not re-wait
  (`src/kernel/jumptable.s`, apple/fgx#28).
- **`FIONBIO` has no generic kernel handling for a chardev.**  Only the module's
  own `COPS_Ioctl` can set `FCB_CDF_NONBLK` in the FCB, the way `_Pty_SetNB`
  does (`src/modules/pty/pty.s:1882`).

## The ring, and what a cursor over it means

Core-bank state, all of it already there:

| cell | where | meaning |
|---|---|---|
| `_kLogBufPtr` | DP `$B0`, 3 bytes | long pointer to the heap ring; **0 until `_AllocLogBuf` runs** |
| `_kernLogHead` | `include/memmap.s:657` | next-write index, wraps at `KMEM_LOGBUF_SIZE` ($1000) |
| `_kernLogWrap` | `include/memmap.s:658` | 1 once the ring has wrapped at least once |

There is **no read pointer and no monotonic byte count**, and the writer is not
reader-aware -- it cannot afford to be, which is the same 5-bytes-free fact that
decided the wakeup.  So the cursor lives in the module, and the valid window is
derived the way `_Sys_Dmesg` derives it:

```
oldest = wrapped ? head : 0
valid  = wrapped ? SIZE : head          ; bytes of history that exist
avail  = (head - rd) mod SIZE           ; bytes this reader has not taken
```

`rd == head` is EMPTY, which is upstream's own rule ("If the reader and writer
are equal then we have caught up and there is nothing more to transfer").

**A LAP CANNOT BE DETECTED, and an earlier draft of this plan was wrong to say it
could.**  `avail` is `(head - rd) mod SIZE`, which is always a legal value, and
`valid` is `SIZE` once the ring has wrapped -- so `avail > valid` can never hold
and a test on it would be a check that cannot fire.  With only a write index and a
one-shot wrapped flag there is nothing to compare against: a lapped reader simply
gets the newest `avail` bytes, in order, having lost what was in between.
Upstream counts that in `sc_overrun` because upstream's WRITER is the one that
discards; this writer cannot afford to know about readers, which is the same
five-bytes-free fact that decided the wakeup.  klog(4)'s BUGS says so, and a lap
needs 4 KB of kernel messages inside one wakeup period.

## Tasks

### Task 1: the module, registered and openable

**Files:** create `src/modules/klog/klog.s`, `src/modules/klog/klog.link.s`;
modify `tools/gen_modplace.py` (append `'klog'` to `ORDER` -- appending only,
inserting shifts the placement-absolute `w5100_patchsites.s` tables),
`tools/ninja/gen.py` (`MODULES`, `KEXPORTS`, and `MODULE_DEV_NODES += ("klog", 22)`),
`disk_src/etc/rc.in` and `disk_src/etc/modload.conf` (both, in the same relative
order -- `tools/check_modload_lists.py` fails the build if they disagree).

**`MODULE_DEV_NODES`, not `DEV_NODES`.**  The parent design says `DEV_NODES`;
that is stale.  `disk/fgxdev.po` is `mkfs --size 64` with sixteen inodes and
every one is spoken for -- "`fgxfs mknod: out of inodes` is what the last attempt
to add one said" (`tools/ninja/gen.py:296-320`) -- so module devices that arrived
after it filled go on the root's `/dev` only.  `include/devnodes.s` is GENERATED
and gets `DEVNODE_KLOG EQU 22` for free.

- Ops table: Open, Close, Getc(EIO stub), Putc(`ENOTSUP`), Ioctl, Poll, DRead(the
  read); DWrite and Stop zero.  Registered `CDF_FIXED | CDF_RECORD` at
  `DEVNODE_KLOG` -- `CDF_RECORD` is what stops the kernel falling back to a
  per-byte loop, which for a record driver is apple/fgx#198's silent half.
- `klog_open`: `ENXIO` when `_kLogBufPtr+2` is still 0 (no ring yet -- upstream's
  `ENOMEM` for an unallocated buffer); `EBUSY` when already open (upstream's
  single-reader rule); otherwise seed `rd = oldest` so the first reader gets the
  boot log, which is what upstream's `bufr = 0` gives it.
- `klog_close`: clear the open flag.  Note the kernel only calls Close on the
  LAST close (`CD_OpenCount`), matching BSD `closei`.
- **Step: register and prove the node exists.**  `ls -l /dev/klog` shows a
  character device; `cat /dev/klog` blocks rather than returning EOF.

### THE READ MUST BE `COPS_DRead`, NOT `COPS_Getc` -- measured, not assumed

The first working build got **EIO** on every read, and the reason rewrites this
task.  `/dev/klog` is a real node, so a read reaches `spec_chread`
(`src/kernel/vfs/spec_vnops.c:666`), which **always tries the bulk op first**:

```
r = kc_cddread((int)vp->v_rdev, uio, ioflag);
st = (r >> 8) & 0xFF;
if (st != 1) return (r & 0xFF);
```

and `_Chardev_Bulk` (`src/kernel/chardev.s:937-943`) answers a **record device
with no `d_read`** with EIO on purpose.  Its comment is the whole argument: status
1 means "run your own per-byte loop", and for a record driver that is
apple/fgx#198's silent half -- `bpf_read` fills from `_Sys_RdBufOff` /
`_Sys_RdMax` / `_Sys_CallerBank`, **syscall-layer singletons no vnode caller
sets**, so on the /dev route those name whatever the last `read(2)` named and the
copy lands in a stranger's buffer while reporting success.

So the `CDF_RECORD` + `COPS_Getc` shape that `bpf` and `pty` use is reachable
only from the non-vnode road, and a device whose node lives in `/dev` needs the
uio.  **Per-byte is not an alternative**: `spec_chread`'s loop runs until
`uio_resid` is zero, so a per-byte driver that blocks when caught up would make
`read(fd, buf, 4096)` wait for 4096 bytes, and one that answers EOF instead
cannot block at all.  "Block until SOME data, then return what there is" is
exactly what only a bulk op can say.

What remains for this task: the uio layout, and how a module moves bytes into a
uio -- `_FarSh_Uiomove` is the far shim `src/drivers/block/rawdisk.s` pile-calls,
and `KSVC_CDDREAD`'s arm is the road in.

### Task 2: the cursored, blocking read -- DONE, as `COPS_DRead`

Implemented as the bulk op per the finding above.  `uiomove` is reached the way
`_Pty_Uio1` reaches it: vfs.mod's bank and its uiomove address resolved once at
`mod_init` through `KSVC_FINDVTABLE`, then a pile call with ten argument bytes
pushed last-argument-first.  cp names the HEAP, not the kernel bank, because the
ring is Kmalloc'd and reached through `_kLogBufPtr`.

Upstream's loop is carried whole: wait once while reader == writer, then
`while (uio->uio_resid)` transferring runs and wrapping the cursor mid-loop
(`if (l == 0) msg_bufr = 0`).  `uio_resid` is re-read from the uio each pass
because uiomove is what decrements it, and it bounds every run -- uiomove clamps
to resid and DISCARDS the excess, which here would be log nobody could read
again.

No bounce buffer: upstream's `char buf[ctob(2)]` exists so a PDP-11 can map the
segment in, and this ring is contiguous, so the bytes go to uiomove where they
lie.

THE NON-BLOCKING FLAG COMES OFF THE STACK (`13,S`) AND IS NEVER CACHED, which is
what makes it safe across the sleep -- the stack is the task's own kernel stack.
That deleted the `_klogNb` cell the first cut had, and with it the whole
apple/fgx#206 parking question.

### Task 2b: what the probe found on the way

- **apple/fgx#462**, filed: `_Chardev_Open` increments `CD_OpenCount` before
  dispatching `COPS_Open` and does not decrement on refusal, so a refused open
  leaves the count high, the next `close(2)` is not the last, and the driver's
  close never runs.  Any refusing open has it, `bpf_open`'s EBUSY included.  The
  probe asks the EBUSY case LAST for that reason.
- **A write to the read-only device is refused above the driver.**  The
  descriptor is `O_RDONLY`, so the syscall layer answers EBADF before any chardev
  op runs, which is correct and is what BSD does.  `klog_write`'s ENOTSUP is the
  backstop for a writable descriptor.
- **alarm(2) did not interrupt the wait.**  The first shape of the blocking proof
  was a real blocking read interrupted by SIGALRM, asserting EINTR; the signal
  never arrived and the read ran to the harness frame cap.  `SYS_ALARM` exists
  (`include/loader.s:489`) and login.c says the port deleted upstream's alarm
  timeout because "FGX has no such subsystem".  Whether a sleeping task is
  interruptible by alarm generally is NOT established here.  The EINTR arm is
  written the way `_PtyM_DRead`'s is and matches sched.s's stated contract, but it
  is uncovered, and klog(4)'s BUGS says so.

### Task 2c: the blocking proof is select(2), bounded

- `klog_read` (in the `COPS_Getc` slot): save X immediately; compute
  `avail`/`valid`; resync on a lap; if `avail == 0` either return `EAGAIN` when
  `VFS_IO_NDELAY` is set or sleep on `WCHAN_LBOLT` and re-test; copy
  `min(avail, _Sys_RdMax, SIZE - rd)` bytes -- capping at the ring's end makes a
  wrapped read a SHORT read rather than two copies, which `read(2)` allows and
  which is what stops a pre-wrap byte being delivered twice; advance `rd`;
  return the count with C=1.
- `klog_poll`: readable iff `avail != 0`, mirroring `logselect`.
- `klog_ioctl`: `FIONBIO` only, setting/clearing `FCB_CDF_NONBLK` through
  `[_fcbPtr]` as `_Pty_SetNB` does -- safe there because an ioctl has not slept.
  Everything else `ENOTTY`.  **`FIONBIO` is implemented specifically so the
  NDELAY branch is reachable**: without a setter that branch could never be
  exercised, and untestable code is worse than absent code.

### Task 3: the probe, with its positive controls

**File:** create `src/userland/klogprobe/klogprobe.c`, and a manifest under
`tools/mame_test/tests/`.

The design names the control: *a reader at EOF must BLOCK rather than spin, and
must not see the ring's pre-wrap bytes twice.*  Assertions, each measured red at
least once:

1. `open("/dev/klog", O_RDONLY)` succeeds; a second open gets `EBUSY`.
2. A read after draining **blocks** -- proven by the elapsed tick count across
   it being at least one `lbolt` period, not by it returning 0.  A spin would
   return immediately; an EOF would return 0.
3. `FIONBIO` then read on a drained device gives `EAGAIN` immediately.
4. **No byte is delivered twice across the wrap.**  Write a known pattern into
   the ring (by logging through the kernel until it wraps), read the whole thing
   in short reads, and assert the byte sequence is monotonic in the pattern with
   no repeat of the pre-wrap tail.
5. A write to `/dev/klog` gets `ENOTSUP`.

### Task 4: man page and provenance

- `src/userland/man/pages/cat4/klog.0` -- pre-formatted cat page only, no
  `man[1-8]` source.  BUGS carries the two divergences: the **one-second wakeup
  latency** (apple/fgx#461) and the **silent loss when a reader is lapped**,
  where upstream counts an overrun in `sc_overrun`.
- `docs/PROVENANCE.md` row naming `vendor/2.11BSD/usr/sys/sys/subr_log.c`
  (`tools/check_provenance.py` fails the build without one).
- Drive-by: `include/memmap.s:657` still calls `_kernLogHead` "0..$06FF", which
  was true at `KMEM_LOGBUF_SIZE` 1792 and is not at $1000.

## Global constraints

- **ASCII only**, no em-dashes.
- **Comments describe the current state only** -- no "this used to be", no dated
  measurement transcripts.
- The **65816 assembly is written by the main agent, never delegated.**
- `include/devnodes.s`, `modplace.s` and `kernel_exports.s` are GENERATED; never
  hand-edit and never `git checkout` one.
- A new source file is not a build input until `gen.py` has re-run:
  `python3 tools/ninja/gen.py -o build.ninja`, then confirm it appears.
- Report the measured module size and the core/far/tty bank numbers per task;
  the baseline is kernel 5 free, far 1,628 free, tty 10,575 free.
- The gate ratchet has zero headroom: adding a gate test means taking one out.
  This probe does **not** join `GATE_TESTS` in this increment.
