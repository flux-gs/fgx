;==============================================================================
;
; FGX - Flux GS uniX
;
; File:     src/kernel/tty/kc_sys.s
; Purpose:  The C-to-kernel direction of the seam, for the TTY BANK.
; Created:  2026-08-22
;
; A second copy of the piece of src/kernel/far/kc_sys.s the tty bank needs, and
; it has to be a copy rather than a call: the _ctp marker that gets this site's
; bank byte patched must be in THIS bank's listing, because Tty_BankInit walks a
; table generated from it.  Reaching the far bank's copy would mean a
; bank-to-bank call whose own bank byte nothing patches.
;
; ONE ROUTINE, because one is reached.  tty_subr.c's clist code calls wakeup()
; on the cwaiting channel when a block comes free; nothing in T1 sleeps on it,
; so the call is present and the path is cold.  A routine here that no C calls
; would be a scraped kernel address in a generated table with nothing to say
; whether it still resolves to the right thing.
;
;==============================================================================

;------------------------------------------------------------------------------
; kc_wakeup(chan) - make every task waiting on chan runnable.  Does not switch.
;
; Entered from fcc-generated code with D = FGX_DP_KERNELC and DBR = this bank
; (KTTY_KC_ENTER).  The kernel's Wakeup wants the kernel's REAL direct page, so
; this swaps D for the duration and puts it back.
;
; The channel is the pointer's OFFSET only -- a sleep channel is an identity,
; not an address to dereference, and the core side compares the word.
;------------------------------------------------------------------------------
kc_wakeup       MX      %00
                LDA     4,S                     ; chan = pointer OFFSET
                PHD                             ; save the kernel-C page
                PHA                             ; TCD needs A, so park chan
_ctp002         JSL     _FarSh_KernDP           ; A = the kernel's REAL direct page
                TCD
                PLA                             ; chan back
_ctp003         JSL     _FarSh_Wakeup           ; shim sets DBR = core bank
                PLD                             ; kernel-C page back
                RTL

;------------------------------------------------------------------------------
; kc_ptywake() - wake WCHAN_PTY, the channel every pty waiter sleeps on.
; apple/fgx#108 T4 increment 4.
;
; `ptsstart's whole body, and the reason it is a shim of its own rather than
; `kc_wakeup(some pointer)': kc_wakeup takes a POINTER and passes its offset,
; because every channel it has served is an object's address.  WCHAN_PTY is not
; an object -- it is a name in the fixed range include/kernel.s reserves for
; kernel-global wait sources -- and spelling it as a cast pointer at the call
; site would put a magic address in the C.  kc_lbolt is the same argument for
; the same reason, one screen down.
;
; COARSE ON PURPOSE: one channel serves every pty waiter, so this wakes them
; all and each re-tests.  That is WCHAN_PIPE's arrangement and the pty plan
; adopted it deliberately.  It is NOT the lbolt channel any more -- the two were
; the same value until apple/fgx#238, which would have made a ptsstart that
; never fired indistinguishable from one that did.
;
; No arguments, no return.
;------------------------------------------------------------------------------
kc_ptywake      MX      %00
                PHD                             ; save the kernel-C page
_ctp047         JSL     _FarSh_KernDP           ; A = the kernel's REAL DP
                TCD
                LDA     #WCHAN_PTY
_ctp048         JSL     _FarSh_Wakeup           ; shim sets DBR = core bank
                PLD                             ; kernel-C page back
                RTL

;------------------------------------------------------------------------------
; kc_sleep(chan) - block until kc_wakeup names the same channel.  T3.
;
; `sleep((caddr_t)&tp->t_outq, TTOPRI)' as this bank can spell it, and the
; third bank's copy of what src/kernel/far/kc_sys.s already does -- same shim,
; same DP dance, same reasoning.  Read that file's header before changing this
; one.
;
; THE CHANNEL IS 16 BITS AND THE POINTER IS 32.  _sleep/_wakeup match channels
; as 16-bit values, so this passes the pointer's OFFSET and drops its bank.
; Two channels in different banks at the same offset would alias, and that is
; safe here for the reason it is safe there: ttywait RE-TESTS its condition
; after every wake, so an aliased channel costs a spurious wakeup and a
; re-test, never a missed one.  It stops being safe the day a waiter trusts the
; wakeup instead of re-testing.
;
; UNINTERRUPTIBLE (_sleepUn, BSD's PRIBIO) rather than TTOPRI's interruptible
; sleep.  Upstream can take a signal here and unwind through u.u_error; this
; bank has no u-area to unwind through, and ttywait's caller has no error path
; -- it loops on the condition.  An interruptible sleep answering "a signal is
; pending, I did not sleep" would spin that loop at full speed.  DIVERGENCE
; WITH AN EXPIRY: it ends when the tty bank can reach a u-area, which is the
; same thing ttyopen is waiting for.
;
; 2 argument bytes: chan (the offset half of a pointer).
;------------------------------------------------------------------------------
kc_sleep        MX      %00
                LDA     4,S                     ; chan = pointer OFFSET
                PHD                             ; save the kernel-C page
                PHA                             ; TCD needs A, so park chan
_ctp018         JSL     _FarSh_KernDP           ; A = the kernel's REAL DP
                TCD
                PLA                             ; chan back
_ctp019         JSL     _FarSh_SleepUn          ; shim sets DBR = core bank
                PLD                             ; kernel-C page back
                RTL

;------------------------------------------------------------------------------
; kc_sleepi(chan) -> 1 if a signal wants us and we did NOT sleep, 0 if woken.
; apple/fgx#108 T6 increment 4b.
;
; THE INTERRUPTIBLE TWIN OF `kc_sleep' ABOVE, and the flip is what makes it
; necessary.  Until now the wait that a keystroke ends was the PUMP'S:
; `kc_getbyte' -> `_Tty_GetByte' -> `Con_GetKey', which sleeps through
; `_FarSh_Sleep' and returns "interrupted" on a pending signal
; (src/kernel/far/console/console_kbd.s:122-131).  After the flip the wait is
; `ttread's own -- `kc_sleep(&tp->t_rawq)' -- and `_sleepUn' has NO signal
; early-out at all: `CLC ; never "give up": no error path' (sched.s:606).
;
; THAT WOULD BE A HANG, not a slow path.  A `^C' reaches `ttyinput' now, which
; flushes the queue and wakes the reader (tty.c:1097-1101) -- and the reader
; would find `t_rawq' empty, `goto loop', and sleep again, forever, never
; reaching the syscall boundary where the signal is delivered.
;
; UPSTREAM SLEEPS INTERRUPTIBLY HERE AND SAYS SO IN ONE CONSTANT: `ttread'
; waits at TTIPRI (vendor/2.11BSD/usr/sys/sys/tty.c:1187), TTIPRI is 10
; (h/tty.h:89), PZERO is 25 (h/param.h:38), and `sleep' takes PCATCH for any
; priority above PZERO (kern_synch.c:238).  So this is the port and `kc_sleep'
; is the divergence -- which is why the two are separate entry points rather
; than a flag.
;
; 2 argument bytes: chan (the offset half of a pointer).
;------------------------------------------------------------------------------
kc_sleepi       MX      %00
                LDA     4,S                     ; chan = pointer OFFSET
                PHD                             ; save the kernel-C page
                PHA                             ; TCD needs A, so park chan
_ctp057         JSL     _FarSh_KernDP           ; A = the kernel's REAL DP
                TCD
                PLA                             ; chan back
_ctp058         JSL     _FarSh_Sleep            ; C=1 = a signal wants us
                PLD                             ; kernel-C page back
                ; THE CARRY IS THE ANSWER AND C CANNOT SEE A CARRY, so fold it
                ; into the value -- the same fold `_FarSh_TtyGetByte' describes
                ; for the byte source (far_shims.s:202-205).  PLD sets N/Z only
                ; and leaves carry alone.
                LDA     #0
                BCC     @ksi_slept
                LDA     #1
