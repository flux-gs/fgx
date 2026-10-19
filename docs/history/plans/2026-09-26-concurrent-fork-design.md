# Concurrent fork -- design

- **Status:** implemented on feat/494-concurrent-fork, 2026-09-26; designed
  with the maintainer and reviewed by Fable the same day.  Implements apple/fgx#494.
  Departures from this text are in section 3.1 (As built) and in the plan's
  "Done (as built)" notes.
- **Goal:** after `fork(2)`, the parent and the child both run, whether or not
  the child execs.  daemon(3) gets 2.11BSD's fork back, /etc/rc starts daemons
  without `&`, and `( ... ) &` subshells run beside their shell.
- **Not the goal:** copy-on-write, a relocating fork, or any change to
  `vfork(2)`, whose contract is a suspended parent.

## 1. Where things stand

- **Fork is a deferred-parent snapshot.**  `_Sys_Fork` (`src/kernel/process.s`,
  `_vf_common`) copies the parent's mutable banks, live stack extent and direct
  page to spare banks (`_Fork_Snapshot`), runs the child IN PLACE at the
  parent's addresses, and sleeps the parent on `WCHAN_VFORK` until the child
  execs or exits, when `_Fork_Restore` copies the parent back.  A child that
  does neither (a daemon, a subshell) never lets its parent run, which is why
  daemon(3) does not fork (`toolchain/lib/libc_c/daemon.c`) and /etc/rc
  backgrounds every daemon.
- **An image cannot move.**  There is no MMU: fcc code and heap data hold
  absolute bank bytes and bank-0 stack addresses, so an image runs only at the
  addresses it was loaded at.  Two images at one set of addresses means one is
  resident and the rest are parked -- "every byte returns to the address it
  left" (`docs/history/plans/b3-stack-swap-scope.md` section 1).
- **Bank 0 already works this way.**  The user-image cache (`Uimg_*`,
  `src/kernel/task.s`; `docs/history/plans/2026-09-17-bank0-residency-
  architecture.md` 5.2) parks and restores each task's stack range and direct
  page at the same address, from `Uimg_Ensure` in `swtch`.  Fork children are
  exempt: `_Uimg_Held` says a child holds its bytes and `_Uimg_Walk` skips it
  (`task.s:3105-3106`), because today it borrows its parent's.
- **2.11BSD's shape.**  `newproc` (`vendor/2.11BSD/usr/sys/sys/kern_fork.c`,
  around line 250): "If there is not enough core for the new process, swap out
  the current process to generate the copy" -- the child is created as a
  swapped copy and both run, swapped in as each is scheduled.  On FGX the
  addresses are always occupied by the other image, so this is the only path.

## 2. Image groups and ownership

- **An image group** is every task sharing one user image: the fork-time bank
  set (the data bank, the soft-frame bank, the parent's pid-owned big-block
  banks) and the stack range with its direct page at the same addresses.  A
  snapshot fork creates or joins one.  Code banks and the refcounted libc bank
  are read-only and untouched.
- **One member owns the image**: it holds the bank list, the stack
  reservation, the soft bank and the big-block rows, as a parent does today.
  The others hold nothing, as a fork child does today (`process.s:606-610`).
  Membership is a per-pid kernel array, `_imgOwner` (owner pid, 0 = none): the
  scheduler entry is padded to 32 bytes and cannot grow.
- **One member is resident**: its bytes are at the real addresses.  Every other
  member has a home -- a bank home (spare banks for the bank set) and a Uimg
  home (stack range and direct page).  The parent's bank home is the fork
  snapshot's spares; a child's is allocated at release (section 3).
- **vfork is unchanged.**  Its child borrows and its parent is suspended; the
  borrower exemptions in the Uimg walk remain for `SEF_VFORKCHILD` only.
  Snapshot children become ordinary claimants of the range.

## 3. When the parent runs, and how members swap

