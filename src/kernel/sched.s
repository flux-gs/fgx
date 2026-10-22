;==============================================================================
;
; FGX - Flux GS uniX
;
; File:     sched.s
; Purpose:  Scheduler core: task selection and the context switch.
;
; The BSD counterparts are sleep/wakeup/swtch in vendor/2.11BSD/usr/sys/sys/
; kern_synch.c.  docs/scheduler.md describes the whole model.
;
;   pick_next   Two passes over the TCB table: pass 1 finds the lowest
;               TCB_Priority among READY tasks, pass 2 round-robins among the
;               tasks at that priority starting after _schedLastSlot.  Both
;               skip a task whose parked user stack cannot come back now.
;   swtch       Save the outgoing task's kernel SP and resume carryover, run on
;               the switch stack (FGX_STK_SWITCH), pick, restore the chosen
;               task's user stack, kernel image and carryover, and RTS into its
;               kernel call chain.  With nothing READY it idles on the switch
;               stack (CLI / WAI / SEI) until an interrupt makes a task ready;
;               there is no PID 0 task.
;==============================================================================

                MX      %00

;=============================================================================
; pick_next - choose the highest-priority READY task.
;
; Scans all TASK_MAX_SLOTS TCBs.  "Highest priority" = lowest TCB_Priority
; value (PRIO_REALTIME=0 .. PRIO_IDLE=7).  Ties round-robin, starting after
; _schedLastSlot.
;
; Out: C=1 + X = TCB byte offset (within the kernel bank) of the chosen task.
;      C=0 if no task is READY.
; Caller MX %00.  Clobbers A, X, Y, _pnBestPri.  Runs DBR=kernel-bank.
;=============================================================================
pick_next       MX      %00
                REP     #$30
                MX      %00
                ; ---- Pass 1: find the best (lowest) priority among READY tasks.
                LDA     #$FFFF
                STA     _pnBestPri
                LDX     #FGX_TASK_TBL_OFF
                LDY     #0                      ; slot counter 0..TASK_MAX_SLOTS-1
@pn_p1          LDA:    TCB_Status,X
                CMP     #TASK_READY
                BNE     @pn_p1n
                ; A task whose bytes are parked and cannot be brought back
                ; right now -- somebody pinned is sitting on its addresses --
                ; is not a candidate.  It must be excluded HERE as well as in
                ; pass 2 -- otherwise it can win _pnBestPri, pass 2 then finds
                ; nobody at that priority, and pick_next returns "nothing
                ; READY" while a runnable lower-priority task sits there.
                ; (B3 scope 4.2b: the borrower case forces this predicate
                ; whatever the trigger, so refusing it bought nothing.)
                JSR     Uimg_CanRun             ; preserves X and Y
                BCC     @pn_p1n
                LDA:    TCB_Priority,X
                AND     #$00FF
                CMP     _pnBestPri              ; strictly lower than best?
                BCS     @pn_p1n
                STA     _pnBestPri
@pn_p1n         TXA
                CLC
                ADC     #TCB_SIZE
                TAX
                INY
                CPY     #TASK_MAX_SLOTS
                BCC     @pn_p1
                LDA     _pnBestPri
                CMP     #$FFFF
                BEQ     @pn_none                ; no READY task

                ; ---- Pass 2: round-robin among READY tasks at _pnBestPri,
                ; starting just AFTER _schedLastSlot.  This is the fairness fix:
                ; a busy task that yields no longer immediately re-wins (it was
                ; always lowest-slot before), so a foreground command is not
                ; starved by a lower-slot background job that spins.
                LDA     _schedLastSlot
                INC
                CMP     #TASK_MAX_SLOTS
                BCC     @pn_startOK
                LDA     #0
@pn_startOK     STA     _pnScan                 ; first slot index to examine
                LDY     #0                      ; iteration count
@pn_p2          ; X = $0800 + _pnScan*64
                LDA     _pnScan
                ASL
                ASL
                ASL
                ASL
                ASL
                ASL
                CLC
                ADC     #FGX_TASK_TBL_OFF
                TAX
                LDA:    TCB_Status,X
                CMP     #TASK_READY
                BNE     @pn_p2n
                LDA:    TCB_Priority,X
                AND     #$00FF
                CMP     _pnBestPri
                BNE     @pn_p2n
                JSR     Uimg_CanRun             ; same test as pass 1
                BCC     @pn_p2n
                ; Found the round-robin winner at the best priority.
                LDA     _pnScan
                STA     _schedLastSlot          ; advance the cursor
                SEC
                RTS                             ; X = chosen TCB offset
@pn_p2n         LDA     _pnScan
                INC
                CMP     #TASK_MAX_SLOTS
                BCC     @pn_p2nok
                LDA     #0
@pn_p2nok       STA     _pnScan
                INY
                CPY     #TASK_MAX_SLOTS
                BCC     @pn_p2
@pn_none        CLC
                RTS

;=============================================================================
; swtch - select the next task and make it current.
;
; Saves the outgoing task's kernel SP and resume carryover in its scheduler-
; state row (SE_KernSP, SE_UserSP/SE_UserDP/SE_CallerBank), so a task can block
; mid-syscall and later resume its kernel call chain.  Then, on the switch
; stack, polls the wake sources, picks (pick_next), and for the chosen task
; restores its user stack bytes (Uimg_Ensure), its carryover and kernel-C
; register file, makes its kernel image resident (_Slot_Ensure), and switches
; D and S to it before RTSing into it.  Nothing READY: idle (@sw_none).
;
; In:  the calling task has already set its own state (READY / BLOCKED /
;      ZOMBIE / STOPPED).
; Out: returns in the context of whichever task was chosen.
; Caller MX %00.  Runs DBR=kernel-bank.
;=============================================================================
swtch           ENT
                MX      %00
                INC    |_vmSwtch                ; cnt.v_swtch++ (kern_synch.c:422)
                BNE     @sw_counted
                INC    |_vmSwtch+2