@ksi_slept      RTL

;------------------------------------------------------------------------------
; kc_uiomove(cp, n, uio) -> errno.  apple/fgx#108 T3.
;
; The discipline`s one way to move bytes between a clist and a caller`s buffer,
; and it has to be a call OUT: uiomove knows whether the far side is kernel or
; user space, and this bank must not learn that.
;
; TWO HOPS, and both are forced.  uiomove lives in vfs.mod, a LOADABLE bank, so
; there is no address to bake at build time -- the core resolves it once at
; boot (_Tty_LoadVfsPtr) and _FarSh_Uiomove PILECALLs it from there.  This end
; only forwards the frame and JSLs the shim, exactly as kc_wakeup JSLs its own.
;
; THE FRAME IS RE-PUSHED, NOT ALIASED.  fcc left the arguments at 4,S..13,S on
; entry; the JSL below puts its own return address on top, so the shim reads
; them at a depth of its own.  Re-pushing is what keeps each side counting only
; its own stack -- the alternative is two files that must agree about a number,
; which is the shape the first cut of _Chardev_Bulk got wrong.
;
; D IS THE KERNEL-C PAGE THROUGHOUT and is deliberately NOT swapped: uiomove is
; itself kernel C and wants exactly that page.  kc_wakeup swaps because _wakeup
; is assembly on the kernel`s own page; the difference is the callee, not the
; caller.
;
; 10 argument bytes: cp (4) + n (2) + uio (4).
;------------------------------------------------------------------------------
kc_uiomove      MX      %00
                LDA     12,S
                PHA
                LDA     12,S
                PHA
                LDA     12,S
                PHA
                LDA     12,S
                PHA
                LDA     12,S
                PHA
_ctp006         JSL     _FarSh_Uiomove          ; shim sets DBR, PILECALLs vfs
                TAY                             ; park the errno
                TSC
                CLC
                ADC     #10                     ; drop the re-pushed arguments
                TCS
                TYA
                RTL

;------------------------------------------------------------------------------
; kc_ureadc(c, uio) -> errno.  apple/fgx#108 T3.
;
; ttread's one-character handoff to the reader.  kc_uiomove's twin in every
; respect -- two hops, a re-pushed frame, D left on the kernel-C page because
; the callee is itself kernel C -- so read that routine's header above for the
; reasoning and this one only for what differs: SIX argument bytes, not ten.
;
; NOT kc_uiomove WITH n = 1.  uiomove panics on a uio whose uio_rw is neither
; READ nor WRITE, walks a loop and clamps against n; ureadc advances past empty
; iovecs and stores one byte.  ttread calls it once per character in its inner
; loop, which is why upstream keeps the cheap one and why this bank does too.
;
; 6 argument bytes: c (2) + uio (4).
;------------------------------------------------------------------------------
kc_ureadc       MX      %00
                LDA     8,S
                PHA
                LDA     8,S
                PHA
                LDA     8,S
                PHA
_ctp032         JSL     _FarSh_Ureadc           ; shim sets DBR, PILECALLs vfs
                TAY                             ; park the errno
                TSC
                CLC
                ADC     #6                      ; drop the re-pushed arguments
                TCS
                TYA
                RTL

;------------------------------------------------------------------------------
; kc_cdttyidx(idx) -> the TTY INDEX, -1 for "not a tty", -2 for "no such device".
;
; FGX's cdevsw[].d_ttys, reached from this bank's C.  tty_find() in tty_dev.c
; is the only caller and turns the index into a `struct tty *'.
;
; THE TWO FAILURES ARE KEPT APART: -1 is "not a tty", -2 is "no such device".
;
; tty_find() treats both the same and should -- a driver has nothing different
; to do.  THE PROBE DOES.  Collapsing them made the bounds check in
; _Chardev_TtyIdx untestable: removing it left the probe GREEN, because reading
; one entry past the registry happened to answer bytes that did not look like a
; tty, so "refused" and "read whatever was there" produced the same -1.  With
; -2 for the refusal, tty_probe asserts the REFUSAL rather than its usual
; consequence, and the mutation goes red every time instead of by luck.
;
; ENODEV is not passed through as itself: 19 is a perfectly plausible tty index
; if NTTY ever grew, and a caller reading it as one would be a wrong answer
; rather than an error.
;
; DBR is this bank on entry (KTTY_KC_ENTER) and the shim sets its own.  The
; kernel's REAL direct page is needed because _Chardev_TtyIdx reads the
; registry through the DP long pointer _cdTablePtr.
;------------------------------------------------------------------------------
kc_cdttyidx     MX      %00
                LDA     4,S                     ; idx
                PHD                             ; save the kernel-C page
                PHA                             ; TCD needs A, so park idx
