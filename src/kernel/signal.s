;==============================================================================
; signal.s - signal posting and delivery.
;
; CATCHABLE SIGNALS: ALL OF THEM except SIGKILL and SIGSTOP, as in BSD
; (apple/fgx#58).  A per-task CATCH mask -- BSD's p_sigcatch -- says which
; signals have a handler, and a single per-task ENTRY offset says where to
; enter: crt0's trampoline, which dispatches on the signum out of the
; process's own handler table, where BSD keeps u_signal[NSIG] too.  Both live
; in the sigHnd block (include/memmap.s).
;
; This replaced five per-signal handler tables that capped the catchable set at
; SIGINT/ALRM/CHLD/TERM/HUP -- and that were redundant, because libc passes the
; SAME trampoline offset for every signal.  SIG_DFL/SIG_IGN were always honored
; for all 31 via the IGN mask; only real handlers were limited.
;
; Delivery model: synchronous, at syscall return.  See
; _Sys_CheckSignal below and the dispatcher-exit hook in syscall.s
; (@je_returnToUser).  A compute loop in fcc-compiled code reaches one at
; its next safepoint once the quantum expires (the safepoint's SYS_YIELD);
; only code that neither makes a syscall nor carries safepoints never sees one.
;
; Public:
;   _Sys_Kill        #37   A=pid, X=sig.  OR sig's bit into target's
;                          TCB_PendingSig.  Unchanged from slice-2 stub.
;
;   _Sys_Signal      #48   A=sig, X=handler offset.
;                          A catchable signal: store offset in handler table.
;                          handler==SIG_DFL(0)/SIG_IGN(1) are passed through
;                          unchanged (delivery treats them as "no handler").
;                          Returns A = previous handler offset.
;
;   _Sys_Alarm       #64   A.lo = seconds.  Sets the current task's
;                          alarm tick counter to seconds*60 (heartbeat
;                          decrements at 60 Hz).  A = 0 cancels.
;                          Returns A = 0 (v1 doesn't report prior remaining).
;
;   _Sys_CheckSignal       Called from syscall dispatcher exit.  Inspects
;                          _curTask's TCB_PendingSig + handler tables.
;                          If SIGINT or SIGALRM is pending AND has a
;                          user handler, clears the bit and sets
;                          _Sys_DeliveredSig/_Sys_HandlerOffset/_Sys_HandlerBank
;                          for the dispatcher to JML into.
;                          Otherwise _Sys_DeliveredSig = 0.
;==============================================================================

;------------------------------------------------------------------------------
; _Sys_Kill (#37) - post a signal to a task or process group.
;
; A = pid (16-bit signed), X = sig (0..NSIG-1; 0 = validate only).
;   pid  > 0 : the single task `pid`.
;   pid  < 0 : every task whose SE_PGroup == (-pid).
;   pid == 0 : every task in the caller's process group (SE_PGroup of _curTask).
;
; Posts sig's bit into each target's TCB_PendingSig (delivered at that task's
; next syscall exit by _Sys_CheckSignal).  SIGCONT and SIGKILL additionally flip
; a TASK_STOPPED target back to READY at post time; a TASK_BLOCKED target is
; _wakeup'd so an interruptible _sleep re-checks (and can return EINTR).
;
; Phase 5.1 note: SE_PGroup is 0 for every task until setpgid lands (Task 5.3),
; so the group forms currently fan out over group 0 (= all tasks).  The single-
; pid form is the path exercised by the 5.1 kill test.
;
; Returns A=0 + C=1 on success; ESRCH (single pid not found) / EINVAL (bad sig)
; + C=0 on error.
;------------------------------------------------------------------------------
_Sys_Kill       ENT
                MX      %00
                STA     _kKillPid                   ; raw 16-bit (signed) pid
                STX     _shTmp1                     ; sig
                LDA     _shTmp1
                AND     #$00FF
                STA     _shTmp1
                CMP     #NSIG
                BCC     @sk_sigOK
                LDA     #EINVAL
                CLC
                RTS
@sk_sigOK       ; Precompute the signal's byte index + bit mask once (shared by
                ; the single-target and fan-out paths).  sig==0 leaves them set
                ; for byte 0 / mask 0 — _Kill_Apply no-ops the post.
                LDA     _shTmp1
                LSR
                LSR
                LSR
                STA     _kSigByteIdx                ; sig >> 3 (0..3)
                LDA     _shTmp1
                AND     #$0007
                TAY
                LDA     _SigBit_LUT,Y
                AND     #$00FF
                STA     _kSigMask                   ; 1 << (sig & 7)
                ; --- Dispatch on pid sign. ---
                LDA     _kKillPid
                BEQ     @sk_groupSelf               ; pid == 0 -> caller's group
                BMI     @sk_groupNeg                ; pid <  0 -> group (-pid)
                ; pid > 0: single target.
                AND     #$00FF
                JSR     Task_Lookup
                BCS     @sk_one
                LDA     #ESRCH
                CLC
                RTS
@sk_one         JSR     _Kill_Apply                 ; X = target TCB offset
                LDA     #0
                SEC
                RTS

@sk_groupSelf   ; pgid = caller's SE_PGroup.
                ; `_skPgid' AND `_skAll' ARE THIS ROUTINE'S OWN (apple/fgx#379).
                ; They used to be `_kPgid' and `_kgfAll', the fan-out's cells,
                ; written here and read there -- so an interrupt-time gsignal
                ; arriving between this store and the JSR below replaced them
                ; and this kill went to the ISR's process group.  The fan-out
                ; takes both in registers now and these are private.
                STZ     _skAll
                LDA     _curTask
                AND     #$00FF
                JSR     _SE_PGroupOf                ; -> A = pgroup
                STA     _skPgid
                BRA     @sk_fanout
@sk_groupNeg    ; pid == -1 IS A BROADCAST, NOT GROUP 1, and it is a separate
                ; case upstream for that reason: 2.11BSD's kill switches on the
                ; pid before it reaches the fan-out --
                ;
                ;     case -1:  error = killpg1(uap->signo, 0, 1);  /* all */
                ;     case 0:   error = killpg1(uap->signo, 0, 0);
                ;     default:  error = killpg1(uap->signo, -uap->pid, 0);
                ;
                ; (kern_sig.c).  Without it `kill(-1, SIGTERM)' means pgid 1
                ; here, which is init's group and one live group among several,
                ; so reboot(8)'s "one chance to catch it" would signal almost
                ; nothing.  The truncation note below is why it could not be
                ; left to fall out of the arithmetic: -1 AND $00FF is 255, a
                ; legal group, so nothing would have looked wrong.
                STZ     _skAll
                LDA     _kKillPid
                CMP     #$FFFF
                BNE     @sk_negGroup
                INC     _skAll                      ; killpg1's `all'
                STZ     _skPgid
                BRA     @sk_fanout
@sk_negGroup    ; pgid = -pid (two's complement of the 16-bit pid).
                LDA     _kKillPid
                EOR     #$FFFF
                INC
                AND     #$00FF
                STA     _skPgid
@sk_fanout      ; PGRP 0 IS "NO GROUP", NOT "THE GROUP NAMED ZERO"
                ; (apple/fgx#70).  2.11BSD killpg1() (kern_sig.c:158-163):
                ;     if (!all && pgrp == 0) {
                ;         pgrp = u.u_procp->p_pgrp;
                ;         if (pgrp == 0) return (ESRCH);
                ;     }
                ; FGX had the state and not the guard.  Every spawnv/spawnx
                ; child sits in pgrp 0 (spawn does not inherit it -- #60), so
                ; one of them calling kill(0, sig) fanned out over EVERY OTHER
                ; pgrp-0 task on the system: unrelated processes that merely
                ; shared the ABSENCE of a group.
                ;
                ; Guarding here rather than in @sk_groupSelf covers the
                ; negative form too, which needs it for an FGX-specific reason:
                ; pids are one byte, so @sk_groupNeg's `AND #$00FF` aliases
                ; kill(-256, sig) onto pgid 0.  BSD's pids are 16-bit and never
                ; truncate, so it has no such door to close.
                LDA     _skAll
                BNE     @sk_fanGo                   ; a broadcast has no pgid
                LDA     _skPgid
                BEQ     @sk_noGroup
@sk_fanGo       LDX     _skPgid                     ; the fan-out's two inputs,
                LDY     _skAll                      ;   in registers so no
                                                    ;   interrupt can replace
                                                    ;   them on the way in
                LDA     _shTmp1                     ; sig; the fan-out precomputes
                JSR     _Kill_GroupFanout           ; -> A = how many it signalled
                ; ESRCH IF THE GROUP MATCHED NOBODY (apple/fgx#75).  2.11BSD
                ; killpg1 counts what it signalled and ends
                ;     return (error ? error : (f == 0 ? ESRCH : 0));
                ; so a caller can tell "I signalled a job" from "that job is
                ; already gone".  FGX reported success for every group kill,
                ; including one against a group that does not exist -- which a
                ; job-control shell reads as "still running".
                ; A IS THE COUNT, returned rather than read back out of
                ; `_kgfHits': an interrupt-time gsignal between the RTS and a
                ; re-read would have zeroed the cell and turned a group kill
                ; that worked into ESRCH.
                CMP     #0
                BEQ     @sk_noGroup
                LDA     #0
                SEC
                RTS
@sk_noGroup     LDA     #ESRCH
                CLC
                RTS

;------------------------------------------------------------------------------
; _Kill_GroupFanout - post signal A to every live (non-zombie) task whose
; SE_PGroup matches.
;
; In:  A = signal, X = pgid, Y = 0 for a group / non-zero for a broadcast.
; Out: A = how many tasks were signalled (killpg1's `f').
; MX %00.  Clobbers A/X/Y and the _shTmp1 / _kSigByteIdx / _kSigMask precompute
; cells.  DP-safe (kernel DP).  Shared by _Sys_Kill's group forms and by
; _Tty_DeliverSig.
;
; THE THREE INPUTS ARE REGISTERS, AND THAT IS THE WHOLE OF apple/fgx#412's
; sibling apple/fgx#379.  The pgid and the broadcast flag used to arrive through
; `_kPgid' and `_kgfAll', which meant every caller wrote them BEFORE this
; routine's own PHP/SEI -- outside the bracket that exists to protect exactly
; those cells.  An interrupt landing between a caller's store and this read runs
; the ISR's entire gsignal, correct in itself, and leaves the cells holding the
; ISR's group; the interrupted caller then resumes and fans its signal out to
; somebody else's process group.  A register cannot be clobbered that way -- the
; interrupt frame saves it -- so the cells are now written INSIDE the bracket,
; four instructions after the SEI, and have no callers at all.
;
; THE COUNT COMES BACK IN A for the same reason at the other end: `_kgfHits' was
; read by _Sys_Kill AFTER the RTS, where an ISR fanout would have reset it to
; zero and turned a successful group kill into ESRCH.
;
; THE SIGNAL COMES IN A, AND THE PRECOMPUTE IS DONE HERE.  It used to be four
; preconditions the caller had to satisfy -- pgid in _kPgid, sig in _shTmp1, and
; _kSigByteIdx / _kSigMask carrying sig>>3 and 1<<(sig&7) -- with nothing to
; catch a caller that set some of them.  A caller that set two of the four (a
; correct _kPgid, a correct _kSigMask left behind by an unrelated routine, and a
; _kSigByteIdx that was a USER-TABLE index rather than 0..3) reached the fan-out,
; matched its target, and posted the bit into the wrong byte of TCB_PendingSig:
; a signal that was fanned out to the right task and could never be delivered.
;
; A four-part precondition on a routine that already has the signal available at
; every call site is a footgun, not an optimisation: the two group callers hold
; the sig in _shTmp1 anyway, so folding the six instructions in costs them
; nothing and removes the class.
;------------------------------------------------------------------------------
_Kill_GroupFanout MX    %00
                ; MASKED FOR ITS WHOLE LENGTH -- apple/fgx#108 T6 increment 3.
                ;
                ; `_shTmp1' BELOW IS SHARED DP SCRATCH, and toolbox.s's own
                ; header forbids exactly this at interrupt time: "DO NOT touch
                ; shared DP scratch (_shTmp* / _libcTmp* / _fsTmp*); the body
                ; fires asynchronously w.r.t. any in-flight kernel call."  That
                ; rule was written for apple/fgx#235, which was `_shTmp0' one
                ; cell over, and `ttyinput' reaches here through `kc_gsignal'
                ; the moment T6 moves it to arrival time.
                ;
                ; `_kPgid', `_kSigByteIdx', `_kSigMask' and `_kgfHits' are the
                ; same hazard without the shared-scratch aggravation: singletons
                ; an ISR would replace mid-fanout, so the outer scan finishes
                ; against another signal's numbers.
                ;
                ; AND check_hb_scratch.py CANNOT SEE ANY OF IT.  That script
                ; scans the heartbeat body's own lines and does not follow
                ; calls, so its scope ends exactly where the flip extends the
                ; body.  The bracket is the fix; widening the script is the
                ; guard, and both belong to this increment.
                ;
                ; Measured non-blocking to depth 3 -- no sleep, no swtch, no WAI
                ; on any path -- so the region is bounded by TASK_MAX_SLOTS.
                ; BOTH exits restore; PLP puts back what was there rather than
                ; enabling, so an ISR caller keeps its mask.
                PHP
                SEI
                STX     _kPgid                      ; the inputs, now that they
                STY     _kgfAll                     ;   cannot be interrupted
                AND     #$00FF
                STA     _shTmp1                     ; sig, for _Kill_Apply
                LSR
                LSR
                LSR
                STA     _kSigByteIdx                ; sig >> 3 (0..3)
                LDA     _shTmp1
                AND     #$0007
                TAY
                LDA     _SigBit_LUT,Y
                AND     #$00FF
                STA     _kSigMask                   ; 1 << (sig & 7)
                ; gsignal()'s own guard, 2.11BSD kern_sig.c:193:
                ;     if (pgrp == 0) return;
                ; BSD carries it in BOTH places -- killpg1 errors, gsignal
                ; silently no-ops -- so that no internal caller can post to
                ; "group 0" by reaching the fan-out directly.  _Tty_DeliverSig
                ; already screens FgPgrp == 0 before it gets here; this makes
                ; that a property of the fan-out rather than of its callers,
                ; which is what stops apple/fgx#70 coming back through a new
                ; one.
                STZ     _kgfHits                    ; #75: count what we signal
                LDA     _kgfAll
                BNE     @kgf_start                  ; a broadcast has no pgid
                LDA     _kPgid
                BNE     @kgf_start
                LDA     _kgfHits                    ; zero, STZ'd two lines up
                PLP                                 ; the early exit restores too
                RTS
@kgf_start      LDX     #FGX_TASK_TBL_OFF
@kgf_loop       ; A FREE SLOT IS ONE WHOSE **STATUS** IS ZERO, which is what
                ; Task_Lookup tests (`LDA: TCB_Status,X / BEQ @tl_nope') and
                ; what this did not: it read TCB_TaskID, and a slot released by
                ; _Exit_Core keeps the pid it last held.  So every stale slot
                ; looked like a live task.
                ;
                ; IT COULD NOT SHOW ON A GROUP KILL, which is why it stood: a
                ; stale slot's SE_PGroup almost never matches the pgid being
                ; signalled, so the extra tasks were filtered one test later by
                ; accident.  A BROADCAST has no pgid to filter on, and the
                ; ghosts became the whole answer -- kill(-1) counted seven
                ; tasks that procinfo does not list, so it never returned
                ; ESRCH and reboot(8)'s drain never ended (apple/fgx#401).
                LDA:    TCB_Status,X
                AND     #$00FF
                BEQ     @kgf_next                   ; free slot
                CMP     #TASK_ZOMBIE
                BEQ     @kgf_next                   ; don't signal zombies
                ; SE_PGroup[slot] == pgid?  seoff = (TCBoff - $0800) >> 1.
                TXA
                SEC
                SBC     #FGX_TASK_TBL_OFF
                LSR
                CLC
                ADC     #SE_PGroup
                TAY
                LDA     [_schedTblPtr],Y
                LDY     _kgfAll
                BNE     @kgf_bcast                  ; broadcast: every group
                CMP     _kPgid
                BNE     @kgf_next
                BRA     @kgf_hit
                ; A BROADCAST SKIPS init AND THE SENDER, which is killpg1's
                ; `p->p_ppid == 0 || (all && p == u.u_procp)' (kern_sig.c:
                ; killpg1).  init's p_ppid is 0 upstream, so BSD's broadcast
                ; never reaches pid 1 either -- and that is exactly why
                ; reboot(8) idles init with its own kill(1, SIGTSTP) first.
                ; Excluding the sender is what lets reboot(8) stay alive to
                ; call reboot(2) after signalling everything else.
@kgf_bcast      LDA:    TCB_TaskID,X
                AND     #$00FF
                CMP     #1
                BEQ     @kgf_next                   ; init
                CMP     _curTask
                BEQ     @kgf_next                   ; the sender
@kgf_hit        INC     _kgfHits                    ; #75: BSD killpg1's `f++`
                JSR     _Kill_Apply                 ; preserves X
@kgf_next       TXA
                CLC
                ADC     #TCB_SIZE
                TAX
                CPX     #FGX_TASK_TBL_OFF+{TASK_MAX_SLOTS*TCB_SIZE}
                BCC     @kgf_loop
                LDA     _kgfHits                    ; the answer, before the mask
                PLP                                 ;   comes back off
                RTS

;------------------------------------------------------------------------------
; `_Tty_DrainSigPend' STOOD HERE and went at T6 increment 4b.  It scanned
; `_kTtySigPend' and delivered what the heartbeat had marked, because the ISR
; ran on the interrupted task's direct page and could not reach `_schedTblPtr'
; to fan a signal out itself.
;
; `kc_gsignal' (src/kernel/tty/kc_sys.s) swaps to the kernel's real direct page
; before it calls, so `ttyinput' reaches `_Kill_GroupFanout' from interrupt
; time directly -- which is why `_Kill_GroupFanout' is SEI-bracketed for its
; whole length.  The mark had no writer left; `_kTtySigAny' and `_kTtySigPend'
; go with it.
;
; `_Tty_DeliverSig' below STAYS: the drain was only one of its two callers, and
; the other is KSVC_TTYSIG (jumptable.s), which pty.mod uses for in-band `^C'.
;------------------------------------------------------------------------------

;------------------------------------------------------------------------------
; _Tty_DeliverSig - deliver signal X to the foreground process group of tty A.
;
; A = tty index (0 = console; 1..NTTY-1 = pty slaves — honored since pty P1c;
; the P2 slave discipline's in-band ^C/^\ delivers through here), X = signal.
; No-op if that tty's TTY_FgPgrp is 0 (no foreground group claimed — the
; pre-shell-job-control state).  Reuses _Kill_GroupFanout: posts sig + wakes
; blocked members + SIGCONT continue.  MX %00, DP-safe (uses _schedTblPtr) —
; call only from kernel-DP contexts (_Sys_CheckSignal, swtch idle loop),
; never the heartbeat ISR.
;------------------------------------------------------------------------------
_Tty_DeliverSig ENT
                MX      %00
                STX     _shTmp1                     ; sig (frees X for the index)
                ; A = tty index -> X = entry byte offset (idx * TTY_SIZE;
                ; NTTY is 3, so the add loop runs at most twice).
                TAY
                LDA     #0
@tds_mul        CPY     #0
                BEQ     @tds_muld
                CLC
                ADC     #TTY_SIZE
                DEY
                BRA     @tds_mul
@tds_muld       TAX
                PHX                                 ; the offset, live below;
                TXA                                 ;   _Se_TtyOffToIdx IS the
                JSR     _Se_TtyOffToIdx             ;   X counter
                JSR     _Tty_PgrpOf                 ; A = the line's fg group
                PLX
                CMP     #0                          ; PLX SETS Z FROM X, NOT A
                BEQ     @tds_done                   ; no fg group -> nothing to do
                STA     _tdsPgid                    ; the group, until the call
                                                    ;   below puts it in X.  ITS
                                                    ;   OWN CELL AND NOT SHARED
                                                    ;   DP SCRATCH: `_shTmp0' is
                                                    ;   the cell apple/fgx#235
                                                    ;   was about, and holding a
                                                    ;   value in it across the
                                                    ;   tty calls below is the
                                                    ;   hazard this change
                                                    ;   exists to remove.
                ; --- INTR FLUSHES THE LINE, AND THE KERNEL OWNS THAT
                ; (apple/fgx#56).  2.11BSD's ttyinput does
                ;     if ((t_flags&NOFLSH) == 0) ttyflush(tp, FREAD|FWRITE);
                ; BEFORE gsignal, so typed-ahead dies whatever the reader does.
                ; FGX consumed the ^C and posted the signal but flushed nothing,
                ; so a partial line survived it.
                ;
                ; MEASURED, and the mechanism is not "the read was interrupted".
                ; The line being edited is not committed yet -- it sat in the
                ; core's CanonBuf when this was measured and it sits in the
                ; discipline's `t_rawq' now -- so it survives the signal either
                ; way and the next read gathers straight on from it.  Under bsh,
                ; which
                ; does not take an interrupt at its prompt, the read simply kept
                ; gathering: type `z`, hit ^C, type `echo $HOME`, and the shell
                ; ran `zecho $HOME` -> "zecho: not found".  Zeroing the cursor
                ; here makes the flush the KERNEL's act, so it happens for every
                ; reader including one that never notices the signal.
                ;
                ; SIGINT ONLY.  BSD flushes on INTR and QUIT, NOT on SUSP: ^Z
                ; stops the job with its input intact, and discarding it would be
                ; a second bug.  LNOFLSH (sgtty.h:129) is honoured, as BSD
                ; honours NOFLSH.
                ;
                ; The OUTPUT half of BSD's ttyflush(FREAD|FWRITE) is NOT done
                ; here: FGX console output is essentially synchronous, so there
                ; is no queue to drop, and the pty rings are the other side of a
                ; path this routine also serves.  Nor is BSD's ttyecho of the ^C.
                ; Both want the tty write path from kernel context; neither is
                ; the defect that had a reproduction.
                ; THE FLUSH WENT AT T6 INCREMENT 4b AND ITS TEST WENT WITH IT,
                ; one commit later than it should have.  The latch set
                ; `_kTtyFlushPend' for `kc_ttread''s pump to act on; the pump
                ; went, so the cell went -- but the `SIGINT'/`LNOFLSH' test
                ; that decided whether to set it was left standing, with
                ; nothing between it and the label both its branches take.  A
                ; cross-bank lmode read whose result is discarded
                ; reads like a guard and is not one.
                ;
                ; NOTHING IS LOST.  `ttyinput' sees the `^C' itself now and
                ; runs upstream's own `if ((t_flags&NOFLSH)==0) ttyflush(tp,
                ; FREAD|FWRITE)' -- the WIDER flush, at the moment the
                ; character arrives, and it honours LNOFLSH there.
@tds_noflush
                LDX     _tdsPgid                    ; pgid
                LDY     #0                          ; a GROUP signal, never a
                                                    ;   broadcast -- see
                                                    ;   _FarSh_Gsignal
                LDA     _shTmp1                     ; sig; the fan-out precomputes
                JSR     _Kill_GroupFanout
@tds_done       RTS

;------------------------------------------------------------------------------
; _Kill_PostOne - post signal A to the task whose TCB offset is in X.
;
; _Kill_Apply's precondition is that _shTmp1 / _kSigByteIdx / _kSigMask are
; already set up, which every caller so far did inline because it was posting
; a whole run of targets and could hoist the work.  A caller with ONE target
; and one signal (the exit path's stopped-child rescue, apple/fgx#71) wants
; the precompute folded in.  Preserves X, as _Kill_Apply does.  MX %00.
;------------------------------------------------------------------------------
_Kill_PostOne   ENT
                MX      %00
                AND     #$00FF
                STA     _shTmp1
                LSR
                LSR
                LSR
                STA     _kSigByteIdx                ; sig >> 3 (0..3)
                LDA     _shTmp1
                AND     #$0007
                TAY
                LDA     _SigBit_LUT,Y
                AND     #$00FF
                STA     _kSigMask                   ; 1 << (sig & 7)
                JSR     _Kill_Apply
                RTS

;------------------------------------------------------------------------------
; _Kill_Apply - post _shTmp1's signal to the task whose TCB offset is in X.
;
; Uses _kSigByteIdx / _kSigMask (precomputed by _Sys_Kill).  sig==0 -> no-op.
; SIGCONT and SIGKILL post-time: a TASK_STOPPED target is flipped back to READY
; (the bit is still posted so the CONT default drops cleanly / a handler could
; see it, and a KILL is acted on: 2.11BSD psignal() makes a stopped process
; run for SIGKILL).
; A TASK_BLOCKED target is _wakeup'd on its SE_WaitChan so an interruptible
; _sleep re-checks its condition and can bail with EINTR.
;
; Preserves X (the fan-out loop reuses it).  MX %00.
;------------------------------------------------------------------------------
_Kill_Apply     MX      %00
                PHX
                LDA     _shTmp1
                AND     #$00FF
                BNE     @ka_haveSig                 ; (long: SEF clear pushed
                JMP     @ka_done                    ;  @ka_done out of BEQ range)
@ka_haveSig     ; SIGCONT and SIGKILL un-stop a stopped target (post time).
                CMP     #SIGCONT
                BEQ     @ka_unstop
                CMP     #SIGKILL
                BNE     @ka_post
@ka_unstop      LDA:    TCB_Status,X
                AND     #$00FF
                CMP     #TASK_STOPPED
                BNE     @ka_post
                LDA     #TASK_READY
                STA:    TCB_Status,X
                ; Clear SEF_STOPREPORTED so a future stop is reported again by
                ; waitpid(WUNTRACED).  X = target TCB; seoff = (TCBoff-$0800)>>1.
                TXA
                SEC
                SBC     #FGX_TASK_TBL_OFF
                LSR
                CLC
                ADC     #SE_Flags
                TAY
                LDA     [_schedTblPtr],Y
                AND     #$FFFD                      ; clear SEF_STOPREPORTED ($0002)
                STA     [_schedTblPtr],Y
@ka_post        ; OR the bit into TCB_PendingSig[byteidx].
                SEP     #$20
                MX      %10
                LDA     _kSigByteIdx
                BEQ     @ka_b0
                CMP     #1
                BEQ     @ka_b1
                CMP     #2
                BEQ     @ka_b2
                LDA:    TCB_PendingSig+3,X
                ORA     _kSigMask
                STA:    TCB_PendingSig+3,X
                BRA     @ka_posted
@ka_b0          LDA:    TCB_PendingSig,X
                ORA     _kSigMask
                STA:    TCB_PendingSig,X
                BRA     @ka_posted
@ka_b1          LDA:    TCB_PendingSig+1,X
                ORA     _kSigMask
                STA:    TCB_PendingSig+1,X
                BRA     @ka_posted
@ka_b2          LDA:    TCB_PendingSig+2,X
                ORA     _kSigMask
                STA:    TCB_PendingSig+2,X
@ka_posted      REP     #$20
                MX      %00
                ; Wake a blocked target so an interruptible _sleep re-checks.
                LDA:    TCB_Status,X
                AND     #$00FF
                CMP     #TASK_BLOCKED
                BNE     @ka_done
                TXA
                SEC
                SBC     #FGX_TASK_TBL_OFF
                LSR
                CLC
                ADC     #SE_WaitChan
                TAY
                LDA     [_schedTblPtr],Y
                BEQ     @ka_done                    ; no channel
                JSR     _wakeup                     ; clobbers A/X/Y (X restored below)
@ka_done        PLX
                RTS

;------------------------------------------------------------------------------
; _Sig_Raise - post signal A to the CURRENT task (self-signal), delivered at
; this syscall's exit by _Sys_CheckSignal.  The kernel-internal counterpart of
; kill(getpid(), sig) without the syscall round-trip — used by _Pipe_Write to
; raise SIGPIPE on a broken pipe.
;
; In:  A = signum (1..NSIG-1).  MX %00, kernel DP, DBR=kernel-bank ($02 = ORG).
; Out: nothing (no-op if _curTask == 0 / boot, or sig out of range).
;      Preserves nothing of interest (clobbers A/X/Y); callers don't rely on
;      regs across it.  Mirrors _Sys_Kill's byteidx/mask precompute and
;      _Sys_CheckSignal's _curTask -> TCB-offset calc, then _Kill_Apply.
;------------------------------------------------------------------------------
_Sig_Raise      MX      %00
                AND     #$00FF
                STA     _shTmp1                     ; sig (for _Kill_Apply's SIGCONT test)
                CMP     #NSIG
                BCS     @sr_done                    ; out of range -> no-op
                CMP     #0
                BEQ     @sr_done                    ; sig 0 -> no-op
                ; Precompute byte index + bit mask (== _Sys_Kill @sk_sigOK).
                LDA     _shTmp1
                LSR
                LSR
                LSR
                STA     _kSigByteIdx                ; sig >> 3 (0..3)
                LDA     _shTmp1
                AND     #$0007
                TAY
                LDA     _SigBit_LUT,Y
                AND     #$00FF
                STA     _kSigMask                   ; 1 << (sig & 7)
                ; X = _curTask's TCB offset (== _Sys_CheckSignal @scs_haveTask).
                LDA     _curTask
                AND     #$00FF
                BEQ     @sr_done                    ; no current task (boot) -> no-op
                DEC
                ASL
                ASL
                ASL
                ASL
                ASL
                ASL                                 ; (pid-1)*64
                CLC
                ADC     #FGX_TASK_TBL_OFF
                TAX
                JSR     _Kill_Apply                 ; OR the bit into TCB_PendingSig
@sr_done        RTS

;------------------------------------------------------------------------------
; _SE_PGroupOf - return (A) the SE_PGroup of the task whose pid is in A.
; seoff = (pid-1) << 5.  MX %00.  Clobbers Y.
;------------------------------------------------------------------------------
_SE_PGroupOf    MX      %00
                AND     #$00FF
                DEC
                ASL
                ASL
                ASL
                ASL
                ASL                                 ; (pid-1)*32 = seoff
                CLC
                ADC     #SE_PGroup
                TAY
                LDA     [_schedTblPtr],Y
                RTS

;------------------------------------------------------------------------------
; _Tty_CurIsFg - is _curTask in the console tty's foreground process group?
; The cooperative ^C poll (_Pipe_PollIntr / _Sock_PollIntr via Con_PollKey) must
; fire only for the FOREGROUND task: a background job (its own pgrp, set by the
; shell's setpgid) must NOT consume keyboard input — else it steals the fg
; shell's keystrokes (the shell looks "hung") and grabs ^C, killing itself.
; Mirrors the tty-read SIGTTIN gate (syscall.s) but for the keyboard ^C poll.
;
; AGAINST THE CALLER'S OWN TTY, not tty[0].  This compared against
; _ttyTable+TTY_FgPgrp with no index -- the console's foreground group, whatever
; tty the caller was actually on.  That was right while the keyboard fed exactly
; one tty and wrong once virtual consoles existed: a shell on ttyv1 was judged
; against a tty it is not attached to, so the answer flipped with what the
; CONSOLE happened to be doing.  BSD asks the same question the same way --
; `u.u_procp->p_pgrp != tp->t_pgrp && tp == u.u_ttyp` (2.11BSD tty.c:333), where
; tp is the caller's own line.  A task with no controlling tty answers for tty[0],
; matching _Vc_CttyIsActive.
;
; Out: C=1 foreground (curtask pgrp == its own tty's TTY_FgPgrp, or no task yet);
;      C=0 background.  MX %00.  Clobbers A; preserves X and Y.
;------------------------------------------------------------------------------
_Tty_CurIsFg    MX      %00
                PHX                                 ; _Se_CurCtty's contract lists
                PHY                                 ;   X as clobbered
                LDA     _curTask
                AND     #$00FF
                BEQ     @tcf_fg                     ; no task (boot) -> foreground
                JSR     _Se_CurCtty                 ; A = ctty index, or $FFFF
                CMP     #$FFFF
                BNE     @tcf_haveIdx
                LDA     #0                          ; no ctty -> the console
@tcf_haveIdx    ; index -> byte offset.  TTY_SIZE is not a power of two, so this
                ; adds rather than shifts -- NTTY is 5, at most four passes.
                TAY
                LDA     #0
@tcf_mul        CPY     #0
                BEQ     @tcf_muld
                CLC
                ADC     #TTY_SIZE
                DEY
                BRA     @tcf_mul
                ; THE LINE'S GROUP IS FETCHED FIRST, a reorder rather than
                ; the original's park-and-compare: the accessor answers in A, so
                ; curtask's pgrp cannot wait there.  Parked on the stack and
                ; compared with CMP sr,S -- and the stack is cleaned on BOTH
                ; arms, because the two exits share one PLY/PLX/RTS epilogue and
                ; a word left behind returns to a garbage address on the compare
                ; path while the boot path stays balanced.
@tcf_muld       JSR     _Se_TtyOffToIdx             ; A = offset -> tty index
                JSR     _Tty_PgrpOf                 ; A = the line's fg group
                PHA
                LDA     _curTask
                AND     #$00FF
                JSR     _SE_PGroupOf                ; A = curtask's pgrp (clobbers Y)
                CMP     1,S
                BEQ     @tcf_fgPull
                PLA
                BRA     @tcf_bg                     ; not the fg group -> background
@tcf_fgPull     PLA
@tcf_fg         PLY
                PLX
                SEC
                RTS
@tcf_bg         PLY
                PLX
                CLC
                RTS

;------------------------------------------------------------------------------
; _Sys_Signal (#48) - install a disposition for a signal (CATCH mask + ENTRY).
;
; Caller A = sig, X = handler offset (16-bit in caller's bank).  SIG_DFL=0
; and SIG_IGN=1 are passed through verbatim and treated by the dispatcher
; as "no handler" (the pending bit gets cleared on delivery check, no JML).
; Returns A = previous handler offset.
;------------------------------------------------------------------------------
_Sys_Signal     ENT
                MX      %00
                AND     #$00FF
                STA     _shTmp0                     ; sig
                STX     _shTmp1                     ; new handler

                ; RANGE FIRST.  Every path below indexes a per-task 32-bit mask
                ; as (sig-1)>>3, so a signum past 31 writes outside this task's
                ; four bytes and into a neighbouring pid's -- sig 255 lands 31
                ; bytes downrange.  libc validates 1..31, but the syscall is
                ; reachable directly, and BSD checks in the kernel too
                ; (kern_sig.c: `if (signo <= 0 || signo >= NSIG) EINVAL`).
                BNE     @ss_sigNZ                   ; sig 0 has no disposition
                BRL     @ss_nocatch                 ; (BRL: @ss_nocatch sits past
@ss_sigNZ       CMP     #NSIG                       ;  the whole install body)
                BCC     @ss_rangeOK
                BRL     @ss_nocatch
@ss_rangeOK

                ; Phase 5.1: SIGKILL and SIGSTOP are uncatchable — you cannot
                ; install a handler OR SIG_IGN for them (BSD: sigaction EINVAL).
                CMP     #SIGKILL
                BEQ     @ss_nocatch
                CMP     #SIGSTOP
                BEQ     @ss_nocatch

                LDA     _curTask
                AND     #$00FF
                BNE     @ss_haveTask
                LDA     #ESRCH
                CLC
                RTS
@ss_haveTask    ; _curTask holds the current pid; convert to TCB offset.
                JSR     Task_Lookup
                BCS     @ss_pidOK
                LDA     #ESRCH
                CLC
                RTS
@ss_pidOK       ; SIG_DFL(0)/SIG_IGN(1): update the per-task IGN-mask bit for
                ; EVERY signal (2026-07-27 -- shells ignore SIGTSTP/TTIN/TTOU
                ; to protect themselves; dropping the install stopped tcsh
                ; dead on ^Z).  Then FALL THROUGH: for INT/ALRM/CHLD the arm
                ; below stores the 0/1 into the handler table too, clearing
                ; any stale handler offset exactly as before.
                ; THE IGN BIT IS UPDATED FOR EVERY DISPOSITION, INCLUDING A
                ; REAL HANDLER (apple/fgx#52).  This used to `CMP #2 / BCS
                ; @ss_realh` -- installing a real handler skipped the IGN update
                ; entirely -- so once a signal had been set to SIG_IGN that bit
                ; stayed set FOREVER, and delivery's "Ignored?" arm discarded the
                ; signal silently even though a handler was installed.
                ;
                ; That is the repeated-^C bug: tcsh ignores SIGINT while a
                ; command runs and reinstalls its handler at the prompt, so the
                ; FIRST ^C worked and every one after it vanished -- generated,
                ; unmasked, never dispatched, no diagnostic anywhere.
                ;
                ; BSD cannot have this bug because there the disposition IS the
                ; handler (u_signal[sig]); there is no second ignore mask to go
                ; stale.  FGX splits them, so both halves must move together:
                ; ONLY SIG_IGN sets the bit, SIG_DFL and any real handler clear
                ; it.
                LDA     _shTmp0
                LDY     #SIGHND_IGN_OFF
                JSR     _SigUserBitY
                SEP     #$20
                MX      %10
                LDX     _shTmp1
                CPX     #1
                BEQ     @ss_setIgn                 ; SIG_IGN: set the bit
                LDA     _kSigMask                  ; SIG_DFL or a real handler:
                EOR     #$FF                       ;   clear it
                AND     [_sigHndPtr],Y
                BRA     @ss_wrIgn
@ss_setIgn      LDA     [_sigHndPtr],Y
                ORA     _kSigMask
@ss_wrIgn       STA     [_sigHndPtr],Y
                REP     #$20
                MX      %00
@ss_realh       ; --- CATCH BIT + ENTRY POINT (apple/fgx#58) ---
                ; This used to look up one of five per-signal handler tables and
                ; store the handler offset there, which is why only five signals
                ; could be caught.  The tables were also REDUNDANT: libc passes
                ; the same value for every signal -- _sig_tramp_off, crt0's
                ; adapter (libc_c/signal.c) -- because the per-signal dispatch
                ; happens in the trampoline, out of the process's own table,
                ; exactly where BSD keeps it (u_signal[NSIG] in the u-area).
                ;
                ; So the kernel keeps BSD's proc-struct half instead: one bit
                ; per signal saying "a handler is installed" (p_sigcatch) plus
                ; one entry offset per task.  All 31 signals become catchable,
                ; and the sigHnd block got SMALLER doing it (288 -> 224 B).
                LDA     _shTmp0
                LDY     #SIGHND_CATCH_OFF
                JSR     _SigUserBitY                ; Y = byte, _kSigMask = bit
                SEP     #$20
                MX      %10
                LDX     _shTmp1
                CPX     #2
                BCS     @ss_setCat
                LDA     _kSigMask                   ; SIG_DFL/SIG_IGN: not caught
                EOR     #$FF
                AND     [_sigHndPtr],Y
                BRA     @ss_wrCat
@ss_setCat      LDA     [_sigHndPtr],Y
                ORA     _kSigMask
@ss_wrCat       STA     [_sigHndPtr],Y
                REP     #$20
                MX      %00
                LDA     _shTmp1
                CMP     #2
                BCC     @ss_ret                     ; DFL/IGN: leave ENTRY alone.
                                                    ;   It is only read when the
                                                    ;   CATCH bit is set, and
                                                    ;   that was just cleared.
                LDA     _curTask
                AND     #$00FF
                DEC
                ASL                                 ; (pid-1)*2
                CLC
                ADC     #SIGHND_ENTRY_OFF
                TAY
                LDA     _shTmp1
                STA     [_sigHndPtr],Y
@ss_ret         ; PREVIOUS DISPOSITION IS LIBC'S TO REPORT.  The kernel only
                ; ever sees the trampoline offset, which is the same for every
                ; signal, so returning it would be a useless answer; libc keeps
                ; the real per-signal shadow and signal() returns that.
                LDA     #0
                SEC
                RTS

@ss_nocatch      LDA     #EINVAL
                CLC
                RTS

;------------------------------------------------------------------------------
; _SigIsCaught - C=1 iff _curTask has a user handler installed for signal A.
;
; In:  A = signal number.  MX %00.
; Out: C=1 iff a user handler is installed (the per-task CATCH bit is set).
;      A clobbered, X PRESERVED, Y clobbered.
;
; BSD's p_sigcatch test.  Replaces _SigHndBase, which answered the narrower
; question "does this signal have one of the five handler tables" and was the
; reason only five signals could be caught (apple/fgx#58).  Its own header used
; to warn that keeping the install and delivery chains in sync by hand is how a
; signal becomes installable but undeliverable (apple/fgx#26); with a mask there
; is no chain left to desynchronise -- the bit the install sets IS the bit
; delivery reads.
;
; X IS PRESERVED because both callers rely on it: _Sys_Signal has the TCB
; offset there and _scs_dispatch needs it for @disp_default and @disp_stop.
;------------------------------------------------------------------------------
_SigIsCaught    MX      %00
                PHX
                LDY     #SIGHND_CATCH_OFF
                JSR     _SigUserBitY                ; Y = byte, _kSigMask = bit
                SEP     #$20
                MX      %10
                LDA     [_sigHndPtr],Y
                AND     _kSigMask
                REP     #$20
                MX      %00
                AND     #$00FF
                PLX                                 ; sets N/Z from X, so the
                                                    ;   AND's Z is gone -- carry
                                                    ;   is re-derived below
                CMP     #1                          ; C=1 iff A >= 1, i.e. caught
                RTS

;------------------------------------------------------------------------------
; _Sys_SigSetMask (#102) - install the caller's 32-bit BSD signal mask.
;
; A = mask lo16, X = mask hi16.  Bit (s-1) blocks signal s (the sigmask()
; user convention).  Masked pending signals stay PENDING (_Sys_CheckSignal
; skips them without clearing) and deliver once unmasked.  Returns A=0; the
; OLD mask is the libc-side shadow's job (single-threaded per task), which
; keeps this handler store-only.
;------------------------------------------------------------------------------
; sigsuspend(2)/sigpause(3) -- apple/fgx#59.
;
; WHY A SYSCALL.  libc used to do this in three: sigsetmask(new), SYS_YIELD,
; sigsetmask(old).  Neither half of what sigsuspend promises survived that.
; The mask install and the wait were not ATOMIC, so the awaited signal could
; arrive between them, be handled, and leave the yield waiting for one that had
; already been and gone.  And SYS_YIELD is not a wait at all -- it returns at
; once -- so a bare "sigpause and sleep until the signal" became a 60 Hz spin.
; It only ever worked because csh-family callers loop around it.
;
; 2.11BSD does both inside the kernel (kern_sig2.c sigsuspend), and this is that
; routine: install the mask, then sleep until a signal is ACTIONABLE, looping
; over ordinary wakes exactly as BSD's `while (tsleep(...) == 0) ;` does.
;
; ALWAYS EINTR, NEVER A RESTART.  BSD's comment is literally "always return
; EINTR rather than ERESTART", and it is the one place tsleep's verdict is
; overridden -- restarting a suspend that has already seen its signal would
; wait for a second one.  FGX has no ERESTART at all (apple/fgx#105), so here
; the two systems agree by different routes.
;
; THE PRE-PAUSE MASK IS RESTORED BY LIBC AFTER THIS RETURNS, AND THAT IS BSD'S
; ORDERING RATHER THAN A SHORTCUT.  BSD needs SAS_OLDMASK/u_oldmask so postsig
; can hand the pre-suspend mask to sendsig and have sigreturn install it AFTER
; the handler.  FGX delivers at SYSCALL EXIT: the dispatcher pushes the handler
; frame above this syscall's own return frame, so the handler runs and RTLs back
; into the libc wrapper, which only then restores.  The handler therefore runs
; under the pause mask and the caller's mask comes back after it -- which is
; what SAS_OLDMASK exists to achieve.
;
; In:  A = mask lo16, X = mask hi16 (the SYS_SIGSETMASK shape).
; Out: C=0, A = EINTR.  Always.
_Sys_SigPause   ENT
                MX      %00
                JSR     _Sys_SigSetMask         ; install it HERE, inside the
                                                ;   same syscall as the sleep --
                                                ;   that adjacency IS the
                                                ;   atomicity
@sp_wait        LDA     #WCHAN_PAUSE
                JSR     _sleep
                BCC     @sp_wait                ; woken with nothing actionable
                                                ;   (a masked signal counts as
                                                ;   nothing): wait again, as
                                                ;   BSD's while-tsleep-==-0 does
                LDA     #EINTR
                CLC
                RTS

; THE ROUTINE IS IN THE FAR BANK (src/kernel/far/sigmask.s).  The core bank has
; been at its ceiling for months and this is a cold syscall: the first cut cost
; 119 bytes here against 31 free.  `_Sys_Uptime', `_Sys_RtcRead' and
; `_Sys_RtcWrite' take the same road.
;
; BOTH NUMBERS LAND HERE.  #102 is sigsetmask, whose callers already pass
; how = 0 (= SIG_SETMASK) as their third syscall argument; #120 is sigprocmask
; and passes a real how.  A/X/Y go through untouched -- unlike the RTC thunks,
; this one must NOT stage the caller bank in X, because X is the new mask's
; high word.
;
; In:  A = new mask lo16, X = new mask hi16, Y = how.
; Out: C=1, A = old lo16, Y = old hi16.  C=0 + A = EINVAL for an unknown how.
;------------------------------------------------------------------------------
_Sys_SigSetMask ENT
                MX      %00
                ; #102 HAS NO `how' ARGUMENT AND MUST NOT READ ONE.  It is a bare
                ; wholesale SETMASK and always was; when #120 joined it to one
                ; routine, `how' started coming from Y, and every #102 caller that
                ; had no reason to set Y began sending whatever it happened to
                ; hold.  crt0's signal trampoline is one: it undoes the
                ; handler's self-block with this call and says in its own comment
                ; that "A/X/Y are free here" (toolchain/lib/libc_start.s, @st_back),
                ; so Y was the interrupted handler's leftover.  A value of 4 or
                ; more is EINVAL, which writes NOTHING -- so the block placed by
                ; @disp_usr was never lifted and the signal stayed masked for the
                ; life of the process.  One SIGALRM, one SIGINT, one SIGCHLD ever.
                LDY     #SIG_SETMASK
_Sys_SigProcMask ENT
                MX      %00
_kfp801         JSL     KFAR_SYS_SIGPROCMASK    ; bank byte patched by Far_Init
                RTS

;------------------------------------------------------------------------------
; _Sys_SetITimer (#121) - arm ITIMER_REAL.  The body is far-bank (far/itimer.s);
; this is the thunk.  A, X and Y all pass through untouched: A is it_value
; seconds, X is it_interval seconds and Y is `which', so there is no caller bank
; to stage the way `_Sys_Uptime' and the RTC calls stage theirs.
;
; In:  A = it_value SECONDS, X = it_interval SECONDS, Y = which.
; Out: C=1, A/Y = the OLD counter's remaining TICKS (lo/hi).
;      C=0 + A = EINVAL or ESRCH.
;------------------------------------------------------------------------------
_Sys_SetITimer  ENT
                MX      %00
_kfp1000        JSL     KFAR_SYS_SETITIMER      ; bank byte patched by Far_Init
                RTS

;------------------------------------------------------------------------------
; _Sys_Alarm (#64) - set the current task's SIGALRM timer.
;
; A.lo = seconds (0 cancels).  ticks = seconds * 60 (heartbeat is 60 Hz).
; v1: returns A = 0 unconditionally (no "previous remaining seconds"
; computation).  255-second max keeps the math 16-bit (255*60 = 15300).
;------------------------------------------------------------------------------
_Sys_Alarm      ENT
                MX      %00
                AND     #$00FF
                STA     _shTmp0                     ; seconds

                LDA     _curTask
                AND     #$00FF
                BNE     @sa_haveTask
                LDA     #ESRCH
                CLC
                RTS
@sa_haveTask    ; _curTask holds pid; convert via Task_Lookup (we don't
                ; actually need the TCB offset for the alarm-ticks slot,
                ; only the pid-1 index — but call Task_Lookup to validate
                ; the slot is live).
                JSR     Task_Lookup
                BCS     @sa_pidOK
                LDA     #ESRCH
                CLC
                RTS
@sa_pidOK       ; idx*4 → Y for _kAlarmTicks indexing.
                LDA     _curTask
                AND     #$00FF
                DEC
                ASL
                ASL
                TAY

                ; Compute new tick count = s * 60 = s*64 - s*4.
                LDA     _shTmp0
                ASL
                ASL                                 ; s*4
                STA     _shTmp1
                ASL
                ASL
                ASL
                ASL                                 ; s*64
                SEC
                SBC     _shTmp1                     ; s*60

                ; Store 32-bit (high word = 0 since max 15300 fits in 16-bit).
                STA     _kAlarmTicks,Y
                LDA     #0
                STA     _kAlarmTicks+2,Y
                ; AND CLEAR ANY setitimer(2) INTERVAL, because that is what
                ; alarm(3) is upstream: `timerclear(&itp->it_interval)' followed
                ; by setitimer with the seconds in it_value
                ; (examples/2.11BSD/usr/lib/libc/gen/alarm.c).  Without this an
                ; alarm() after a setitimer() would inherit the repeat and keep
                ; firing, which no caller of alarm() can be asking for.  Y is
                ; (pid-1)*4; the reload is indexed (pid-1)*2.
                TYA
                LSR
                TAX
                STZ     _kAlarmReload,X

                ; Return 0 (v1: no previous-remaining).
                LDA     #0
                SEC
                RTS

;------------------------------------------------------------------------------
; _Sys_CheckSignal - dispatcher-exit hook (Phase 5.1: full default-action model).
;
; Scans every pending signal bit (signum 1..NSIG-1, ascending) in _curTask and,
; for each pending signal, either delivers a user handler or applies the
; per-signal default action from _SigDefAction:
;   - SIGINT / SIGALRM with a handler installed (offset >= 2): clear the bit,
;     schedule the handler, and STOP scanning (one user-handler delivery per
;     syscall exit, as before).  Output for the dispatcher:
;        _Sys_DeliveredSig  = signum
;        _Sys_HandlerOffset = handler offset (16-bit) in the user bank
;        _Sys_HandlerBank   = user code bank byte
;   - Otherwise:
;        SA_TERM -> terminate via _Exit_Core with a WIFSIGNALED wait status
;                   (signum in the low byte).  Never returns.
;        SA_STOP -> mark TASK_STOPPED and swtch away; resumes here when SIGCONT
;                   (post time, in _Sys_Kill) flips the task back to READY.
;        SA_CONT -> drop the bit (the continue already happened at post time).
;        SA_IGN  -> drop the bit.
;
; MUST preserve the caller's C flag (the dispatcher hands it to userland): PHP
; at entry / PLP at each return.  Runs MX %00, DBR=kernel-bank ($02 = assembly
; ORG), on the per-task kernel stack, BEFORE the dispatcher restores user
; DP/SP/DBR.
;------------------------------------------------------------------------------
_Sys_CheckSignal ENT
                MX      %00
                PHP                                 ; preserve caller (C, M0, X0)
                ; RELOC: _Sys_Deliver* are read by the dispatcher via LDAL ($02)
                ; AFTER it restores the user DBR, so they MUST live at $02.  This
                ; routine now runs DBR=kernel-bank under reloc (not literal $02),
                ; so write/read them long ($02), not DBR-relative.
                LDA     #0
_we019          STAL    _Sys_DeliveredSig
                ; Phase 5.3c: drain a pending tty signal request (^C/^Z the
                ; heartbeat consumed and flagged).  Fan it out to the foreground
                ; group HERE (kernel DP — the heartbeat ISR can't touch
                ; _schedTblPtr).  The per-task scan below then delivers it to
                ; _curTask if we belong to that group.  Inert until a shell sets
                ; TTY_FgPgrp (5.3d): with FgPgrp 0 the heartbeat never sets the
                ; flag, so this is a cheap "BEQ" on the common path.
                JSR     _Tty_DrainOutPend
@scs_noTtyReq    ; Slice D: a VC switch is REQUESTED in the keyboard ISR and
                ; executed here, where no task is inside the console engine.
                ; AFTER the label, not before it: the BEQ above skips to here
                ; whenever no tty signal is pending, which is the common case --
                ; a drain placed above would only ever run when a ^C happened to
                ; be in flight, i.e. essentially never.
                JSR     _Vc_DrainSwitch
                JSR     _Con_DrainRestore       ; a desk accessory's screen
                ; ...and the once-a-second lbolt wake (apple/fgx#108 T3).  This
                ; is the site that covers "something else is running": the idle
                ; loop's copy only runs when NOTHING is runnable.  _Lbolt_Wake
                ; (sched.s) is a load-and-branch when no second has elapsed,
                ; which is 59 ticks in 60.
                JSR     _Lbolt_Wake
                LDA     _curTask
                AND     #$00FF
                BNE     @scs_haveTask
                PLP
                RTS
@scs_haveTask   ; tcb_off = $0800 + (pid-1)*64 -> X (for the fast-path test).
                JSR     _CurTcbX
                ; Fast path: nothing pending at all? (one 16-bit OR + branch).
                LDA:    TCB_PendingSig,X            ; bytes 0,1
                ORA:    TCB_PendingSig+2,X          ; bytes 2,3
                BNE     @scs_scan
                PLP
                RTS

@scs_scan       ; _Sys_HandlerIdx = (pid-1)*2 (handler-table index).
                LDA     _curTask
                AND     #$00FF
                DEC
                ASL
                STA     _Sys_HandlerIdx
                LDA     #1
                STA     _scsSig
@scs_loop       ; Rebuild the pending-mask DP ptr from _curTask each iteration:
                ; an SA_STOP swtch can let another task clobber _libcTmp2/X, so
                ; nothing derived before a swtch may be trusted afterward.
                LDA     _curTask
                AND     #$00FF
                DEC
                ASL
                ASL
                ASL
                ASL
                ASL
                ASL                                 ; *64
                CLC
                ADC     #FGX_TASK_TBL_OFF+TCB_PendingSig
                STA     _libcTmp2
                SEP     #$20
                MX      %10
                _BANKK
                STA     _libcTmp2+2
                REP     #$20
                MX      %00
                ; byteidx = sig>>3 ; mask = 1<<(sig&7).
                LDA     _scsSig
                LSR
                LSR
                LSR
                STA     _scsByteIdx
                LDA     _scsSig
                AND     #$0007
                TAY
                LDA     _SigBit_LUT,Y
                AND     #$00FF
                STA     _scsMask
                LDY     _scsByteIdx
                SEP     #$20
                MX      %10
                LDA     [_libcTmp2],Y
                AND     _scsMask
                BNE     @scs_pending
                REP     #$20
                MX      %00
                JMP     @scs_advance
@scs_pending    ; Masked?  (BSD sigmask bit (sig-1); a masked signal stays
                ; PENDING and delivers after SYS_SIGSETMASK unmasks it --
                ; tcsh's pfork blocks SIGCHLD across fork+palloc so pchild
                ; cannot run before the child's pid is recorded.)
                REP     #$20
                MX      %00
                LDA     _scsSig
                LDY     #SIGHND_MASK_OFF
                JSR     _SigUserBitY
                SEP     #$20
                MX      %10
                LDA     [_sigHndPtr],Y
                AND     _kSigMask
                REP     #$20
                MX      %00
                BEQ     @scs_unmasked
                JMP     @scs_advance            ; masked -> leave the bit pending
@scs_unmasked   ; A stop while this task still holds its parent stays pending
                ; (2.11BSD issignal(), apple/fgx#511): stopping a fork child
                ; before it lets go would stop the parent with it.
                LDA     _scsSig
_ktp112         JSL     KTTY_SIG_HOLD
                BCC     @scs_take
                JMP     @scs_advance
@scs_take       LDY     _scsByteIdx             ; re-establish the pending index
                SEP     #$20
                MX      %10
                ; Clear the bit (known set -> EOR clears exactly it).
                LDA     [_libcTmp2],Y
                EOR     _scsMask
                STA     [_libcTmp2],Y
                REP     #$20
                MX      %00
                ; Ignored?  (SIG_IGN honored for EVERY signal since 2026-07-27:
                ; bit (sig-1) in the per-task IGN table.  Bit already cleared
                ; above -> just skip; no action, no default.)
                LDA     _scsSig
                LDY     #SIGHND_IGN_OFF
                JSR     _SigUserBitY
                SEP     #$20
                MX      %10
                LDA     [_sigHndPtr],Y
                AND     _kSigMask
                REP     #$20
                MX      %00
                BEQ     @scs_notIgn
                JMP     @scs_advance            ; ignored -> dropped
@scs_notIgn     JSR     _scs_dispatch               ; SA_TERM path never returns
_we020          LDAL     _Sys_DeliveredSig
                BNE     @scs_ret                    ; a handler was scheduled -> stop
@scs_advance    INC     _scsSig
                LDA     _scsSig
                CMP     #NSIG
                BCS     @scs_ret                    ; (the mask gate pushed
                JMP     @scs_loop                   ;  @scs_loop out of BCC range)
@scs_ret        PLP
                RTS

;------------------------------------------------------------------------------
; _scs_dispatch - act on the single pending signal in _scsSig (bit already
; cleared by the caller).  Re-derives X = TCB offset (an SA_STOP swtch can
; clobber it).  Sets _Sys_DeliveredSig != 0 iff it scheduled a user handler.
; MX %00.  Returns to continue the scan; SA_TERM never returns.
;------------------------------------------------------------------------------

;------------------------------------------------------------------------------
; _CurTcbX - X = _curTask's TCB byte offset ($0800 + (pid-1)*64).  MX %00.
; Clobbers A.  Shared by _Sys_CheckSignal / _scs_dispatch (dedup 2026-07-27).
;------------------------------------------------------------------------------
;------------------------------------------------------------------------------
; _SigUserBitY - user-convention signal-bit locator (dedup 2026-07-27).
; In:  A = signal number (1..31), Y = sigHnd-block table base
;      (SIGHND_MASK_OFF or SIGHND_IGN_OFF).
; Out: Y = base + (curTask pid-1)*4 + ((sig-1)>>3);
;      _kSigMask = 1 << ((sig-1)&7)  (the BSD sigmask() bit, NOT the kernel
;      pending-bit layout).  MX %00.  Clobbers A + _kSigByteIdx (both are
;      recompute-per-use kill-path scratch).
;------------------------------------------------------------------------------

;------------------------------------------------------------------------------
; _Sig_CurOpted - has _curTask opted out of `sig' through the table at Y?
;
; In:  A = signal number, Y = SIGHND_IGN_OFF or SIGHND_MASK_OFF.
; Out: C=1 the bit is set (SIG_IGN, or blocked), C=0 it is not -- boot included.
;      MX %00.  Clobbers A, Y and _SigUserBitY's scratch.
;
; apple/fgx#108 T3.  BSD's `u.u_procp->p_sigignore & sigmask(sig)' and its
; p_sigmask twin, as another bank can ask for them.  The TABLE IS THE ARGUMENT
; because that is how _SigUserBitY already takes it and because upstream tests
; the two fields separately at all four of its background gates -- folding them
; into one "has opted out" answer would read as a simplification of BSD's test
; rather than a spelling of it.
;
; C=0 WITH NO CURRENT TASK.  _SigUserBitY DECs the pid to index its tables, so
; pid 0 would index at $FFFF; the callers that predate this all guard with the
; same test, and answering "has not opted out" is the neutral answer rather
; than a failure a cross-bank caller would have to encode.
;------------------------------------------------------------------------------
_Sig_CurOpted   ENT
                MX      %00
                PHA                             ; sig, while the pid is tested
                LDA     _curTask
                AND     #$00FF
                BEQ     @sco_noTask
                PLA                             ; sig back
                JSR     _SigUserBitY            ; -> Y = byte index, _kSigMask
                LDA     [_sigHndPtr],Y
                AND     _kSigMask
                AND     #$00FF
                BEQ     @sco_no
                SEC
                RTS
@sco_noTask     PLA
@sco_no         CLC
                RTS

;------------------------------------------------------------------------------
; _Sig_CurPending - _curTask's WHOLE pending-signal mask, both words.
;
; Out: A = bytes 0,1.  X = bytes 2,3.  MX %00.  Clobbers A and X.
;
; apple/fgx#108 T3.  BSD's `u.u_procp->p_sig', as another bank can ask for it.
; ttycheckoutq snapshots it, sleeps, and compares -- "did a signal arrive while
; I waited" -- so what it needs is the RAW mask and nothing else.
;
; THE RAW MASK, NOT AN ACTIONABLE ONE.  _Sig_PendingActionable is next door and
; is NOT a substitute: it answers "is there a signal this task would act on",
; which folds in the handler and block tables.  Upstream compares p_sig itself,
; blocked and ignored bits included, and it has to -- a mask filtered by those
; tables would miss an arrival that changes nothing actionable, and would also
; report a difference of zero forever once something ignored was already
; pending.
;
; BOTH WORDS, AND THAT IS THE WHOLE REASON THIS RETURNS TWO REGISTERS.  This
; kernel numbers pending bits `byte = sig>>3, bit = sig&7' with NO decrement
; (@ka_post, :422), so signals 16..23 live in byte 2 -- SIGURG, SIGSTOP,
; SIGTSTP, SIGCONT, SIGCHLD, SIGTTIN and SIGTTOU (loader.s:795-801).  A
; low-word-only answer would be blind to every job-control signal there is,
; which for a routine whose callers are tty-blocked printers is the worst
; possible half to lose.
;
; ZERO WITH NO CURRENT TASK, and _CurTcbX is why the guard comes first: it DECs
; the pid to index the task table, so pid 0 would index at $FFFF.  The sibling
; above guards the same way.  Zero here means "nothing pending", so a boot-time
; caller sees no change and carries on rather than bailing out.
;------------------------------------------------------------------------------
_Sig_CurPending ENT
                MX      %00
                LDA     _curTask
                AND     #$00FF
                BEQ     @scp_noTask
                JSR     _CurTcbX                ; X = this task's TCB offset
                LDA:    TCB_PendingSig+2,X      ; high word out of the way...
                PHA
                LDA:    TCB_PendingSig,X        ; ...low word into A, X still
                PLX                             ;    live for it; then high -> X
                RTS
@scp_noTask     LDA     #0
                TAX
                RTS

_SigUserBitY    MX      %00
                STY     _kSigByteIdx            ; scratch: table base
                DEC                             ; sig-1
                PHA
                AND     #$0007
                TAY
                LDA     _SigBit_LUT,Y
                AND     #$00FF
                STA     _kSigMask
                LDA     _curTask
                AND     #$00FF
                DEC
                ASL
                ASL                             ; (pid-1)*4
                CLC
                ADC     _kSigByteIdx
                STA     _kSigByteIdx
                PLA                             ; sig-1
                LSR
                LSR
                LSR
                CLC
                ADC     _kSigByteIdx
                TAY
                RTS

_CurTcbX        MX      %00
                LDA     _curTask
                AND     #$00FF
                DEC
                ASL
                ASL
                ASL
                ASL
                ASL
                ASL                                 ; *64
                CLC
                ADC     #FGX_TASK_TBL_OFF
                TAX
                RTS

_scs_dispatch   MX      %00
                JSR     _CurTcbX                    ; X = _curTask's TCB offset
                LDA     _scsSig
                JSR     _SigIsCaught                ; C=1 -> a handler is
                                                    ; installed.  Preserves X
                                                    ; (the TCB offset
                                                    ; @disp_default and
                                                    ; @disp_stop both need).
                BCC     @disp_default               ; uncaught -> default action
                JMP     @disp_usr                   ; (JMP, not BRA: @disp_usr
                                                    ;  sits past the SA_STOP arm,
                                                    ;  out of 8-bit branch range)
@disp_default   ; Apply the per-signal default action (8-bit table read).
                SEP     #$20
                MX      %10
                LDY     _scsSig
                LDA     _SigDefAction,Y
                CMP     #SA_TERM
                BEQ     @disp_term
                CMP     #SA_STOP
                BEQ     @disp_stop
                REP     #$20                        ; SA_IGN / SA_CONT: bit already
                MX      %00                         ; cleared -> nothing more
                RTS
@disp_term      REP     #$20
                MX      %00
                LDA     _scsSig
                AND     #$00FF
                STA     _ex_encStatus               ; WIFSIGNALED: signum in low byte
                JMP     _Exit_Core                  ; zombify+wake parent+swtch; no return
@disp_stop      REP     #$20
                MX      %00
                LDA     #TASK_STOPPED
                STA:    TCB_Status,X                ; X = our TCB offset
                ; apple/fgx#109: remember WHICH signal stopped us, so
                ; waitpid(WUNTRACED) can report a real WSTOPSIG instead of a
                ; hardcoded SIGTSTP.  _scsSig is the dispatcher's current signal
                ; and is still live here (@disp_default read the default-action
                ; table with it).  _Uarea_Cur clobbers A and Y but not X, which
                ; the TCB_ParentID read below still needs.
                JSR     _Uarea_Cur                  ; -> _u for the stopping task
                BCC     @disp_stopNoU               ; no u-area (boot): skip
                LDA     _scsSig
                AND     #$00FF
                LDY     #U_StopSig
                STA     [_u],Y
@disp_stopNoU
                ; Wake our parent so a waitpid(WUNTRACED) on us reports the stop
                ; (mirror _exit's parent wakeup; chan = parent's TCB offset).
                ; DP-safe: _wakeup uses _schedTblPtr, valid in this kernel DP.
                LDA:    TCB_ParentID,X
                AND     #$00FF
                BEQ     @disp_stopSw                ; no parent
                PHA                                 ; parent pid (for SIGCHLD)
                JSR     Task_Lookup                 ; X = parent TCB offset
                BCC     @disp_stopPop
                TXA
                JSR     _wakeup
                ; Report the STOP asynchronously too (2026-07-27): BSD raises
                ; SIGCHLD for stopped children as well as dead ones -- tcsh's
                ; pchild reaps stops via wait3(WNOHANG|WUNTRACED), and without
                ; this post pjwait polled forever after ^Z on a foreground job.
                ; Default action is SA_IGN, so wait()-only parents are inert.
                PLA                                 ; parent pid
                LDX     #SIGCHLD
                JSR     _Sys_Kill                   ; clobbers A/X/Y + kill scratch
                BRA     @disp_stopSw
@disp_stopPop   PLA
@disp_stopSw    SEI
                ; Preserve the interrupted syscall's return-value globals across
                ; the job-control stop.  We reached here from the dispatcher exit
                ; (syscall.s: STA _Sys_SavedA / STY _Sys_SavedRetY at :227, consumed
                ; at :258) — the swtch below yields to the shell while we are
                ; TASK_STOPPED, and every shell syscall (Con_GetKey, jobs/bg line
                ; edits, hist_save) re-enters that same exit and OVERWRITES these
                ; $02 globals.  On SIGCONT we resume at the RTS below and
                ; syscall.s:258 reloads them; without this save it would deliver
                ; the SHELL's last return value to our interrupted read() -> a
                ; spurious EOF -> truncated write + unlink of the input file.
                ; The un-fixed sibling of the SE_CallerBank save (sched.s:208);
                ; @disp_stop is the only path that yields in the :227..:258 window,
                ; so a local push/pull across this one swtch suffices.  MX %00 here
                ; (Task_Lookup/_wakeup preserve it; swtch below requires it).
                ;
                ; RELOC (critical): the dispatcher reads/writes _Sys_SavedA/RetY
                ; DBR-RELATIVE, BEFORE the PLB at syscall.s:259 (see :227/:228/:255/
                ; :258, all plain absolute — "DBR still $20").  Under kernel
                ; relocation the live copy is in the relocated kernel bank ($20/$7D),
                ; NOT the baked $02 image.  So we MUST use plain LDA/STA here (DBR =
                ; live kernel bank at @disp_stop, per @disp_stop's own `STA: TCB_*,X`)
                ; to touch the SAME copy the dispatcher does.  (Contrast _Sys_Deliver*
                ; at :521, which are read AFTER PLB → those live at $02 / use LDAL.)
                ; An earlier LDAL/STAL $02 here saved a DEAD copy → no-op fix.
                LDA     _Sys_SavedA
                PHA
                LDA     _Sys_SavedRetY
                PHA
                JSR     swtch                       ; resumes here after a SIGCONT
                PLA                                 ;   or a SIGKILL
                STA     _Sys_SavedRetY
                PLA
                STA     _Sys_SavedA
                ; THE SCAN STARTS AGAIN FROM THE TOP, as 2.11BSD's issig()
                ; does after its stop: a signal posted while this task was
                ; stopped may number below the one that stopped it -- the
                ; SIGKILL that resumed it is 9, a stop is 17 or more -- and
                ; continuing from the stop's number would return to user mode
                ; with it pending.  _scsSig is shared, too, and another task's
                ; scan may have moved it meanwhile.  @scs_advance makes it 1.
                STZ     _scsSig
                CLI
                RTS
@disp_usr       ; Shared user-handler arm: the CATCH bit is set, so the entry
                ; point is this task's single SIGHND_ENTRY_OFF slot -- crt0's
                ; trampoline, which dispatches on the signum itself.  One arm
                ; serves every catchable signal, which is the whole of #58.
                LDA     _Sys_HandlerIdx             ; (pid-1)*2
                CLC
                ADC     #SIGHND_ENTRY_OFF
                TAY
                LDA     [_sigHndPtr],Y
                CMP     #2                          ; never installed / bogus?
                BCC     @disp_nohnd
_we021          STAL     _Sys_HandlerOffset
                LDA     _scsSig
_we022          STAL     _Sys_DeliveredSig
                ; BLOCK THE DELIVERED SIGNAL FOR THE HANDLER'S DURATION
                ; (apple/fgx#53).  2.11BSD's postsig() does
                ; `p_sigmask |= u.u_sigmask[sig] | mask` before invoking the
                ; handler and sigreturn() restores it, so a handler can never be
                ; re-entered by its own signal.  FGX did neither: _Sys_CheckSignal
                ; runs at EVERY syscall exit, including syscalls made from INSIDE
                ; a running handler, so a second ^C could nest a second pintr on
                ; top of the first while it was in write()/ioctl(), and SIGCHLD
                ; could re-enter pchild mid-walk of the proc list -- which is the
                ; kind of thing that presents as unreproducible corruption.
                ;
                ; A masked signal stays PENDING (see @scs_pending above), so the
                ; second one is not lost: it delivers once the mask is restored.
                ;
                ; THE UNDO LIVES IN THE TRAMPOLINE, not here, and it is not a
                ; sigreturn: crt0's _sig_tramp saves the pre-delivery mask on its
                ; OWN frame (so nested deliveries nest) and reinstalls it after
                ; the handler returns.  A handler that never returns normally --
                ; tcsh's pintr1 longjmps out -- therefore leaves the signal
                ; blocked, exactly as it would on BSD, which is why pintr1 ends
                ; with `sigsetmask(sigblock(0) & ~sigmask(SIGINT))`.  That call
                ; only means anything once this block is real.
                LDA     _scsSig
                LDY     #SIGHND_MASK_OFF
                JSR     _SigUserBitY            ; Y = byte idx, _kSigMask = bit
                SEP     #$20
                MX      %10
                LDA     [_sigHndPtr],Y
                ORA     _kSigMask
                STA     [_sigHndPtr],Y
                REP     #$20
                MX      %00
@disp_setBank   SEP     #$20
                MX      %10
                LDA:    TCB_CodeBank,X
_we023          STAL     _Sys_HandlerBank
                REP     #$20
                MX      %00
                RTS
@disp_nohnd     ; No handler: SIGCHLD's default is SA_IGN (bit already cleared;
                ; wait()-based shells never install one); INT/ALRM/TERM/HUP
                ; fall to the default-action table (all four are SA_TERM).
                LDA     _scsSig
                CMP     #SIGCHLD
                BEQ     @disp_ign
                JMP     @disp_default
@disp_ign       RTS

;------------------------------------------------------------------------------
; _Sig_PendingActionable - would a signal ACT on _curTask right now?
;
; Out: C=1 if some signal is pending AND unblocked AND not ignored -- i.e. it
;      will terminate, stop, or run a handler at the next dispatcher boundary.
;      C=0 otherwise.  Preserves A, X, Y.
;
; "Actionable" is the whole point.  Returning C=1 for ANY pending bit would be
; cheaper (one 32-bit OR) but WRONG: BSD does not interrupt a syscall for a
; signal the task has blocked or ignored, and tcsh blocks and ignores signals
; routinely, so the cheap version would spray spurious EINTRs through every
; interactive read.  Hence the per-signal walk, gated behind a fast-path OR so
; the common "nothing pending" case stays two loads and a branch.
;
; NOTE the two different bit layouts, which is why this cannot be one AND:
; the KERNEL pending bits are indexed sig>>3 / 1<<(sig&7), while the user-facing
; mask and IGN tables use the BSD sigmask() convention, (sig-1)>>3 /
; 1<<((sig-1)&7), via _SigUserBitY.  Mixing them silently tests the wrong signal.
;
; MX %00, kernel DP (uses _sigHndPtr), DBR = kernel bank.
;------------------------------------------------------------------------------
_Sig_PendingActionable ENT
                MX      %00
                PHA
                PHX
                PHY
                STZ     _spaRes
                LDA     _curTask
                AND     #$00FF
                BNE     @spa_haveTask               ; (SIG_DFL/SA_IGN test below
                BRL     @spa_done                   ;  pushed @spa_done out of
@spa_haveTask   JSR     _CurTcbX                    ;  8-bit branch range)
                STX     _spaTcb
                LDA:    TCB_PendingSig,X            ; fast path: nothing pending?
                ORA:    TCB_PendingSig+2,X
                BNE     @spa_scan
                BRL     @spa_done
@spa_scan       LDA     #1
                STA     _spaSig
@spa_loop       ; --- pending?  (kernel layout: byte sig>>3, bit 1<<(sig&7))
                LDA     _spaSig
                LSR
                LSR
                LSR
                STA     _spaByteIdx
                LDA     _spaSig
                AND     #$0007
                TAY
                LDA     _SigBit_LUT,Y
                AND     #$00FF
                STA     _spaMask
                LDA     _spaTcb
                CLC
                ADC     _spaByteIdx
                TAX
                SEP     #$20
                MX      %10
                LDA:    TCB_PendingSig,X
                AND     _spaMask
                REP     #$20
                MX      %00
                BEQ     @spa_next                   ; not pending
                ; --- blocked?  (user layout, via _SigUserBitY -> Y + _kSigMask)
                LDA     _spaSig
                LDY     #SIGHND_MASK_OFF
                JSR     _SigUserBitY
                SEP     #$20
                MX      %10
                LDA     [_sigHndPtr],Y
                AND     _kSigMask
                REP     #$20
                MX      %00
                BNE     @spa_next                   ; masked -> stays pending
                ; --- a stop held for a parent?  Not actionable either: the
                ; scan leaves it pending (KTTY_SIG_HOLD), and a sleep that
                ; returned early for it would never block -- so a fork child
                ; would never reach the sleep that lets its parent go.
                LDA     _spaSig
_ktp113         JSL     KTTY_SIG_HOLD
                BCS     @spa_next
                ; --- ignored?
                LDA     _spaSig
                LDY     #SIGHND_IGN_OFF
                JSR     _SigUserBitY
                SEP     #$20
                MX      %10
                LDA     [_sigHndPtr],Y
                AND     _kSigMask
                REP     #$20
                MX      %00
                BNE     @spa_next                   ; ignored -> no action
                ; --- disposition SIG_DFL and the DEFAULT action is "ignore"?
                ; BSD's issignal() drops such a signal: it will neither
                ; terminate, stop, nor run a handler, so interrupting a syscall
                ; for it is wrong.  Testing only the explicit SIG_IGN table
                ; above is not enough -- a task that never touched a signal has
                ; a zeroed IGN mask, so SIGCHLD read as "actionable".
                ;
                ; SIGCHLD is the one that bites, because _Sys_Exit posts it to
                ; the parent on EVERY child death.  Without this test a
                ; background job's exit woke the parent shell out of its console
                ; read, _sleep returned C=1, SYS_READ returned EINTR, bsh took
                ; the short read for EOF and exited -- init then reaped the
                ; shell, left its waitpid loop and halted the machine.  So
                ; `sleep 2 &` killed the system (issue #3).
                ;
                ; A user handler makes it actionable again.  THIS USED TO BE A
                ; SIGCHLD-ONLY TEST, because SIGCHLD was the only SA_IGN-default
                ; signal that could have one.  The comment here said, in as many
                ; words, "add a catchable signal whose default is SA_IGN and
                ; this must be generalised" -- apple/fgx#58 is that change, so
                ; SIGURG/SIGIO/SIGWINCH/SIGINFO can now carry handlers too and
                ; the test is the general one.
                SEP     #$20
                MX      %10
                LDY     _spaSig
                LDA     _SigDefAction,Y
                CMP     #SA_IGN
                BEQ     @spa_defQuiet
                CMP     #SA_CONT                    ; SA_CONT is the same class:
                                                    ;   _Sys_CheckSignal just DROPS
                                                    ;   the bit for a running task
                                                    ;   (it only resumes a STOPPED
                                                    ;   one, and consumes it there),
                                                    ;   so a pending CONT must not
                                                    ;   EINTR a syscall either --
                                                    ;   that is issue #3 again with
                                                    ;   CONT in place of CHLD.
@spa_defQuiet   REP     #$20                        ; REP/SEP leave Z and C alone
                MX      %00
                BNE     @spa_act                    ; default acts -> actionable
                LDA     _spaSig
                JSR     _SigIsCaught                ; reads _curTask itself, not
                                                    ;   _Sys_HandlerIdx -- that
                                                    ;   global is
                                                    ;   _Sys_CheckSignal's
                                                    ;   scratch and belongs to
                                                    ;   whichever task last
                                                    ;   dispatched
                BCC     @spa_next                   ; SA_IGN default, uncaught
@spa_act        LDA     #1                          ; pending, unblocked, unignored
                STA     _spaRes
                BRA     @spa_done
@spa_next       INC     _spaSig
                LDA     _spaSig
                CMP     #NSIG
                BCS     @spa_done                   ; (long back-branch: the
                BRL     @spa_loop                   ;  SA_IGN test grew the loop)
@spa_done       PLY
                PLX
                PLA
                ; Carry is the return value, so it must be set AFTER the pulls
                ; (PLA/PLX/PLY touch N and Z, not C -- but the result lives in a
                ; static precisely so the restore order cannot matter).
                PHA
                LDA     _spaRes
                BEQ     @spa_no
                PLA
                SEC
                RTS
@spa_no         PLA
                CLC
                RTS

;------------------------------------------------------------------------------
; _Sig_ResetOnExec - apply POSIX exec semantics to the CURRENT task's signal
; dispositions.
;
; Caught signals (handler offset >= 2) revert to SIG_DFL.  SIG_IGN (1) is LEFT
; ALONE and the blocked/ignored masks are untouched -- that is the BSD contract:
; exec resets what was CAUGHT, because the handler address belonged to the old
; image and means nothing in the new one, while an inherited "ignore" is a
; deliberate instruction from the parent and must survive.
;
; WHY THIS EXISTS (2026-08-01, issue #1).  fork correctly INHERITS handlers;
; exec is what has to undo that, and it never did.  Task_Alloc zeroes these
; tables for a fresh task, so the gap was invisible until a shell forked and
; exec'd with handlers installed.  MEASURED: `cat` run from tcsh came up with
; SIGINT = $01C5 -- tcsh's handler offset, interpreted in cat's bank.
; _Sys_CheckSignal saw >= 2, called it a user handler and scheduled it instead
; of applying SA_TERM, so ^C killed NO tcsh foreground job.  After this reset the
; same slot reads $0000 and SA_TERM fires.
;
; Call it at the exec COMMIT point, never before: a failed exec must leave the
; process exactly as it was, dispositions included.
;
; MX %00, DBR = kernel bank, kernel DP (uses _sigHndPtr).  Preserves A/X/Y/flags.
;------------------------------------------------------------------------------
_Sig_ResetOnExec ENT
                MX      %00
                PHP
                REP     #$30
                MX      %00
                PHA
                PHX
                PHY
                LDA     _curTask
                AND     #$00FF
                BEQ     @sre_done                   ; no current task
                DEC
                ASL
                ASL                                 ; (pid-1)*4 = mask index
                CLC
                ADC     #SIGHND_CATCH_OFF
                TAY
                ; CAUGHT -> SIG_DFL, wholesale: clearing the CATCH mask is now
                ; the whole of it (apple/fgx#58).  This used to walk five
                ; handler tables comparing each entry against 2.
                ;
                ; IGNORED SURVIVES EXEC and is deliberately untouched -- BSD
                ; resets p_sigcatch and keeps p_sigignore, which is what lets a
                ; shell hand a child a signal it has chosen to ignore.
                LDA     #0
                STA     [_sigHndPtr],Y
                INY
                INY
                LDA     #0
                STA     [_sigHndPtr],Y
@sre_done       PLY
                PLX
                PLA
                PLP
                RTS

;------------------------------------------------------------------------------
; _Sys_AlarmTickAll - decrement every task's alarm counter by 1.  Called
; from the heartbeat task once per VBL tick (60 Hz).  When a counter
; reaches 0 (and was non-zero), OR the SIGALRM bit into that task's
; TCB_PendingSig so the next syscall exit will deliver.
;
; Iterates all MAX_TASKS=16 slots so it's O(16) per tick regardless of
; alarm activity.  Skips zero counters (no decrement, no delivery).
;------------------------------------------------------------------------------
_Sys_AlarmTickAll ENT
                MX      %00
                PHP
                PHX
                PHY
                REP     #$30
                MX      %00
                LDY     #0                          ; Y = task idx (0..15)
@sat_loop       TYA
                ASL
                ASL                                 ; Y*4 = tick-slot offset
                TAX                                 ; X reused as scratch index
                LDA     _kAlarmTicks,X
                ORA     _kAlarmTicks+2,X
                BEQ     @sat_skip
                ; Decrement 32-bit counter.
                LDA     _kAlarmTicks,X
                BNE     @sat_loDec
                ; Lo word is 0; borrow from hi.
                LDA     _kAlarmTicks+2,X
                DEC
                STA     _kAlarmTicks+2,X
                LDA     #$FFFF
                STA     _kAlarmTicks,X
                BRA     @sat_chkZero
@sat_loDec      DEC
                STA     _kAlarmTicks,X
@sat_chkZero    ; Did we hit zero?
                LDA     _kAlarmTicks,X
                ORA     _kAlarmTicks+2,X
                BNE     @sat_skip
                ; RECORD the expiry; do not post the signal here (#152).
                ;
                ; This used to OR the SIGALRM bit straight into TCB_PendingSig
                ; and stop, which is only half of what posting a signal means:
                ; the kill(2) path also WAKES a TASK_BLOCKED target so its
                ; interruptible _sleep re-checks and can bail.  Without the wake
                ; a task blocked on a channel with no other waker slept through
                ; its own alarm forever -- and the timeout case is precisely the
                ; one where no other waker fires.
                ;
                ; It cannot post-and-wake here instead: WE ARE IN THE HEARTBEAT
                ; INTERRUPT (toolbox.s), and _Kill_PostOne walks the scheduler
                ; table that a syscall may be part-way through.  So record the
                ; expiry and let swtch deliver it in scheduler context, exactly
                ; as _kSockWakePending defers the W5100 ISR's wake.
                ;
                ; The live-slot test moved to _Sig_AlarmDeliver with the rest of
                ; the decision; all this arm needs is the index.
                SEP     #$20
                MX      %10
                LDA     #1
                STA     _kAlarmFired,Y              ; Y = task idx (X16 here)
                STA     _kAlarmFiredAny             ; cheap gate for swtch
                REP     #$20
                MX      %00
                ; RE-ARM from the interval (setitimer(2), ITIMER_REAL).  Copied
                ; UNCONDITIONALLY, as upstream copies it -- a zero reload leaves
                ; the counter zero and the timer stays the one-shot alarm(2) is,
                ; so there is nothing here to branch on:
                ;     p->p_realtimer.it_value = p->p_realtimer.it_interval;
                ;               -- vendor/2.11BSD/usr/sys/sys/kern_synch.c:50
                ;
                ; X holds idx*4 (SEP #$20 narrowed the ACCUMULATOR only, and
                ; nothing in this arm touches X); the reload is indexed idx*2,
                ; so it is X halved and then doubled back.  Y is the loop
                ; counter and is left alone.  The expiry recorded just above is
                ; delivered once whatever is reloaded here.
                TXA
                LSR                                 ; idx*2
                TAX
                LDA     _kAlarmReload,X             ; 16-bit ticks
                PHA
                TXA
                ASL                                 ; idx*4 again
                TAX
                PLA
                STA     _kAlarmTicks,X
                STZ     _kAlarmTicks+2,X            ; reload is 16-bit; hi = 0
@sat_skip       INY
                CPY     #TASK_MAX_SLOTS
                BCC     @sat_loop
                PLY
                PLX
                PLP
                RTS

;------------------------------------------------------------------------------
; _Sig_AlarmDeliver - deliver the alarm expiries the heartbeat recorded.
;
; apple/fgx#152.  The other half of _Sys_AlarmTickAll: it flags expiries at
; interrupt time, and this runs them through the SAME post-and-wake routine
; kill(2) uses, in scheduler context where touching the scheduler table is
; legal.  Posting a signal is one operation -- set the bit AND make a blocked
; target runnable -- and having two implementations of it is what let the timer
; path drift into doing only the first half.
;
; Called from swtch, gated on _kAlarmFiredAny.  The gate is cleared by the
; caller BEFORE the scan, so an expiry recorded while we scan is picked up on
; the next switch rather than lost.
;
; SCRATCH DISCIPLINE: _Kill_PostOne writes _shTmp1 / _kSigByteIdx / _kSigMask,
; and swtch runs inside whatever syscall yielded -- which may hold live values
; in those cells.  They are saved and restored here (the shared-DP-cell-across-
; a-switch class: apple/fgx#41, #100).  MX %00 in/out; preserves X and Y.
;------------------------------------------------------------------------------
_Sig_AlarmDeliver ENT
                MX      %00
                PHX
                PHY
                LDA     _shTmp1
                PHA
                LDA     _kSigByteIdx
                PHA
                LDA     _kSigMask
                PHA

                LDY     #0
@sad_loop       SEP     #$20
                MX      %10
                LDA     _kAlarmFired,Y
                BEQ     @sad_next                   ; nothing for this slot
                LDA     #0
                STA     _kAlarmFired,Y              ; consume it
                REP     #$20
                MX      %00
                ; TCB offset = FGX_TASK_TBL_OFF + idx*64
                TYA
                ASL                                 ; *2
                ASL                                 ; *4
                ASL                                 ; *8
                ASL                                 ; *16
                ASL                                 ; *32
                ASL                                 ; *64
                CLC
                ADC     #FGX_TASK_TBL_OFF
                TAX
                ; Live slot?  A counter can outlive its task (exit does not
                ; clear _kAlarmTicks), so an expiry may name a dead slot.
                LDA:    TCB_Status,X
                AND     #$00FF
                CMP     #TASK_UNUSED+1
                BCC     @sad_bump                   ; UNUSED -> nothing to signal
                LDA     #SIGALRM
                JSR     _Kill_PostOne               ; posts the bit AND wakes a
                                                    ;   blocked target -- the one
                                                    ;   routine kill(2) uses too
                BRA     @sad_bump
@sad_next       REP     #$20
                MX      %00
@sad_bump       INY
                CPY     #TASK_MAX_SLOTS
                BCC     @sad_loop

                PLA
                STA     _kSigMask
                PLA
                STA     _kSigByteIdx
                PLA
                STA     _shTmp1
                PLY
                PLX
                RTS

;------------------------------------------------------------------------------
; _SigBit_LUT - 1 << bit, for bits 0..7.  Local to this module.
;------------------------------------------------------------------------------
_SigBit_LUT     DFB     $01,$02,$04,$08,$10,$20,$40,$80

;------------------------------------------------------------------------------
; _SigDefAction - per-signal default disposition (SIG_DFL), indexed by signum
; 0..NSIG-1.  BSD-faithful (see include/loader.s signal numbers).  Consulted by
; _Sys_CheckSignal when a pending signal has no installed handler.
;------------------------------------------------------------------------------
SA_IGN          EQU     0               ; ignore (drop the bit)
SA_TERM         EQU     1               ; terminate (WIFSIGNALED)
SA_STOP         EQU     2               ; job-control stop (TASK_STOPPED)
SA_CONT         EQU     3               ; continue (handled at SIGCONT post time)

_SigDefAction   DFB     SA_IGN          ; 0   (no signal)
                DFB     SA_TERM         ; 1   SIGHUP
                DFB     SA_TERM         ; 2   SIGINT
                DFB     SA_TERM         ; 3   SIGQUIT
                DFB     SA_TERM         ; 4   SIGILL
                DFB     SA_TERM         ; 5   SIGTRAP
                DFB     SA_TERM         ; 6   SIGABRT
                DFB     SA_TERM         ; 7   SIGEMT
                DFB     SA_TERM         ; 8   SIGFPE
                DFB     SA_TERM         ; 9   SIGKILL
                DFB     SA_TERM         ; 10  SIGBUS
                DFB     SA_TERM         ; 11  SIGSEGV
                DFB     SA_TERM         ; 12  SIGSYS
                DFB     SA_TERM         ; 13  SIGPIPE
                DFB     SA_TERM         ; 14  SIGALRM
                DFB     SA_TERM         ; 15  SIGTERM
                DFB     SA_IGN          ; 16  SIGURG
                DFB     SA_STOP         ; 17  SIGSTOP
                DFB     SA_STOP         ; 18  SIGTSTP
                DFB     SA_CONT         ; 19  SIGCONT
                DFB     SA_IGN          ; 20  SIGCHLD
                DFB     SA_STOP         ; 21  SIGTTIN
                DFB     SA_STOP         ; 22  SIGTTOU
                DFB     SA_IGN          ; 23  SIGIO
                DFB     SA_TERM         ; 24  SIGXCPU
                DFB     SA_TERM         ; 25  SIGXFSZ
                DFB     SA_TERM         ; 26  SIGVTALRM
                DFB     SA_TERM         ; 27  SIGPROF
                DFB     SA_IGN          ; 28  SIGWINCH
                DFB     SA_IGN          ; 29  SIGINFO
                DFB     SA_TERM         ; 30  SIGUSR1
                DFB     SA_TERM         ; 31  SIGUSR2

;------------------------------------------------------------------------------
; Signal-dispatcher scratch (kernel-bank statics; $02 = assembly ORG).  Read by syscall.s
; @je_returnToUser after _Sys_CheckSignal sets them up.
;------------------------------------------------------------------------------
_Sys_DeliveredSig   DS  2               ; 0 = no signal pending
_Sys_HandlerOffset  DS  2               ; 16-bit handler addr in user bank
_Sys_HandlerBank    DS  2               ; user code bank (low byte used)
_Sys_HandlerIdx     DS  2               ; scratch: (pid-1)*2

;------------------------------------------------------------------------------
; _Sys_CheckSignal scan scratch + _Sys_Kill target-resolution scratch.
;------------------------------------------------------------------------------
_scsSig         DS  2                   ; CheckSignal: current signum 1..NSIG-1
_scsByteIdx     DS  2                   ; CheckSignal: signum >> 3 (0..3)
_scsMask        DS  2                   ; CheckSignal: 1 << (signum & 7)
_kKillPid       DS  2                   ; Kill: raw 16-bit (signed) pid arg
_kSigByteIdx    DS  2                   ; Kill: sig >> 3 (0..3)
_kSigMask       DS  2                   ; Kill: 1 << (sig & 7)
_tdsPgid        DS  2                   ; _Tty_DeliverSig's OWN fg-group id,
                                        ;   held across the flush arm
_skPgid         DS  2                   ; _Sys_Kill's OWN resolved pgid, held
                                        ;   across _SE_PGroupOf and handed to
                                        ;   the fan-out in X (apple/fgx#379)
_skAll          DS  2                   ; ...and its own killpg1 `all' flag,
                                        ;   handed over in Y
_kPgid          DS  2                   ; Kill: resolved process-group id
_kgfAll         DS  2                   ; Kill: killpg1's `all' -- non-zero makes
                                        ;   the fan-out a BROADCAST (kill(-1)),
                                        ;   which ignores _kPgid and skips init
                                        ;   and the sender
_kgfHits        DS  2                   ; Kill: tasks _Kill_GroupFanout actually
                                        ;   signalled -- BSD killpg1's `f`
                                        ;   (apple/fgx#75).  Read by _Sys_Kill's
                                        ;   group arms; _Tty_DeliverSig ignores
                                        ;   it, as BSD's gsignal does (gsignal
                                        ;   has no return value).
_spaSig         DS  2                   ; PendingActionable: current signum
_spaByteIdx     DS  2                   ; PendingActionable: signum >> 3 (0..3)
_spaMask        DS  2                   ; PendingActionable: 1 << (signum & 7)
_spaTcb         DS  2                   ; PendingActionable: _curTask TCB offset
_spaRes         DS  2                   ; PendingActionable: 1 = actionable found

;------------------------------------------------------------------------------
; TTY table (Phase 5.2) — NTTY entries of TTY_SIZE.  tty[0] = the console.
; TTY_FgPgrp set/read via TIOCSPGRP/TIOCGPGRP and gated by tty read().  Zeroed
; at boot (FGX_Entry).  Kernel-bank static (absolute,DBR=kernel-bank; $02 = ORG — DP-independent, so
; reachable from the dispatcher, ioctl, and the read gate alike).
;------------------------------------------------------------------------------
_ttyTable       DS  NTTY*TTY_SIZE

; Device names for FIODGNAME, one TTYNAME_MAX-byte record per tty, in tty-index
; order -- tty[0] = the console, tty[1..2] = the pty slaves, tty[3..4] = the
; virtual consoles, tty[5] = the serial line.  Kept parallel to _ttyTable rather
; than as a field inside it: the kernel bank is at its ceiling and a per-entry
; field would cost NTTY*TTYNAME_MAX inside a struct that every tty ioctl
; indexes, for data only one op reads.  Names carry NO "/dev/" prefix; libc's
; ttyname() adds it.
;
; THERE MUST BE NTTY RECORDS HERE.  @si_dgname turns a tty index into a record
; offset and copies TTYNAME_MAX bytes from it; nothing bounds that index against
; this table's own length, so a line whose record is missing reads whatever
; assembles next and reports it as a device name.
;
; TTYNAME_MAX MUST equal FIODGNAME_MAX in toolchain/include/sys/ioctl.h -- the
; kernel truncates to this width and the caller sizes its buffer from that one.
; It must also stay a POWER OF TWO: @si_dgname converts index -> record offset
; with three ASLs rather than a multiply.  Changing it means changing both.
TTYNAME_MAX     EQU     8               ; 7 chars + NUL
_ttyNames       ASC     'console',00
                ASC     'ttyp0',00,00,00
                ASC     'ttyp1',00,00,00
                ASC     'ttyv1',00,00,00        ; slice D: tty[3] = VC 1
                ASC     'ttyv2',00,00,00        ; slice D: tty[4] = VC 2
                ASC     'tty01',00,00,00        ; tty[5] = the SCC chan B serial
                ASC     'ttyv3',00,00,00        ; tty[6] = VC 3, the card's.
                                                ; The serial line's index is
                                                ; serial.s SER_TTYIDX_B; the
                                                ; record count is checked by
                                                ; check_ntty, which stops at
                                                ; the first non-ASC line.

;------------------------------------------------------------------------------
; _kTtySigPend (was _kTtySigReq) - pending tty signal requests set by the
; heartbeat when it consumes a ^C/^Z (SIGINT/SIGTSTP) while a foreground group
; owns the tty.  Drained by _Sys_CheckSignal + swtch's idle loop (kernel-DP
; contexts) into _Tty_DeliverSig.  Kernel-bank statics (the heartbeat writes
; them absolute/DBR=kernel-bank, which is DP-independent and the only
; signal-post an ISR on a foreign direct page can safely do).
;
; ONE BYTE PER TTY, ONE BIT PER SIGNAL, because the single word this replaces
; DROPPED SIGNALS (apple/fgx#59).  A ^C and a ^Z, or a ^C on two virtual
; consoles, arriving inside the same drain window meant the second store
; overwrote the first and one was simply lost.
;
; WHY A BITMAP IS NOT AN APPROXIMATION OF BSD BUT THE SAME THING.  BSD's
; ttyinput() gsignals immediately, per event, so nothing can queue up -- but
; what it signals INTO is `p_sig`, a BITMASK, so two SIGINTs to one process
; coalesce there exactly as two set bits do here.  The only case this loses
; that BSD would not is the same signal twice on the same tty inside one drain
; window, which BSD collapses in p_sig a moment later anyway.  Distinct
; (tty, signal) pairs -- what the issue is actually about -- are now lossless.
;
; FGX CANNOT DO THE IMMEDIATE gsignal, and that is why a deferral exists at
; all: the heartbeat ISR runs on the interrupted task's direct page, so
; _schedTblPtr is unreachable and no fan-out is possible from there.  The fix
; is to make the deferral lossless, not to pretend it can be immediate.
;------------------------------------------------------------------------------
; `TTYSIG_INT', `TTYSIG_TSTP', `_kTtySigPend' and `_kTtySigAny' STOOD HERE and
; went at T6 increment 4b with `_Tty_DrainSigPend', the only thing that read
; them.  The heartbeat stopped writing them when the flip handed `^C' and `^Z'
; to `ttyinput'.
; Nonzero when the interrupt-time discipline deferred output on some line.
; apple/fgx#108 T6 increment 4b.
;
; THE SAME SUMMARY SHAPE AS `_kTtySigAny' ABOVE AND FOR THE SAME REASON: the
; drain sits on the syscall-exit path and in the swtch idle loop, so the common
; case has to stay one BEQ rather than a cross-bank call into C.  The per-line
; state is the tty bank's `TS_TIMEOUT' -- upstream's own "output is deferred"
; bit -- and this word only says "at least one of them".
;
; THE ORDER IS THE SAME TOO: `_Tty_DrainOutPend' clears this FIRST and asks the
; bank second, so a heartbeat landing mid-drain costs at worst one extra scan
; that finds nothing.  Clearing it last would drop a mark set inside the window.
;
; SET BY THE HEARTBEAT, not by the tty bank, which is why no far shim carries
; it: the heartbeat is core-bank code and is the only thing that runs the
; discipline at interrupt time, so it can set the summary from `kc_ttyinput's
; own answer without a second crossing.
_kTtyOutAny     DS  2

;==============================================================================
; END signal.s
;==============================================================================