**Release.**  The parent still sleeps on `WCHAN_VFORK` at fork.  The child is
RELEASED the first time it sleeps interruptibly (`_sleep`, not `_sleepUn`) or
yields its quantum at the syscall boundary.  Release first allocates the
child's homes; on success the child is marked released and `WCHAN_VFORK` is
woken, and on failure the child is simply not released -- the parent waits as
it does today, so fork never fails mid-run for want of swap.  The parent's wake
predicate gains "child released"; the parent returns the child's pid.

Why interruptible: exec's disk reads sleep through `kc_sleep` ->
`_FarSh_SleepUn` (`src/kernel/far/kc_sys.s:90-99`), so a fork-then-exec child
never releases and the shell's hot path stays at today's two image copies.  A
READY parent at fork would be swapped in while the child waited on the disk
(`Uimg_Evictable` treats any blocked task as freely parkable,
`task.s:3041-3043`) and cost two more copies per command (Fable).

**Swap.**  `Uimg_CanRun` and `Uimg_Ensure` become group-aware:
- A non-resident member can run only if the group's resident member is
  evictable -- not running, not `SEF_STKLOCK`, past the 12-tick dwell if READY.
  Otherwise `pick_next` passes it over, as it does for stacks today.
- Park the resident: its bank set to its bank home, its stack extent
  `[S, top]` and direct page to its Uimg home.  Restore the chosen member from
  its homes.
- Extents are recomputed at every park from the parked member's own state: the
  stack from its saved S, the soft bank from `_fcc_sfp` in its direct page
  (read before the page is copied), the data bank as `[0, HEAP_BRK)` plus the
  allocator's cells at `$FFFA-$FFFF` (`include/kernel.s`, HEAP_BASE..HEAP_BRK).
  The data-segment bound the snapshot rejects (`process.s`, pair 0's comment,
  apple/fgx#372) is a different bound: the heap is the tail of the bank, and
  the break covers it.
- **What lives in `[HEAP_BRK, $FFFA)`** (checked): nothing, with one
  exception.  libc malloc grows only by sbrk, and large requests go to
  `SYS_MALLOC32` big blocks (`toolchain/lib/libc_c/malloc.c:1-30`).  The
  loader writes only the three cells (`far/loader.s:1621-1661`).  Soft frames
  live in their own bank, and a failed grant leaves a zero bank that traps
  (`toolchain/lib/crt0_far.s:130-150`).  tcsh, elvis and the direct sbrk
  users (fsck, mount, telnet, fstab) write only what sbrk or malloc returned.
  **The exception is bsh.**  `locstak()` promises `brkincr` bytes of headroom
  (`vendor/2.11BSD/usr/bin/sh/stak.c:36-60`), but the `pushstak` loops in
  `macro.c` are unbounded:
  - `copyto` (:28);
  - identifiers (:76);
  - `$var` expansion (:120, :123);
  - the backquote body (:181).

  So a value longer than the headroom is written past the break.  2.11BSD
  grows the break from the MEMF fault (`fault.c:29-30`); FGX has no write
  fault, so the stores are silent.  apple/fgx#16 guarded `word.c` and
  `blok.c` but not these sites.  They are guarded before Task 3 bounds the
  copy by the break.
- The fork-time snapshot descriptor keeps only the bank pairs; its stack and
  direct-page tail is replaced by the Uimg home, which is sized for the whole
  reservation -- the descriptor is sized for the fork-time extent and cannot
  hold a deeper later park (Fable).

**No eager restore.**  When a resident member exits or execs, the group has no
resident image and the next member picked is restored lazily.
`_Fork_Restore` no longer writes the parent back from the child's context.

**Post-fork big blocks** are keyed to the allocating pid and private to it, so
only the fork-time bank set is ever swapped.

### 3.1 As built (Task 5)

- **N-1 bank homes, not N.**  The member with `SE_SnapPtr = 0` HOLDS the
  live banks; every other member has a bank home.  Fork makes one home and
  the parent parks into it; the child holds the live banks.  When a homed
  member is restored, its home and the live banks EXCHANGE a word at a time
  (`_Img_Xchg`, about 20 cycles a byte against 14 for two block moves) and
  the home passes to the previous holder (`Img_Swap`, from `_Uimg_Restore`).
  Nothing is allocated or freed in `swtch`.  A holder that leaves hands the
  live banks to a homed member, whose home then goes (`_Img_Leave`).  A home
  per member made at fork cost two spare banks per fork and ran manyproc,
  which is calibrated at the block-table ceiling, into `too big`.
- **Release at an interruptible sleep only.**  The quantum is one
  free-running countdown (`toolbox.s`, `QUANTUM_TICKS`), so a release at the
  quantum yield would fire for almost every child before its exec.  A child
  that computes without sleeping keeps its parent waiting, as before.
- **Exec does not sleep on FGX.**  SmartPort reads are synchronous, so the
  fork-then-exec path reaches neither `_sleepUn` nor a quantum yield; that,
  not the `_sleepUn` rule, is what keeps it at two image copies.

## 4. Exit and exec

- **The owner exits while members live** (the daemon path).  Before anything is
  freed, ownership passes to an heir -- the resident member if there is one:
  the bank list (copied to the heir's TCB and cleared in the exiting one, so
  `_Task_FreeBanks` finds nothing), the stack reservation base and size, the
  soft bank, and the big-block rows (re-keyed to the heir, so
  `_BlkRow_FreeByOwner` finds none).  `_imgOwner` names the heir for every
  member.  The exiting task frees only its homes, kernel stack, u-area, file
  table and libc reference.  Without this the daemon parent's exit frees the
  child's image (Fable: `_Task_FreeBanks`, `Task_FreeStack`, the soft-bank
  `Bank_Free`, `_BlkRow_FreeByOwner`).
