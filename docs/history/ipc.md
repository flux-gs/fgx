# IPC (message passing) — abandoned design / possible future

> **Not implemented.** This file preserves an *aspirational* microkernel design
> that FGX considered early on and did **not** build. FGX is a monolithic kernel
> with **POSIX-shaped syscalls** (`socket`/`read`/`write`/`spawn`/`wait`/`pipe`/
> …), not message passing. Nothing in the running system uses any of the below.
> Kept as a record of the path not taken, and as a sketch should a future version
> want a message-passing layer. See [../architecture.md](../architecture.md) for
> what FGX actually is.

## The original idea

An early design imagined FGX as a microkernel where user-space *servers* (a
filesystem server, a network server, drivers) communicated with clients and the
kernel through **synchronous and asynchronous message passing** over *ports*,
rather than through a fixed syscall table. Bank `$03` was reserved as an "IPC
bank" to hold the message machinery:

- a **message pool** (a fixed array of small fixed-size message slots),
- a **port table** (named endpoints a task could send to / receive from),
- **async queue buffers** for non-blocking delivery,
- a **shared-memory registry** for bulk transfers too large to copy into a
  message, and
- **large-message buffers**.

A syscall would have been "send a message to the kernel port"; a driver would
have been "a server blocked on receive from its port."

## Why FGX didn't go this way

FGX is a single-user hobby OS on a ~1 MHz-effective 65816 with no MMU and no
hardware protection between tasks. The microkernel payoffs (fault isolation
between servers, swappable user-space drivers) need protection and cheap context
switches to be worth their message-copy overhead — neither of which the platform
offers cheaply. A **monolithic kernel with a flat syscall trampoline** (`JSL
SYS_TRAMP` + a number byte) is simpler, faster, and maps directly onto the
BSD-shaped userland FGX wanted to host. Swappability is instead provided by
**loadable FGXM modules** (the ProDOS FST, serial, etc.) behind in-kernel
jump-table / FOP seams — the benefit without the IPC tax.

Bank `$03` is now the **console framebuffer**; the kernel's modular seams are the
FOP/FST dispatch and the module jump tables, not ports.

## If a future version wanted message passing

It would most naturally sit **on top of** the existing primitives rather than
replace them: a `pipe()`-style or `socketpair()`-style fd, or an `mmap`-shared
region plus a wakeup channel (`_sleep`/`_wakeup` already exist — see
[../scheduler.md](../scheduler.md)). That keeps the syscall ABI and the
cooperative scheduler intact and treats messaging as one more BSD-shaped IO
object, not a kernel rearchitecture.
