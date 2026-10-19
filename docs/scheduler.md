# FGX Scheduler

> Source of truth: `src/kernel/{sched,task,process,signal,syscall}.s`,
> `src/kernel/toolbox.s` (heartbeat), `src/kernel/tty/tty.c` (the tty read
> path), `include/kernel.s` (structures) and `cfg/system.cfg` (sizes).  The
> BSD counterparts are `vendor/2.11BSD/usr/sys/sys/kern_synch.c` (sleep,
> wakeup, swtch) and `kern_sig.c`.  Where this doc and the code disagree, the
> code wins.

## Model: user code preempted, kernel code runs to completion

This is 2.11BSD's shape ("Model A"): a timer quantum preempts user code, and a
task inside the kernel runs until it blocks or returns.  The design record is
[history/plans/2026-07-17-preemption-campaign-roadmap.md](history/plans/2026-07-17-preemption-campaign-roadmap.md).

Every `QUANTUM_TICKS` (4) VBLs the heartbeat sets `_kYieldReq` and mirrors it to
the user-readable `KFGX_YIELD_MIRROR` (`$030A`).  The flag is a *request*,
honoured at two boundaries and never inside the kernel:

- **the syscall boundary** -- the dispatcher (`src/kernel/syscall.s`) yields on
  the way out when the flag is set;
- **fcc loop safepoints** -- `fcc` emits an inline test of the mirror at the
  top of every loop by default (`LDAL KFGX_YIELD_MIRROR / BEQ *+5 /
  JSR _fcc_safepoint`, `emit_safepoint()` in `toolchain/src/cc/emit.c`;
  `-fno-safepoints` disables it).  Only when the mirror is set does it call
  `_fcc_safepoint` (`toolchain/lib/fcc_runtime.s`), which makes `SYS_YIELD`.  This is what preempts a compute loop that makes no
  syscalls.

A C tool built with safepoints loses the CPU on a quantum even in a tight
loop; hand-written assembly that neither traps nor safepoints runs until it
blocks.  Kernel sequences are never preempted, which is what keeps the kernel's
non-reentrant state safe.

Blocking syscalls call `_sleep` (which calls `swtch`):

- **`waitpid` / `wait`** on a live child -- sleeps on the parent's own TCB
  offset as the channel.
- **terminal read** -- 2.11BSD `ttread` (tty bank, `src/kernel/tty/tty.c`)
  sleeps on the line's raw queue (`kc_sleepi(&tp->t_rawq)`) until the line
  discipline has input.  `SYS_GETKEY` (50) still reads the console key ring
  through `Con_GetKey`, sleeping on `WCHAN_KBD`.
- **socket `recv` / `connect` / `send`** -- `_Sock_PollIntr` sleeps on
  `WCHAN_SOCK`.
- **`nanosleep`** (`SYS_NANOSLEEP`, 83) -- sleeps on `WCHAN_TIMER` until its
  deadline.
- **`yield`** (`SYS_YIELD`, 79) -- voluntary; the task stays READY.
- a **job-control stop** (SIGTSTP/SIGTTIN/SIGTTOU) -- switches away in
  `TASK_STOPPED`.