- **A non-owner exits:** its homes are freed and it leaves the group; a snapshot
  child's exit still wakes a parent on `WCHAN_VFORK`.
- **Exec:** the member hands off ownership if it is the owner, leaves the group,
  frees its homes, and loads into fresh banks as a snapshot child's exec does
  today.  A failed exec leaves it in the group untouched.
- **Dissolving:** with one member left, it owns everything, its homes are freed
  and its group entry is cleared.
- **Grandchildren** join the same group; the owner is unchanged and the new
  child runs first.  "One resident, the rest homed" covers any size.
- **Reaping:** a member leaves at exit, so a zombie holds no image.
- **Assertion:** a group with two owners, or with members and no owner, panics.

## 5. The lock rule and the survey

A parked member's banks hold another member's bytes, so a write into a task's
memory from outside that task's running context is a corruption.  The stack
swap settled this as "lock, do not audit" (`b3-stack-swap-scope.md` 3.3); the
rule extends to banks:

- `SEF_STKLOCK` covers the whole image (stack, direct page, bank set).  Any
  kernel path that keeps a pointer into a task's banks or stack across a sleep
  sets it for that window; `Uimg_Evictable` already refuses a locked task, and
  the existing sleep-while-locked panic stays the tripwire.
- **Survey** (first task of the plan), recorded here as a table when done:
  - safe by construction (Fable, and the B3 table `b3-stack-swap-scope.md`
    198-214): I/O copies, signal frames (pushed at syscall return in the
    target's own context, `_Sys_CheckSignal`), wait status, select masks,
    far-bank syscalls writing the caller bank in place -- all run in the owner's
    context after `Uimg_Ensure` restored it;
  - to check: interrupt-driven writes into user memory (serial, network,
    keyboard receive paths, SmartPort reads into a user buffer), and module or
    far-bank code writing through a saved caller bank and offset after the
    syscall slept;
  - removed by this design: `_Fork_Restore` from the child's context;
  - redirected: `SYS_PROCS` reads `dataBank:HEAP_HWM` directly
    (`include/kernel.s`, PI_HeapHwm), which for a parked member is the
    resident's cell; it reads through the home as `Task_StkHwm` does.
- A refused residency is logged with its cause, as `upin` logs a refused pick.

### 5.1 The survey (done)

Every sleep site was followed: 23 in assembly, plus 17 `kc_sleep` calls in the
vfs and tty C.  After each one the task that slept resumes and performs its
own copy.  `_Sys_CallerBank` is reloaded per task from `SE_CallerBank`
(`sched.s:249`, `:399`).  No interrupt handler and no block driver stores
through a user bank.

| Path | file:line | Touches | Context | Verdict |
|---|---|---|---|---|
| IRQ dispatch, heartbeat, keyboard ring, VBL | `sim.s:239,376-393,460-475`; `toolbox.s:313-903` | kernel statics, reserved bank-0 cells | interrupt | SAFE |
| tty input -> `ttyinput`, signal post | `toolbox.s:773`; `tty/kc_sys.s:33,701`; `signal.s:497` | clists, TCB pending bits | interrupt | SAFE |
| `serial_isr`, `_Uthernet2_ISR`, alarm tick | `modules/serial/serial.s:821,965`; `uthernet.s:299`; `signal.s:1759` | module rings, flags | interrupt | SAFE |
| **User sound IRQ** (`$E1002C`, ntpplay/ensoniqplay) | `userland/ntpplay/ntpplay_stubs.s:23`; `_Sys_SoundClaim` `syscall.s:5952` | `_docOwner`'s data bank | interrupt | **LOCK**: `Uimg_Evictable` refuses the `_docOwner` member while it holds the DOC |
| `SYS_SIM_INSTALL` handler | `sim.s:560`; callers `serial.s:191,238` only | the installer's bank | interrupt | SAFE today (modules only); a user caller would need the same LOCK |
| SmartPort read/write | `drivers/block/block.s:860-929,1400-1430` | `BLK_STAGE` / kernel arena, then MVN | caller, no sleep under `src/drivers` | SAFE |
| Socket, pipe, pty, klog, bpf, tty reads | `net_xport.s:1517,1744`; `net.s:1431`; `pipe.s:534,563,1006`; `pty.s:784,994,1196`; `klog.s:600`; `bpf.s:465-481`; `tty.c:1899,1961,2180` | kernel ring -> caller's uio | reader, after its own sleep | SAFE |
| `select` | `syscall.s:1418-1440` | argblk masks (bank saved across the sleep) | own | SAFE |
| `_waitpid_WriteStatus` | `process.s:3953-3972` | parent's data bank via `_curTask` | parent | SAFE |
| Signal frame push | `syscall.s` ~640-700 | own stack | own, syscall exit | SAFE |
| `_Sys_Brk` | `process.s:2089,2275` | own `HEAP_BRK`/`HEAP_HWM` | own | SAFE |
| **SYS_PROCS heap mark** | `syscall.s:5300-5308` | any task's `TCB_DataBank:HEAP_HWM` | `ps` | **REDIRECT** (`Img_DataHome`, Task 7) |
| **SYS_PROCS -> `Task_StkHwm`** | `syscall.s:5285` -> `task.s:2399,2445` | another task's bank-0 stack | `ps` | **REDIRECT**, as the Uimg home already is for a parked task; must hold for group members |
| `_Tas_ReportHwm` from `Task_FreeStack` | `task.s:2508,839` | the dying task's stack | own at exit | SAFE |
| `_Loader_StageArgs` | `main.s:1093`; `process.s:467,2486` | child's stack | parent | LOCK (existing `SEF_STKLOCK` window) |
| Writes through `Uimg_DPPtr` (soft-frame seed, floor, carve) | `process.s:1908,2012`; `task.s:797`; `main.s:1031` | a task's direct page | parent / exec | REDIRECT (already through the home when parked) |
| `_Fork_Snapshot` | `process.s:1381` | parent's own banks -> spares | parent | SAFE |
| **`_Fork_Restore`** | `process.s:1636`, from `:2555` (exec) and `:3111` (exit) | the PARENT's banks, stack, DP | the CHILD | **REMOVED** by section 3 (no eager restore) |
| Loader heap seed | `far/loader.s:1627-1661` | a fresh data bank before first run | spawner | SAFE |
| `_Exit_Core` frees | `process.s:3191-3210` | `SE_SoftBank`, owned banks | exiting task | covered by the hand-off, section 4 |

Carried rule: a sleeper that keeps a long pointer in shared scratch
(`_libcTmp2`, the apple/fgx#100 class) must save and restore it, as
`_Sock_PollIntr`, `_Pipe_PollIntr` and `select` do.  Today a stale bank
writes another task's bank; in a group it would silently hit the resident
member.  Syscall scratch saved across a sleep lives on the private per-pid
kernel stacks (`syscall.s:176-190`), outside the shared range.

## 6. daemon(3), /etc/rc, and the cost at boot

- **daemon(3)** takes 2.11BSD's `fork()` / parent `_exit(0)` back; FGX's detach
  delta (TIOCNOTTY through fds 0-2, `/dev/tty` having no driver) stays.  The
  "THE FORK IS NOT DONE" text leaves the source, BUGS and PROVENANCE.
- **/etc/rc** drops the `&` from update, inetd, syslogd and adjkerntz -i, as
  2.11BSD's and FreeBSD's rc have none; the BACKGROUNDED comments go.  The
  bounded wait for /var/run/syslog.pid stays: it prevents duplicate boot lines,
  not a hang.  syslogd(8) and adjkerntz(8) lose their `&` BUGS paragraphs; the
  sh and tcsh pages are checked for a stated subshell limitation.
- **Cost.**  A daemon's fork is four image copies: the snapshot, parking the
  child at release, restoring the parent, restoring the child after the
  parent's exit.  A whole data bank is about 165 ms at 2.8 MHz (block move,
  7 cycles a byte); with the `HEAP_BRK` bound a daemon's small heap makes each
  copy tens of milliseconds.  Boot frames to the first prompt are measured on
  MAME before and after and recorded with the image-copy count per daemon.

## 7. Testing

One probe, `forkpair`, with modes; each case red on today's kernel:

1. **Parent first:** the child `sleep(2)`s; the parent's marker appears before
   the child's (today: after).
2. **Own bytes across swaps:** after release both sides write distinct values
   to a global, a soft-frame local in a recursion and a stack local, alternate
   sleeps, and read back only their own.
3. **Owner exits first:** the parent `_exit`s after release; the child sleeps,
   then execs `/bin/echo` with a marker.  Today: hang.  Mutation (no ownership
   hand-off): double free or leak; the gate's bank-pairing check stays green.
4. **Hot path:** a kernel image-copy counter, read through `memory_regions`,
   shows `sh -c true` costs exactly 2.  Mutation (release on `_sleepUn`) must
   fail it.
5. **Three-way group:** parent, child and grandchild alternate, each checking
   its own bytes.
6. **daemon(3):** `daemontest` calls `daemon()`, sleeps, writes a marker file;
   the prompt returns at once and the marker appears later.  The boot tests
   reach the prompt with rc's `&` gone; syslogd's boot lines stay single.
7. **ps:** a parked member's `PI_HeapHwm` is its own, not the resident's.

The fork, vfork and soft-frame tests (fknest, fkiso, softfork, vfexec, vfexit,
bigforkx) and manyproc stay green, with the full suite.  The new cases go in the
MAME suite; the gate's seconds budget is not raised.

## 8. Risks, in order (Fable, 2026-09-26)

1. The owner's exit freeing the shared image (section 4).
2. The walk exemptions leaving an exec'ing child's range unpinned (section 2).
3. The hot path regressing through eviction of a blocked child (section 3).
4. A fork-time descriptor too small for a later park (section 3).
5. Two home mechanisms for one range -- the FSD tail and Uimg -- the "two
   roads" trap; this design keeps one (Uimg) for stack and direct page.
6. An eager restore from the child's context (section 3).