_ctp004         JSL     _FarSh_KernDP           ; A = the kernel's REAL DP
                TCD
                PLA                             ; idx back
_ctp005         JSL     _FarSh_CdTtyIdx         ; shim sets DBR = core bank
                BCS     @kct_ok
                LDA     #$FFFE                  ; -2: no such device (refused)
@kct_ok         PLD                             ; kernel-C page back
                RTL

;------------------------------------------------------------------------------
; kc_cdioctl(dev, cmd, arg) -> errno, 0 on success.  apple/fgx#108 T3.
;
; `(*cdevsw[major(dev)].d_ioctl)(dev, cmd, arg, flag)' as this bank can spell
; it.  FGX HAS NO cdevsw ARRAY -- tty_dev.c says so at length -- so the call
; cannot be written upstream's way: the character-device switch is the runtime
; registry in include/chardev.s and _Chardev_Ioctl is its d_ioctl.
;
; UPSTREAM'S FOURTH ARGUMENT, `flag', IS NOT CARRIED.  Both call sites pass 0,
; and the registry's op takes its flag in X from a dispatcher this does not go
; through; a 0 forwarded into a slot nothing reads would be a parameter that
; looks meaningful and is not.
;
; THE ANSWER IS AN ERRNO, NOT A CARRY.  ttyblock and ttyunblock both test the
; call `== 0', which is upstream's success convention, so the C/A pair the
; registry returns is folded into one number by _FarSh_CdIoctl.  A device with
; no modem-control lines answers ENOTTY and the RTSCTS arm simply does not fire
; -- which is the correct behaviour for it, not a failure.
;
; TWO THINGS SWAPPED, for the two reasons the shims above give separately: D
; goes to the kernel's REAL page because _Chardev_Dispatch reads the registry
; through the DP long pointer _cdTablePtr (kc_cdttyidx, below), and the frame is
; RE-PUSHED rather than aliased because the JSL puts its own return address on
; top (kc_uiomove, above).
;
; 8 argument bytes: dev (2) + cmd (2) + arg (4).
;------------------------------------------------------------------------------
kc_cdioctl      MX      %00
                PHD                             ; save the kernel-C page
_ctp010         JSL     _FarSh_KernDP           ; A = the kernel's REAL DP
                TCD
                LDA     12,S                    ; re-push the 8 argument bytes
                PHA                             ;   (PHD moved them up by 2)
                LDA     12,S
                PHA
                LDA     12,S
                PHA
                LDA     12,S
                PHA
_ctp011         JSL     _FarSh_CdIoctl          ; shim sets DBR = core bank
                TAY                             ; park the errno
                TSC
                CLC
                ADC     #8                      ; drop the re-pushed arguments
                TCS
                PLD                             ; kernel-C page back
                TYA
                RTL

;------------------------------------------------------------------------------
; kc_cdwrite(dev, cp, n) -- write a RUN of bytes to a chardev.  apple/fgx#108
; T3 stage 3, and this bank's FIRST WAY TO EMIT ANYTHING.
;
; Every other kc_ entry in this file asks the core a question or posts an
; event; none of them moves data outward.  `t_oproc' needs to, because a
; discipline that fills `t_outq' and cannot drain it is a queue that grows
; until the clist pool is gone.
;
; A RUN, NOT A BYTE, and `dzstart' is why: it drains with `ndqb', which returns
; a CONTIGUOUS run inside one cblock, and hands the whole run to the device.
; One crossing per run rather than per character is the difference between
; this and putting a JSL plus a PHD/TCD pair on every byte the machine prints.
;
; `cp' POINTS INTO THIS BANK -- it is `t_outq.c_cf', a pointer into the clist
; pool -- so the core side walks it with a DP long pointer.  See _FarSh_CdWrite.
;
; NO RETURN VALUE.  A short write cannot be expressed through the chardev putc
; ABI and does not need to be: the two devices a tty line drives are the
; console, which is synchronous, and a pty ring, which sleeps rather than
; refusing.
;
; 8 argument bytes: dev (2) + cp (4) + n (2).
;------------------------------------------------------------------------------
kc_cdwrite      MX      %00
                PHD                             ; save the kernel-C page
_ctp039         JSL     _FarSh_KernDP           ; A = the kernel's REAL DP
                TCD
                LDA     12,S                    ; re-push the 8 argument bytes
                PHA                             ;   (PHD moved them up by 2)
                LDA     12,S
                PHA
                LDA     12,S
                PHA
                LDA     12,S
                PHA
_ctp040         JSL     _FarSh_CdWrite          ; shim sets DBR = core bank
                TSC
                CLC
                ADC     #8                      ; drop the re-pushed arguments
                TCS
                PLD                             ; kernel-C page back
                RTL

;------------------------------------------------------------------------------
; kc_ttyopen(idx, pgrp) -> the line's t_pgrp after the open.  apple/fgx#108 T3.
;
; ttyopen's session-acquisition block -- 2.11BSD tty.c:652-659 -- as this bank
; can reach it:
;
;     pp = u.u_procp;
;     if (pp->p_pgrp == 0) {
;         u.u_ttyp = tp;  u.u_ttyd = dev;
;         if (tp->t_pgrp == 0)  tp->t_pgrp = pp->p_pid;
;         pp->p_pgrp = tp->t_pgrp;
;     }
;
; THE ONE PLACE THIS BANK CALLS A CORE PREDICATE INSTEAD OF PORTING IT, and the
; reason is in docs/history/plans/tty-kernel-bank.md section 9.  BSD puts the job-control
; PREDICATE in the tty layer -- both trees, every site -- so the background gate
; comes across as C over field accessors.  This block is different: FGX's answer
; to "which process is this open for" is _kCttyTarget when a spawn is applying
; file actions and _curTask otherwise, because init opens the device inside the
; CHILD.  Upstream's `u.u_procp' cannot express that, so a verbatim port would
; put the shell's line under init's process group -- the defect _Se_TtyOpen's
; own header in ttyv.s records.
;
; THE PGRP GOES BOTH WAYS, which is what keeps the tty state on this side: the
; caller hands over tp->t_pgrp and stores what comes back.  The core routine no
; longer reads _ttyTable at all (it was split for this), so the two banks' tty
; structures cannot drift apart through it.
;
; D goes to the kernel's REAL page because _Se_TtyOpenPg reaches the scheduler
; table through the DP long pointer _schedTblPtr, and the frame is RE-PUSHED
; rather than aliased for the reason kc_uiomove gives above.
;
; 4 argument bytes: idx (2) + pgrp (2).
;------------------------------------------------------------------------------
kc_ttyopen      MX      %00
                PHD                             ; save the kernel-C page