Task selection (`pick_next`, `src/kernel/sched.s`) is a **two-pass scan** of
the TCB table: pass 1 finds the lowest `TCB_Priority` among READY tasks, pass 2
round-robins among the tasks at that priority starting after
`_schedLastSlot`.  Both passes skip a task whose user stack bytes are parked
and cannot be brought back right now (`Uimg_CanRun`).  There is no ready
queue, and nothing sets a nonzero priority (TCBs are zeroed at alloc, there is
no `setpriority`/`nice`, `vfork` copies the parent's 0), so selection is a flat
round-robin.

## Context switch (`swtch`)

`swtch` (`src/kernel/sched.s`) saves the outgoing task's kernel SP and resume
carryover, then runs on its own stack (`FGX_STK_SWITCH`, bottom-word
canaried) for everything that follows.  Per-task state lives in the
scheduler-state table (`SE_*`, reached via `[_schedTblPtr],Y`):

- **`SE_KernSP`** -- the saved kernel stack pointer, which lets a task block
  mid-syscall and later resume its kernel call chain.
- **`SE_UserSP` / `SE_UserDP` / `SE_CallerBank`** -- the dispatcher's
  user-resume carryover, so a blocked syscall's user context survives another
  task's syscall in between.

For the chosen task, `swtch`:

1. restores its user stack bytes if they are parked, parking whoever holds
   those addresses (`Uimg_Ensure`, `src/kernel/task.s`);
2. marks it `TASK_RUNNING`, restores the carryover and the kernel-C register
   file (`_KcDp_Rest`);
3. makes its kernel image resident in a slot (`_Slot_Ensure`, below);
4. switches `D` to the task's kernel page and `S` to its kernel SP, and `RTS`es
   into it.

The outgoing task's status (READY / BLOCKED / ZOMBIE / STOPPED) is set by the
caller before it calls `swtch`.  Before picking, `swtch` also polls the wake
sources (a key in the ring, the W5100 ISR's `_kSockWakePending`, expired
timers, alarms) so a busy background task does not starve a blocked one.

### Kernel stacks are slots

A task's kernel image -- its kernel direct page and its kernel stack -- lives
in one of `kernel.kslots` (7) **kernel-image slots** while it is inside the
kernel (`include/kernel.s`, `cfg/system.cfg`):

- slot *s* has a direct page at `FGX_KSLOT_DP + s*256` (`$D000`) and
  `kernel.kstk` (1024) bytes of stack at `FGX_STK_KTASKS + s*1024` (`$E000`),
  in the language-card RAM that stays mapped for the life of the system;
- `_Slot_Ensure` binds a slot when the scheduler picks the task and publishes
  the page and stack top for the dispatcher; a task keeps its slot while it
  sleeps;
- when every slot is held and another task needs one, a sleeper's page and the
  live part of its stack are parked in its home image (`FGX_KHOME_STRIDE`,
  2 KB per pid, in one bank) and restored when it next runs;
- each slot stack is painted and bottom-word canaried at boot, and the
  dispatcher checks the running task's canary at every syscall entry.

The slot count does not bound `NPROC`.  Boot runs on the top slot
(`FGX_STK_BOOT`) until the first task exists.  The addresses are derived by
`tools/ninja/genconfig.py` into `include/config.s` and checked by
`tools/check_bank0_geometry.py`.

**First run.** A freshly spawned task has never executed, so
`Task_PrimeKernStack` records `_Task_FirstRun-1` as its first-run frame; the
frame is written into the task's slot when one is bound (`_Slot_Seed`), so
the first `swtch` into it `RTS`es to `_Task_FirstRun`, which loads the child
DP/stack, `CLI`s, and `RTL`s into the child's user entry point.
`Task_PrimeKernStackAt` takes another target (the vfork child exits through
the syscall dispatcher instead).

## Tasks, states, tables

States (`include/kernel.s`):

```
TASK_UNUSED=0  TASK_READY=1  TASK_RUNNING=2  TASK_BLOCKED=3  TASK_ZOMBIE=4  TASK_STOPPED=5
```

`TASK_STOPPED` is the job-control stop; `pick_next` skips it until SIGCONT
flips it back to READY.

- **TCB table** -- at `FGX_TASK_TBL` (`$0800` in the core kernel bank),
  `NPROC` (`kernel.nproc` in `cfg/system.cfg`, currently **32**) slots x 64
  bytes.  **PID = slot index + 1** (PID 1 = init).  Managed by `Task_Alloc` /
  `Task_Free` / `Task_Lookup`; the field layout is authoritative in
  `include/kernel.s`.
- **Scheduler-state table** -- per-task bookkeeping that does not fit the TCB
  (`SE_KernSP`, u-area pointer, `SE_WaitChan`, `SE_PGroup`, `SE_Flags`, the
  user-resume carryover, `SE_WakeTime`), in a Kmalloc'd block reached via the
  `_schedTblPtr` DP long-pointer (`_AllocSchedTbl`).  Two more Kmalloc'd
  per-pid tables hold each task's cwd (`_cwdTblPtr`) and process name
  (`_procNameTblPtr`, which feeds `ps`).
- **User stack** -- each task's user stack is a reservation in the bank-0
  stack arena (`Task_AllocStack`); its first page is the task's user direct
  page.  When the arena has no free run, a request of at least
  `kernel.stkover` pages may be placed over other tasks' reservations, whose
  live bytes are parked and restored by `Uimg_Ensure` (`cfg/system.cfg`).

## Blocking and wakeup

These are 2.11BSD `sleep`/`wakeup` (`kern_synch.c`), with BSD's sleep
priority split into two entry points:

- **`_sleep(chan)`** -- `SEI`, record `SE_WaitChan = chan`, mark the caller
  `TASK_BLOCKED`, `swtch`; returns (CLI'd) when re-selected.  It returns
  **C=1** when a signal is actionable (checked before blocking and after
  waking), and the caller abandons the wait and returns `EINTR`.  This is
  BSD's interruptible sleep (`pri > PZERO`, which `kern_synch.c` emulates with
  `PCATCH` and a `longjmp`); FGX has no `longjmp` out of a sleep, so the
  caller unwinds.
- **`_sleepUn(chan)`** -- uninterruptible, BSD's `PRIBIO`, for waits with no
  error path (buffer locks in `vfs_bio`, exec's disk reads).
- **`_wakeup(chan)`** -- marks every `TASK_BLOCKED` task whose
  `SE_WaitChan == chan` READY, as BSD's `wakeup` does.  It does not switch,
  masks interrupts across its scan, and is safe to call from an ISR.

Kernel C (the tty bank, vfs.mod) sleeps on addresses, as BSD does.  The fixed
channels (`include/kernel.s`): `WCHAN_KBD` (`$FF01`), `WCHAN_SOCK` (`$FF02`),
`WCHAN_TIMER` (`$FF03`, woken by `_Timer_WakeExpired`), `WCHAN_PIPE`
(`$FF04`), `WCHAN_SELECT` (`$FF05`), `WCHAN_VFORK` (`$FF06`), `WCHAN_PTY`
(`$FF07`), `WCHAN_PAUSE` (`$FF08`, sigsuspend/sigpause), `WCHAN_LBOLT`
(`$FF09`, the once-a-second retry wake) and `WCHAN_LD` (`$FF0A`, ld.mod).

**Idle.** When `pick_next` finds nothing READY, `swtch` idles on its switch
stack (`CLI / WAI / SEI`) until the next IRQ, then drains deferred tty output,
pending VC switches and the lbolt wake, wakes socket/select/timer sleepers,
and re-picks.  There is no busy-spin and no PID 0 task.

## The heartbeat (requests a resched; never switches)

The 60 Hz heartbeat is a firmware VBL Toolbox task (`_HBTickTask`, installed by
`Toolbox_InstallHB`; `src/kernel/toolbox.s`).  Each VBL it bumps the 32-bit
`_kSystemTicks`; decrements `_kQuantum` and every `QUANTUM_TICKS` raises
`_kYieldReq` + `KFGX_YIELD_MIRROR`; reads the key latch and hands each key to
2.11BSD `ttyinput` in the tty bank at interrupt time (`_Tty_IrqInput`), then
to the 16-entry `_kKbdRing`; and runs `_Sys_AlarmTickAll` (per-task alarm
countdowns, SIGALRM).

`ttyinput` does the `^C` / `^Z` / `^\` recognition against the line's own
special characters (`t_intrc`, `t_suspc`, ...) and posts the signal to the
foreground group directly (`kc_gsignal` swaps to the kernel's direct page
before calling `_Kill_GroupFanout`).  There is no deferred signal word.

The heartbeat never calls `swtch` or `pick_next`; a key arriving raises the
same yield request as quantum expiry.

## Job control (BSD-shaped)

- **`setpgid`** / **`getpgrp`** (`SYS_SETPGID` / `SYS_GETPGRP`) -- read/write
  `SE_PGroup`; pid 0 = caller, pgid 0 = make the pid its own group leader.
- **`tcsetpgrp` / `tcgetpgrp`** are the `TIOCSPGRP` / `TIOCGPGRP` ioctls,
  reading/writing the terminal's `TTY_FgPgrp`.
- **`waitpid`** (`SYS_WAITPID`) with `WUNTRACED` reaps a ZOMBIE child or reports
  a STOPPED child without reaping (`SEF_STOPREPORTED` prevents
  double-reporting; SIGCONT clears it).  `WNOHANG` polls.  `wait` (`SYS_WAIT`)
  = `waitpid(-1,...,0)`.
- **`kill`** (`SYS_KILL`) -- pid > 0 one task; pid < 0 a process group; pid ==
  0 the caller's group.  Group fan-out posts to every live task with the
  matching `SE_PGroup`.  SIGKILL/SIGSTOP are uncatchable.
- **SIGTTIN gate** -- 2.11BSD `ttread`'s background check: a background
  reader that ignores or blocks SIGTTIN, or is a vfork child, gets `EIO`;
  otherwise its group gets SIGTTIN.  FGX then returns `EINTR` where upstream
  sleeps on `lbolt` and retries, because the signal is delivered at the
  syscall return (comment at the gate in `src/kernel/tty/tty.c`).

Signals are delivered at the **syscall boundary**: `_Sys_CheckSignal`
(`src/kernel/signal.s`) runs on syscall return and applies the default action
(terminate via `_Exit_Core` with a WIFSIGNALED status, stop, continue, ignore)
or delivers a user handler.  A task that makes no syscall and reaches no fcc
safepoint is not signalled until it does.

The interactive shell (`tcsh`) drives this: `setpgid` per job, `TIOCSPGRP` to
hand the tty to the foreground job, `waitpid(WUNTRACED)` to track stops.

## Process lifecycle

FGX has **`fork`** (`SYS_FORK`, 2), **`vfork`** (`SYS_VFORK`, 46) and
**`execve`** (`SYS_EXECVE`, 11), plus the FGX-specific **`posix_spawn`**
(`SYS_POSIX_SPAWN`, 43, and `SYS_POSIX_SPAWNX`).  `vfork` parks the parent on
`WCHAN_VFORK` until the child execs or exits.

- **`posix_spawn`** is **asynchronous**.  It allocates the child's TCB, user
  memory, fd table (copied from the parent, bumping FCB refcounts), cwd
  (inherited), process name, user stack reservation (its first page is the
  DP), kernel-image home, and u-area; loads the binary; stages argv/envp;
  primes the first run; then marks the child **`TASK_READY` and returns to
  the parent immediately** (C=1, A = child pid).  The child runs when
  `pick_next` next picks it.
- **`_exit`** (`_Exit_Core`, `src/kernel/process.s`) -- stops the DOC if the
  task owned it, closes all fds, marks the task `TASK_ZOMBIE`, frees its
  memory, **reparents its children to PID 1** (tagged `SEF_REPARENTED`), wakes
  the parent, auto-reaps reparented orphan zombies, then `swtch`es away for
  good.  It is also the landing for a fatal signal.
- **Reaping** -- `waitpid` / `wait` calls `Task_Free` on the zombie's slot,
  which frees the fd table, the user stack reservation, the kernel-image slot
  binding and the u-area, clears the sched-state flags and name slot, and
  marks the slot `TASK_UNUSED`.
- **init (PID 1)** is started by the kernel from `/sbin/init`
  (`_InitPath`, `src/kernel/main.s`) on a hand-built TCB.  It is 2.11BSD
  init(8) (`src/userland/init/init.c`): it runs `/etc/rc`, then keeps the
  program each `on` line of `/etc/ttys` names alive (the console runs
  `/bin/sh`, the virtual consoles `getty`).  The machine is stopped with
  `reboot(8)` or `halt(8)` (one binary, `src/userland/reboot/reboot.c`).

## Unused definitions

`include/kernel.s` still defines the `RQ_*` ready-queue struct and the
`TCB_LastRun` / `TCB_NextReady` / `TCB_PrevReady` fields; no code uses them by
those names.  `TCB_StackHandle` is an alias over the `TCB_NextReady` bytes, so
do not resurrect the old fields.  `TCB_Priority` and `PRIO_*` are live but
constant (see "Model" above).
