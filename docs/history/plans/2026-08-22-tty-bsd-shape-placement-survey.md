# The BSD tty shape: where it can live.  A placement survey.

Run 2026-08-22, at the maintainer's direction, before any code moves.  The ruling this
survey works under: **B adopts BSD's `struct tty` and its queues; match BSD
wherever feasible.**

The question asked was "module or a third static kernel bank".  **The answer is
that placement is not the binding constraint.**  The binding constraint is that
FGX's tty input discipline runs at INTERRUPT time and kernel C's register file
is a singleton that exists only because kernel C never runs at interrupt time.
That decides more than which bank the code sits in, and it has to be settled
first.

---

## 1. What "the discipline" is today, and who reaches it

Measured, not estimated.  Spans are label-to-next-label in `src/kernel/syscall.s`.

| routine | lines | what it is in BSD terms |
|---|---:|---|
| `_RdOp_Console` | 470 | `ttread` + `ttyoutput`'s echo half |
| `_WrOp_Chardev` | 177 | driver write + the background gate |
| `_RdOp_Chardev` | 92 | driver read + the pty detour + `_SyTty_Resolve` |
| `_WrOp_Console` | 51 | `ttwrite` |
| **total** | **790** | |

plus eleven `_Tty_*` helpers and nine `_SyTty_*` (`src/kernel/pty.s`,
`src/kernel/tty_tty.s`).

`TTY_CanonBuf` / `TTY_CanonLen` / `TTY_CanonPos` have **40 references across
five files**: `syscall.s` (29), `ttyv.s` (6), `signal.s` (4), `pty.s` (2).

### Callers, classified

Most of it is syscall-only, which is what makes it look movable:

* `_Tty_EchoByte`, `_Tty_GetByte`, `_Tty_PollByte`, `_Tty_EchoOpen`,
  `_Tty_EchoClose`, `_Tty_BgWriteGate` -- every caller is in `syscall.s`.

Four are not:

* `_Tty_CookedDefaults` -- **`main.s:293`, boot**, plus `ttyv.s` and a
  jump-table service.  This is `ttychars()`.
* `_Tty_DrainSigPend` -- `signal.s` and **`sched.s:437`, the scheduler's idle
  loop**, after `WAI`.  Its own comment: *"when every task is blocked, this idle
  loop is the only kernel-DP site that runs, so it must deliver the
  foreground-group signal"*.
* `_Tty_PollReadable` -- `ttyv.s`, `syscall.s`.
* `_Tty_CurIsFg` -- `net_dispatch.s`, `syscall.s`.

## 2. The pre-`modload` finding, and it is not the one expected

The expectation going in was that boot logging might take the discipline.  It
does not -- `Kern_LogStr` goes to `Con_Write`, which is the driver, below the
discipline.

**It is the keyboard.**  `src/kernel/toolbox.s` is the 60 Hz heartbeat task,
installed by `Toolbox_InstallHB` which *"enables the Mega-II VBL source and
unmasks CPU IRQs (CLI)"*.  At `@hb_kbd*` (toolbox.s:602-637) it:

```
                LDA     _ttyTable+TTY_SgFlags,X
                AND     #SG_RAW
                BNE     @hb_sigNoGrp            ; raw: the byte IS the data
                ...
                CMP     #$0003                  ; ^C
                ...
                ORA     _kTtySigPend,X
                STA     _kTtySigPend,X
                ...
                STA     _kTtySigAny
```

That reads per-tty mode flags, applies `SG_RAW`, detects `^C`/`^Z`, and posts a
pending signal.  **It is `ttyinput`.**  It is the only writer of
`_kTtySigPend`/`_kTtySigAny`.

Boot order in `src/kernel/main.s`:

```
  293   JSR  _Tty_CookedDefaults      ; ttychars() -- tty state exists
  398   JSR  _Chardev_InitBuiltins    ; the registry
  444   JSR  Toolbox_InstallHB        ; VBL on, CLI -- ttyinput IS LIVE
  596   JSR  Mod_LoadConf             ; modules exist from here
```