_ctp020         JSL     _FarSh_KernDP           ; A = the kernel's REAL DP
                TCD
                LDA     8,S                     ; re-push the 4 argument bytes
                PHA                             ;   (PHD moved them up by 2)
                LDA     8,S
                PHA
_ctp021         JSL     _FarSh_SeTtyOpen        ; shim sets DBR = core bank
                TAY                             ; park the resulting pgrp
                TSC
                CLC
                ADC     #4                      ; drop the re-pushed arguments
                TCS
                PLD                             ; kernel-C page back
                TYA
                RTL

;------------------------------------------------------------------------------
; kc_lbolt() - `sleep((caddr_t)&lbolt, TTIPRI)'.  apple/fgx#108 T3.
;
; BSD's "wait a bit and retry" channel.  ttwrite sleeps on it three times: once
; after signalling a background writer, and twice when the clist pool is empty
; and output has to be kicked and retried.
;
; NOT kc_sleep WITH A CONSTANT.  kc_sleep takes a POINTER and passes its offset,
; because every channel it has served so far is an object's address; lbolt is
; not an object here at all -- FGX names it WCHAN_LBOLT ($FF07) in the fixed
; range include/kernel.s reserves for kernel-global wait sources.  Spelling that
; as a cast pointer at the call site would put a magic address in the C.
;
; WHAT WAKES IT: _Lbolt_Wake (sched.s), driven by the heartbeat MARKING and two
; kernel-DP sites PERFORMING -- 2.11BSD's own needsoft/softclock split.  Read
; that routine's header for what the guarantee is and where it is weaker than
; upstream's.
;
; UNINTERRUPTIBLE, like kc_sleep and for the same reason plus one more: every
; lbolt sleeper re-tests its condition and loops, so a signal that cannot cut
; the sleep short costs at most the rest of the current second before the loop
; comes round and the syscall boundary notices it.  It stops being merely a
; delay the day a caller trusts the wake instead of re-testing.
;
; No arguments, no return.
;------------------------------------------------------------------------------
kc_lbolt        MX      %00
                PHD                             ; save the kernel-C page
_ctp022         JSL     _FarSh_KernDP           ; A = the kernel's REAL DP
                TCD
                LDA     #WCHAN_LBOLT
_ctp023         JSL     _FarSh_SleepUn          ; shim sets DBR = core bank
                PLD                             ; kernel-C page back
                RTL

;------------------------------------------------------------------------------
; `kc_getbyte', `kc_pollbyte' and `kc_ttflushpend' STOOD HERE and went at T6
; increment 4b, with the pump that was their only caller.
;
; THEY EXISTED BECAUSE FGX HAD NO RECEIVE INTERRUPT.  Upstream never pumps a
; line from the reader -- bytes enter the discipline where they ARRIVE, a
; device receive interrupt for a real line and `ptcwrite' for a pty
; (vendor/2.11BSD/usr/sys/sys/tty_pty.c:439 calls `l_rint' per character) --
; so with no keyboard interrupt that could run a discipline, the reader had to
; fetch.  The heartbeat calls `kc_ttyinput' now, which is what `dzrint' does,
; and there is nothing left to fetch.
;
; `kc_ttflushpend' went for the same reason from the other end: it existed
; because the heartbeat CONSUMED a `^C' to post the signal rather than ringing
; the key, so the discipline never saw it and its own flush never ran.
; `ttyinput' sees it now and runs upstream's own
; `if ((t_flags&NOFLSH)==0) ttyflush(tp, FREAD|FWRITE)', which is the WIDER
; flush.
;------------------------------------------------------------------------------

;------------------------------------------------------------------------------
; The three per-process reads ttwrite's background gate needs.  apple/fgx#108
; T3, and read src/kernel/far_shims.s's block above _FarSh_CurPgrp for WHY they
; are field reads rather than one predicate call: both BSD trees put the
; job-control predicate in the tty layer, and Reno's `isbackground(p, tp)' is
; HANDED the proc rather than reaching a global.
;
; Each answers a neutral value when there is no current task, so the gate cannot
; fire during boot: no group, no controlling terminal, not a vfork child.
;
; All three swap D to the kernel's REAL page: the scheduler table and the signal
; tables are reached through DP long pointers.
;------------------------------------------------------------------------------
; kc_curpgrp() -> `u.u_procp->p_pgrp', 0 when there is no current task.
kc_curpgrp      MX      %00
                PHD
_ctp024         JSL     _FarSh_KernDP
                TCD
_ctp025         JSL     _FarSh_CurPgrp
                PLD
                RTL

; kc_curctty() -> the caller's controlling-terminal INDEX, -1 for none.  BSD's
; `tp == u.u_ttyp' is a pointer compare; FGX keeps the ctty as an index, so the
; caller compares indices.
kc_curctty      MX      %00
                PHD
_ctp026         JSL     _FarSh_KernDP
                TCD
_ctp027         JSL     _FarSh_CurCtty
                PLD
                RTL

; kc_isvforked() -> 1 if the caller still holds its parent, else 0.
; `p_flag&SVFORK'.
kc_isvforked    MX      %00
                PHD
_ctp028         JSL     _FarSh_KernDP
                TCD
                JSR     kt_holdsparent
                LDA     #0
                BCC     @iv_no
                INC
@iv_no          PLD
                RTL

;------------------------------------------------------------------------------
; kt_holdsparent - C=1 if the running task still holds its parent, BSD's
; `p_flag & SVFORK': a vfork child (SEF_VFORKCHILD), or a snapshot fork child
; that has not yet released it (SEF_SNAPCHILD without SEF_FORKREL) -- until
; its first interruptible sleep the parent waits on WCHAN_VFORK for it.
; Boot (no task) is not.  D = the kernel's real page.  MX %00.  Clobbers A, Y.
;------------------------------------------------------------------------------
kt_holdsparent  MX      %00
                LDA     _curTask
                AND     #$00FF
                BEQ     @hp_no
                DEC
                ASL
                ASL
                ASL
                ASL
                ASL                             ; (pid-1) * SE_SIZE
                CLC
                ADC     #SE_Flags
                TAY
                LDA     [_schedTblPtr],Y
                BIT     #SEF_VFORKCHILD
                BNE     @hp_yes
                AND     #SEF_SNAPCHILD+SEF_FORKREL
                CMP     #SEF_SNAPCHILD
                BNE     @hp_no
@hp_yes         SEC
                RTS
@hp_no          CLC
                RTS

;------------------------------------------------------------------------------
; _KTty_SigHold - slot 55.  A = a pending signal -> C=1 if it must stay
; pending: a stop signal while the running task still holds its parent.
; 2.11BSD issignal(): `if (p->p_flag&SVFORK) mask &= ~stopsigmask;' -- a stop
; waits until the child execs, exits or lets its parent go, then acts.
; Stopping it sooner would stop the parent with it.  D = the kernel's real
; page (the signal scan's).  MX %00.  Clobbers A, Y.
;------------------------------------------------------------------------------
_KTty_SigHold   MX      %00
                CMP     #SIGSTOP
                BEQ     @sh_stop
                CMP     #SIGTSTP
                BEQ     @sh_stop
                CMP     #SIGTTIN
                BEQ     @sh_stop
                CMP     #SIGTTOU
                BEQ     @sh_stop
                CLC
                RTL
@sh_stop        JSR     kt_holdsparent
                RTL

;------------------------------------------------------------------------------
; kc_ttobuf() -> `char *' at THIS TASK's `u.u_ttyobuf'.
; kc_ttobufsz() -> how many bytes are there.
;
; `ttwrite's staging buffer.  Upstream declares it `char obuf[OBUFSIZ]' on the
; kernel stack (2.11BSD tty.c:1322) and FGX cannot: 100 bytes is a fifth of
; FGX_KSTK_SIZE, and through a `/dev' node `ttwrite' runs with the whole vnode
; chain of fcc frames still under it.  Measured at 516 of 512 -- a machine reset
; with no diagnostic, since `_fcc_stkfloor' is zero on FGX_DP_KERNELC.
; apple/fgx#246, and `U_TtyObuf' in include/kernel.s carries the argument.
;
; PER TASK, NOT A STATIC IN THIS BANK.  `ttwrite' holds the buffer across
; `kc_lbolt' and across the high-watermark sleep, so two writers on one static
; would be apple/fgx#89 exactly.  A u-area address is stable for as long as the
; task exists, which is the property U_TtyIov/U_TtyUio are already there for.
;
; THE POINTER COMES BACK IN `_fcc_fpr0' (offset) and `_fcc_fpr0+2' (bank).
; That is fcc's far-pointer return and it was READ OFF THE COMPILER rather than
; assumed: every `tty_byidx' call site takes its result from exactly those two
; cells and ignores A (tty_dev.s, after each `PILECALL').
;
; `_u' IS ON THE KERNEL'S REAL PAGE and `_fcc_fpr0' is on the C one, so the two
; halves sit either side of the PLD -- the offset parked in X and the bank in Y
; across it, which is kc_curpgrp's dance with a result to carry out.
;------------------------------------------------------------------------------
kc_ttobuf       MX      %00
                PHD
_ctp059         JSL     _FarSh_KernDP           ; A = the kernel's REAL DP
                TCD
                LDA     _u                      ; the u-area's offset...
                CLC
                ADC     #U_TtyObuf
                TAX                             ; ...parked across the PLD
                SEP     #$20
                MX      %10
                LDA     _u+2                    ; ...and its bank, one byte:
                REP     #$30                    ;   `_u' is a THREE-byte cell
                MX      %00                     ;   (dpmap.s:287)
                AND     #$00FF
                TAY
                PLD                             ; back on the C register file
                STX     _fcc_fpr0
                SEP     #$20
                MX      %10
                TYA
                STA     _fcc_fpr0+2
                REP     #$30
                MX      %00
                TXA                             ; A = the offset, as fcc leaves
                RTL                             ;   it on the way out

; The LENGTH is asked for rather than spelled, so `U_TTYOBUF_LEN' is the one
; authority and the chunk size cannot outrun the reservation.  That is why
; upstream's OBUFSIZ #define is gone from tty.h instead of sitting beside it.
kc_ttobufsz     MX      %00
                LDA     #U_TTYOBUF_LEN
                RTL

;------------------------------------------------------------------------------
; kc_sigopted(sig, which) -> 1 if the caller has opted out of `sig'.
; which = 0 asks p_sigignore (SIG_IGN), 1 asks p_sigmask (blocked).
;
; ONE SHIM WITH A SELECTOR, not two.  The two differ only in a table base and
; _Sig_CurOpted already takes that base as an argument; two entry points would
; be two export slots and two manifest rows saying the same thing.  Upstream
; still tests the two fields SEPARATELY at every background gate, and the C
; keeps doing that -- what is shared here is the lookup, not the test.
;
; 4 argument bytes: sig (2) + which (2).
;------------------------------------------------------------------------------
kc_sigopted     MX      %00
                PHD                             ; save the kernel-C page
_ctp030         JSL     _FarSh_KernDP           ; A = the kernel's REAL DP
                TCD
                LDA     8,S                     ; re-push the 4 argument bytes
                PHA                             ;   (PHD moved them up by 2)
                LDA     8,S
                PHA
_ctp031         JSL     _FarSh_SigOpted         ; shim sets DBR = core bank
                TAY                             ; park the answer
                TSC
                CLC
                ADC     #4                      ; drop the re-pushed arguments
                TCS
                PLD                             ; kernel-C page back
                TYA
                RTL

;------------------------------------------------------------------------------
; kc_uid() -> the caller's effective uid, 0 for root.
;
; A field read like kc_curpgrp, and the same shape.  ttioctl reads it four
; times; upstream's `u.u_uid' is the only u-area field of the six this file
; reaches for that FGX actually keeps in a u-area.
;------------------------------------------------------------------------------
kc_uid          MX      %00
                PHD                             ; save the kernel-C page
_ctp035         JSL     _FarSh_KernDP           ; A = the kernel's REAL DP
                TCD
_ctp036         JSL     _FarSh_CurUid           ; A = effective uid
                TAY                             ; park it across the PLD
                PLD                             ; kernel-C page back
                TYA
                RTL

;------------------------------------------------------------------------------
; kc_spgok(pgrp) -> 1 if the caller may hand a tty to that process group.
;
; THE WHOLE OF upstream's TIOCSPGRP TEST IN ONE CALL, and the core's header on
; _Se_SpgOk argues why: `pfind' is Task_Lookup and the rest is _Spg_Permitted,
; both of which live over there already.  Porting pfind and inferior into this
; bank would be re-implementing a predicate the other side owns.
;
; 2 argument bytes: pgrp.
;------------------------------------------------------------------------------
kc_spgok        MX      %00
                PHD                             ; save the kernel-C page
_ctp037         JSL     _FarSh_KernDP           ; A = the kernel's REAL DP
                TCD
                LDA     6,S                     ; re-push pgrp (PHD moved it up)
                PHA
_ctp038         JSL     _FarSh_SpgOk            ; A = 1 permitted, 0 refuse
                TAY                             ; park the answer
                TSC
                CLC
                ADC     #2                      ; drop the re-pushed argument
                TCS
                PLD                             ; kernel-C page back
                TYA
                RTL

;------------------------------------------------------------------------------
; kc_pendsig() -> long, the caller's WHOLE pending-signal mask.
;
; No arguments, so this is kc_curpgrp's shape rather than kc_sigopted's -- the
; argument re-push above exists only to carry arguments past the PHD.
;
; LONG, AND THAT IS DELIBERATE.  fcc returns a long in A (low) and
; _fcc_long_hi (high).  A 16-bit answer would fit the register and lose the
; half that matters: this kernel numbers pending bits `byte = sig>>3,
; bit = sig&7' with NO decrement, so signals 16..23 -- SIGURG through SIGTTOU,
; every job-control signal there is -- live in byte 2.  ttycheckoutq's caller is
; a tty-blocked printer, so that is the worst half to be blind to.
;
; STX AFTER THE PLD, AND THE ORDER IS THE WHOLE ROUTINE.  _fcc_long_hi is $EC
; (far/fcc_dp.s:43) on the kernel-C page, and $EC on the kernel's REAL page --
; which is what D holds between the TCD and the PLD -- is _conTmp5, a console
; scratch (dpmap.s:399).  Storing the high word one instruction earlier would
; drop it AND corrupt the console, silently, and only when a signal was pending
; in the high half.
;------------------------------------------------------------------------------
kc_pendsig      MX      %00
                PHD                             ; save the kernel-C page
_ctp033         JSL     _FarSh_KernDP           ; A = the kernel's REAL DP
                TCD
_ctp034         JSL     _FarSh_SigPending       ; A = bytes 0,1  X = bytes 2,3
                PLD                             ; kernel-C page back FIRST
                STX     _fcc_long_hi            ;   ...only now is $EC ours
                RTL

;------------------------------------------------------------------------------
; kc_selwakeup() - BSD's selwakeup.  No arguments, no return.
;
; UPSTREAM'S TWO ARGUMENTS ARE DROPPED, AND THAT IS THE PORT, NOT A SHORTCUT.
; selwakeup(p, coll) names the proc that registered in tp->t_rsel and whether
; two selectors collided on this tty.  FGX's select(2) registers on nothing --
; _Sys_Select polls and yields, and its block-forever arm sleeps on the single
; WCHAN_SELECT -- so there is no recorded proc to name and no per-tty collision
; to distinguish.  Passing a t_rsel that is always 0 and a collision bit nothing
; sets would be two arguments that look meaningful and are not.
;
; D IS SWAPPED because _wakeup walks the scheduler table through _schedTblPtr on
; the kernel's own page, the same reason kc_wakeup swaps.
;------------------------------------------------------------------------------
kc_selwakeup    MX      %00
                PHD                             ; save the kernel-C page
_ctp012         JSL     _FarSh_KernDP           ; A = the kernel's REAL DP
                TCD
_ctp013         JSL     _FarSh_SelWakeup        ; shim sets DBR = core bank
                PLD                             ; kernel-C page back
                RTL

;------------------------------------------------------------------------------
; kc_gsignal(pgrp, sig) - post sig to every task in process group pgrp.
;
; BSD's gsignal, over the core's _Kill_GroupFanout -- the same fan-out
; _Sys_Kill's group forms already use.  The tty bank holds
; the pgid in its own `struct tty' t_pgrp, so nothing here consults _ttyTable.
;
; 4 argument bytes: pgrp (2) + sig (2).  Re-pushed rather than aliased, as
; kc_uiomove's note explains.
;------------------------------------------------------------------------------
kc_gsignal      MX      %00
                PHD                             ; save the kernel-C page
_ctp014         JSL     _FarSh_KernDP           ; A = the kernel's REAL DP
                TCD
                LDA     8,S                     ; re-push pgrp + sig (PHD moved
                PHA                             ;   them up by 2)
                LDA     8,S
                PHA
_ctp015         JSL     _FarSh_Gsignal          ; shim sets DBR = core bank
                TSC
                CLC
                ADC     #4                      ; drop the re-pushed arguments
                TCS
                PLD                             ; kernel-C page back
                RTL

;------------------------------------------------------------------------------
; kc_cdstop_now(dev, rw) - cdevsw[].d_stop, as this bank can reach it.
;
; `_now' BECAUSE IT IS NOT THE ONE THE DISCIPLINE CALLS.  `kc_cdstop' is a C
; wrapper in tty_dev.c that defers to the output rail when the discipline is
; running at interrupt time, and calls this when it is not.  A chardev dispatch
; cannot run in the heartbeat: `_Chardev_Dispatch' self-modifies one shared
; five-byte JSL cell whose critical region runs through the device call
; (chardev.s:501).  T6 increment 4b.
;
; HALTS OUTPUT ALREADY IN FLIGHT, and nothing else: every caller has set
; TS_TTSTOP itself before getting here, so the software stop is the tty
; layer's and this is only the hardware half.  A device with nothing in flight
; has a zero slot and _Chardev_Stop returns without dispatching -- which is
; 2.11BSD's own arrangement for its console (pdp/conf.c gives `cn' nulldev
; here), not an FGX shortfall.
;
; 4 argument bytes: dev (2) + rw (2).
;------------------------------------------------------------------------------
kc_cdstop_now   MX      %00
                PHD                             ; save the kernel-C page