@sw_counted
                ; Phase 5.3d: wake a keyboard sleeper if keys are pending, on
                ; EVERY switch — not only when the system idles.  A busy
                ; background task (e.g. spinner's `for(;;) yield()`) is always
                ; READY, so @sw_idle never runs; without this, a foreground shell
                ; blocked in read() would never wake while a bg job spins.
                ; DP-safe (kernel DP here; _wakeup uses _schedTblPtr).
                LDA     _kKbdRingCount
                BEQ     @sw_ckTimer
                LDA     #WCHAN_KBD
                JSR     _wakeup
                LDA     _nSelSleepers           ; + a select blocked on a console fd
                BEQ     @sw_ckTimer
                LDA     #WCHAN_SELECT
                JSR     _wakeup
@sw_ckTimer     ; Wake any EXPIRED nanosleep timer on every switch too (not only
                ; when idle): a busy background task is always READY, so @sw_idle
                ; never runs and a lone @sw_idle scan would starve the sleeper —
                ; same lesson as the keyboard wakeup above.  Gated cheap on the
                ; count so the common (no-sleeper) path is one LDA+BEQ.
                LDA     _nTimerSleepers
                BEQ     @sw_ckSock
                JSR     _Timer_WakeExpired
@sw_ckSock      ; Wake any blocked socket op (recv/connect/send) on every switch
                ; if the W5100 ISR flagged a socket event since last time — same
                ; busy-bg-task reasoning as above.  Gated on the flag so we don't
                ; re-poll the slow W5100 indirect bus on every switch; the woken
                ; op re-checks its own condition (data ready / TX space / SR).
                LDA     _kSockWakePending
                BEQ     @sw_ckAlarm
                STZ     _kSockWakePending
                LDA     #WCHAN_SOCK
                JSR     _wakeup
                LDA     _nSelSleepers           ; + a select blocked on a socket fd
                BEQ     @sw_ckAlarm
                LDA     #WCHAN_SELECT
                JSR     _wakeup
@sw_ckAlarm     ; Deliver any alarm the heartbeat flagged (apple/fgx#152).  The
                ; heartbeat runs at interrupt time and must not walk the
                ; scheduler table, so it only RECORDS expiries; posting the
                ; signal and waking the blocked target happen here, in scheduler
                ; context, through the same _Kill_PostOne kill(2) uses.  Before,
                ; the timer path set the pending bit and stopped, so a task
                ; asleep on a channel with no other waker never woke -- which is
                ; every alarm-as-timeout, by definition.
                ; Gate cleared BEFORE the scan: an expiry recorded while we scan
                ; is then picked up next switch rather than dropped.
                LDA     _kAlarmFiredAny
                BEQ     @sw_save
                STZ     _kAlarmFiredAny
                JSR     _Sig_AlarmDeliver
@sw_save        ; ---- Save the OUTGOING task's resume context into its
                ;      sched-entry.  _curTask = outgoing pid; the caller has
                ;      already set its own TCB_Status (READY/BLOCKED/ZOMBIE).
                ;      We save the kernel SP (so it resumes mid-call-chain) plus
                ;      the dispatcher carryover globals (so its eventual
                ;      dispatcher-exit RTLs into the right user context).
                ;      seoff_out = (pid-1) * SE_SIZE = (pid-1) << 5.
                LDA     _curTask
                AND     #$00FF
                BEQ     @sw_pick                ; boot/idle (pid 0) — nothing to save
                DEC
                ASL
                ASL
                ASL
                ASL
                ASL                             ; A = (pid-1)*32 = seoff_out
                STA     _swSeoff
                ; SE_KernSP = current kernel SP
                CLC
                ADC     #SE_KernSP
                TAY
                TSC
                STA     [_schedTblPtr],Y
                ; SE_UserSP = _Sys_UserSP
                LDA     _swSeoff
                CLC
                ADC     #SE_UserSP
                TAY
                LDA     _Sys_UserSP
                STA     [_schedTblPtr],Y
                ; SE_UserDP = _Sys_UserDP
                LDA     _swSeoff
                CLC
                ADC     #SE_UserDP
                TAY
                LDA     _Sys_UserDP
                STA     [_schedTblPtr],Y
                ; SE_CallerBank = _Sys_CallerBank  (Phase 5.3d: a blocked syscall's
                ; caller bank — used by e.g. _Sys_Read to store into the caller's
                ; buffer — must survive an intervening task's syscall, which the
                ; dispatcher otherwise overwrites in this global.  Without it, a
                ; foreground read blocked while a bg job runs stores keystrokes to
                ; the bg task's bank → the shell's line buffer stays stale.)
                LDA     _swSeoff
                CLC
                ADC     #SE_CallerBank
                TAY
                LDA     _Sys_CallerBank
                STA     [_schedTblPtr],Y

                ; ---- Save the kernel-C register file into this task's slot.
                ;
                ; UNGATED SINCE apple/fgx#204.  This used to sit inside
                ; `DO KCPROBE', a knob include/kernel.s describes as "is any
                ; kernel C actually COMPILED IN?  0 in a shipping kernel" --
                ; and that description has been false since vfs.mod shipped.
                ; src/modules/vfs/vfs.s says in as many words that the module
                ; is NOT gated on KCPROBE, its C sleeps in `getblk' and
                ; `biowait', and T4 increment 4 gave the tty bank a real one
                ; too: `ttywait' waits for a queue only the pty master's read
                ; can empty.  So a KCPROBE = 0 kernel had C that sleeps and NO
                ; per-task register file behind it -- and the corruption would
                ; appear in the task that was SUSPENDED, not the one that
                ; overwrote the band.
                ;
                ; It costs what it already cost: KCPROBE = 1 is the committed
                ; setting, so nothing in the shipping build changes size or
                ; speed.  What changes is that the protection stops depending
                ; on a debug knob.
                ;
                ; The slot comes from _curTask inside the routine, which is the
                ; same thing _swSeoff above was derived from.  X and Y are dead
                ; here: pick_next reloads X and every use of Y below recomputes
                ; it.
                ;
                ; The band comes from KC_DP_LO/KC_DP_BYTES in the GENERATED slot
                ; map, which main.s PUTs for exactly this.  Never write those
                ; numbers as literals here -- that would be a second copy of the
                ; map, and when the copies disagree the symptom is C state
                ; corrupted across a sleep, appearing in the task that was
                ; suspended rather than the one that overwrote it.
                ;
                ; Deliberately NOT on the swtch_nosave path below: that entry
                ; abandons its kernel stack rather than suspending on it, so
                ; there is no C frame to come back to.
                JSR     _KcDp_Save

;=============================================================================
; swtch_nosave - enter the scheduler WITHOUT saving a continuation.
;
; For a caller that is ABANDONING its current kernel stack rather than
; suspending on it.  exec is the case: it has re-primed its own kernel stack
; with Task_PrimeKernStack so the next pick resumes it at _Task_FirstRun, and
; swtch's normal @sw_save would immediately overwrite that primed SE_KernSP with
; the very frame being abandoned.
;
; JMP here, never JSR -- there is no return.  Caller: MX %00, SEI held, its own
; TCB_Status already set (READY), and SE_KernSP already primed.
;=============================================================================
swtch_nosave    ENT
                MX      %00
                BRA     @sw_pick

@sw_pick        ; ---- Pick the next task and make it current. ----
                ;
                ; FROM HERE ON swtch STANDS ON ITS OWN STACK.  The outgoing
                ; task's resume SP is saved above (or, for swtch_nosave, its
                ; stack is being abandoned), and no path below returns to the
                ; frame this was entered on: every one ends in a TCS to the
                ; chosen task's saved kernel SP, or comes back here.  So
                ; picking, parking and restoring user images, restoring the kernel-C
                ; register file, idling in WAI and the kernel C the idle arm
                ; enters all push on FGX_STK_SWITCH, and a task's kernel stack
                ; is written only by that task and the interrupts it takes.
                ;
                ; Re-entered from the idle arm with balanced pushes, so
                ; resetting S to the top each time discards nothing live.
                ;
                ; THE CANARY FIRST, while the frame that would have overrun
                ; it is still there to read: the bottom word is $C5C5 from
                ; boot (main.s) and nothing else writes it.  Reported once,
                ; never halted on -- the reset below is about to abandon
                ; whatever overran, so the machine goes on and the log says
                ; the stack is too small.
                LDAL    $000000+FGX_STK_SWITCH
                CMP     #$C5C5
                BEQ     @sw_swOk
                LDA    |_swStkLatch
                BNE     @sw_swOk
                INC    |_swStkLatch
                JSR     _Sw_StkReport
@sw_swOk        LDA     #FGX_STK_SWITCH_TOP
                TCS
                JSR     pick_next               ; C=1 + X=TCB off, or C=0
                BCC     @sw_none
                ; THE USER IMAGE: bring the chosen task's bytes back to its
                ; addresses if they are parked, parking whoever holds them.
                ; This is the ONLY place a task is restored.  It cannot fail:
                ; pick_next already refused every candidate whose addresses
                ; could not be taken (Uimg_CanRun in both passes), and nothing
                ; between that test and here can change residency --
                ; interrupts are off (every swtch caller enters with SEI) and no
                ; other task runs until the TCS below.
                ;
                ; Section 5's "never from interrupt context" holds because swtch
                ; is only ever reached from task context: _sleep, the yield at
                ; the syscall boundary, and _Sys_Exit.  The heartbeat ISR sets
                ; flags and calls _wakeup; it never switches.
                JSR     Uimg_Ensure             ; preserves X
                LDA:    TCB_TaskID,X
                AND     #$00FF
                ; _kCurPid, NOT _curTask.  _curTask is now a per-page identity
                ; and we are still on the OUTGOING task's page here -- storing
                ; the incoming pid into it would make the outgoing page claim
                ; to be somebody else.  The incoming page already reads back
                ; the right pid; SWITCHING D IS THE ASSIGNMENT, and that
                ; happens at the resume below.
                STA     _kCurPid
                ; The cwd rebase USED TO BE HERE and has moved to the resume,
                ; below.  _fsCwdPtr is a DIRECT-PAGE cell, and at this point D
                ; is still the OUTGOING task's kernel page -- so writing the
                ; incoming task's cwd pointer here stored it on the wrong
                ; page, every switch.  Measured on the branch before the move:
                ; init's page held pid 4's cwd slot and pid 2's page held pid
                ; 1's.  It stayed invisible because nearly every task's cwd is
                ; "/", so resolving a relative path against a stranger's cwd
                ; landed in the same directory.
                LDA     #TASK_RUNNING
                STA:    TCB_Status,X
                ; seoff_in = (X - FGX_TASK_TBL_OFF) >> 1
                TXA
                SEC
                SBC     #FGX_TASK_TBL_OFF
                LSR
                STA     _swSeoff
                ; restore carryover globals from sched[next]
                CLC
                ADC     #SE_UserSP              ; A = seoff_in (unchanged by STA)
                TAY
                LDA     [_schedTblPtr],Y
                STA     _Sys_UserSP
                LDA     _swSeoff
                CLC
                ADC     #SE_UserDP
                TAY
                LDA     [_schedTblPtr],Y
                STA     _Sys_UserDP
                ; restore SE_CallerBank -> _Sys_CallerBank (per-task; see save)
                LDA     _swSeoff
                CLC
                ADC     #SE_CallerBank
                TAY
                LDA     [_schedTblPtr],Y
                STA     _Sys_CallerBank

                ; ---- Restore the incoming task's kernel-C register file.
                ;
                ; UNGATED SINCE apple/fgx#204, with the save above.
                ;
                ; Mirror of the save.  _kCurPid is already the INCOMING pid
                ; here -- it was stored just above -- so the routine picks the
                ; right slot with no argument.  (It reads _kCurPid, NOT
                ; _curTask: this runs BEFORE the TCD below, so the direct page
                ; is still the outgoing task's and _curTask would name it.)
                ;
                ; Must run BEFORE the TCS below, which resumes the task with no
                ; further instructions of ours executing.  A is reloaded from
                ; _swSeoff immediately after, so clobbering it here is free.
                JSR     _KcDp_Rest

                ; ---- THE KERNEL IMAGE.  Make the incoming task's slot hold
                ; its page and its stack: bind one if it has none (a task that
                ; has never run, or that exec re-primed), park whoever holds
                ; its slot if it was parked, restore it, and publish the page
                ; and stack top for the dispatcher.  This is the ONLY place a
                ; slot changes hands, and it runs here, on the switch stack,
                ; because the outgoing task may be the one parked -- its slot
                ; is the one most likely to be free of live frames -- and
                ; nothing below stands on any task's stack.
                ;
                ; _Slot_Ensure may REWRITE THE PAGE D NAMES: the outgoing
                ; task's page is a slot page, and the incoming image can land
                ; in that very slot.  So every direct-page read that mattered
                ; happened above, and the resume SP comes back in A rather
                ; than through _swSeoff.  X is the incoming TCB, which the
                ; register-file restore clobbered.
                LDA     _kCurPid
                JSR     Task_Lookup             ; X = the incoming TCB (RUNNING)
                JSR     _Slot_Ensure            ; A = its resume SP
                ; --- the actual context switch ---
                ; D moves to the incoming task's page LAST; the SP rides the
                ; switch stack across the TCD.
                PHA                             ; incoming kernel SP
                LDAL   KFGX_CUR_KDP
                TCD                             ; D = incoming task's kernel page
                PLA                             ; incoming kernel SP
                TCS
                RTS                             ; resumes the chosen task where it
                                                ; last called swtch — or, for a
                                                ; freshly-primed task, at _Task_FirstRun
@sw_none        ; Nothing READY — idle (Phase 4.1).  Instead of a separate PID-0
                ; task, swtch itself idles here, on the scheduler's own stack
                ; taken at @sw_pick: CLI+WAI until an IRQ (the 60 Hz heartbeat)
                ; fires, then re-pick.  Interrupt frames land on that stack too,
                ; never on the blocked caller's.
                ; We run with kernel DP + DBR=kernel-bank, so calling
                ; _wakeup here is DP-safe — the heartbeat ISR can't (it runs with the
                ; interrupted task's DP), which is why the keyboard wakeup lives
                ; here rather than in the heartbeat.  A key landing in the ring
                ; wakes any Con_GetKey sleeper (WCHAN_KBD); if nothing is ever
                ; runnable this is a benign 60 Hz wake-poll-sleep, not busy-spin.
@sw_idle        LDA     #CP_IDLE                ; the tick that wakes us is idle
                STA    |_kCpState
                CLI
                WAI                             ; halt until the next IRQ
                SEI
                LDA     #CP_SYS
                STA    |_kCpState
                ; T6 4b: and restart output the interrupt-time discipline
                ; deferred.  THIS SITE IS NOT BELT-AND-BRACES -- a cooked line
                ; wakes its reader on a LINE DELIMITER, so between the first
                ; keystroke and Enter there may be no syscall at all, and every
                ; echoed character would arrive in a burst when the line was
                ; submitted.  Entering C here is safe for the reason
                ; _Tty_DrainOutPend's header gives.
                JSR     _Tty_DrainOutPend
                JSR     _Con_DrainScroll        ; a console scroll left pending
@sw_noTtyReq    ; Slice D: drain a pending VC switch HERE TOO, not only at
                ; syscall exit.  Alt-N is SWALLOWED by the heartbeat rather than
                ; enqueued -- a shell must not see a stray digit -- so a task
                ; blocked in read() never reaches a syscall boundary and the
                ; request would sit there forever.  AFTER the label: the BEQ
                ; above skips here when no tty signal is pending, so a drain
                ; placed before it is dead code in the common path.
                JSR     _Vc_DrainSwitch
                JSR     _Con_DrainRestore       ; a desk accessory's screen
                ; ...and the once-a-second lbolt wake, for the case that has no
                ; syscall boundary to be honoured at: everything blocked.  See
                ; _Lbolt_Wake below.
                JSR     _Lbolt_Wake
                ; Wake any blocked W5100 socket op (recv/connect/send) so it
                ; re-checks its condition.  Unconditional: the W5100 RX/TX/conn
                ; IRQ (acked by the existing ISR) is what woke this WAI, but we
                ; can't read chip status cheaply here, so just wake + let the op
                ; re-poll (a benign 60 Hz re-poll if nothing's ready).  No-op
                ; scan when no socket sleeper exists.
                LDA     #WCHAN_SOCK
                JSR     _wakeup
                LDA     _nSelSleepers           ; + a block-forever select: the 60 Hz
                BEQ     @sw_idle_ckTimer        ; re-scan safety net (idle => this is the
                LDA     #WCHAN_SELECT           ; main task; catches any missed busy-path
                JSR     _wakeup                 ; wake)
@sw_idle_ckTimer ; Wake any expired nanosleep timer (lone-sleeper case: a `sleep`
                ; that is the only task idles here on the 60 Hz heartbeat until
                ; its deadline passes, then wakes itself).
                LDA     _nTimerSleepers
                BEQ     @sw_idle_kbd
                JSR     _Timer_WakeExpired
@sw_idle_kbd    ; Wake any keyboard sleeper if the heartbeat enqueued a key.
                LDA     _kKbdRingCount
                BNE     @sw_kbdWake             ; ring non-empty -> wake a sleeper
                BRL     @sw_pick                ; ring empty — re-pick (BRL: the cwd
                                                ;   repoint grew @sw_pick past BEQ range)
@sw_kbdWake     LDA     #WCHAN_KBD
                JSR     _wakeup                 ; -> any keyboard sleeper = READY
                BRL     @sw_pick

;-----------------------------------------------------------------------------
; _Sw_StkReport - the switch stack's bottom word is no longer its canary.
;
; Called from @sw_pick with the latch already set, so it runs at most once per
; boot, on whatever stack swtch was entered on.  The word is printed because a
; residue tells a different story from an overrun: $A5A5 is paint that was
; never seeded, anything else is a frame that reached the bottom.
;-----------------------------------------------------------------------------
_Sw_StkReport   MX      %00
                LDA     #@ssr_Msg
                STA     _conStrPtr
                JSR     Kern_LogStrNoEOL
                LDAL    $000000+FGX_STK_SWITCH
                JSR     Kern_LogHex16
                JMP     Kern_LogEOL
@ssr_Msg        ASC     'swstk: switch-stack canary dead, bottom word $',$00
_swStkLatch     DS      2               ; report once per boot

;=============================================================================
; _Task_FirstRun - landing pad for a freshly-spawned task's first resume.
;
; posix_spawn primes the child's kernel stack with a fake swtch-return frame
; whose return address is _Task_FirstRun, and sets SE_KernSP to that frame.
; When swtch first selects the child, its `LDA SE_KernSP / TCS / RTS` lands
; here (on the child's own kernel stack).  We then drop into the child's user
; entry exactly the way main.s resumes PID 1: TCD to the child DP, TCS to its
; primed user stack, PLB+RTL pop [DBR,PCL,PCH,PB] into user code.
;
; _curTask is the child (swtch set it).  Carryover globals were restored by
; swtch from the (still-garbage) sched-entry, so we re-derive from the TCB.
; Entry: MX %00, DBR=kernel-bank, on the child's kernel stack.  Never returns.
;=============================================================================
_Task_FirstRun  ENT
                MX      %00
                LDA     _curTask
                JSR     Task_Lookup             ; X = child TCB offset (C=1)
                LDA:    TCB_DirectPage,X
                TCD                             ; DP = child user DP
                LDA:    TCB_SavedS,X            ; abs,X (DBR=kernel-bank, DP-independent)
                TCS                             ; S = child user stack (primed frame)
                STZ    |_kCpState               ; CP_USER: the child runs user code
                CLI                             ; user runs with IRQs enabled
                PLB                             ; DBR = child (from primed frame)
                RTL                             ; -> child user entry (pops PB:PCH:PCL)

;=============================================================================
; _sleep - block the current task on a wait channel until _wakeup(chan).
;
; In:  A = chan (16-bit, nonzero wait address), X = pri (BSD sleep priority —
;      reserved; the task keeps its TCB_Priority for now).
; Out: returns (CLI'd) when a _wakeup(chan) marks us READY and swtch reselects
;      us — i.e. resumes the caller's syscall right after its _sleep call.
;      C=1 means DO NOT LOOP: a signal is pending that will act on this task at
;      the next dispatcher boundary, so the caller must abandon its wait and
;      return (EINTR).  C=0 = ordinary wake, re-test the condition and carry on.
;      A/X/Y are unchanged by the check.
;
;      The check runs BEFORE blocking as well as after waking.  Before, because
;      a signal posted while we were runnable must not be slept through; after,
;      because that is the case that matters for ^C.  Without this every
;      poll/sleep loop spins forever on a signal it never notices — measured as
;      "^C kills no tcsh foreground job blocked in read()" (issue #2): Con_GetKey
;      was woken on every switch, re-polled a ring the heartbeat had deliberately
;      NOT enqueued into, and slept again, so the syscall boundary that runs
;      _Sys_CheckSignal was never reached.
;
; Caller MX %00.  The caller must re-test its wait condition under SEI (spl) and
; only then call _sleep, to avoid a lost wakeup (an ISR delivering the event
; between the test and the BLOCKED mark).  _sleep keeps IRQs masked across the
; switch and CLIs on wake.
;
;=============================================================================
_sleep          ENT
                MX      %00
                SEI                             ; spl — close the lost-wakeup race
                STA     _slpChan                ; A = chan
                ; Don't block with an actionable signal already pending.
                JSR     _Sig_PendingActionable
                BCC     @slp_go
                CLI
                SEC                             ; C=1: interrupted, never slept
                RTS
@slp_go         JSR     Img_Release             ; a snapshot child lets its
                                                ;   parent run (process.s)
                JSR     _Slp_Block
                ; Woken: tell the caller whether to give up rather than re-wait.
                JSR     _Sig_PendingActionable  ; -> C
                CLI                             ; (CLI does not touch carry)
                RTS

;=============================================================================
; _sleepUn - UNINTERRUPTIBLE sleep.  BSD's PRIBIO, without PCATCH.
;
; In:  A = chan (16-bit).  Caller MX %00.  Returns C=0 always.
;
; WHY A SECOND ENTRY POINT RATHER THAN A FLAG.  _sleep's contract is "C=1 means
; a signal is pending, abandon the wait and return EINTR", and every caller of
; it is a poll loop that can do that.  A BUFFER LOCK WAIT CANNOT.  The waiter
; holds no error path: vfs_bio's getblk and getnewbuf sleep and then `goto
; loop` to re-test, because a buffer that is B_BUSY is not a condition the
; caller can decline.  Handed _sleep, an actionable signal would make it return
; C=1 WITHOUT EVER SLEEPING, the loop would re-test, call again, and spin at
; full speed for as long as the signal stayed pending.
;
; 2.11BSD and Reno both sleep at PRIBIO for buffers, and PRIBIO is below
; PZERO -- so it is not interruptible there either.  This is that priority, not
; a new idea.
;
; The state that distinguishes the two is NOT a shared cell.  A flag byte set
; before the switch and read after it is read on the far side of a context
; switch, where another task has had the machine -- the shape of apple/fgx#41,
; where a ctty gate slept without saving a shared DP cell.  Two entry points
; around one body keep the distinction in the PROGRAM COUNTER, which the
; switch already preserves per task.
;=============================================================================
; NO RELEASE HERE, unlike _sleep: exec's disk reads sleep here, and a fork
; child released on them would swap its parent in and out again while the
; image loads -- two more image copies on the shell's fork-then-exec path.
_sleepUn        ENT
                MX      %00
                SEI                             ; spl — close the lost-wakeup race
                STA     _slpChan                ; A = chan
                JSR     _Slp_Block
                CLC                             ; never "give up": no error path
                CLI                             ; (CLI does not touch carry)
                RTS

;=============================================================================
; _Slp_Block - mark the current task BLOCKED on _slpChan and switch away.
;
; The body both sleeps share.  Entered with IRQs already masked and _slpChan
; already set; returns when something wakes us, IRQs still masked.
;
; It runs one JSR deeper than the old fall-through did, so the kernel stack is
; two bytes taller at the moment of the switch.  That is preserved per task by
; SE_KernSP like the rest of the frame.
;=============================================================================
_Slp_Block
                ; --- B3 ASSERTION.  Sleeping interruptibly while the kernel
                ; holds a pointer into our own user stack is exactly the
                ; combination address-preserving stack swap cannot survive: the
                ; swapper would see an eligible victim, park it, and the holder
                ; would go on writing bytes that are no longer there.  No path
                ; does this today (the B3.0 survey found only writes into
                ; NOT-YET-RUNNABLE tasks), so this is a tripwire for the path
                ; somebody adds later -- loud in development instead of silent
                ; corruption once B3.2 lands.  See SEF_STKLOCK in include/kernel.s.
                ;
                ; It sits AFTER the pending-signal early-out on purpose: that arm
                ; returns without ever blocking, so it is not a sleep.
                ;
                ; The sleeper's TCB comes first, and a pid with none halts:
                ; 2.11BSD tsleep() (sys/kern_synch.c) panics "tsleep" when the
                ; sleeper is not a running process.  Every store below is
                ; indexed by this pid, and with no task behind it they land in
                ; kernel memory that belongs to nobody -- silently
                ; (apple/fgx#469).  X is the TCB offset from here to the
                ; TASK_BLOCKED store; nothing between them touches X.
                LDA     _curTask
                JSR     Task_Lookup
                BCS     @slp_haveTask
                JMP     _Slp_NoTaskPanic
@slp_haveTask
                LDA     _curTask
                AND     #$00FF
                DEC
                ASL
                ASL
                ASL
                ASL
                ASL
                CLC
                ADC     #SE_Flags
                TAY
                LDA     [_schedTblPtr],Y
                AND     #SEF_STKLOCK
                BEQ     @slp_lockOK
                JSR     _Slp_StkLockPanic
@slp_lockOK
                ; SE_WaitChan[_curTask] = chan      (seoff = (pid-1)<<5)
                LDA     _curTask
                AND     #$00FF
                DEC
                ASL
                ASL
                ASL
                ASL
                ASL
                CLC
                ADC     #SE_WaitChan
                TAY
                LDA     _slpChan
                STA     [_schedTblPtr],Y
                ; TCB_Status[_curTask] = TASK_BLOCKED  (X = its TCB, from above)
                LDA     #TASK_BLOCKED
                STA:    TCB_Status,X
                JSR     swtch                   ; resume another task; back here on wake
                RTS                             ; IRQs still masked; the two
                                                ;   entry points differ in what
                                                ;   they do from here

;=============================================================================
; _Slp_StkLockPanic - report the B3 stack-lock violation, then halt.
;
; Names the offending pid, because "PANIC" alone has cost this project whole
; sessions before (issue #9: a silent stack-guard kill presented as "a sourced
; script just stops").
;
; IT HALTS.  B3.2 has landed, so this is no longer a tripwire for a hypothetical
; future path -- the swapper exists, and a task that sleeps interruptibly while
; the kernel holds a pointer into its user stack is an eligible victim whose
; bytes are about to move out from under a live pointer.  That is silent memory
; corruption in another task's address space, and the one thing worse than
; halting is continuing.
;
; It reported-and-returned until 2026-08-07, deliberately: before a swapper
; existed nothing was actually corrupted, and halting would have hung the
; harness on a timeout and hidden every later occurrence, where returning let a
; run accumulate every offending pid.  That trade inverted the moment the swap
; became real -- which is exactly the kind of "revisit when X lands" note that
; goes quiet and stays quiet, so it is being honoured on the day X landed.
;
; The pid is still named first.  "PANIC" alone has cost this project whole
; sessions (issue #9: a silent stack-guard kill presented as "a sourced script
; just stops"), and a halt with no name is the same defect with a louder symptom.
;=============================================================================
_Slp_StkLockPanic
                MX      %00
                LDA     #_slpLockMsg
                STA     _conStrPtr
                JSR     Kern_LogStrNoEOL
                LDA     _curTask
                AND     #$00FF
                JSR     Kern_LogDec16
                JSR     Kern_LogEOL
                JMP     _Kern_Halt              ; see the header: this is live
                                                ; corruption now, not a tripwire

_slpLockMsg     ASC     'PANIC B3: interruptible sleep with SEF_STKLOCK held, pid ',$00

;=============================================================================
; _Slp_NoTaskPanic - a sleep by a pid with no TCB, then halt.
;
; 2.11BSD's tsleep panics "tsleep" when the sleeper is not a running process.
; Pid 0 is the usual form here: a sleep issued while _curTask does not name the
; running task's slot page, which is what apple/fgx#468 was.  Named, because
; the stores it stops were silent.
;=============================================================================
_Slp_NoTaskPanic
                MX      %00
                LDA     #_slpNoTaskMsg
                STA     _conStrPtr
                JSR     Kern_LogStrNoEOL
                LDA     _curTask
                AND     #$00FF
                JSR     Kern_LogDec16
                JSR     Kern_LogEOL
                JMP     _Kern_Halt

_slpNoTaskMsg   ASC     'PANIC tsleep: no task for pid ',$00

;=============================================================================
; _wakeup - mark every task blocked on chan READY.  Does NOT switch.
;
; In:  A = chan (16-bit).  Callable from mainline OR an ISR (short, no alloc).
; Caller MX %00.  Clobbers A, X, Y.  DBR=kernel-bank.
;
; THE BRACKET IS WHAT MAKES THAT SECOND SENTENCE TRUE (apple/fgx#108 T6
; increment 3).  It was a CLAIM until 2026-08-26 and the claim was false.  All
; sixteen call sites were enumerated with their interrupt state and NOT ONE
; masks on its own -- the three in `swtch_nosave' only inherit SEI from the idle
; loop's CLI/WAI/SEI, and the two that `ttwakeup' actually takes,
; `_FarSh_Wakeup' and `_FarSh_SelWakeup', mask nothing at all.
;
; `_wkChan' BELOW IS A SINGLETON, so an ISR entering here on top of an
; interrupted _wakeup replaces the channel MID-SCAN.  The outer scan then
; compares its REMAINING slots against the wrong channel, and a task blocked on
; the outer one is never marked READY.  That is a lost wakeup, which is a hang
; in whichever task drew the short straw -- the failure shape that presents in
; the victim rather than the culprit.
;
; IT GOES INSIDE RATHER THAN AT THE CALL SITES, all sixteen of which are then
; unaffected, and it is upstream's model: `dzrint' calls `wakeup()' straight
; from the receive interrupt (examples/2.11BSD/usr/sys/pdpuba/dz.c), protected
; by nothing but priority level.  The scan is bounded by TASK_MAX_SLOTS and
; MEASURED non-blocking -- no sleep, no swtch, no WAI on any path -- so the
; masked region is a few hundred cycles against a 16 ms VBL.
;
; PLP RESTORES, it does not enable: a caller already holding SEI (swtch, and
; every ISR that will reach here at T6) gets SEI back.
;=============================================================================
_wakeup         ENT
                MX      %00
                PHP
                SEI
                STA     _wkChan
                LDX     #FGX_TASK_TBL_OFF
@wk_loop        LDA:    TCB_Status,X
                CMP     #TASK_BLOCKED
                BNE     @wk_next
                ; seoff+SE_WaitChan -> Y ; compare SE_WaitChan to chan
                TXA
                SEC
                SBC     #FGX_TASK_TBL_OFF
                LSR
                CLC
                ADC     #SE_WaitChan
                TAY
                LDA     [_schedTblPtr],Y
                CMP     _wkChan
                BNE     @wk_next
                LDA     #0
                STA     [_schedTblPtr],Y        ; SE_WaitChan = 0 (no longer waiting)
                LDA     #TASK_READY
                STA:    TCB_Status,X
@wk_next        TXA
                CLC
                ADC     #TCB_SIZE
                TAX
                CPX     #FGX_TASK_TBL_OFF+{TASK_MAX_SLOTS*TCB_SIZE}
                BCC     @wk_loop
                PLP                             ; see the header: restores, and
                RTS                             ;   does not enable

;=============================================================================
; _Lbolt_Wake - BSD's `wakeup((caddr_t)&lbolt)'.  apple/fgx#108 T3.
;
; The PERFORMING half of the split the heartbeat's comment describes: the
; heartbeat counts VBLs and sets _kLboltDue; this runs the wakeup, on the
; kernel direct page where _wakeup can reach _schedTblPtr.
;
; THAT IS 2.11BSD's OWN SHAPE.  hardclock sets `needsoft' and defers to
; softclock (kern_clock.c:142) precisely because a callout may call wakeup();
; schedcpu is such a callout and `wakeup((caddr_t)&lbolt)' is its first line
; (kern_synch.c:36).  FGX marks in the ISR and performs in a safe context for
; the same reason, and reuses the two sites _Tty_DrainSigPend already drains
; at, because between them they cover both cases: _Sys_CheckSignal when
; something is running and making syscalls, and swtch's idle arm when
; everything is blocked -- which is exactly when a tty writer waiting on a slow
; device needs it and the syscall boundary will never come.
;
; WHAT THIS DOES NOT DO, STATED RATHER THAN DISCOVERED: 2.11BSD writes
; `++runrun;  /* swtch at least once a second */' on the line before it re-arms
; the callout (kern_synch.c:71), which FORCES a reschedule and so guarantees
; every runnable process reaches the scheduler each second.  FGX cannot: Model
; A preemption "never preempts kernel code; the dispatcher honors it between
; syscalls" (toolbox.s), so a CPU-bound task that issues no syscall reaches
; neither drain site and an lbolt sleeper waits behind it.  That is FGX's
; EXISTING preemption divergence rather than a new one this introduces -- but
; it is the reason an lbolt sleeper must never be the only thing standing
; between a caller and correctness.  Every 2.11BSD site treats it as "retry
; shortly", re-tests its condition on waking and loops, which is what makes the
; weaker guarantee survivable.
;
; In:  none.  MX %00.  DBR=kernel-bank, kernel DP.  Clobbers A, X, Y.
; Out: C=1 it woke the channel, C=0 nothing was due.
;
; THE CARRY EXISTS FOR THE PROBE, and it is the cheap way to make the guard
; TESTABLE rather than merely present.  Asserting only that the flag ends up
; clear cannot tell a correct routine from one whose `BEQ' has been deleted:
; both leave it clear, because the unconditional version STZs it too.  The
; difference is whether _wakeup ran, and nothing else here can see that.  A
; branch already knows the answer, so reporting it costs one SEC/CLC and no
; state -- a counter would have been two bytes of kernel data existing only to
; be asserted.
;=============================================================================
_Lbolt_Wake     ENT
                MX      %00
                LDA     _kLboltDue
                BEQ     @lbw_none               ; the common path: 59 ticks in 60
                STZ     _kLboltDue
                LDA     #WCHAN_LBOLT
                JSR     _wakeup
                SEC
                RTS
@lbw_none       CLC
                RTS

;=============================================================================
; _Timer_WakeExpired - mark every WCHAN_TIMER-blocked task whose SE_WakeTime
; deadline has passed (32-bit _kSystemTicks >= SE_WakeTime) READY.  A timer-
; specialized _wakeup: same scan, plus the deadline compare.  Called from swtch
; (@sw_save, gated on _nTimerSleepers, so a busy bg task can't starve a sleeper)
; and the idle loop (@sw_idle, lone-sleeper case).  Runs under SEI (callers mask
; IRQs across swtch), so _kSystemTicks is stable across the 32-bit compare.
; MX %00.  DBR=kernel-bank.  Clobbers A, X, Y.
;=============================================================================
_Timer_WakeExpired MX   %00
                LDX     #FGX_TASK_TBL_OFF
@tw_loop        LDA:    TCB_Status,X
                CMP     #TASK_BLOCKED
                BNE     @tw_next
                ; seoff = (X - FGX_TASK_TBL_OFF) >> 1  (X preserved as TCB off)
                TXA
                SEC
                SBC     #FGX_TASK_TBL_OFF
                LSR
                STA     _twSeoff
                ; SE_WaitChan == WCHAN_TIMER ?
                CLC
                ADC     #SE_WaitChan
                TAY
                LDA     [_schedTblPtr],Y
                CMP     #WCHAN_TIMER
                BNE     @tw_next
                ; expired?  32-bit: now (_kSystemTicks) - SE_WakeTime, no borrow.
                LDA     _twSeoff
                CLC
                ADC     #SE_WakeTime
                TAY                             ; Y -> SE_WakeTime low word
                LDA     _kSystemTicks
                SEC
                SBC     [_schedTblPtr],Y        ; now.lo - deadline.lo
                INY
                INY                             ; Y -> SE_WakeTime high word
                LDA     _kSystemTicks+2
                SBC     [_schedTblPtr],Y        ; now.hi - deadline.hi (borrow chain)
                BCC     @tw_next                ; borrow -> now < deadline -> not expired
                ; expired: SE_WaitChan = 0, TCB_Status = READY
                LDA     _twSeoff
                CLC
                ADC     #SE_WaitChan
                TAY
                LDA     #0
                STA     [_schedTblPtr],Y
                LDA     #TASK_READY
                STA:    TCB_Status,X
@tw_next        TXA
                CLC
                ADC     #TCB_SIZE
                TAX
                CPX     #FGX_TASK_TBL_OFF+{TASK_MAX_SLOTS*TCB_SIZE}
                BCC     @tw_loop
                RTS

;=============================================================================
; _Sys_Yield (SYS_YIELD = 79) - voluntarily yield the CPU.  Keeps the caller
; READY so pick_next reselects it when nothing else is runnable (returns to
; self in the single-task case).  MX %00.
;
; (Round-robin within a priority level is a later refinement — pick_next still
; breaks ties by lowest slot, so two same-priority tasks don't yet alternate.)
;=============================================================================
_Sys_Yield      ENT
                MX      %00
                ; P2': servicing a yield clears the resched request + its
                ; userland mirror, so a safepoint that called SYS_YIELD here
                ; doesn't also trip the dispatcher's F5 hook on the way out
                ; (one swtch per request, not two).
                LDA     #0
                STA     _kYieldReq
                STAL    KFGX_YIELD_MIRROR
                LDA     _curTask
                AND     #$00FF
                BEQ     @yld_ret                ; no user task (boot) — nop
                JSR     Task_Lookup
                LDA     #TASK_READY
                STA:    TCB_Status,X            ; stay runnable
                SEI
                JSR     swtch
                CLI
@yld_ret        SEC
                RTS

;=============================================================================
; _Sys_Nanosleep (SYS_NANOSLEEP = 83) - block the caller for A ticks (60 Hz).
;
; Idle-blocks via _sleep(WCHAN_TIMER); _Timer_WakeExpired wakes us once
; _kSystemTicks reaches our deadline.  A signal (e.g. ^C -> SIGINT) can wake us
; early -> EINTR.  MX %00.
;   In:  A = duration in ticks (16-bit).  A=0 returns immediately.
;   Out: C=1 + A=0 when the deadline passes; C=0 + A=EINTR if a signal woke us
;        first (now < deadline on resume).
;
; The post-_sleep seoff is RECOMPUTED from _curTask, never read from a static:
; another task's nanosleep would clobber a shared scratch across our block (the
; cross-block-global-state class).  SE_WakeTime is per-task (in the sched-entry)
; so it survives correctly.
;=============================================================================
_Sys_Nanosleep  ENT
                MX      %00
                CMP     #$0000
                BNE     @ns_arm
                LDA     #0                      ; A=0 -> no wait, success
                SEC
                RTS
@ns_arm         STA     _nsDur                  ; save duration ticks
                LDA     _curTask
                AND     #$00FF
                BEQ     @ns_now                 ; no user task (defensive) — success
                ; seoff = (pid-1)<<5 ; SE_WakeTime = _kSystemTicks + duration (32-bit)
                DEC
                ASL
                ASL
                ASL
                ASL
                ASL
                CLC
                ADC     #SE_WakeTime
                TAY                             ; Y -> SE_WakeTime low
                LDA     _kSystemTicks
                CLC
                ADC     _nsDur
                STA     [_schedTblPtr],Y
                INY
                INY                             ; Y -> SE_WakeTime high
                LDA     _kSystemTicks+2
                ADC     #0                      ; + carry from low add
                STA     [_schedTblPtr],Y
                INC     _nTimerSleepers         ; arm the per-swtch timer scan
                LDA     #WCHAN_TIMER
                JSR     _sleep                  ; blocks; back here on wake
                DEC     _nTimerSleepers
                ; Expired (success) or signal-woken early (EINTR)?  Recompute our
                ; seoff (a shared scratch may have been clobbered during the block).
                LDA     _curTask
                AND     #$00FF
                DEC
                ASL
                ASL
                ASL
                ASL
                ASL
                CLC
                ADC     #SE_WakeTime
                TAY
                LDA     _kSystemTicks           ; now >= deadline ?  (32-bit, no borrow)
                SEC
                SBC     [_schedTblPtr],Y
                INY
                INY
                LDA     _kSystemTicks+2
                SBC     [_schedTblPtr],Y
                BCC     @ns_eintr               ; now < deadline -> a signal woke us
@ns_now         LDA     #0
                SEC
                RTS
@ns_eintr       LDA     #EINTR
                CLC
                RTS

;------------------------------------------------------------------------------
; swtch/_Task_FirstRun/_sleep/_wakeup scratch (kernel-bank statics).
;------------------------------------------------------------------------------
_swSeoff        DS      2                       ; sched-entry byte offset scratch

;------------------------------------------------------------------------------
; _kcDpSave - per-task save area for the KERNEL-C DIRECT-PAGE REGISTER FILE.
;
; fcc's register file is ONE SHARED PAGE (FGX_DP_KERNELC), so the moment kernel
; C can be suspended mid-call the file has to be saved and restored with the
; rest of the task's context -- the same way BSD saves registers.  A task's C
; FRAMES need no help: kernel C compiles with -fno-safepoints and frames on the
; bank-0 hardware stack (`TSC/SBC/TCS` in its prologue, no _fcc_sfp anywhere),
; which is the task's kernel stack and is already preserved by SE_KernSP.  The
; register file is the only shared part, and this is it.
;
; STRIDE IS A POWER OF TWO so the slot offset is seven shifts of (_curTask-1)
; rather than a multiply on the switch path.  The 24 bytes per task that buys
; costs nothing anyone can measure and only exists in a debug kernel at all.
; The table is NPROC slots of 128 bytes; there is no slot for pid 0 and none is
; needed.
;
; DS zero-fills in a fixed-address binary, so a task resumed before it has ever
; entered C restores zeros rather than garbage -- which is also what _KcProbe
; explicitly establishes before the first call, because two of fcc's slots are
; READ BEFORE THEY ARE WRITTEN.  _KcProbe's own self-test has to put the two
; slots it borrows BACK to zeros for that to stay true; it does, and the reason
; is written out there.
;------------------------------------------------------------------------------
KC_DP_STRIDE    EQU     128
                ERR     {KC_DP_BYTES-1}/KC_DP_STRIDE  ; stride must cover the band

; THESE ARE NOT GATED ON KCPROBE, apple/fgx#204.  They were, and the gate meant
; that a kernel built the way include/kernel.s says a SHIPPING one is built --
; "KCPROBE ... 0 in a shipping kernel" -- had no per-task register file at all,
; while vfs.mod's C and the tty bank's kept sleeping.  The knob answers "is the
; boot self-test compiled in", which is a different question from "does kernel C
; exist", and the two stopped having the same answer the day the first module
; carried C of its own.  `_KcProbe' in main.s is still gated: it IS the
; self-test.

;------------------------------------------------------------------------------
; _KcDp_Save / _KcDp_Rest - copy the kernel-C register file to/from the
; CURRENT task's slot.
;
; In:  nothing.  MX %00.  The slot comes from _curTask.
; Out: A, X, Y clobbered.  Carry undefined -- both callers set it themselves.
;
; The slot used to be an argument, computed as `_swSeoff ASL ASL` at each of
; the two call sites.  That put the same arithmetic in two places and left it
; unreachable from any test -- the boot check drove these routines with literal
; slot numbers, so a call site that computed the WRONG slot but still landed
; inside the table would have passed everything in the tree.  Both sides derive
; _swSeoff from _curTask anyway (the save path from _curTask directly, the
; restore path from the incoming TCB after it has already stored _curTask), so
; taking it from _curTask here makes it ONE computation, on the only path that
; matters, and the boot check drives that computation instead of bypassing it.
;
; These are SUBROUTINES rather than inline copies in swtch for one reason: a
; loop nobody can call is a loop nobody can test.  Inline, the only thing that
; would ever execute them is a context switch between two tasks that have both
; entered kernel C -- which nothing does yet -- so a wrong stride or a wrong
; bound would sit green through every test in the tree and surface later as
; corrupted C state in a task that did nothing wrong.  Factored out, _KcProbe
; can drive them at boot with a known pattern and prove they round-trip.
;
; The band is KC_DP_LO/KC_DP_BYTES from the GENERATED slot map.  Never a
; literal: that would be a second copy of the map.
;------------------------------------------------------------------------------
; _KcDp_Slot - A = the current task's slot base, C=1.  C=0 if there is none.
;
; pid 0 is the boot/idle context.  It has no slot and never needs one: the save
; path returns before reaching here for pid 0, and every task pick_next chooses
; has pid >= 1.  The guard exists so the boot self-test can drive these routines
; before any task exists without writing 128 bytes below the table.
_KcDp_Slot      ; Refuse if the table was never allocated.  Only the BANK byte
                ; is tested: a Kmalloc'd pointer never lands in bank 0, and a
                ; 16-bit read at +2 would take the bank plus whatever follows
                ; it in memmap, which is a different variable.
                SEP     #$20
                MX      %10
                LDA    |_kcDpSaveBase+2
                REP     #$20
                MX      %00
                AND     #$00FF
                BEQ     @kdsl_none          ; never allocated -- see _AllocKcDpSave
                ; _kCurPid, not _curTask: this runs on BOTH sides of the D
                ; switch (save on the outgoing page, restore on the incoming
                ; one), so it must ask who is RUNNING rather than which page
                ; it happens to be standing on.
                LDA     _kCurPid
                AND     #$00FF
                BEQ     @kdsl_none
                DEC
                ASL
                ASL
                ASL
                ASL
                ASL
                ASL
                ASL                             ; *128 = KC_DP_STRIDE
                ; Bound the result against the table.  The boot check catches a
                ; DROPPED shift (slots collide and the patterns fail), but an
                ; ADDED one round-trips two test slots perfectly while sending
                ; pid 7 and up past the end of the table -- 104 bytes written
                ; over whatever follows it, silently.  This turns that into a
                ; task with no slot, which the dispatcher's stamp check reports.
                CMP     #CFG_KERNEL_NPROC*KC_DP_STRIDE
                BCS     @kdsl_none
                SEC
                RTS
@kdsl_none      CLC
                RTS

_KcDp_Save      ENT
                MX      %00
                JSR     _KcDp_Slot
                BCC     @kds_out
                PHA
                KHEAP_USE _kcDpSaveBase
                PLA
                TAY                             ; Y = slot base
                LDX     #0
@kds_lp         LDAL    $000000+FGX_DP_KERNELC+KC_DP_LO,X
                STA     [_kHeapCur],Y
                INX
                INX
                INY
                INY
                CPX     #KC_DP_BYTES
                BCC     @kds_lp
@kds_out        RTS

_KcDp_Rest      ENT
                MX      %00
                JSR     _KcDp_Slot
                BCC     @kdr_out
                PHA
                KHEAP_USE _kcDpSaveBase
                PLA
                TAY
                LDX     #0
@kdr_lp         LDA     [_kHeapCur],Y
                STAL    $000000+FGX_DP_KERNELC+KC_DP_LO,X
                INX
                INX
                INY
                INY
                CPX     #KC_DP_BYTES
                BCC     @kdr_lp
@kdr_out        RTS
_slpChan        DS      2                       ; _sleep wait channel stash
_wkChan         DS      2                       ; _wakeup target channel
_twSeoff        DS      2                       ; _Timer_WakeExpired seoff scratch
_nTimerSleepers DS      2                       ; count of tasks in nanosleep (gates the
                                                ; per-swtch timer scan; init 0 in
                                                ; _AllocSchedTbl, ++/-- in _Sys_Nanosleep)
_nSelSleepers   DS      2                       ; count of tasks in a block-forever
                                                ; select (gates the per-swtch WCHAN_SELECT
                                                ; wakes; init 0 in _AllocSchedTbl, ++/-- in
                                                ; _Sys_Select)
_nsDur          DS      2                       ; _Sys_Nanosleep duration (pre-_sleep only)

; 2.11BSD's meters (h/vmmeter.h `struct vmsum', h/dk.h `cp_time'), kept as
; the longs upstream's `sum' accumulates -- FGX increments these directly,
; with no per-second `cnt' to fold.  Only the counters FGX has an event for
; are stored; the sysctl that copies out a struct vmsum fills the rest
; (paging, swapping, overlays, floating-point simulation) with zeros.
; Inline statics: KGlobals is at its ceiling.
_vmSwtch        DS      4               ; v_swtch:   every swtch entry
_vmSyscall      DS      4               ; v_syscall: every dispatcher entry
_vmIntr         DS      4               ; v_intr:    every hardware IRQ
_cp_time        DS      CPUSTATES*4     ; ticks charged per CP_* state
_kCpState       DW      CP_SYS          ; the CP_* state the next tick goes to;
                                        ; the boot is system time

;==============================================================================
; END sched.s
;==============================================================================