**152 lines of boot separate a live interrupt-time `ttyinput` from the first
moment a module could exist.**  So `tty.mod` is ruled out for the input half on
load order, and the far-bank doc's surviving objection holds -- though only that
one: its other two (*"modules cannot allocate kernel heap"*, *"the module jump
table is full"*) were retired by `KSVC_KMALLOC`/`KSVC_KFREE` and by KSVC being a
sub-dispatch under one slot.

Note also that the serial driver has **no** `ttyinput` at all: `serial_isr`
fills `_sccRxBuf` and `serial_read` pops it.  Its bytes never meet a discipline.
That is a divergence a port would close, and it means the two tty families in
this kernel disagree about where input processing happens.

## 3. THE BLOCKER: a singleton register file versus interrupt-time C

`include/kernelc.s:342` states it plainly:

> `FGX_DP_KERNELC` **is a SINGLETON**: kernel C is compiled `-fno-safepoints`
> and runs to completion inside a syscall, which is what makes one register file
> safe.  **Two C contexts live at once would share it and corrupt each other**,
> so a C module must not be re-entered from far-bank C or from itself.

A ported `ttyinput` is C.  Called from the VBL handler, it is a second C context
live at once whenever the interrupt lands inside any kernel C -- a `vfs_read`, a
`namei` walk, the buffer cache.  That is not a bank problem and no bank fixes
it.

**Confirmed that nothing does this today**: the only far calls in `toolbox.s`
are `_kfp103`/`_kfp104`, both on fatal init paths ending in `_Kern_Halt`, not in
the tick handler.  `sched.s` and `signal.s` have none.  The invariant is intact
and this port would be the first thing to break it.

### Why BSD gets away with it, since that is the useful question

Not because BSD is cleverer about interrupts.  Because it pays for the property
in two places FGX has not:

1. **Its compiler puts C's working state on the stack.**  An interrupt gets a
   fresh frame on the kernel stack, so nested C contexts cannot collide.  fcc
   keeps "its register file, frame pointer and stack floor in the direct page"
   (`include/kernelc.s`) -- ONE fixed copy.  That single choice is the whole
   difference, and it is a compiler property, not an OS one.
2. **Its tty data is protected by `spl`, not by "only one context at a time".**
   `putc` opens `s = spltty();` and `ttread` opens `s = spltty(); if
   (tp->t_flags&PENDIN) ttypend(tp); splx(s);`.  The structures are guarded by
   priority level *so that* interrupt and process context can both touch them.
   FGX has SEI/CLI but no spl discipline over tty state, and its safety argument
   is the opposite one: nothing else is running.

A third, smaller: FGX's "ISR" is a firmware heartbeat task dispatched at VBL
through the toolbox Heartbeat Interrupt Handler, running on the interrupted
task's direct page -- which is why `sched.s` notes the heartbeat "can't" call
`_wakeup`.  It has less room to establish a context than a native device ISR.

### BSD ALREADY DEFERS ttyinput, AND THE MECHANISM IS PORTABLE

This is the finding that reorders the options.  `tty.c`:

    ttypend(tp)
            register struct tty *tp;
    {
            struct clist tq;
            register int c;

            tp->t_flags &= ~PENDIN;
            tp->t_state |= TS_TYPEN;
            tq = tp->t_rawq;
            tp->t_rawq.c_cc = 0;
            tp->t_rawq.c_cf = tp->t_rawq.c_cl = 0;
            while ((c = getc(&tq)) >= 0)
                    ttyinput(c, tp);
            tp->t_state &= ~TS_TYPEN;
    }

called from `ttread`'s head under `PENDIN`.  Upstream sets `PENDIN` on a mode
change (`tty.c:461`, leaving CBREAK) because queued raw characters must be
reinterpreted -- but the mechanism IS "characters were queued without
discipline; run `ttyinput` over them later".  Deferral is therefore not a
divergence in MECHANISM, only in how often the flag is set.

### The three ways out, re-costed

1. **A second register file.**  Interrupt-time C gets its own `$98..$FF`, so the
   ISR's C context and the syscall's do not share one.  Full BSD shape:
   `ttyinput` really does run at arrival.  Costs the `$98..$FF` region of
   another direct page in bank 0 -- contended, since the geometry is arena
   `$1A00`+152p, kernel-C DP `$B200`, per-task DPs `$B300..$C000` and NPROC is
   already walled -- plus an entry macro selecting it and a rule that the two C
   worlds never call each other.
2. **Deferral via `PENDIN`, kept permanently set.**  The ISR gets the byte into
   `t_rawq`; `ttread` runs `ttypend`, which runs the real ported `ttyinput`.
   BSD's own code, BSD's own flag.  **But `putc` is itself 30 lines of C with an
   allocator**, so this splits again:
   * **2a -- a raw ring in front of `t_rawq`.**  The ISR keeps today's assembly
     ring; a safe-point drain does `putc` then `ttyinput`.  All C stays in safe
     context, and the cost is permanent: TWO input queues where BSD has one, so
     `t_rawq` is never the sole input queue and the port sits one layer off
     upstream forever.
   * **2b -- an assembly `putc`.**  ~20 lines against `tty_subr.c`'s documented
     cblock layout, called from the ISR; everything above it is ported C.  ONE
     queue, BSD's data structures, BSD's deferral, one hand-written primitive.
3. **The interrupt half stays assembly.**  `ttyinput` is not ported at all.
   Least BSD, least risk, strands row 5 of the convergence table.

### What deferral actually costs, itemised

Four candidate downsides.  Two are already paid by the tree as it stands:

* **Signal latency** -- already paid.  `_kTtySigPend` is posted by the ISR and
  drained at syscall exit and the scheduler idle loop today, and `ptyintr`'s
  manifest records the consequence: "FGX delivers pending signals at SYSCALL
  EXIT, so a target making no syscall at all could not receive one however this
  is wired."
* **Echo timing** -- already paid.  BSD echoes inside `ttyinput`, so typing
  appears while a compute-bound process runs; FGX echoes in `_RdOp_Console`, so
  it appears only while something is reading.  (Predicted from the code, NOT
  measured: typing during a long non-reading command shows nothing until it
  ends.)

One is genuinely new, and it is the one to weigh:

* **`^S`/`^Q` flow control goes soft.**  `ttyinput` handles `t_stopc`/`t_startc`.
  Deferred, output does not stop until a reader runs.  On the 9600-baud serial
  line with an IRQ TX ring that is a real degradation, and unlike the signal
  case there is no existing deferral to hide behind.

And one is structural rather than behavioural:

* **Where `putc` runs decides whether there are one or two input queues** --
  2a versus 2b above.  That is the choice that determines how close the finished
  port sits to upstream.

## 4. Memory: BSD's queues are cheaper than what FGX has

Measured from the kernel listing: `_ttyTable DS {5}*{302}` = **1,510 bytes**,
of which **1,280 is five fixed `TTY_CanonBuf DS 256`**.

BSD's `struct tty` (`vendor/2.11BSD/usr/sys/h/tty.h`) holds three `struct clist`
-- `t_rawq`, `t_canq`, `t_outq` -- each `{int c_cc; char *c_cf; char *c_cl;}`.
With fcc's 4-byte pointers that is 10 bytes a clist; the whole struct including
`ttychars` (14) and `winsize` (8) comes to roughly **95 bytes**.

    FGX today          5 x 302                        = 1,510 B
    BSD shape          5 x ~95  + NCLIST x CBLOCK
                       = ~475   + (48 x 32 = 1,536)   = ~2,011 B
                       = ~475   + (32 x 32 = 1,024)   = ~1,499 B

`CBLOCK` is 32 (`param.h:74`), `CBSIZE = CBLOCK - sizeof(struct cblock *)` = 28
chars a block with fcc pointers.  **At `NCLIST` around 32 the swap is memory
neutral**, and it buys what the fixed buffers cannot: a pool shared across all
five lines, so one busy terminal can hold what five idle ones are not using.

## 5. Size: what the port costs in bytes

Measured rate, comments stripped, across four far-bank translation units:
**19.1 bytes of 65816 per line of kernel C** (801 code lines -> 15,264 bytes).

| source | code lines | est. bytes |
|---|---:|---:|
| `tty.c` | 1,168 | 22,257 |
| `tty_subr.c` | 554 | 10,557 |
| `tty_pty.c` | 467 | 8,899 |
| `tty_conf.c` | 114 | 2,172 |
| `tty.h` | 100 | 1,905 |
| `tty_tty.c` | 57 | 1,086 |
| **total** | **2,460** | **~46,900** |

Against: core bank **378** free, far bank **18,411** free.  `tty_pty.c` belongs
in pty.mod rather than with the discipline, which leaves **~38 KB** for the
discipline proper.

## 6. A third static bank is nearly free, and that was the surprise

`src/boot/stage2.s:60` -- `KERNEL_BANKS EQU $02` -- and `LoaderAllocKernelBank`
*"claims KERNEL_BANKS contiguous, bank-aligned banks"*, over-allocating
`KERNEL_BANKS+1` and rounding the base up.  The far bank *"is the HEADROOM bank
of the kernel handle, not a new allocation ... base+1 is therefore already
claimed, locked and bank-aligned"*, and `Far_Init` derives it as `_BANKK` `INC`.

**The allocation is already parametric in `KERNEL_BANKS`.**  A third bank is
that constant (in two places -- `stage2.s:60` and `include/kernel.s:64`), a
third image loaded at base+2, and a second copy of the per-bank apparatus:

    src/kernel/far_patchsites.s          core -> far  (generated)
    src/kernel/far/core_patchsites.s     far -> core  (generated)
    src/kernel/far/kernel_exports.s      addresses    (generated)
    src/kernel/far_shims.s               far -> core  (hand-written)
    tools/gen_far_bankpatch.py           already takes a direction argument
    tools/check_far_calls.py, check_far_rtl_calls.py

Three of those are generated and one generator already parameterises direction.
This is real work but it is a known quantity, not new machinery.

## 7. Where that leaves the recommendation

**Placement, given the above:**

* The **discipline body** (`tty.c`, `tty_subr.c`, `tty_conf.c`) is fcc C, ~38 KB,
  and must be present from boot.  It goes in a **third static kernel bank**.
  Not a module -- load order rules that out for anything the ISR path can reach,
  and not the far bank -- 18.4 KB free against ~38 KB needed.
* **`tty_pty.c`** goes in pty.mod, rewritten against the new ABI.  Drivers and
  disciplines are separate upstream too.
* **`tty_tty.c`** (57 lines) replaces the hand-written `src/kernel/tty_tty.s`
  (11 KB of assembly) and can go with the discipline.

**But none of that can start until the interrupt-time question is decided**,
because it determines whether `ttyinput` is C at all -- and `ttyinput` is what
`t_rawq` exists for, which is what `tty_subr.c` exists for.  Choosing (3) above
would mean the clists have an assembly producer and a C consumer, which changes
what "adopt the queues" means.

## 8. DECIDED (the maintainer, 2026-08-22)

**2b as the increment, the second register file as the endpoint.**  An assembly
`putc` into `t_rawq`, `PENDIN` kept permanently set, and ported `ttypend` /
`ttyinput` above it -- one input queue, BSD's data structures, BSD's own
deferral, one hand-written twenty-line primitive.

**The `^S`/`^Q` cost is accepted for now**, on the grounds that nothing is
using serial.  It is a KNOWN DIVERGENCE with a home rather than an oversight:
until the last increment lands, `t_stopc`/`t_startc` are honoured when a reader
runs rather than when the character arrives.  Anything that starts driving the
serial line before then should reopen this.

## 9. The campaign, in increments

Ordered by dependency, each landing green with a witness.

**T1 -- the third static kernel bank, arriving with its first tenant.**
`KERNEL_BANKS` `$02` -> `$03` (`src/boot/stage2.s:60`, `include/kernel.s:64`), a
third image at base+2, and a second copy of the per-bank apparatus: export
table at bank offset `$0000`, `core->new` and `new->core` patch tables (both
generated -- `gen_far_bankpatch.py` already takes a direction argument), shims,
and the two check scripts.  Its first tenant is `h/tty.h` + `tty_subr.c`, so the
bank does not land empty -- a bank with no caller is a table nothing checks.
Witness: a clist probe that pushes and pops through `putc`/`getc`/`q_to_b` and
asserts `c_cc`/`c_cf`/`c_cl`, plus the cblock pool's free count.

**T2 -- the cdevsw/linesw ABI.  This is apple/fgx#198's fix.**  `d_open(dev,
flag, mode)`, `d_read(dev, uio, flag)`, `d_write`, `d_ioctl`, `d_select` across
all eight vtables; `linesw` with `tty_conf.c`'s TEN slots even though three are
filled; every driver becomes `ptswrite`'s two lines.

THE EXISTING DISCIPLINE DOES NOT MOVE IN T2.  `l_read`/`l_write` point at a thin
adapter that unpacks the uio into today's core-bank per-byte loop.  Moving 790
lines of assembly that T3 then deletes would be paying twice; a seam is what is
wanted here, not a relocation.

Closes #198 -- record mode, the stray `[_fcbPtr]` write and the discipline
detour all stop existing -- and unblocks UFS 1.7d I4's `/ldev` sweep, which is
downstream of it.

**T3 -- `tty.c`.**  `ttread`, `ttwrite`, `ttyinput`, `ttyoutput`, `ttypend`,
`ttioctl`, `ttselect` into the T1 bank, against T1's `struct tty`.  The assembly
`putc` and permanent `PENDIN` land here.  `linesw[0]` repoints from the adapter
to the real thing and the core-bank discipline is DELETED -- `_RdOp_Console`'s
470 lines, `_RdOp_Chardev`'s detour, the `_Tty_*` helpers, `TTY_CanonBuf` and
its 40 references.

This is the increment that retires apple/fgx#108 and the one to split if it
proves too big: read before write is the natural seam, since `l_read` and
`l_write` are independent slots.

**T4 -- `tty_pty.c`** into pty.mod, replacing the original driver.  Drivers and
disciplines are separate upstream too, which is why the pty does not go in the
tty bank.

**T5 -- `tty_tty.c`** (57 lines) replacing `src/kernel/tty_tty.s` (11 KB of
assembly), and `_SyTty_Resolve` leaves `_RdOp_Chardev` for good.

**T6 -- the second register file.**  Interrupt-time C gets its own `$98..$FF`;
`ttyinput` returns to arrival time; `^S`/`^Q` become crisp and section 8's
accepted divergence closes.  By this point it moves only WHERE `ttyinput` is
called from -- the queue and the code are already upstream's -- which is the
whole reason it is last rather than first.

### What T1-T6 does not cover

`ttyinput` for SERIAL.  `serial_isr` fills `_sccRxBuf` and `serial_read` pops
it, so its bytes never meet a discipline at all (section 2).  Giving the serial
line an `l_rint` is a seventh increment, and it is the one that makes section
8's accepted `^S`/`^Q` divergence matter -- so it belongs after T6, not before.

Nothing in the tree changed for this survey.