_ctp016         JSL     _FarSh_KernDP           ; A = the kernel's REAL DP
                TCD
                LDA     8,S                     ; re-push dev + rw (PHD moved
                PHA                             ;   them up by 2)
                LDA     8,S
                PHA
_ctp017         JSL     _FarSh_CdStop           ; shim sets DBR = core bank
                TSC
                CLC
                ADC     #4                      ; drop the re-pushed arguments
                TCS
                PLD                             ; kernel-C page back
                RTL

;------------------------------------------------------------------------------
; kc_panic(msg) - name the failure, then halt.
;
; It HALTS rather than returning.  Its one caller so far is ttyrub's `default:'
; arm, which upstream reaches only when t_flags names an erase mode that does
; not exist -- a broken invariant, and continuing past it would rub out
; characters against a screen state the terminal does not have.
;
; THE NAME IS PRINTED FIRST.  A halt with no name has cost this project whole
; sessions; far/kc_sys.s says the same thing beside its own copy, and so does
; _Slp_StkLockPanic in sched.s.
;
; DBR STAYS ON THE TTY BANK ACROSS THE LOG CALL, and that is the whole reason
; this cannot be a plain forward to the core's panic.  `msg' points at an fcc
; string literal in THIS bank's data segment; Kern_LogStr walks it with the
; CALLER's DBR, and _FarSh_LogStr is the one shim that leaves DBR alone.
; Forcing the core bank here would print whatever sits at the same offset in
; the core kernel -- which is not a wrong message, it is a plausible one.
;
; Structurally identical to far/kc_sys.s's kc_panic.  That is deliberate: the
; two banks reach the core the same way and a reader who knows one knows this.
;------------------------------------------------------------------------------
kc_panic        MX      %00
                LDA     4,S                     ; msg offset, in the TTY bank
                PHD
                PHA
