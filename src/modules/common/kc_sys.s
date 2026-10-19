;==============================================================================
; kc_sys.s (shared) - the C-TO-KERNEL direction of the kernel-C seam, for C
; compiled into an FGXM MODULE rather than the far kernel bank.
;
; SHARED BY EVERY C MODULE, and it became shared rather than copied the moment
; there were two of them (ufs.mod, apple/fgx#169).  The seam is identical on
; both sides -- same services, same signatures, same direct-page argument --
; so a second copy would be two files that have to be fixed in lockstep, which
; is the drift this tree refuses everywhere else.  Nothing here names a
; particular module; the storage below is module-LOCAL by virtue of being
; assembled into whichever image PUTs it.
;
; THE C DOES NOT CHANGE.  This file provides the same five C-callable symbols
; src/kernel/far/kc_sys.s provides -- kc_sleep, kc_wakeup, kc_panic, kc_blkio,
; kc_blkreads -- with the same signatures and the same return conventions.  Only
; how they REACH the kernel differs: the far bank JSLs _FarSh_* shims at
; addresses scraped from the kernel listing, and a module cannot, because it
; does not know the kernel's bank at build time.  A module goes through the
; bank-0 gateway instead, whose addresses are fixed by construction.
;
; That substitution is the whole of what far.s meant by "promoting a subsystem
; out of here into a real module later is a LINK CHANGE, NOT A REWRITE".
;
;------------------------------------------------------------------------------
; TWO THINGS THE FAR BANK GETS FOR FREE AND A MODULE MUST ARRANGE.
;
; 1. DBR.  The KSVC dispatcher does PHB/PHK/PLB itself (jumptable.s
;    _Sys_KCallImpl), so it lands on the kernel bank whatever the caller had.
;    Nothing to do here -- and that is worth stating, because the obvious
;    defensive PHK/PLB in these shims would be wrong: PHK in a MODULE yields
;    the MODULE's bank, so it would point the dispatcher at the wrong one.
;
; 2. THE DIRECT PAGE, which the dispatcher does NOT set.  Its arms touch kernel
;    DP cells -- @kc_logstr writes _conStrPtr at $E0 -- so D must be the
;    kernel's real page, and kernel C runs on FGX_DP_KERNELC instead.  Every
;    shim below therefore brackets its call with PHD / TCD / PLD, exactly as
;    the far bank's shims do around _FarSh_KernDP.
;
; WHERE THE KERNEL'S DP COMES FROM, and why not the obvious places.  It is the
; RUNNING TASK'S SLOT PAGE, which the scheduler publishes in the bank-0 cell
; KFGX_CUR_KDP (include/kernel.s), and these shims read it there with LDAL.
;
; BANK 0 IS THE ONLY BANK A MODULE CAN NAME.  _kFgxDPKernel and _kCurKDP both
; need DBR on the kernel bank, and these shims are called from C with DBR on
; the MODULE's bank -- reading a kernel-bank absolute there is apple/fgx#93
; exactly.  LDAL of a kernel symbol would bake a bank at assembly time, which
; ufsdir.s calls the trap that has cost this tree two sessions.  KFGX_ANCHOR
; would work and costs a bank-0 read PLUS a DBR switch per call; this costs the
; bank-0 read alone.
;
; A CACHED PAGE IS NOT THE ANSWER, and that was apple/fgx#468.  The page used to
; be captured once at mod_init, where D is the page the loader ran on: pid 0's
; template, whose `_curTask' reads 0.  Every kernel routine that asks who is
; running from the direct page therefore answered 0 for every task -- kc_curuid
; returned root for every caller (jumptable.s @kc_curuid), a driver open bound
; nothing (ttyv.s), and KSVC_SLEEP marked the wrong TCB blocked and never saved
; the caller, so `cat /dev/klog' hung and ^C could not reach it.  The page is
; per-task; it cannot be read once and kept.
;==============================================================================

;------------------------------------------------------------------------------
; ENTERK / LEAVEK - bracket a kernel service call from inside kernel C.
;
; Arguments that must survive the switch are parked on the STACK rather than in
; a register, because TCD needs A.  The far bank does the same thing around its
; _FarSh_KernDP call and for the same reason.
;------------------------------------------------------------------------------
ENTERK          MAC
                PHD                             ; the kernel-C page
                LDAL   KFGX_CUR_KDP            ; bank 0: no DBR dependency
                TCD                             ; D = the task's own slot page
                <<<

LEAVEK          MAC
                PLD                             ; kernel-C page back
                <<<

;------------------------------------------------------------------------------
; ARGUMENTS ARE READ AFTER THE BRACKET, and the +2 is ENTERK's PHD.
;
; The far bank reads its argument BEFORE switching and parks it on the stack,
; because there the direct page arrives in A from a _FarSh_KernDP CALL and A is
; therefore not free.  Here it arrives from a load, so the argument can simply
; be read after the switch -- stack-relative addressing does not depend on D.
; That removes the park, and with it the ordering hazard the park creates: a
; PHA before ENTERK is popped by ENTERK's own PHD, not by the PLA that follows.
;------------------------------------------------------------------------------

;------------------------------------------------------------------------------
; kc_sleep(chan) - block until kc_wakeup names the same channel.
;
; UNINTERRUPTIBLE, matching the far bank's choice and for its reason: a buffer
; wait has no error path to take.  getblk does `b_flags |= B_WANTED;
; kc_sleep(bp); goto loop;` and biowait does `while (!(b_flags & B_DONE))
; kc_sleep(bp);` -- both re-test and loop, so an interruptible sleep's "a signal
; is pending, I did not sleep" answer does not abandon the wait, it spins at
; full speed for as long as the signal stays pending.
;
; KSVC_SLEEPUN, NOT KSVC_SLEEP, AND THE DIFFERENCE COST A REVIEW TO FIND.  The
; first cut of this file called KSVC_SLEEP and asserted in this very comment
; that jumptable.s routed it to _sleepUn.  It does not and never did: KSVC_SLEEP
; is pty.mod's service and goes to _sleep, the INTERRUPTIBLE one, which is
; correct for a read(2) on an empty ring and wrong here.  The far bank called
; _FarSh_SleepUn and got the right routine; the module quietly got the other.
; No checker could see it -- check_fs_sleep_invariant polices WHERE a sleep
; happens, not WHICH -- and the boot probe cannot reproduce it, being
; single-tasked with no signal pending and no contention.  It would have gone
; live with 1.6b.
;
; A COMMENT ASSERTING A ROUTING IS NOT EVIDENCE OF IT.  Follow the arm.
;------------------------------------------------------------------------------
kc_sleep        MX      %00
                ENTERK
                LDA     6,S                     ; chan = pointer OFFSET
                LDX     #KSVC_SLEEPUN
                JSL     SYS_KCALL
                LEAVEK
                RTL

;------------------------------------------------------------------------------
; kc_sleepi(chan) -> 0 slept and woken, 1 a signal ended (or prevented) it.
;
; THE INTERRUPTIBLE ONE: KSVC_SLEEP, pty.mod's service, which reaches _sleep
; and answers in A (jumptable.s @kc_sleep).  For a wait with an error path --
; flock(2)'s wait for a conflicting lock, upstream's `tsleep(..., PLOCK |
; PCATCH, ...)' -- where a signal must end the call with EINTR rather than be
; ignored.  kc_sleep above is the one for a wait that has none.
;------------------------------------------------------------------------------
kc_sleepi       MX      %00
                ENTERK
                LDA     6,S                     ; chan = pointer OFFSET
                LDX     #KSVC_SLEEP
                JSL     SYS_KCALL
                LEAVEK
                RTL

;------------------------------------------------------------------------------
; kc_wakeup(chan) - make every task waiting on chan runnable.  Does not switch.
;------------------------------------------------------------------------------
kc_wakeup       MX      %00
                ENTERK
                LDA     6,S
                LDX     #KSVC_WAKEUP
                JSL     SYS_KCALL
                LEAVEK
                RTL

;------------------------------------------------------------------------------
; kc_blkio(dev, blkhi, blklo, addr, isread) -> 0 on success, else errno.
;
; One 512-byte device transfer.  IT MUST NOT SLEEP, and that is not a style
; preference: it is the property that makes biowait's sleep unreachable and so
; keeps every remaining sleep in the filesystem above the block driver.
; SmartPort PIO spins and the RAM disk copies, so nothing here can block.
;
; THE ARGUMENTS SPLIT THREE WAYS, and the split is why this is not a
; transcription of the far bank's version:
;
;   _blkNum, _blkNumHi, _blkBuf, _fsCurDevIdx are DIRECT PAGE, so they are
;   written here -- correct the moment D is the kernel's page, with no DBR.
;
;   The buffer BANK is not.  _blkBufBank is a core-bank static ($10-$1F was
;   full), so writing it needs DBR on the kernel bank, which a module cannot
;   establish without naming a kernel address.  It rides in A through
;   KSVC_BLKIO and the kernel arm stores it -- the same division of labour
;   _FarSh_BlkIo has, arrived at for the same reason.
;
;   The direction rides in Y, because X is the KSVC selector.
;
; SYS_BLKREAD/SYS_BLKWRITE are the wrong gateway slots for this and it is worth
; saying why they are not simply used: they take no arguments at all, so the
; buffer bank would be left at whatever the last caller stored, and 0 there
; means "the live kernel bank" -- the one bank the VFS buffer arena is not in.
;
; Stack, with the caller's args above ENTERK's PHD:
;   6,S dev   8,S blkhi   10,S blklo   12,S addr offset   14,S addr bank
;   16,S isread
;------------------------------------------------------------------------------
kc_blkio        MX      %00
                ENTERK                          ; the block layer's args are DP
                                                ;   cells, so D must be right
                                                ;   BEFORE they are written
                LDA     10,S                    ; block number, low word
                STA     _blkNum
                LDA     8,S                     ; block number, high word --
                STA     _blkNumHi               ;   consumed and zeroed by the
                                                ;   Blk_* entry latch, so it is
                                                ;   set per transfer, not once
                LDA     12,S                    ; buffer offset
                STA     _blkBuf
                SEP     #$20
                MX      %10
                LDA     6,S                     ; device index (low byte)
                STA     _fsCurDevIdx
                REP     #$30
                MX      %00
                LDA     16,S                    ; isread -> Y, since X selects
                TAY                             ;   the service
                LDA     14,S                    ; buffer BANK -> A, for the arm
                AND     #$00FF
                LDX     #KSVC_BLKIO
                JSL     SYS_KCALL
                BCS     @kbi_ok
                AND     #$00FF                  ; C=0: A = errno from the driver
                BRA     @kbi_out
@kbi_ok         LDA     #0
@kbi_out        LEAVEK
                RTL

;------------------------------------------------------------------------------
; kc_blkreads() -> the kernel's device-read count, low word.
;
; No direct page switch, because nothing here touches a DP cell -- the counter
; is a core-bank static and the arm's own DBR is all that is needed.  The
; routines above switch D only because the block layer's parameters live there.
;------------------------------------------------------------------------------
kc_blkreads     MX      %00
                LDX     #KSVC_BLKREADS
                JSL     SYS_KCALL
                RTL

;------------------------------------------------------------------------------
; kc_curpid() - which process is running.  -> A = pid, 1..VFS_NPROC.
;
; The VFS indexes its per-process nameidata slots with this (UFS 1.2).
;
; ENTERK IS LOAD-BEARING, AND THE FIRST VERSION OF THIS SHIM OMITTED IT.
;
; _curTask is a kernel DIRECT PAGE cell ($9E), and jumptable.s's @kc_curpid
; therefore assembles `LDA _curTask` as `A5 9E` -- a DP read, resolved against
; whatever D is in effect.  _Sys_KCallImpl sets DBR only (PHB/PHK/PLB); it does
; NOT touch D, exactly as the header of this file says.  So without the bracket
; the arm reads offset $9E on FGX_DP_KERNELC -- a slot in fcc's REGISTER FILE --
; and returns a compiler temporary that looks exactly like a plausible pid.
;
; The first version carried a comment asserting the dispatcher had already
; switched D.  It had not.  That is the same shape as the KSVC_SLEEP comment
; that claimed a routing to _sleepUn which never existed: a sentence about a
; guard is not the guard.  Follow the arm.
;
; CALL IT EVERY TIME; DO NOT CACHE IT IN A C STATIC.  A pid read before a sleep
; names a different process after one (apple/fgx#41), and here that would index
; another process's nameidata.
;------------------------------------------------------------------------------
kc_curpid       MX      %00
                ENTERK                          ; for _curTask's DP, not for DBR
                LDX     #KSVC_CURPID
                JSL     SYS_KCALL
                LEAVEK
                RTL

;------------------------------------------------------------------------------
; kc_curuid() / kc_curgid() - the caller's EFFECTIVE ids.  -> A.
;
; UFS campaign 2.6's permission checks.  `ufs_access' needs to know who is
; asking, and the u-area that knows is in bank 0 while the check runs in a
; module bank.
;
; ENTERK FOR THE SAME REASON kc_curpid GIVES, and it matters more here.  The
; arm calls `_Uarea_Cur', which reads `_curTask' from the kernel DIRECT PAGE;
; without the bracket that read lands in fcc's register file and returns a
; compiler temporary.  For a pid that produced a wrong nameidata slot.  For a
; uid it would produce a wrong ANSWER TO A PERMISSION QUESTION, and the value
; that means "allow everything" is 0.
;
; CALL THEM EVERY TIME.  kc_curpid's warning applies -- a value read before a
; sleep names a different process after one -- and setuid(2) adds a second
; case: the ids can move under a task that never slept.
;------------------------------------------------------------------------------
kc_curuid       MX      %00
                ENTERK                          ; for _curTask's DP
                LDX     #KSVC_CURUID
                JSL     SYS_KCALL
                LEAVEK
                RTL

kc_curgid       MX      %00
                ENTERK
                LDX     #KSVC_CURGID
                JSL     SYS_KCALL
                LEAVEK
                RTL

;------------------------------------------------------------------------------
; _Mod_StampFnPtrs - write this module's own bank into every &function cell.
;
; WHAT IS BROKEN WITHOUT IT (apple/fgx#173).  fcc's --module-bank emits an
; &function data cell as MOD_FN_PTR: offset, bank byte, pad.  The offset is
; assembled -- a module is one Merlin link -- but the bank is chosen by
; Bank_Alloc at LOAD time, so the byte leaves the assembler zero.  An indirect
; call reads it, so until this runs every function pointer in the image names
; bank $00.
;
; PHK IS THE ANSWER AND IT IS ONLY AVAILABLE HERE.  Inside mod_init the program
; bank IS this module's bank, so PHK yields the one thing the assembler could
; not know.  That is the whole difference from the kernel far bank, whose
; runtime bank nothing can name at any point -- which is why KFAR_FN_PTR leaves
; its byte dead and takes the bank from PHK at each CALL instead.  That works
; only while there is one bank, and stopped being true when UFS got its own.
;
; MUST RUN BEFORE ANY C.  A single dispatch through an unstamped cell is a JMP
; to bank 0.
;
; In:  nothing.  MX %00.  Called from mod_init with the module's bank in PB.
; Out: nothing.  A/X/Y clobbered; DBR and P preserved.
;------------------------------------------------------------------------------
_mfpBank        DS      2       ; MODBANK-OK: mod_init only (DBR=ours below).

_Mod_StampFnPtrs MX     %00
                PHP
                REP     #$30
                MX      %00
                PHB
                PHK
                PLB                     ; DBR = ours: the table is in this image
                SEP     #$20
                MX      %10
                PHK
                PLA                     ; A = our RUNTIME bank -- the byte the
                                        ;   assembler could not write
                STA    |_mfpBank
                REP     #$30
                MX      %00
                LDY     #0
@sfp_L          CPY     #_modFnPtrBytes
                BCS     @sfp_done
                LDA    |_modFnPtrTab,Y  ; the cell's BANK-BYTE address
                TAX
                SEP     #$20
                MX      %10
                LDA    |_mfpBank
                ; `|` IS LOAD-BEARING, and for the reason ufs.s records at its
                ; own vtable copy: without it Merlin sees a $0000 operand,
                ; shortens the mode and emits `95 00` -- STA DIRECT PAGE,X --
                ; which scribbles fcc's register file instead of the cell.  It
                ; does not warn; the instruction is legal.
                STA    |$0000,X
                REP     #$30
                MX      %00
                INY
                INY
                BRA     @sfp_L
@sfp_done       PLB
                PLP
                RTS


;------------------------------------------------------------------------------
; kc_time() / kc_ltime() -> long: the kernel clock's seconds, UTC or local.
;
; KSVC_TIME, which asks the kernel clock in the tty bank
; (src/kernel/tty/kern_time.c) -- 2.11BSD's `time.tv_sec', a memory load
; there.  The service hands the long back in A and X; fcc wants it in A and
; `_fcc_long_hi', which is on the page D names here, the caller's kernel-C
; page.  No arguments, so no stack offsets, and no ENTERK: nothing on the way
; touches a direct-page cell (the service's stub sets and restores its own D).
;------------------------------------------------------------------------------
kc_time         MX      %00
                LDY     #0                      ; UTC
                BRA     kc_time1
kc_ltime        MX      %00
                LDY     #1                      ; local time
kc_time1        LDX     #KSVC_TIME
                JSL     SYS_KCALL               ; -> A = low word, X = high
                STX     _fcc_long_hi
                RTL

;------------------------------------------------------------------------------
; kc_ticks(buf) - the 60 Hz tick counter, 32 bits, into a 4-byte MODULE buffer.
;
; apple/fgx#182.  This exists so kern_time() can stop paying a firmware
; excursion for a number BSD reads out of a global -- MEASURED at 3.6 ms per
; call against a 0.1 ms syscall floor (src/userland/rtcbench), and holding
; interrupts off throughout.
;
; THE BUFFER MUST BE IN THIS MODULE'S DATA BANK, which is the rule every
; DBR-relative buffer in this tree follows.  The dispatcher restores the
; caller's DBR before returning, so on the RTL below DBR is ours and the stores
; are plain absolute,Y against it.  fcc pushes a far pointer for an array
; argument -- offset at 4,S, bank at 6,S -- and the bank is deliberately NOT
; consulted: honouring it would need a long pointer, which would need a
; direct-page pair, and the shared DP scratch here is held live across calls by
; the block-cache pin path.  A module static is what both callers have.
;
; THE OFFSET GOES THROUGH A, because LDY HAS NO STACK-RELATIVE MODE.  Only the
; eight "accumulator" operations take dp,S on this processor; `LDY 4,S` is not
; an addressing mode and merlin32 rejects it.  A and X are both live results at
; that point, so they are parked and pulled back rather than recomputed.
;
; NO ENTERK: nothing here touches a direct-page cell.
;
; Stack (no PHD, so the args start at 4,S):
;   4,S buf offset   6,S buf bank (unused, see above)
;------------------------------------------------------------------------------
kc_ticks        MX      %00
                LDX     #KSVC_TICKS
                JSL     SYS_KCALL       ; -> A = lo16, X = hi16, C=1
                PHA                     ; park the results: the offset below
                PHX                     ;   has to come through A
                LDA     8,S             ; buf offset (4,S plus the two pushes)
                TAY
                PLX                     ; hi16 back
                PLA                     ; lo16 back
                STA     $0000,Y         ; absolute,Y -- STA has no dp,Y mode,
                TXA                     ;   so this cannot be mis-assembled
                STA     $0002,Y         ;   short
                LDA     #0
                RTL

;==============================================================================
; THE CHARACTER DEVICE SWITCH, for kernel C.  UFS 1.13b.
;
; Five shims onto the chardev registry (src/kernel/chardev.s), so that
; spec_vnops.c's VCHR arms -- a panic naming 1.13 since 1.7b -- can reach a
; real driver.  Reno would dispatch cdevsw[major(dev)]; FGX has one major and
; an INDEX into a registry, so these take that index.
;
; EVERY ONE OF THEM ENTERKs, AND NOT FOR ITS OWN SAKE.  None of these shims
; touches a direct-page cell; the routines they reach do.  The registry table
; is a Kmalloc'd soft-global addressed through _cdTablePtr, a KERNEL direct-page
; long pointer, and every _Chardev_* entry point dereferences it -- so a call
; made with the module's D reads the chardev table out of fcc's register file
; and gets plausible garbage.  _Sys_KCallImpl sets DBR only; it does NOT touch
; D, which is the trap kc_curpid above documents at length.  ENTERK is what
; makes that true here too.
;
; PER BYTE, WHICH IS THE REGISTRY'S SHAPE.  _Chardev_Read hands back one byte
; and _Chardev_Write takes one; spec_read/spec_write loop over them with a
; uio.
;==============================================================================

;------------------------------------------------------------------------------
; kc_cdlookup(name) -> chardev index 0..15, or -1 if there is no such device.
;
; `name` is a NUL-terminated string in the CALLER's bank ("null", "console").
; A registry index is handed out in registration ORDER, so it is not a number
; a caller may bake -- this is how one is found.
;
; Stack, with the caller's args above ENTERK's PHD:
;   6,S name offset   8,S name bank
;------------------------------------------------------------------------------
kc_cdlookup     MX      %00
                ENTERK
                LDA     8,S                     ; name BANK -> Y, since X
                AND     #$00FF                  ;   selects the service
                TAY
                LDA     6,S                     ; name offset
                LDX     #KSVC_CDLOOKUP
                JSL     SYS_KCALL
                BCC     @kcl_none
                AND     #$00FF                  ; C=1: A.lo = the index
                BRA     @kcl_out
@kcl_none       LDA     #$FFFF                  ; -1: no device of that name
@kcl_out        LEAVEK
                RTL

;------------------------------------------------------------------------------
; kc_cdopen(idx) -> 0, or an errno.
;------------------------------------------------------------------------------
kc_cdopen       MX      %00
                ENTERK
                LDA     6,S
                AND     #$00FF
                LDX     #KSVC_CDOPEN
                JSL     SYS_KCALL
                BCS     @kco_ok
                AND     #$00FF                  ; C=0: A = errno
                BRA     @kco_out
@kco_ok         LDA     #0
@kco_out        LEAVEK
                RTL

;------------------------------------------------------------------------------
; kc_cdclose(idx) -> 0, or an errno.
;
; The DRIVER's teardown runs only on the registry's last open; earlier closes
; return success without dispatching.  That counting is _Chardev_Close's, and
; it is NOT the same question spec_close's vcount answers -- one counts opens
; of the device, the other counts vnodes naming it.
;------------------------------------------------------------------------------
kc_cdclose      MX      %00
                ENTERK
                LDA     6,S
                AND     #$00FF
                LDX     #KSVC_CDCLOSE
                JSL     SYS_KCALL
                BCS     @kcc_ok
                AND     #$00FF
                BRA     @kcc_out
@kcc_ok         LDA     #0
@kcc_out        LEAVEK
                RTL

;------------------------------------------------------------------------------
; kc_cdread AND kc_cdwrite MOVED to ../ufsdir/kc_chardev.s, beside the bulk pair,
; on the rule that file's own header states: only vfs.mod's C calls them, and a
; routine one module needs belongs to that module.  They also need CHARDEV_MAX
; and VFS_IO_NDELAY now, for apple/fgx#310's index|ioflag encoding, and neither
; constant is PUT by every module.
;------------------------------------------------------------------------------

;------------------------------------------------------------------------------
; kc_panic(msg) - name the failure, then halt.
;
; It HALTS rather than returning, because every caller is a broken-invariant
; check (biodone on a buffer already done; bgetvp on a buffer that is not
; free).  Continuing past one of those corrupts a cache other tasks are reading.
;
; The name is printed FIRST.  A halt with no name has cost this project whole
; sessions before -- SYS_PANIC prints the five letters "PANIC" and hangs, and
; nothing else.
;
; DBR IS ALREADY RIGHT AND MUST BE LEFT ALONE.  msg points at an fcc string
; literal in THIS MODULE's data segment; KSVC_LOGSTRNE reads the string through
; the CALLER's DBR (jumptable.s @kc_logstr does PLB before touching it); and
; kernel C runs with DBR = this module's bank, because MOD_KC_ENTER put it
; there.  So the pointer resolves correctly with no switch at all.  Adding the
; defensive PHK/PLB that looks right here is what printed hellokc's probe value
; with no prefix -- one level up from apple/fgx#93 and the same shape.
;
; D is NOT already right: @kc_logstr writes _conStrPtr, a kernel DP cell.
;------------------------------------------------------------------------------
kc_panic        MX      %00
                ENTERK                          ; for _conStrPtr, not for DBR
                LDA     6,S                     ; msg offset, in THIS bank
                LDX     #KSVC_LOGSTRNE
                JSL     SYS_KCALL
                LDX     #KSVC_LOGEOL
                JSL     SYS_KCALL
                JSL     SYS_PANIC               ; never returns
                LEAVEK                          ; unreachable; present so the
                RTL                             ;   frame reads as balanced
