;==============================================================================
;
; FGX - Flux GS uniX
;
; File:     ttybank.s
; Purpose:  Tty kernel bank segment root
; Created:  2026-08-22
;
; The THIRD statically linked kernel image, at live kernel bank + 2.  It holds
; the BSD tty layer: struct tty, the clists, and the line discipline as the
; increments of apple/fgx#108 land them.
;
; WHY IT IS A BANK AND NOT A MODULE, measured rather than assumed.  FGX's tty
; INPUT discipline runs at INTERRUPT time -- toolbox.s's 60 Hz heartbeat reads
; the line's mode word, applies SG_RAW and posts _kTtySigPend -- and it is live
; from Toolbox_InstallHB (main.s), 152 lines of boot before Mod_LoadConf.  A
; module cannot be there.  And the layer is ~46,900 bytes of ported C against
; 18,411 free in the far bank, so it cannot go there either.  See
; docs/history/plans/2026-08-22-tty-bsd-shape-placement-survey.md.
;
; NOT an FGXM module, for the same reasons far.s is not: loaded by stage 2
; before a filesystem exists, and free to call Kmalloc and _sleep.
;
; BANK-AGNOSTIC.  This file ORGs at FGX_KTTY_CODE ($09:0000) for assembly only.
; At runtime the image lives in the kernel handle's second headroom bank and
; every entry point does PHK/PLB so DBR becomes whatever bank it was loaded
; into.
;
; See docs/history/plans/tty-kernel-bank.md.
;
;==============================================================================

                MX      %00             ; 16-bit A, X, Y (native mode default)

                PUT     ../../../include/config.s
                PUT     ../../../include/hardware.s
                PUT     ../../../include/kernel.s
                PUT     ../../../include/errno.s
                PUT     ../../../include/loader.s       ; signal numbers (_KTty_SigHold)
                PUT     ../../../include/macros.s
                PUT     ../../../include/dpmap.s        ; DUM $00 block: DP offsets
                                                ;   only, emits no bytes.  DP is
                                                ;   reached through D, not DBR, so
                                                ;   these resolve identically in
                                                ;   any bank.
;--- memmap.s is DUM-only (emits no bytes).  CAUTION, exactly as in far.s: it
;--- names the CORE kernel's statics, and those must be reached with a
;--- _ctp-marked LDAL, never `LDA |sym`, or they resolve against THIS bank at
;--- the same offset.
                PUT     ../../../include/memmap.s
                PUT     ../../../include/ktty.s

;--- The kernel-C seam: fcc's direct-page slot map, and the asm->C boundary
;--- macros.  Both are EQU/MAC only and emit nothing here.  fcc_dp.s is
;--- GENERATED (tools/gen_fcc_dp.py) into the FAR bank's directory and shared
;--- from there rather than generated twice: it is the compiler's own slot map,
;--- identical for every bank, and two copies of a generated file is two things
;--- to keep in step for no gain.
                PUT     ../far/fcc_dp.s
                PUT     ../../../include/kernelc.s

                ORG     FGX_KTTY_CODE