_ctp007         JSL     _FarSh_KernDP           ; kernel's REAL direct page
                TCD                             ; _conStrPtr is a kernel DP cell
                PLA
                STA     _conStrPtr
_ctp008         JSL     _FarSh_LogStr           ; leaves DBR = tty, on purpose
_ctp009         JSL     _FarSh_Halt             ; never returns
                PLD                             ; unreachable; present so the
                RTL                             ;   frame reads as balanced


;------------------------------------------------------------------------------
; kc_spltty() -> int  /  kc_splx(s).  apple/fgx#108 T6 increment 2.
;
; UPSTREAM'S INTERRUPT-PRIORITY BRACKET, WITH A BODY AT LAST.  `spltty()' and
; `splx()' were `#define spltty() 0' / `#define splx(s)' from the day tty.c
; landed, and src/kernel/tty/ttyparam.h has named this the landing site ever
; since: "these two macros are where the real bracket goes on that day".  The
; SEVENTY call sites in tty.c and tty_subr.c are upstream's own and did not
; move; only what they mean changed.
;
; THE PRIMITIVE IS THE I FLAG, and it is not a new one -- it is the same
; masking THIS KERNEL'S SCHEDULER ALREADY CALLS spl.  `_sleep' (sched.s):
;
;     The caller must re-test its wait condition under SEI (spl) and only then
;     call _sleep, to avoid a lost wakeup ... _sleep keeps IRQs masked across
;     the switch and CLIs on wake.
;
; So a `spltty()' region that sleeps is what the scheduler ASKS for rather than
; something to be defended against, which is why `ttywait' -- the one blocking
; call inside an spl region in the whole bank -- needs no adaptation.
;
; ONE DIFFERENCE FROM UPSTREAM'S `sleep', STATED RATHER THAN LEFT TO BE FOUND:
; `_sleep' CLIs on wake UNCONDITIONALLY, where upstream's restores the caller's
; priority.  An spl region that continues past a sleep is therefore already at
; spl0.  `ttywait' re-raises on the very next line (`splx(s); s = spltty();'),
; which is upstream's own text -- so there the `splx' is the no-op and the
; re-take is the work.  A future region that sleeps and then keeps going
; without re-taking would be running unprotected; check_spl_balance.py names
; every such site so it cannot appear unnoticed.
;
; WHAT `spltty' RETURNS is the I bit as it was, not a priority LEVEL: the 65816
; has one mask and no levels, so `splx' can only put back what was there.  That
; makes the pair nest correctly, which is what the call sites assume.
;
; THE WIDTHS ARE THE TRAP HERE.  `PHP' pushes ONE byte and the callers run
; MX %00, so a bare `PLA' would pull two and take a byte of whatever is under
; it.  Hence the SEP/REP around the pull, and the `AND #$00FF' after it: the
; high half of A is B, which held something else entirely.
;
; TTY-BANK LOCAL, reached by JSL within the bank.  Every other kc_* seam here
; pays a cross-bank shim because it reaches CORE state; these touch nothing but
; P, and a shim crossing per `putc' would put this increment's whole cost in
; the one place it cannot be afforded.
;
; kc_spltty: no arguments.  kc_splx: 2 argument bytes, the saved bit.
;------------------------------------------------------------------------------
kc_spltty       MX      %00
                PHP                             ; one byte: P is 8 bits
                SEI
                SEP     #$20
                MX      %10
                PLA                             ; A.lo = the P that was
                AND     #$04                    ; ...and only its I bit
                REP     #$20
                MX      %00
                AND     #$00FF                  ; B held something else
                RTL

kc_splx         MX      %00
                LDA     4,S                     ; the bit kc_spltty returned
                AND     #$0004
                BNE     @kx_keep                ; they were masked: leave them
                CLI
@kx_keep        RTL

;------------------------------------------------------------------------------
; kc_todsnap / kc_todstore / kc_tickset -- kern_time.c's three doors onto the
; core's time of day (include/memmap.s, `_kTodSec' on).
;
; UNDER SEI, AND THAT IS THE WHOLE POINT OF DOING IT HERE.  The heartbeat adds
; one tick to `_kTodFrac' and carries into `_kTodSec' at interrupt time, so a
; copy taken a word at a time with interrupts open could pair a second from
; before a carry with a fraction from after it and read a whole second wrong.
; 2.11BSD takes the same copy the same way: `s = splhigh(); atv = time; ms =
; lbolt; splx(s);' (vendor/2.11BSD/usr/sys/sys/kern_time.c:36).  PHP/PLP puts
; the caller's I back, so a caller that was already masked stays masked.
;
; kc_todsnap: sec lo/hi, frac lo/hi and _kSystemTicks lo/hi into tod_snap[6].
; kc_todstore: tod_new[4] (sec lo/hi, frac lo/hi) into the clock.
; kc_tickset: tod_tick[2] into `_kTickFrac'.
; No arguments; the arrays are kern_time.c's globals, in this bank, which is
; DBR here as it is for all of this bank's C.
;------------------------------------------------------------------------------
kc_todsnap      MX      %00
                PHP
                SEI