;==============================================================================
; The export table.  FIRST thing in the bank -- see include/ktty.s for why.
;
; Slots are JMP abs16 and are NEVER patched: the caller's JSL has already set
; PBR to this bank, so a 16-bit JMP lands correctly.
;
; Every unassigned slot jumps to _Ktty_StubHalt rather than falling through, so
; an accidental call fails loudly instead of executing whatever follows.
;==============================================================================
                DW      KTTY_MAGIC              ; +0  'KT'
                DW      KTTY_ABI_VERSION        ; +2
                DW      0                       ; +4  reserved

                ; --- slot 0: the init entry ---
                JMP     Tty_BankInit
                DFB     0

                ; --- slot 1: boot-state reporting ---
                JMP     Tty_LogState
                DFB     0

                ; --- slots 2-3: kernel C ---
                JMP     cinit
                DFB     0
                ; SLOTS 3 AND 4 EXIST EITHER WAY, because a slot's ADDRESS is
                ; its identity: dropping them would renumber
                ; every slot above and silently repoint the core's calls.  With
                ; the probes gated out they take the same red-border halt an
                ; unassigned slot takes, so a caller that was not gated with
                ; them stops the machine instead of getting a plausible answer.
                JMP     _Ktty_StubHalt  ; probe removed 2026-09-07;
                DFB     0               ;  SLOT KEPT: its address is
                                        ;  its identity
                JMP     _Ktty_StubHalt  ; probe removed 2026-09-07;
                DFB     0               ;  SLOT KEPT: its address is
                                        ;  its identity
                ; --- slot 5: a retired probe's slot, kept as a
                ; stub so the table does not renumber. ---
                JMP     _Ktty_StubHalt  ; probe removed 2026-09-07;
                DFB     0               ;  SLOT KEPT: its address is
                                        ;  its identity

                ; --- slot 7 comes after slot 6 below; the table is positional
                ; and slot 6 was already here, so the new half takes 7 rather
                ; than displacing a binding every kernel needs.
                ; --- slot 6: tty_devinit.  NOT GATED, and that is the point:
                ; it BINDS the devices, it does not test them.  It sat inside
                ; the probes until they went behind a flag, at which point
                ; the default kernel bound nothing -- see _TtyDevInit in main.s.
                JMP     tty_devinit
                DFB     0

                ; --- slot 7: a retired probe's slot, kept as a
                ; stub so the table does not renumber. ---
                JMP     _Ktty_StubHalt  ; probe removed 2026-09-07;
                DFB     0               ;  SLOT KEPT: its address is
                                        ;  its identity

                ; --- slots 8-11: the core bank's window onto struct tty.
                ; UNGATED, unlike every probe slot above: these are production
                ; state accessors, and T3's cutover makes the core bank unable
                ; to find a foreground process group without them. ---
                JMP     Tty_PgrpGet
                DFB     0
                JMP     Tty_PgrpSet
                DFB     0
                JMP     Tty_FlagsGet
                DFB     0
                JMP     Tty_FlagsSet
                DFB     0

                ; --- slot 12: kc_ttioctl, the core bank's door into ttioctl.
                ; UNGATED like 8-11 and for the same reason: it is production
                ; dispatch, not a probe.  Straight at the C function with no
                ; wrapper, per the note on slots 2-3 -- the caller's JSL leaves
                ; exactly the 3-byte frame fcc reads its arguments against. ---
                JMP     kc_ttioctl
                DFB     0

                ; --- slot 13: kc_ttychars.  Production init, ungated.
                ; ON THE STUB, not the C: apple/fgx#268, the shape
                ; `_KTty_Carrier' established.  The core's wrapper was a seam
                ; bracket and nothing else. ---
                JMP     _KTty_Chars
                DFB     0

                ; --- slot 14: Tty_IntrQuit, assembly.  See include/ktty.s. ---
                JMP     Tty_IntrQuit
                DFB     0

                ; --- slot 15: Tty_WinSzSet, assembly.  See include/ktty.s. ---
                JMP     Tty_WinSzSet
                DFB     0

                ; --- slot 16: Tty_EraseKill, assembly.  See include/ktty.s. ---
                JMP     Tty_EraseKill
                DFB     0

                ; --- slot 17: kc_ttwrite, the core's door into the discipline's
                ; write half.  Straight at the C function like slot 12, per the
                ; note on slots 2-3. ---
                JMP     kc_ttwrite
                DFB     0

                ; --- slot 18: a retired probe's slot, kept as a
                ; stub so the table does not renumber. ---
                JMP     _Ktty_StubHalt  ; probe removed 2026-09-07;
                DFB     0               ;  SLOT KEPT: its address is
                                        ;  its identity

                ; --- slot 19: kc_ttread, the core's door into the
                ; discipline's read half.  Slot 17's twin. ---
                JMP     kc_ttread
                DFB     0

                ; --- slot 20: kc_ttflush, the core's door onto ttyflush.
                ; ON THE STUB since apple/fgx#268 took `_Tty_Flush' out of
                ; the core bank: the staging the core wrapper used to do is
                ; `_KTty_Flush's now, so the four callers JSL the slot. ---
                JMP     _KTty_Flush
                DFB     0

                ; --- slot 21: kc_ttnread, select(2)'s readiness answer.
                ; ON THE STUB, for slot 13's reason. ---
                JMP     _KTty_NRead
                DFB     0

                ; --- slot 22: kc_ttopen, the discipline's l_open.  T4
                ; increment 2: what sets TS_ISOPEN, and nothing in this kernel
                ; had ever called it. ---
                JMP     _KTty_LineOpen
                DFB     0

                ; --- slot 23: kc_ttmodem, the discipline's l_modem.  T4
                ; increment 2: the master's presence is the slave's carrier. ---
                JMP     _KTty_Modem
                DFB     0

                ; --- slot 24: kc_ttclose, the discipline's l_close and then
                ; ttyclose.  T4 increment 3: what makes a line a cycle. ---
                JMP     _KTty_LineClose
                DFB     0

                ; --- slot 25: kc_ptyoproc, ptcopen/ptcclose's two lines.  T4
                ; increment 4: a pty slave line's t_oproc is ptsstart, which
                ; wakes and moves nothing.  ON THE STUB, not the C:
                ; apple/fgx#268, the shape `_KTty_Carrier' established. ---
                JMP     _KTty_PtyOproc
                DFB     0

                ; --- slot 26: kc_ttoutq_run, ndqb -- how many contiguous
                ; bytes the master may take now. ---
                JMP     _KTty_OutqRun
                DFB     0

                ; --- slot 27: kc_ttoutq_cf, where that run starts. ---
                JMP     kc_ttoutq_cf
                DFB     0

                ; --- slot 28: kc_ttoutq_flush, ndflush + ttyowake. ---
                JMP     kc_ttoutq_flush
                DFB     0

                ; --- slot 29: kc_ttoutq_uio, the same dequeue delivered
                ; through a uio -- cdevsw's d_read route (apple/fgx#198). ---
                JMP     kc_ttoutq_uio
                DFB     0

                ; --- slot 30: a retired probe's slot, kept as a
                ; stub so the table does not renumber. ---
                JMP     _Ktty_StubHalt  ; probe removed 2026-09-07;
                DFB     0               ;  SLOT KEPT: its address is
                                        ;  its identity

                ; --- slot 31: kc_ttstopped, TS_TTSTOP for a driver a bank
                ; away.  The half of `ptsstart's packet arm this bank can
                ; answer; pty.mod holds the other (PF_STOPPED). ---
                JMP     _KTty_Stopped
                DFB     0

                ; --- slot 32: kc_ttselect, `ttyselect' for a driver a bank
                ; away.  `_PtyS_Poll' answered POLLOUT out of a ring increment
                ; 4 stopped feeding; this is the queue that holds the bytes.
                ; ON THE STUB, not the C: apple/fgx#268. ---
                JMP     _KTty_Select
                DFB     0

                ; --- slot 33: kc_irqprobe, the callee that proves the
                ; interrupt-time register file is a second one (T6). ---
                JMP     kc_irqprobe
                DFB     0

                ; --- slot 34: kc_splprobe, the case that can tell a real
                ; spl bracket from the empty macros it replaced (T6 inc 2). ---
                JMP     kc_splprobe
                DFB     0

                ; --- slot 35: kc_ptcinput, `ptcwrite's inner loop for one
                ; byte -- the master's write feeds the discipline (T6 4a).
                ; ON THE STUB, not the C: apple/fgx#268. ---
                JMP     _KTty_PtcInput
                DFB     0

                ; --- slot 36: a retired probe's slot, kept as a
                ; stub so the table does not renumber. ---
                JMP     _Ktty_StubHalt  ; probe removed 2026-09-07;
                DFB     0               ;  SLOT KEPT: its address is
                                        ;  its identity

                ; --- slot 37: `ptcselect's FWRITE arm -- the complement of
                ; slot 35, so a master's select and its write cannot disagree
                ; (T6 4a).
                ;
                ; IT LANDS ON A STUB, the apple/fgx#268 shape `_KTty_Carrier'
                ; established one slot family over: the marshalling that stood
                ; in the CORE bank as `_Tty_PtcWritable' is on this side now. ---
                JMP     _KTty_PtcWritable
                DFB     0

                ; --- slot 38: kc_ttyinput, the RECEIVE INTERRUPT's door into
                ; the discipline (T6 increment 4b).  Landed INERT: nothing
                ; calls it until the heartbeat does.  DECLARING THE EQU IS NOT
                ; ASSIGNING THE SLOT -- increment 5 spent a run on exactly
                ; that, with slot 31 named in include/ktty.s while still inside
                ; the stub run below, and a stub halt looks like NO VERDICT AND
                ; NO FAILURE from outside.  Through _Ktty_IrqTtyinput, which
                ; keeps fcc's static scratch across the interrupt. ---
                JMP     _Ktty_IrqTtyinput
                DFB     0

                ; --- slot 39: kc_ttdrain, the SOFT half of the output rail
                ; (T6 increment 4b).  The ISR marks TS_TIMEOUT; this restarts
                ; every marked line from task context, through `ttrstrt'. ---
                JMP     kc_ttdrain
                DFB     0

                ; --- slot 40: kc_ttgetraw, ONE RAW BYTE from a line
                ; (T6 increment 4b).  SYS_GETKEY/SYS_POLLKEY read the caller's
                ; CONTROLLING TERMINAL through this instead of dequeuing a
                ; second copy of the keystroke from `_kKbdRing'.  Mode
                ; independent, because "one raw key" is those syscalls' whole
                ; contract; see include/ktty.s.  ON THE STUB, not the C:
                ; apple/fgx#268. ---
                JMP     _KTty_GetRaw
                DFB     0

                ; --- slot 41: TS_CARR_ON for a driver a bank away.
                ; `ptcread' decides EOF on the carrier and not on whether a
                ; slave is open right now (apple/fgx#266).
                ;
                ; IT LANDS ON A STUB RATHER THAN ON kc_ttcarrier DIRECTLY, and
                ; that is the apple/fgx#268 shape: the marshalling that used to
                ; sit in the CORE bank as `_Tty_Carrier' is now on this side of
                ; the seam, where the bank derivation is a PHK instead of a
                ; PHK/INC/INC and the caller needs no bracket at all. ---
                JMP     _KTty_Carrier
                DFB     0

                ; --- slot 42: tty_devbind, the BINDING half of tty_devinit.
                ; Called again after any module registers a chardev, because
                ; /dev/tty01's driver is a module and modules load from
                ; /etc/rc -- long after main.s's one tty_devinit.  It lands on
                ; the C directly, like slot 6: no argument, and the answer is
                ; the count, which nothing reads.
                JMP     tty_devbind
                DFB     0

                ; --- slot 43: tod_init, the kernel clock's inittodr
                ; (kern_time.c).  No argument, so it lands on the C directly
                ; like slot 42; the core brackets it with KTTY_KC_ENTER. ---
                JMP     tod_init
                DFB     0

                ; --- slot 44: gettimeofday(2).  A stub, the _KTty_Carrier
                ; shape, because the syscall hands over a far pointer in A and
                ; X that the C wants as one argument. ---
                JMP     _KTty_Gtod
                DFB     0

                ; --- slot 45: adjtime(2), slot 44's shape. ---
                JMP     _KTty_Adj
                DFB     0

                ; --- slot 46: settimeofday(2), slot 44's shape. ---
                JMP     _KTty_Stod
                DFB     0

                ; --- slot 47: sysctl(2)'s machdep node, slot 44's shape. ---
                JMP     _KTty_Sysctl
                DFB     0

                ; --- slot 48: KSVC_TIME, the kernel clock for kernel C in a
                ; module.  A stub: Y in, a long back in A and X. ---
                JMP     _KTty_Now
                DFB     0

                ; --- slots 49-54: shared-library residency (ld_hooks.s). ---
                JMP     _Ld_Ctl
                DFB     0
                JMP     _Ld_Exit
                DFB     0
                JMP     _Ld_Fork
                DFB     0
                JMP     _Ld_Exec
                DFB     0
                JMP     _Ld_Talloc
                DFB     0
                JMP     _Ld_Reclaim
                DFB     0
                JMP     _KTty_SigHold           ; 55
                DFB     0

                ; --- slots 56-62: the shared-text table (text.s) ---
                JMP     _KTty_TextFind
                DFB     0
                JMP     _KTty_TextClaim
                DFB     0
                JMP     _KTty_TextReclaim
                DFB     0
                JMP     _KTty_TextUnref
                DFB     0
                JMP     _KTty_TextFork
                DFB     0
                JMP     _KTty_TextSet
                DFB     0
                JMP     _KTty_TextFill          ; 62
                DFB     0
                JMP     _KTty_TextTotal         ; 63
                DFB     0

                ; --- slots 64.. unassigned, stride 4 (3-byte JMP + 1 pad).
                ; Growing KTTY_SLOT_COUNT is on the terms include/ktty.s states:
                ; it moves where the bank's code starts and renumbers nothing --
                ; slot n is KTTY_SLOT0 + 4n and KTTY_SLOT0 is fixed. ---
                LUP     KTTY_SLOT_COUNT-64
                JMP     _Ktty_StubHalt
                DFB     0
                --^
                ; The same guard the far bank now carries, for the same reason:
                ; a LUP whose count has gone negative emits NOTHING and merlin
                ; says nothing, so the stubs above would quietly cease to exist
                ; the first time the assigned slots outgrew KTTY_SLOT_COUNT.
                ; That is not hypothetical -- it is what the far bank did, from
                ; slot 32 until apple/fgx#210.  This bank is well inside its
                ; reservation today; the point is that it cannot leave it quietly.
                ERR     *-{FGX_KTTY_CODE+KTTY_TABLE_SZ}


;==============================================================================
; _KTty_Carrier - slot 41's entry.  A.lo = tty index -> A = 1 carrier up / 0.
;
; THE FIRST OF THE INWARD STUBS, and apple/fgx#268 is why they exist.  The core
; bank's `_Tty_Carrier' did all of this from the other side: KTTY_KC_ENTER to
; put D on FGX_DP_KERNELC and DBR on this bank, the argument push, the JSL
; through this slot, then KTTY_KC_LEAVE.  Seventeen lines of the bank that has
; none to spare, to reach a bank that has eleven kilobytes.
;
; DOING IT HERE IS STRICTLY CHEAPER, not merely tidier.  KTTY_KC_ENTER has to
; DERIVE this bank -- PHK, INC, INC -- because the core cannot name it; a stub
; already running here gets it from PHK alone.  And the caller keeps its
; registers without a bracket, so the core side of a call like this collapses
; to `LDA idx / JSL <slot>'.
;
; X AND Y ARE PRESERVED because `_Tty_Carrier' preserved them and its caller
; (jumptable.s's KSVC arm) was written against that.  A stub that quietly
; stopped would be a defect with no failing test: the arm's X and Y are dead by
; the time it returns today, so nothing would notice until something read them.
;
; THE C IS REACHED BY A PILE CALL, not by JSL.  fcc's functions are RTL
; routines and a same-bank JSL would bake this file's ORG bank ($09) into the
; operand -- the bank the kernel does NOT run in.  PHK supplies the live one.
; `_Vfs_DevRW' in the far bank is the same idiom for the same reason, and
; tools/check_far_rtl_calls.py is what notices when someone writes the JSR.
;==============================================================================
_KTty_Carrier   MX      %00
                PHY
                PHX
                PHA                             ; the index, read back below
                PHB
                PHD
                PHK
                PLB                             ; DBR = the LIVE tty bank
                LDA     #FGX_DP_KERNELC
                TCD
                LDA     4,S                     ; D(2) B(1) then the index
                PHA                             ; arg1: idx
                PHK
                PEA     @ktc_ret-1
                PHK
                PEA     kc_ttcarrier-1
                RTL                             ; pile call into the C
@ktc_ret        TAY                             ; park it; the pops clobber A
                PLA                             ; drop arg1
                PLD
                PLB
                PLA                             ; drop the staged index
                TYA
                PLX
                PLY
                RTL


;==============================================================================
; _KTty_Gtod / _KTty_Stod / _KTty_Adj / _KTty_Sysctl - slots 44, 46, 45 and
; 47: gettimeofday(2), settimeofday(2), adjtime(2) and sysctl(2)'s machdep
; node.  A = the argument block's offset, X = its bank -> C=1 A=0,
; or C=0 A=errno.  One body, `_KTty_TodBlk', with the C to call in Y.
;
; The block is libc's, in the CALLING program's bank, so the pointer the C
; gets is X:A, built here.  X comes from `_Sys_CallerBank' loaded 16-bit over a
; one-byte cell, so its high byte is junk and is masked off before it becomes
; the pointer's bank word.
;
; The C is reached by a pile call for the reason _KTty_Carrier gives, and its
; address minus one travels in Y into the PHY that stands where a PEA would.
; X and Y are not preserved: the syscall dispatcher reads only A and the carry.
;==============================================================================
_KTty_Gtod      MX      %00
                LDY     #tod_gettimeofday-1
                BRA     _KTty_TodBlk
_KTty_Stod      MX      %00
                LDY     #tod_settimeofday-1
                BRA     _KTty_TodBlk
_KTty_Adj       MX      %00
                LDY     #tod_adjtime-1
                BRA     _KTty_TodBlk
_KTty_Sysctl    MX      %00
                LDY     #tod_sysctl-1
_KTty_TodBlk    MX      %00
                PHB
                PHD
                PHA                             ; the offset, read back below
                TXA
                AND     #$00FF                  ; the bank; X's high byte is junk
                PHA                             ; arg1 high word: the bank
                LDA     3,S                     ; the offset again
                PHA                             ; arg1 low word
                PHK
                PLB                             ; DBR = the LIVE tty bank
                LDA     #FGX_DP_KERNELC
                TCD
                PHK
                PEA     @ktg_ret-1
                PHK
                PHY                             ; the C, minus one
                RTL                             ; pile call into the C
@ktg_ret        TAY                             ; park it; the pops clobber A
                PLA                             ; drop arg1
                PLA
                PLA                             ; drop the staged offset
                PLD
                PLB
                TYA
                BNE     @ktg_err
                SEC                             ; C=1: done, A=0
                RTL
@ktg_err        CLC                             ; C=0: A = errno
                RTL

;==============================================================================
; _KTty_Now - slot 48's entry, KSVC_TIME.  Y = 0 for UTC, 1 for local ->
; A = the seconds' low word, X = the high word.
;
; tod_now returns a long, which fcc hands back in A and `_fcc_long_hi'.  That
; cell is on the kernel-C page, so X is loaded from it BEFORE the PLD gives the
; caller its D back.  The C is reached by a pile call for the reason
; _KTty_Carrier gives.
;==============================================================================
_KTty_Now       MX      %00
                PHB
                PHD
                PHY                             ; arg1: 0 UTC, 1 local
                PHK
                PLB                             ; DBR = the LIVE tty bank
                LDA     #FGX_DP_KERNELC
                TCD
                PHK
                PEA     @ktn_ret-1
                PHK
                PEA     tod_now-1
                RTL                             ; pile call into the C
@ktn_ret        TAY                             ; the low word
                LDX     _fcc_long_hi            ; the high, while D is still ours
                PLA                             ; drop arg1
                PLD
                PLB
                TYA
                RTL

;==============================================================================
; _KTty_Chars - slot 13's entry.  A.lo = tty INDEX; the C returns void.
;
; THE THIRD INWARD STUB, and `_KTty_Carrier' above carries the whole argument
; for the shape: the core's `_Tty_Chars' did nothing but cross the seam, and a
; stub already running in this bank gets the bank from PHK alone where
; KTTY_KC_ENTER has to derive it with PHK/INC/INC.
;
; A COMES BACK HOLDING THE INDEX, which is not decoration -- the core wrapper
; ended on `PLA' over its own staged copy, so every caller written against it
; got the index back in A whether it wanted it or not.  Preserving that costs
; nothing here and a stub that quietly stopped would be a defect with no
; failing test, exactly as the carrier's header says of X and Y.
;
; X AND Y ARE PRESERVED for that same reason: `_Tty_Chars' preserved them.
;==============================================================================
_KTty_Chars     MX      %00
                PHY
                PHX
                PHA                             ; the index, read back below
                PHB
                PHD
                PHK
                PLB                             ; DBR = the LIVE tty bank
                LDA     #FGX_DP_KERNELC
                TCD
                LDA     4,S                     ; D(2) B(1) then the index
                PHA                             ; arg1: idx
                PHK
                PEA     @ktch_ret-1
                PHK
                PEA     kc_ttychars-1
                RTL                             ; pile call into the C
@ktch_ret       PLA                             ; drop arg1
                PLD
                PLB
                PLA                             ; A = the staged index, which is
                                                ;   what the core wrapper left
                PLX
                PLY
                RTL


;==============================================================================
; _KTty_NRead - slot 21's entry.  A.lo = tty INDEX -> A = bytes a read(2) would
; return now, 0 = it would block.
;
; ITS ONLY CALLER IS ANOTHER CORE WRAPPER, `_Tty_PollReadable', which is why
; this one is worth moving even though nothing outside ttyv.s ever called it:
; the bracket was pure marshalling sitting in the bank that has no room, and
; the caller keeps its `_Se_TtyOffToIdx' conversion core-side either way.
;
; THE OFFSET-TO-INDEX CONVERSION DOES NOT MOVE.  `_Se_TtyOffToIdx' is core-bank
; code, so `_Tty_PollReadable' still converts before it calls -- the same
; division `_KTty_PtcWritable' records, and a stub that expected an offset
; would answer about somebody else's queue with no test able to tell, both
; being valid small integers.
;
; X AND Y ARE PRESERVED because `_Tty_NRead' preserved them and
; `_Tty_PollReadable' is written against that -- its own comment says so at the
; PHX ("_Se_TtyOffToIdx clobbers X; this does not").
;==============================================================================
_KTty_NRead     MX      %00
                PHY
                PHX
                PHA                             ; the index, read back below
                PHB
                PHD
                PHK
                PLB                             ; DBR = the LIVE tty bank
                LDA     #FGX_DP_KERNELC
                TCD
                LDA     4,S                     ; D(2) B(1) then the index
                PHA                             ; arg1: idx
                PHK
                PEA     @ktnr_ret-1
                PHK
                PEA     kc_ttnread-1
                RTL                             ; pile call into the C
@ktnr_ret       TAY                             ; park it; the pops clobber A
                PLA                             ; drop arg1
                PLD
                PLB
                PLA                             ; drop the staged index
                TYA
                PLX
                PLY
                RTL


;==============================================================================
; _KTty_PtcWritable - slot 37's entry.  A.lo = tty INDEX -> A = 1 / 0.
;
; THE SECOND INWARD STUB, and `_KTty_Carrier' above carries the argument for
; the shape: the core bank's wrapper did nothing but cross the seam, and doing
; it here is strictly cheaper because a stub already running in this bank gets
; the bank from PHK alone where KTTY_KC_ENTER has to derive it with PHK/INC/INC.
;
; THE INDEX AND NOT THE OFFSET, which is the one thing that does NOT move.
; `_Se_TtyOffToIdx' is core-bank code, so the KSVC arm still converts before it
; calls -- exactly as it does for the carrier.  A stub that expected an offset
; would read the wrong line and `ptcselect' would answer about somebody else's
; queue, which no test in the pty family would catch because both are valid
; small integers.
;
; X AND Y ARE PRESERVED because `_Tty_PtcWritable' preserved them and the arm
; was written against that.
;==============================================================================
_KTty_PtcWritable MX    %00
                PHY
                PHX
                PHA                             ; the index, read back below
                PHB
                PHD
                PHK
                PLB                             ; DBR = the LIVE tty bank
                LDA     #FGX_DP_KERNELC
                TCD
                LDA     4,S                     ; D(2) B(1) then the index
                PHA                             ; arg1: idx
                PHK
                PEA     @kpw_ret-1
                PHK
                PEA     kc_ptcwritable-1
                RTL                             ; pile call into the C
@kpw_ret        TAY                             ; park it; the pops clobber A
                PLA                             ; drop arg1
                PLD
                PLB
                PLA                             ; drop the staged index
                TYA
                PLX
                PLY
                RTL

; THE ONE-ARGUMENT ENTRY STUBS -- apple/fgx#268, the shape _KTty_PtcWritable
; established and _KTty_Carrier before it.  Each was a seam BRACKET in the core
; bank and nothing else: stage the index, switch DBR and the direct page, push
; one argument, call the C, unwind.  Every byte of that is marshalling, and
; marshalling does not have to live in the bank that is out of room.  The
; offset-to-index conversion STAYS core-side in both cases, because
; `_Se_TtyOffToIdx' is core code and the KSVC arm still runs it before the JSL.
_KTty_LineOpen  MX      %00
                PHY
                PHX
                PHA                             ; the index, read back below
                PHB
                PHD
                PHK
                PLB                             ; DBR = the LIVE tty bank
                LDA     #FGX_DP_KERNELC
                TCD
                LDA     4,S                     ; D(2) B(1) then the index
                PHA                             ; arg1: idx
                PHK
                PEA     @klo_ret-1
                PHK
                PEA     kc_ttopen-1
                RTL                             ; pile call into the C
@klo_ret        TAY                             ; park it; the pops clobber A
                PLA                             ; drop arg1
                PLD
                PLB
                PLA                             ; drop the staged index
                TYA
                PLX
                PLY
                RTL

; THE TWO-ARGUMENT ENTRY STUB.  Same argument as the one-argument stubs above
; -- the bracket is marshalling and marshalling does not have to sit in the
; bank that is out of room -- with `_Tty_Modem's staging shape rather than
; `_Tty_Stopped's: fcc reads its arguments RIGHT TO LEFT, so `flag' is pushed
; first and `idx' last.
_KTty_LineClose MX      %00
                PHY
                PHA                             ; staged: the index
                PHX                             ; staged: flag
                PHB
                PHD
                PHK
                PLB                             ; DBR = the LIVE tty bank
                LDA     #FGX_DP_KERNELC
                TCD
                LDA     4,S                     ; D(2) B(1) then flag
                PHA                             ; arg2: flag
                LDA     8,S                     ;   ...then the index
                PHA                             ; arg1: idx
                PHK
                PEA     @klc_ret-1
                PHK
                PEA     kc_ttclose-1
                RTL                             ; pile call into the C
@klc_ret        TAY                             ; park it; the pops clobber A
                PLA                             ; drop the two arguments
                PLA
                PLD
                PLB
                PLA                             ; drop the two staged words
                PLA
                TYA
                PLY
                RTL

_KTty_Modem     KTTY_STUB2 kc_ttmodem

;==============================================================================
; _KTty_PtyOproc - slot 25's entry.  A = tty index, X = 1 install / 0 clear.
; _KTty_Select   - slot 32's entry.  A = tty index, X = rw -> A = 1 ready / 0.
;
; apple/fgx#268, and they are the first two moves made AS a macro rather than
; as a transcription.  Both were seam brackets in `ttyv.s' and nothing else --
; stage, cross, unstage -- with one caller apiece in the core bank's KSVC
; dispatch, which now calls the slot directly.
;
; WHAT STAYS CORE-SIDE is what is not a crossing: `_Se_TtyOffToIdx', because
; the KSVC convention passes a byte OFFSET and the C wants an index, and the
; Y-to-X swap, because the convention owns Y and this shape owns X.
;==============================================================================
_KTty_PtyOproc  KTTY_STUB2 kc_ptyoproc
_KTty_Select    KTTY_STUB2 kc_ttselect
_KTty_GetRaw    KTTY_STUB2 kc_ttgetraw
_KTty_PtcInput  KTTY_STUB2 kc_ptcinput
_KTty_Flush     KTTY_STUB2 kc_ttflush

_KTty_Stopped   MX      %00
                PHY
                PHX
                PHA                             ; the index, read back below
                PHB
                PHD
                PHK
                PLB                             ; DBR = the LIVE tty bank
                LDA     #FGX_DP_KERNELC
                TCD
                LDA     4,S                     ; D(2) B(1) then the index
                PHA                             ; arg1: idx
                PHK
                PEA     @kst_ret-1
                PHK
                PEA     kc_ttstopped-1
                RTL                             ; pile call into the C
@kst_ret        TAY                             ; park it; the pops clobber A
                PLA                             ; drop arg1
                PLD
                PLB
                PLA                             ; drop the staged index
                TYA
                PLX
                PLY
                RTL

_KTty_OutqRun   MX      %00
                PHY
                PHX
                PHA                             ; the index, read back below
                PHB
                PHD
                PHK
                PLB                             ; DBR = the LIVE tty bank
                LDA     #FGX_DP_KERNELC
                TCD
                LDA     4,S
                PHA                             ; arg1: idx
                PHK
                PEA     @kor_ret-1
                PHK
                PEA     kc_ttoutq_run-1
                RTL                             ; pile call into the C
@kor_ret        TAY
                PLA                             ; drop arg1
                PLD
                PLB
                PLA                             ; drop the staged index
                TYA
                PLX
                PLY
                RTL

;==============================================================================
; _Ktty_StubHalt - an unassigned export slot was called.
;
; Red border and halt.  Same loud-failure contract _Far_StubHalt gives the far
; bank: a wild cross-bank jump must be obvious on the screen, not a silent
; wrong-execution.
;==============================================================================
_Ktty_StubHalt  SEP     #$20
                MX      %10
                LDA     #$01
                STAL    $E0C034                 ; border = red
@spin           BRA     @spin

;==============================================================================
; Tty_PgrpGet / Tty_PgrpSet / Tty_FlagsGet / Tty_FlagsSet -- the core bank's
; window onto `struct tty', for the fields that outlive the old discipline.
;
; ASSEMBLY, DELIBERATELY.  toolbox.s reads the foreground group at 60 Hz at
; INTERRUPT TIME, and include/kernelc.s makes kernel C a singleton: a second
; live C context would share its register file.  That rules out a kc_ pair for
; these four and nothing else about them is interesting.
;
; NO _kTtyReady GUARD, and that is Tty_Init's doing rather than an omission: a
; missing tty bank halts the boot since T3, so by the time anything can reach
; a slot the answer is always yes.
;
; EVERY OFFSET COMES FROM include/ktty.s's DUM CHAIN.  Nothing here spells a
; number: `ERR TTYC_TAIL+30-TTYC_SIZE' pins the chain at BUILD time.  The probe
; that also pinned it ON THE MACHINE was removed 2026-09-07, so the build-time
; ERR is now the whole guard -- it catches a layout that disagrees with itself,
; not one that disagrees with what the C compiler actually emitted.
;
; In:   MX %00.  A = tty index.  Out: C=0, nothing touched, if it is not one.
;==============================================================================
_ttyRowOff      DA      0*TTYC_SIZE             ; index -> byte offset into
                DA      1*TTYC_SIZE             ;   ttys[].  A TABLE rather than
                DA      2*TTYC_SIZE             ;   a multiply because 92 is not
                DA      3*TTYC_SIZE             ;   a shift.
                DA      4*TTYC_SIZE
                DA      5*TTYC_SIZE             ; tty01, the serial line
                DA      6*TTYC_SIZE             ; ttyv3, the card's console
                ; ONE ROW PER LINE, NTTY OF THEM, and tools/check_ntty.py
                ; COUNTS THEM: the slots below bound the index against NTTY
                ; and never against this table, so a table short of NTTY rows
                ; assembles, and the last lines' slots then read their row
                ; offset out of the first bytes of Tty_PgrpGet's code.  That
                ; is a garbage offset into ttys[], so the line's foreground
                ; group is stored somewhere else and reads back as 0 -- and
                ; ttioctl's SIGTTOU check then holds a getty on the line in
                ; its lbolt loop forever, on its first TIOCSETP.
                ; NO `ERR' GUARDS THIS TABLE'S LENGTH, and that is a finding
                ; rather than an omission: MERLIN'S LATE ERR PASS DOES NOT SEE
                ; THE ADDRESSES IT EMITTED.  Written three ways -- `*', the
                ; next routine's label, and a dedicated `EQU *' -- the same
                ; expression read 40 where the listing shows the table is 10
                ; bytes at 09/0090 with Tty_PgrpGet at 09/009A.  An `ERR' that
                ; is wrong about addresses cannot guard addresses, which is
                ; why the count lives in the checker.

Tty_PgrpGet     MX      %00
                CMP     #NTTY                   ; unsigned: catches $FFFF too
                BCS     @tpg_bad
                PHB
                PHK
                PLB                             ; DBR = tty bank, for ttys[]
                ASL                             ; index -> row-table offset
                TAX
                LDA     |_ttyRowOff,X
                TAX                             ; X = the row's byte offset
                LDA     |ttys+TTYC_PGRP,X
                PLB
                SEC                             ; PLB touches N/Z, never C
                RTL
@tpg_bad        CLC
                RTL

Tty_PgrpSet     MX      %00
                CMP     #NTTY
                BCS     @tps_bad
                PHB
                PHK
                PLB
                PHX                             ; the value, while X is needed
                ASL
                TAX
                LDA     |_ttyRowOff,X
                TAX
                PLA
                STA     |ttys+TTYC_PGRP,X
                PLB
                SEC
                RTL
@tps_bad        CLC
                RTL

; A LONG, RETURNED A=low X=high, which is kc_pendsig's convention -- and it has
; to be a long because THE HIGH WORD IS THE LOCAL MODE WORD: ioctl.h:174 spells
; the L* bits `((int)(CRTBS>>16))', so LTOSTOP is TOSTOP >> 16.  A 16-bit
; accessor would silently drop every bit signal.s tests.
Tty_FlagsGet    MX      %00
                CMP     #NTTY
                BCS     @tfg_bad
                PHB
                PHK
                PLB
                ASL
                TAX
                LDA     |_ttyRowOff,X
                TAX
                LDA     |ttys+TTYC_FLAGS+2,X    ; high word out of the way...
                PHA
                LDA     |ttys+TTYC_FLAGS,X      ; ...low into A, X still live
                PLX                             ;    for it; then high -> X
                PLB
                SEC
                RTL
@tfg_bad        CLC
                RTL

; A = idx -> A = t_intrc, X = t_quitc, Y = the sgtty mode word, C=1.  The two
; characters are returned zero extended in 16-bit registers so the caller can
; CMP them against a byte it has widened the same way.
;
; ONE CALL FOR ALL THREE, and the third joined at T3 stage 2d for the reason
; the first two share one call: pty.mod's `@mw_disc' tests EVERY BYTE WRITTEN
; TO A MASTER for RAW first and then against t_intrc and t_quitc, so a second
; bank crossing there is paid per character.  Y was the one register the slot
; was not already using.
Tty_IntrQuit    MX      %00
                CMP     #NTTY           ; unsigned: catches $FFFF too
                BCS     @tiq_bad
                PHB
                PHK
                PLB
                ASL
                TAX
                LDA     |_ttyRowOff,X
                TAX
                LDA     |ttys+TTYC_FLAGS,X      ; t_flags' LOW half IS sg_flags
                PHA
                LDA     |ttys+TTYC_QUITC,X      ; the two are ADJACENT bytes, so
                AND     #$00FF                  ;   one word read would fetch
                PHA                             ;   both -- but t_quitc is the
                LDA     |ttys+TTYC_INTRC,X      ;   HIGH byte of that word only
                AND     #$00FF                  ;   because INTRC is even here,
                PLX                             ;   which is a layout accident
                PLY                             ;   and not worth depending on
                PLB
                SEC
                RTL
@tiq_bad        CLC
                RTL

; A = idx -> A = t_erase, Y = t_kill, C=1.  Both zero extended, like the pair
; above and for the same reason.  They are `t_chars.tc_erase' and `tc_kill' --
; the first two bytes of `struct ttychars', which `sgttyb' carries as sg_erase
; and sg_kill and which the core's canonical line editor tests every keystroke
; against.
;
; Y RATHER THAN X FOR THE SECOND VALUE, and that is not symmetry with slot 14:
; the caller is `@rd_g_key' in the core's read path, where X IS THE CALLER'S
; BUFFER OFFSET and live -- apple/fgx#224 exactly.  A slot that answered in X
; could not be wrapped register-transparently there.
Tty_EraseKill   MX      %00
                CMP     #NTTY
                BCS     @tek_bad
                PHB
                PHK
                PLB
                ASL
                TAX
                LDA     |_ttyRowOff,X
                TAX
                LDA     |ttys+TTYC_CHARS+1,X    ; tc_kill
                AND     #$00FF
                PHA
                LDA     |ttys+TTYC_CHARS,X      ; tc_erase
                AND     #$00FF
                PLY
                PLB
                SEC
                RTL
@tek_bad        CLC
                RTL

Tty_FlagsSet    MX      %00
                CMP     #NTTY
                BCS     @tfs_bad
                PHB
                PHK
                PLB
                PHY                             ; high word
                PHX                             ; low word
                ASL
                TAX
                LDA     |_ttyRowOff,X
                TAX
                PLA
                STA     |ttys+TTYC_FLAGS,X
                PLA
                STA     |ttys+TTYC_FLAGS+2,X
                PLB
                SEC
                RTL
@tfs_bad        CLC
                RTL

; A = idx, X = ws_row, Y = ws_col -> ttys[idx].t_winsize, C=1.  Tty_FlagsSet's
; shape exactly, one field along: two adjacent words, taken in the two
; registers that are not carrying the line.
;
; THE PIXEL FIELDS ARE LEFT ALONE, DELIBERATELY.  No FGX terminal can answer
; them honestly, and a caller that HAS set them -- through TIOCSWINSZ, which
; carries a whole `struct winsize' and does not come this way -- owns them.
; This slot exists to SEED a line's rows and columns, which is what
; `_Tty_CookedDefaults' and pty.mod's slave init did with two stores into
; `_ttyTable' before apple/fgx#108 T3 stage 2c.
Tty_WinSzSet    MX      %00
                CMP     #NTTY
                BCS     @tws_bad
                PHB
                PHK
                PLB
                PHY                             ; ws_col
                PHX                             ; ws_row
                ASL
                TAX
                LDA     |_ttyRowOff,X
                TAX
                PLA
                STA     |ttys+TTYC_WINSIZE,X
                PLA
                STA     |ttys+TTYC_WINSIZE+2,X
                PLB
                SEC
                RTL
@tws_bad        CLC
                RTL

;==============================================================================
; Tty_BankInit - patch every tty-side cross-bank operand bank byte to the CORE
; bank, then return.
;
; Reached as `JSL <ttybank>:KTTY_INIT` (slot 0) from the core kernel's Tty_Init.
;
; In:   A = core bank number in the low byte.  MX %00.
; Out:  C=1 on success.  A/X/Y clobbered.  DBR restored to the caller's.
;==============================================================================
Tty_BankInit    MX      %00
                PHB
                PHK
                PLB                     ; DBR = tty bank, to reach our own tables

                ; --- Re-bank every tty-side cross-bank operand to the CORE bank.
                ;     _CorePatchTbl (generated: core_patchsites.s) lists each
                ;     operand BANK byte's in-tty-bank offset; we overwrite each
                ;     with the core bank passed in A.  DBR is ALREADY this bank
                ;     and the sites are IN this bank, so `STA abs,Y` reaches
                ;     them -- absolute indexed uses DBR.
                STA     _tbiCoreBank            ; stash core bank (low byte used)
                LDX     #0
@tbi_patchL     CPX     #_CorePatchBytes
                BCS     @tbi_patchDone
                LDY     _CorePatchTbl,X         ; Y = in-bank offset of a bank byte
                SEP     #$20
                MX      %10
                LDA     _tbiCoreBank            ; the value being written (low byte)
                STA     |$0000,Y                ; DBR = tty bank -> patches our own
                REP     #$30
                MX      %00
                INX
                INX
                BRA     @tbi_patchL
@tbi_patchDone

                ; --- Stamp every &function cell's bank byte with THIS bank --
                ;     linesw[] and the t_oproc routines are all KFAR_FN_PTR,
                ;     emitted with the byte zero because the assembler cannot
                ;     know this image's bank, and every indirect call reads it.
                ;     Far_BankInit's walk, over tools/gen_mod_bankpatch.py's
                ;     table.  Before any interrupt can reach l_rint.
                SEP     #$20
                MX      %10
                PHK
                PLA
                STA     _tbiCoreBank            ; reused: the value, low byte
                REP     #$30
                MX      %00
                LDX     #0
@tbi_fnptrL     CPX     #_modFnPtrBytes
                BCS     @tbi_fnptrDone
                LDY     _modFnPtrTab,X          ; Y = a cell's bank-byte offset
                SEP     #$20
                MX      %10
                LDA     _tbiCoreBank
                STA     |$0000,Y
                REP     #$30
                MX      %00
                INX
                INX
                BRA     @tbi_fnptrL
@tbi_fnptrDone

                ; --- LD_TRAMP's default: JML _Ld_Absent, in this bank, until
                ;     ld.mod's mod_init replaces it (FPSIM_TRAMP's pattern,
                ;     far.s's Far_BankInit).  Runs before the first Task_Alloc
                ;     (main.s), so no hook ever finds the cell unset.
                SEP     #$20
                MX      %10
                LDA     #$5C                    ; JML
                STAL    LD_TRAMP+0
                LDA     #<_Ld_Absent
                STAL    LD_TRAMP+1
                LDA     #>_Ld_Absent
                STAL    LD_TRAMP+2
                PHK
                PLA
                STAL    LD_TRAMP+3
                REP     #$30
                MX      %00

                PLB                     ; restore caller's DBR
                SEC
                RTL

;--- Tty_BankInit scratch.  EMITTED, not DUM: it is written before anything
;--- zeroes this bank's statics, and there is no global BSS clear.
_tbiCoreBank    DS      2               ; core bank number (low byte significant)

;==============================================================================
; Tty_LogState - report that the tty bank is up, FROM the tty bank.
;
; The first tty->core call in the tree, and deliberately a real one rather than
; a probe: it exercises scraped core address + _ctp marker + Tty_BankInit
; patching the bank byte, which is the whole return path everything above it
; needs.  Far_LogState is the same routine one bank down, and the far bank's
; history says debugging machinery and payload together is how a bank move goes
; wrong.
;
; The string lives HERE.  That works because Kern_LogStr reads it with
; `LDA (_conStrPtr),Y` -- DP-indirect-indexed, so the bank comes from the
; CALLER's DBR -- and _kernLogPutByte sets its own DBR via PHK/PLB.  _conStrPtr
; is direct page, reached through D, so it is bank-agnostic.
;
; The call goes through _FarSh_LogStr, not Kern_LogStr: every core routine
; reached across a bank must be RTL-terminated.  See src/kernel/far_shims.s --
; the shims are core-bank routines and serve any bank that scrapes them, so the
; tty bank reuses the far bank's set rather than growing a second copy.
;
; In:  MX %00.  Out: A/X/Y per Kern_LogStr; DBR restored.
;==============================================================================
; NOTHING TO SAY.  `tty: bank ready' was one of the development lines the boot
; console carried; a bank that did not come up cannot answer this call at all,
; so the message never told anyone anything the next line of boot did not.
Tty_LogState    MX      %00
                RTL

;==============================================================================
; Subsystem PUTs go here as they migrate.  Code grows UP from just above the
; export table, so the binary stays contiguous from FGX_KTTY_CODE and the
; ceiling check measures something real.
;==============================================================================

;------------------------------------------------------------------------------
; KERNEL C: the fcc runtime, its traps, its scratch, and the compiled TUs.
;
; ALL OF IT EMITS BYTES, so all of it MUST stay below the ORG -- see the export
; table's note above and check_kernel_ceiling.py's KTTY_MAGIC assertion.
;
; THE RUNTIME IS SHARED BY SOURCE AND DUPLICATED BY EMISSION, which is what is
; wanted: a PUT of the far bank's copy assembles a SECOND copy of the code into
; THIS bank, and it has to be a second copy because a cross-bank call to the
; other one would need a bank byte nothing patches.  Sharing the source keeps
; the two banks running the identical runtime; sharing the bytes is impossible.
;
; fcc_rt.s is GENERATED from toolchain/lib/fcc_runtime.s (tools/gen_fcc_rt.py),
; taking everything from _fcc_mul16 onward -- the region measured to be free of
; syscalls, libc and every other outside call.  The three routines above that
; point exit or yield through SYS_TRAMP, which a kernel cannot do to itself, so
; fcc_ktrap.s supplies kernel versions that stop the machine instead.
;
; NOT GATED ON KCPROBE, unlike the far bank's block.  There the C is a probe;
; here it is the payload.
;------------------------------------------------------------------------------
                PUT     ../far/fcc_rt.s
                PUT     ../far/fcc_ktrap.s
_kttyScrLo
                PUT     ../../../toolchain/lib/fcc_runtime_data.s
_kttyScrHi

;------------------------------------------------------------------------------
; _Ktty_IrqTtyinput - slot 38's body: kc_ttyinput, with fcc's static scratch
; kept across it.
;
; fcc keeps some of its temporaries in STATIC cells -- the block just above,
; addressed DBR-relative -- and this bank's C runs at two levels: a task's
; system call, and the heartbeat's receive interrupt feeding `ttyinput'.  An
; interrupt between a task's `STA _fcc_tmp_b' and its `CMP _fcc_tmp_b' would
; come back with the cell holding the interrupt's value.  In ttbgread that
; answers "background" to the foreground shell, and tcsh reads EIO and logs
; out (`G_N_Char(): errno == 5', apple/fgx#503).  A PDP-11 never meets this:
; the compiler's temporaries are registers, and the interrupt entry saves
; them -- r0 and r1 in `call', r2-r5 in csv (2.11BSD usr/sys/pdp/mch_trap.s).
; So the interrupt's C runs between a save and a restore of the block: the
; same property, kept by hand.
;
; ONE SAVE AREA AND ONE RETURN CELL ARE ENOUGH.  The caller is inside
; KTTY_KC_ENTER_IRQ, which is not reentrant (kernelc.s says why), with DBR on
; this bank.  The caller's 3-byte return is lifted off the stack so that
; kc_ttyinput's JSL-shaped frame sits exactly where the caller's did and it
; finds its arguments where it expects them.  A (the result) comes back
; through; X and Y are fcc's to clobber, as for any C call.
;------------------------------------------------------------------------------
_Ktty_IrqTtyinput MX    %00
                PLA                             ; the caller's return: PCL, PCH
                STA     _kttyIrqRet
                SEP     #$20
                MX      %10
                PLA                             ; ...and PB
                STA     _kttyIrqRet+2
                REP     #$20
                MX      %00
                LDX     #0
@kit_save       LDA     _kttyScrLo,X
                STA     _kttyScrSave,X
                INX
                INX
                CPX     #_kttyScrHi-_kttyScrLo
                BCC     @kit_save
                PHK                             ; kc_ttyinput returns RTL: a
                PEA     @kit_back-1             ;   JSL frame into this bank
                JMP     kc_ttyinput
@kit_back       STA     _kttyIrqA               ; the result
                LDX     #0
@kit_rest       LDA     _kttyScrSave,X
                STA     _kttyScrLo,X
                INX
                INX
                CPX     #_kttyScrHi-_kttyScrLo
                BCC     @kit_rest
                SEP     #$20
                MX      %10
                LDA     _kttyIrqRet+2
                PHA
                REP     #$20
                MX      %00
                LDA     _kttyIrqRet
                PHA
                LDA     _kttyIrqA
                RTL
_kttyIrqRet     DS      3
_kttyIrqA       DS      2
_kttyScrSave    DS      _kttyScrHi-_kttyScrLo+1

;--- The C-to-kernel direction.  A second copy of the far bank's, because the
;--- _ctp markers have to be in THIS bank's listing for Tty_BankInit's table.
                PUT     kc_sys.s

;--- THE TENANT.  2.11BSD's clists (docs/PROVENANCE.md), plus T1's witness.
;--- Each fcc translation unit brings its DATA segment with it: leaving one out
;--- is how a kernel-C global silently does not exist, and cfree IS a global.
                PUT     tty_subr.s
                PUT     tty_subr.data.s

;--- T2.1: the line-discipline switch, the tty instances, and their witness.
                PUT     tty_conf.s
                PUT     tty_conf.data.s
                PUT     tty_dev.s
                PUT     tty_dev.data.s

;--- T3: the discipline itself, one increment at a time.  ttyoutput first --
;--- the only part of upstream's tty.c that reaches nothing outside this bank.
                PUT     tty.s
                PUT     tty.data.s

;--- The kernel clock (kern_time.c): a tenant for this bank's room, not its
;--- subject.  docs/history/plans/tty-kernel-bank.md, "Tenants other than the tty layer".
                PUT     kern_time.s
                PUT     kern_time.data.s
                PUT     ld_hooks.s

;--- The shared-text table: a tenant for this bank's room, like the clock.
                PUT     text.s


;--- Generated: CORE symbol addresses (tools/gen_kernel_exports.py, 'tty'
;--- manifest).  abs24 with the core ORG bank baked in; Tty_BankInit rewrites
;--- each site's bank byte to the live core bank, which is why every use carries
;--- a _ctp marker.  Regenerated every build, so a renamed or removed core
;--- symbol FAILS THE BUILD rather than drifting stale.
                PUT     kernel_exports.s

;--- Generated: tty-side cross-bank operand sites (tools/gen_far_bankpatch.py,
;--- direction 'tty').  MUST come after the export table: anything emitted
;--- before it would displace the table from offset $0000.
                PUT     core_patchsites.s

;--- Generated: the bank-byte address of every KFAR_FN_PTR cell in this image
;--- (tools/gen_mod_bankpatch.py --macro KFAR_FN_PTR), walked by Tty_BankInit.
;--- Last of the emitted bytes: it is the only output whose size depends on the
;--- scan, so nothing after it can move a cell it lists.
                PUT     fnptr_patchsites.s

;==============================================================================
; Tty-bank STATIC region.  A DUM block, so these reserve space without emitting
; bytes into bin/fgxtty.bin.
;
; NOTHING ZEROES THEM AT LOAD.  There is no global BSS clear in FGX and stage 2
; MVNs only the image's real bytes, so a DUM cell holds whatever the Memory
; Manager last left in that bank.  Every owner zeroes its own region before
; first read -- the same contract the far bank's statics live under.
;
; FGX_KTTY_DATA is the tty bank's code ceiling (include/kernel.s), the same way
; FGX_KFAR_DATA is the far bank's, so check_kernel_ceiling.py keeps measuring
; something real.
;
; THIS BLOCK IS EMPTY, AND THE RESERVE BEHIND IT IS NOW 256 BYTES, not 5 KB.
; Every tty-bank static is an fcc data segment inside the CODE region, so the
; four kilobytes the old split held back were holding nothing while T3 ran out
; of room.  The block stays because the contract does: a static that genuinely
; wants a DUM cell has somewhere to go, and it is zeroed by its owner rather
; than at load.
;==============================================================================
                DUM     FGX_KTTY_DATA
_ttyBankStaticsStart    EQU *
                DEND