_ctp060         LDAL    _kTodSec
                STA     tod_snap
_ctp061         LDAL    _kTodSec+2
                STA     tod_snap+2
_ctp062         LDAL    _kTodFrac
                STA     tod_snap+4
_ctp063         LDAL    _kTodFrac+2
                STA     tod_snap+6
_ctp064         LDAL    _kSystemTicks
                STA     tod_snap+8
_ctp065         LDAL    _kSystemTicks+2
                STA     tod_snap+10
                PLP
                RTL

kc_todstore     MX      %00
                PHP
                SEI
                LDA     tod_new
_ctp066         STAL    _kTodSec
                LDA     tod_new+2
_ctp067         STAL    _kTodSec+2
                LDA     tod_new+4
_ctp068         STAL    _kTodFrac
                LDA     tod_new+6
_ctp069         STAL    _kTodFrac+2
                PLP
                RTL

kc_tickset      MX      %00
                PHP
                SEI
                LDA     tod_tick
_ctp070         STAL    _kTickFrac
                LDA     tod_tick+2
_ctp071         STAL    _kTickFrac+2
                PLP
                RTL

; kc_rootfstime -- the root superblock's fs_time, which root_mount.c left in
; `_kRootFsTime' for inittodr's base.  A long, which fcc returns in A (low)
; and _fcc_long_hi (high); D is the caller's kernel-C page throughout, so the
; high word goes straight there (kc_pendsig above has to PLD first).
kc_rootfstime   MX      %00
_ctp072         LDAL    _kRootFsTime+2
                STA     _fcc_long_hi
_ctp073         LDAL    _kRootFsTime
                RTL

;------------------------------------------------------------------------------
; kc_rtcread / kc_rtcwrite -- the battery clock, through Misc Tools
; ReadTimeHex ($0D03) and WriteTimeHex ($0E03), with tod_rtc[6] as the frame:
; sec, min, hour, year-1900, day-1, month-1, one byte each, `_rtcFrame''s
; layout (far/clock.s).  inittodr's read and resettodr's write, which FreeBSD's
; own routines make directly (vendor/FreeBSD-2.2.8/sys/i386/isa/clock.c:709,
; :771).  WriteTimeHex takes ReadTimeHex's packing, first-named field in the
; high byte (Toolbox Ref vol.1 p.626-627).
;
; THREE RULES, ALL FROM far/clock.s's _RtcFwRead, which learned each of them
; the hard way:
;   * INTERRUPTS OFF for the whole excursion.  The tool's WAIT path drops to
;     emulation mode, and a tick taken in there cannot be resumed reliably.
;   * D = $0000.  The ROM keeps 6502-style zero-page scratch at whatever D it
;     inherits, and hangs with a non-zero one.
;   * A PAGE-$01 STACK.  The same SEC/XCE truncates S to its low byte, so a
;     call on a per-task kernel stack returns into the weeds.  A caller already
;     on page $01 keeps its own stack; anyone else moves to $01FF.  The saved S
;     is `tod_rtcsp', a kern_time.c global, because nothing on the stack can
;     be reached once S has moved.
; Nothing DP-relative may appear between the TCD and the PLD.  No arguments,
; no return.
;------------------------------------------------------------------------------
kc_rtcread      MX      %00
                PHP
                SEI
                PHD                             ; on the CALLER's stack
                TSC
                STA     tod_rtcsp
                XBA
                AND     #$00FF                  ; the caller's stack page
                CMP     #$0001
                BEQ     *+6                     ; page $01 already: keep S
                LDA     #FGX_STK_KERNEL+$FF     ; $01FF
                TCS
                LDA     #$0000
                TCD
                PEA     $0000                   ; weekday|pad (pulled last)
                PEA     $0000                   ; month|day
                PEA     $0000                   ; year|hour
                PEA     $0000                   ; minute|second (pulled first)
                LDX     #$0D03                  ; ReadTimeHex
                JSL     $E10000
                PLA                             ; minute|second
                STA     tod_rtc
                PLA                             ; year|hour
                STA     tod_rtc+2
                PLA                             ; month|day
                STA     tod_rtc+4
                PLA                             ; weekday|pad: dropped
                LDA     tod_rtcsp               ; the caller's stack back
                TCS
                PLD
                PLP
                RTL

kc_rtcwrite     MX      %00
                PHP
                SEI
                PHD
                TSC
                STA     tod_rtcsp
                XBA
                AND     #$00FF
                CMP     #$0001
                BEQ     *+6                     ; page $01 already: keep S
                LDA     #FGX_STK_KERNEL+$FF
                TCS
                LDA     #$0000
                TCD
                LDA     tod_rtc+4               ; month (hi) | day (lo)
                PHA
                LDA     tod_rtc+2               ; year-1900 (hi) | hour (lo)
                PHA
                LDA     tod_rtc                 ; minute (hi) | second (lo)
                PHA
                LDX     #$0E03                  ; WriteTimeHex
                JSL     $E10000                 ; consumes the three words
                LDA     tod_rtcsp
                TCS
                PLD
                PLP
                RTL

;------------------------------------------------------------------------------
; kc_log(msg) -- a line to the kernel log, and back.  kc_panic without the
; halt, for inittodr's `Invalid time in real time clock' (FreeBSD clock.c:765):
; the same DBR rule applies, `msg' being an fcc literal in THIS bank.
; 2 argument bytes: msg's offset.
;------------------------------------------------------------------------------
kc_log          MX      %00
                LDA     4,S                     ; msg offset, in the TTY bank
                PHD
                PHA
_ctp074         JSL     _FarSh_KernDP           ; kernel's REAL direct page
                TCD                             ; _conStrPtr is a kernel DP cell
                PLA
                STA     _conStrPtr
_ctp075         JSL     _FarSh_LogStr           ; leaves DBR = tty, on purpose
                PLD
                RTL
