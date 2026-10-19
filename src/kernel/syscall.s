;==============================================================================
; syscall.s - syscall dispatcher and syscall table.
;
; User code enters via `JSL SYS_TRAMP` ($000328), a 4-byte JML cell that
; _Sys_InstallVectors plants at boot pointing at _Sys_JslEntry in the live
; kernel bank.  The signature byte (syscall number) follows the JSL; the
; dispatcher reads it, bumps the caller PC past it, then dispatches via
; _Syscall_Table.
;
; Slice 1: SYS_EXIT (#1) and SYS_WRITE (#4) only.  Subsequent slices add
; fork/exec/wait/signal etc. — see spec §3.3.
;==============================================================================

;------------------------------------------------------------------------------
; _Sys_InstallVectors - plant the bank-$00 JSL syscall trampoline at
; SYS_TRAMP ($000328) so user code can reach the dispatcher.
;
; Trampoline contents (4 bytes): JML _Sys_JslEntry  ($5C lo mid hi)
;
; Called once from FGX_Entry at boot.  Caller MX %00.
;------------------------------------------------------------------------------
_Sys_InstallVectors ENT
                MX      %00
                ; Build the JSL syscall trampoline at SYS_TRAMP (\$000328).
                ; Bytes: $5C (JML opcode) + 24-bit target = _Sys_JslEntry.
                ; User code: \`<args>; JSL SYS_TRAMP; DFB SYS_NUM\`
                SEP     #$20
                MX      %10
                LDA     #$5C
                STAL    SYS_TRAMP+0
                LDA     #<_Sys_JslEntry
                STAL    SYS_TRAMP+1
                LDA     #>_Sys_JslEntry
                STAL    SYS_TRAMP+2
                ; bank byte = our own running kernel bank (PHK), not baked
                ; ^_Sys_JslEntry (=$02).  Makes the $000328 trampoline follow the
                ; kernel to whatever bank the loader places it in (relocatable).
                PHK
                PLA
                STAL    SYS_TRAMP+3
                REP     #$20
                MX      %00
                RTS

;==============================================================================
; _Sys_JslEntry - JSL-based syscall entry point (slice-1 ABI).
;
; User code:
;       LDA #arg0        ; or set up other args in A/X/Y
;       LDX #arg1
;       LDY #arg2
;       JSL SYS_TRAMP    ; \$000328 -> JML here
;       DFB SYS_NUM      ; signature byte = syscall number (1 byte)
;       ; execution returns here after the DFB
;
; This mirrors the COP-with-signature-byte mechanism but doesn't depend
; on patching the native COP vector (which is fighting LC RAM banking
; on the IIgs).
;
; Stack at entry (JSL pushes PB:PCH:PCL — 3 bytes; PC = byte after JSL):
;   SP+1: caller PCL    (= addr of signature byte)
;   SP+2: caller PCH
;   SP+3: caller PB
;
; Dispatcher reads the signature byte at caller PC, increments caller PC
; by 1 on the stack so RTL skips the signature, then dispatches via the
; same _Syscall_Table that COP would have used.
;==============================================================================
_Sys_JslEntry  ENT
                MX      %00
                REP     #$30
                MX      %00
                ; --- Push caller's DBR onto the user stack and switch DBR
                ;     to the live kernel bank so abs/abs,X stores reach kernel
                ;     statics ($02 = assembly ORG only). ---
                PHB                             ; caller DBR onto user stack
                PHK
                PLB                             ; DBR = kernel-bank (PHK/PLB; $02 = ORG)

                ; --- Save caller's A/X/Y to kernel statics. ---
                STA     _Sys_SavedA
                STX     _Sys_SavedX
                STY     _Sys_SavedY

                ; --- DP swap-in (Commit A).  Save caller's D into _Sys_UserDP
                ;     so the exit path can restore it (or a different task's
                ;     saved D, if _Task_SwitchTo changed _Sys_UserDP mid-syscall).
                ;     Then switch D to _kFgxDPKernel — the MM-allocated bank-0
                ;     page that holds kernel DP state.  Subsequent DP-relative
                ;     accesses below (STA _libcTmp2, etc.) all target the
                ;     kernel page regardless of what user DP was. ---
                TDC                             ; A ← D (TDC always 16-bit)
                STA     _Sys_UserDP
                ; THE RUNNING TASK'S KERNEL DIRECT PAGE is its slot's, published
                ; in _kCurKDP by the scheduler when it bound the slot (task.s,
                ; _Slot_Ensure); boot's is the template page.  A kernel-bank
                ; absolute, not a cell on the page being selected, which would
                ; be circular.
                LDAL   KFGX_CUR_KDP
                TCD

                ; --- Repoint _fd_table_ptr at the current task's fd table
                ;     (Slice-3 B.2).  Per-task fd tables live in M_FS heap;
                ;     TCB_FdTablePtr holds a 24-bit long ptr.  Skipped if
                ;     _curTask = 0 (no user task — boot only).
                LDA     _curTask
                AND     #$00FF
                BEQ     @je_noTask
                JSR     Task_Lookup
                BCC     @je_noTask
                LDA:    TCB_FdTablePtr,X
                STA     _fd_table_ptr
                SEP     #$20
                MX      %10
                LDA:    TCB_FdTablePtr+2,X
                STA     _fd_table_ptr+2
                REP     #$20
                MX      %00
@je_noTask
                ; --- Read signature byte via long-indirect [dp].  Caller's
                ;     PCL+PCH+PB still live on the user stack; the dispatcher
                ;     INCs PCL+PCH so RTL skips the sig byte on return.
                ; Stack at entry (still on user stack):
                ;   SP+1: caller DBR (PHB'd above)
                ;   SP+2: caller PCL
                ;   SP+3: caller PCH
                ;   SP+4: caller PB
                LDA     2,S                     ; 16-bit PCL+PCH
                INC                             ; +1 = signature byte addr
                STA     2,S                     ; bump on user stack
                STA     _libcTmp2               ; lo word of long ptr
                SEP     #$20
                MX      %10
                LDA     4,S                     ; caller PB (sig byte lives here)
                STA     _libcTmp2+2             ; bank of long ptr → sig
                ; Slice 4.5 multi-bank: _Sys_CallerBank used by buffer-passing
                ; handlers (write/read/getcwd/CopyPathToBuf) must be the
                ; caller's DBR — that's where DBR-relative buffers like
                ; _libc_lstrBufA actually live.  For single-bank FGX1 binaries
                ; DBR == PB so behavior is unchanged.  For multi-bank FGX2
                ; (n_data_segment > 0), DBR points to the data bank and
                ; the buffers do too — PB would be the code bank.
                LDA     1,S                     ; caller DBR (PHB'd at entry)
                STA     _Sys_CallerBank
                STA     _Sys_PathBank           ; default source bank for a path
                LDA     [_libcTmp2]             ; A = signature byte
                STA     _Sys_SavedSig
                REP     #$20
                MX      %00

                ; --- Save user SP (we're about to switch to kernel stack),
                ;     then TCS to $01FF.  The 4 bytes at user_SP+1..+4 hold
                ;     [DBR, PCL, PCH, PB] — exactly what PLB+RTL consumes
                ;     on the way back to user code.
                TSC
                STA     _Sys_UserSP
                ; THE SAMPLED HIGH-WATER MARK (task.s _kStkMinSP): the deepest
                ; user S seen at an entry, kept per pid for the region it was
                ; seen in.  It is what a SHARED region -- one another task's
                ; reservation has overlapped, a snapshot-fork parent's --
                ; reports instead of a paint scan, so
                ; every entry pays these few cycles; an S outside the tracked
                ; region (exec, still standing on the old stack) is ignored.
                LDA     _kCurPid
                AND     #$00FF
                BEQ     @je_nosample            ; boot: no reservation
                DEC
                ASL
                TAX
                LDA     _Sys_UserSP
                CMP    |_kStkMinBase,X
                BCC     @je_nosample            ; below the tracked region
                CMP    |_kStkMinSP,X
                BCS     @je_nosample            ; not deeper than the deepest seen
                STA    |_kStkMinSP,X
@je_nosample
                ; --- Select the kernel stack this syscall's handler runs on.
                ;     Phase 3c: each live task has a PRIVATE kernel stack at
                ;     FGX_STK_KTASKS+(pid<<8) (top = +$FF), mirroring the user
                ;     stacks at FGX_STK_TASKS.  A private kernel stack is the
                ;     substrate a task needs to block mid-syscall without
                ;     clobbering another task's in-flight handler state.  Boot
                ;     / no-task syscalls (_curTask==0) fall back to the static
                ;     $0100 stack.
                ;     CONSTRAINT: a handler may run on a non-page-$01 stack
                ;     ONLY because the one emulation-mode firmware path in the
                ;     syscall layer — SmartPort disk I/O via _blkSmartJump /
                ;     BlkTramp, whose SEC/XCE forces the stack high byte to $01
                ;     — is made stack-page-neutral (it bounces to $0100 for the
                ;     firmware excursion and restores the caller S).  Native
                ;     toolbox calls (NewHandle etc.) are page-agnostic and need
                ;     no bounce.  See feedback_kernel_stack_must_be_page1_for_emul_firmware.
                ; THE PID COMES FROM _kCurPid, for the same reason the direct
                ; page above does: _curTask is a cell ON the per-task page, so
                ; selecting this task's resources from it is circular.  The page
                ; selection got that right and the stack selection did not, and
                ; the gap is not academic -- apple/fgx#120 reported a warm boot
                ; where page 1's identity cell read $44B1 instead of $0001, and
                ; this arithmetic turned that into S = $E000 + $B1FF = $91FF,
                ; a kernel stack pointed into the middle of the stack arena.
                ; The dead-canary message downstream is not the failure; it is
                ; the first code to notice it.
                ;
                ; A corrupt identity cell is still a bug and still breaks the
                ; ~170 "which task am I" reads that legitimately use it.  What
                ; this removes is the part where it also destroys the stack the
                ; kernel is standing on, which is what made the symptom
                ; unreadable.
                LDA     _kCurPid
                AND     #$00FF
                BEQ     @je_kstatic
                ; The running task's slot stack, published beside its page by
                ; the scheduler.  The stack is EMPTY at every entry: a task
                ; reaches user mode only through the exit below, so the top is
                ; the right place to start, and it is what makes a slot bindable
                ; to any task that is not asleep inside the kernel.
                LDA    |_kCurKStkTop
                TCS                             ; now on OWN kernel stack
                LDX    |_kCurKStkBase
                ; Canary check (2026-07-18): the slot's bottom word must still
                ; read $C5C5 (seeded at boot, main.s).  Log ONCE (latch), don't
                ; halt: visibility over cleverness.
                ;
                ; WHAT IT DETECTS IS THIS SLOT'S OVERFLOW, not a neighbour's.
                ; Stacks grow DOWN and X is the ENTERING task's slot base, so
                ; the word read here is the LOWEST two bytes of the stack it is
                ; about to use -- the first thing an overflow writes on the way
                ; out.  A neighbour's overflow is invisible here until the
                ; neighbour has eaten a whole slot.
                ;
                ; AND IT IS ONE WORD AT THE VERY BOTTOM, so it answers only
                ; "did this stack overflow ALL of it".  A slot can sit thirty
                ; bytes off its base on every boot with this check green, which
                ; is measured and is what apple/fgx#230 is about.  ITS SILENCE
                ; IS NOT EVIDENCE OF HEADROOM.  The depth is a separate
                ; measurement and the slots are painted for it:
                ; tools/mame_test/kstkhwm_check.py.
                LDAL    $000000,X
                CMP     #$C5C5
                BEQ     @je_kdone
                LDA    |_kStkOvfLatch
                BNE     @je_kdone
                LDA     #1
                STA    |_kStkOvfLatch
                JSR     _Sys_KStkReport         ; OUT OF LINE: the report grew
                BRA     @je_kdone               ; past BEQ @je_kstatic's reach,
                                                ; and the hot path is no place
                                                ; for it anyway
@je_kstatic     LDA     #FGX_STK_KERNEL+$FF     ; static boot / no-task stack
                TCS
@je_kdone
                ;--------------------------------------------------------------
                ; USER-STACK FLOOR CHECK (bank-0 stack campaign, increment 0.2).
                ;
                ; fcc's prologue guard arms only on indirect-call, self-recursion,
                ; or a frame >= 128 bytes (parse_stmt.c).  MUTUAL recursion
                ; through small frames arms NOTHING -- tcsh has a 117-member
                ; recursion SCC, and a cycle of two 40-byte functions calling
                ; each other walks straight past TCB_StackBase and into the
                ; neighbouring task's pages with no check anywhere.  That is the
                ; silent-cross-task-corruption class: it presents as SOMEONE
                ; ELSE's failure, which is why it has historically survived
                ; until the test oracle itself was repaired.
                ;
                ; A runaway recursion cannot do anything useful without a
                ; syscall, so the dispatcher is the one place every such task
                ; must pass through.  It is not a substitute for the prologue
                ; guard (a cycle that never syscalls is still unguarded until
                ; increment 3.1 makes the guard near-universal) -- it is the
                ; backstop that turns "corrupt a neighbour" into "die cleanly".
                ;
                ; We are already on the KERNEL stack here, so the kill path
                ; runs on healthy memory.  The kill is done by REWRITING the
                ; call to exit(134) rather than by a private teardown: the
                ; normal handler dispatch then does all the usual work, and
                ; there is only one exit path in the kernel to keep correct.
                LDA     _curTask
                AND     #$00FF
                BEQ     @je_floorOK             ; boot / no task
                JSR     Task_Lookup
                BCC     @je_floorOK
                LDA:    TCB_StackBase,X
                BEQ     @je_floorOK             ; unset base: nothing to compare
                CLC
                ADC     #FCC_STK_FLOOR_MARGIN   ; same floor the fcc guard uses
                CMP     _Sys_UserSP
                BCC     @je_floorOK             ; floor < SP: healthy
                LDA     #1
                STA    |_kStkSysOflow           ; tell _Sys_Exit which guard fired
                LDA     #SYS_EXIT
                STA     _Sys_SavedSig
                LDA     #TASK_EXIT_STKOFLOW
                STA     _Sys_SavedA
@je_floorOK
                LDA     #CP_SYS                 ; ticks from here are system time
                STA    |_kCpState
                INC    |_vmSyscall              ; cnt.v_syscall++ (pdp/trap.c:334)
                BNE     @je_counted
                INC    |_vmSyscall+2
@je_counted
                DO      LATPROBE=1
                ; P0 latency survey (preemption campaign): stamp the entry
                ; tick + a swtch-count snapshot; the exit sample below skips
                ; any syscall that slept/yielded (blocked wall-time is not
                ; CPU time).  DBR = kernel here (the range-check's absolute
                ; reads below rely on the same).
                LDA    |_kSystemTicks
                STA    |_kLatTick
                LDA    |_vmSwtch
                STA    |_kLatSw
                FIN

                DO      KCPROBE
                ; --- Kernel-C register-file integrity across a real switch. ---
                ;
                ; This is the INTEGRATION half of the context save in sched.s.
                ; The boot check proves the copy loops and the slot arithmetic,
                ; but both would still pass if swtch called them in the WRONG
                ; PLACES -- a restore after the TCS, say, is unreachable and
                ; silent.  Only a genuine switch between two genuine tasks
                ; proves the placement, and every blocking syscall in the
                ; existing tests produces one.
                ;
                ; Stamp this task's pid into the band; @after_handler checks it
                ; is still ours.  No switch-counter snapshot is needed, and that
                ; is not a shortcut: if no switch happened the stamp is trivially
                ; still ours, and if one did, the ONLY thing that can have
                ; overwritten it is another task stamping its own pid on its way
                ; into a syscall.  So the check is silent exactly when nothing
                ; could have gone wrong, and fires exactly when the restore
                ; failed to bring our band back.
                ;
                ; The marker sits at KC_DP_MARK, INSIDE the band -- outside it
                ; would not be saved and restored, and would prove nothing --
                ; but in the one part of the band kernel C cannot reach.
                ; $E0-$E7 belongs to args.s and libc's SRC/DST scratch, both
                ; USERLAND ONLY: kernel C links no libc and takes no argv, so
                ; those eight bytes are dead on this page.  The extracted slot
                ; map shows the hole plainly -- it runs $DC, $DE, then $E8.
                ;
                ; IT MUST NOT BE A CELL KERNEL C WRITES, or the check fires
                ; against innocent code.  gen_fcc_dp.py REFUSES TO EMIT if fcc
                ; ever allocates a slot into $E0-$E7, because "fcc has nothing
                ; there" is exactly the sort of fact that stops being true
                ; quietly.
                LDA     _curTask
                STAL    $000000+FGX_DP_KERNELC+KC_DP_MARK
                FIN

                ; --- Range-check + look up handler. ---
                LDA     _Sys_SavedSig
                AND     #$00FF
                CMP     #SYS_NUM_MAX+1
                BCC     @je_inRange
                LDA     #ENOSYS
                CLC
                JMP     @je_returnToUser
@je_inRange     ASL                             ; *2 = table offset
                TAX
                LDA     _Syscall_Table,X        ; handler address
                STA     _Sys_HandlerAddr

                ; --- Indirect call via PHA+RTS idiom on the kernel stack. ---
                LDA     #@after_handler-1
                PHA
                LDA     _Sys_HandlerAddr
                DEC
                PHA
                LDA     _Sys_SavedA
                LDX     _Sys_SavedX
                LDY     _Sys_SavedY
                RTS                             ; -> handler
@after_handler                                  ; handler returned via RTS
                ; --- MX %00 invariant re-establishment (Fix #2 lesson: handler
                ;     return MX is undefined; chdir error path returned M=8 and
                ;     truncated the LDA below to a 1-byte read, leaving TCD to
                ;     set D from a half-loaded A → D=$01B7).  Force M=16/X=16
                ;     here so the 16-bit DP restore is byte-correct regardless
                ;     of how the handler exited. ---
                REP     #$30
                MX      %00

                DO      KCPROBE
                ; Did our band come back?  P and A carry the handler's success
                ; flag and return value; X and Y are saved too because the
                ; failure arm calls the logger.
                PHP
                PHA
                PHX
                PHY
                LDAL    $000000+FGX_DP_KERNELC+KC_DP_MARK
                CMP     _curTask
                BEQ     @je_kcOK
                LDA     #_msg_kcdp_bad
                STA     _conStrPtr
                JSR     Kern_LogStr
@je_kcOK        PLY
                PLX
                PLA
                PLP
                FIN

                DO      LATPROBE=1
                ; P0 latency survey: record the worst CPU-BOUND syscall in
                ; 60 Hz ticks + its syscall number.  PHP/PHA: the CMPs below
                ; must not eat the handler's carry (its success flag) or A.
                ; A swtch inside the syscall (read() blocking, PollKey yield)
                ; disqualifies the sample — that's wait, not work.
                PHP
                PHA
                LDA    |_vmSwtch
                CMP    |_kLatSw
                BNE     @je_latSkip
                LDA    |_kSystemTicks
                SEC
                SBC    |_kLatTick
                CMP    |_kLatMax
                BCC     @je_latSkip
                BEQ     @je_latSkip
                STA    |_kLatMax
                LDA     _Sys_SavedSig
                AND     #$00FF
                STA    |_kLatMaxSig
@je_latSkip     PLA
                PLP
                FIN
                ; --- F5/P1: resched at the syscall boundary (kbd OR quantum). ---
                ; The flag arrived (heartbeat) while this task ran.  Yield HERE,
                ; not in the exit sequence: the Saved-arg singletons are already
                ; consumed and the Saved-result stores happen after we resume.
                ; REGISTER SURVIVAL ACROSS THE YIELD (2026-07-18 correction —
                ; the old comment claimed "swtch carries A/X/Y/P": FALSE. swtch
                ; saves ONLY SE_KernSP/UserSP/UserDP/CallerBank; what survives a
                ; switch is the task's own KERNEL STACK, nothing in registers.)
                ; So everything the exit path still needs must be PUSHED: P and
                ; A were (PHP/PHA) — Y was NOT, and Y is a documented syscall
                ; return channel (SYS_MALLOC32 offset, SYS_LSEEK hi — rule 4:
                ; "return secondary words via Y, not X").  Under P1 the quantum
                ; lands this yield on ARBITRARY syscalls, so a malloc that got
                ; preempted here returned a garbage offset in Y — userland then
                ; held (and later freed) a wild pointer: the "ls HEAP CORRUPT"
                ; wild-free bug.  Latent since F5 for kbd-yields too (a keypress
                ; during any Y-returning syscall).  PHY/PLY closes it.  X needs
                ; no save: the exit clobbers X unconditionally (LDX _Sys_UserSP).
                ; The per-switch kbd wake (sched.s) then runs the blocked fg
                ; shell.  Flag cleared BEFORE the yield (one yield per burst;
                ; _Sys_Yield's own boundary can't re-fire).
                PHP
                PHA
                LDA     _kYieldReq
                BEQ     @je_noYield
                LDA     #0
                STA     _kYieldReq
                STAL    KFGX_YIELD_MIRROR       ; P2': clear the userland mirror too
                PHY                             ; Y = handler's 2nd return word
                JSR     _Sys_Yield
                PLY
@je_noYield     PLA
                PLP
@je_returnToUser
                ; --- Restore caller's DP/SP/DBR while preserving the handler's
                ;     return A AND its N/Z flags.  The previous PHA/PLA bracket
                ;     preserved A across TCD but LDX _Sys_UserSP (and PLB) both
                ;     stomped Z — so any user code relying on the "STA result /
                ;     BEQ eof" idiom saw Z reflecting the user SP / caller DBR,
                ;     not A.  cp(1) hit this hard: SYS_READ at EOF returned A=0
                ;     but Z=0, so STA cp_chunk + BNE always branched, and cp
                ;     ping-ponged SYS_READ→SYS_WRITE(0) forever.  cat survived
                ;     only because it AND'd the return before testing.
                ;
                ; Fix order matters: PLB itself sets N/Z from the popped DBR
                ; byte, so the A reload must happen AFTER PLB — and must use
                ; a *long* load (LDAL) since DBR is now the caller's bank, not
                ; the kernel-bank ($02 = assembly ORG).  PLB preserves C (so SEC/CLC from the handler
                ; survives) and N/Z get rewritten by LDAL anyway.
                STA     _Sys_SavedA             ; stash handler return A
                STY     _Sys_SavedRetY          ; stash handler return Y (DBR=$20).
                                                ; Y still holds the handler's return
                                                ; here; the A-in-Y carry below would
                                                ; otherwise destroy a Y-return syscall
                                                ; (SYS_LSEEK pos-hi, SYS_MM_ALLOC off).


                ; --- vi-port slice 3: synchronous signal delivery hook.
                ; Inspect _curTask's TCB_PendingSig.  If a deliverable
                ; signal (SIGINT/SIGALRM with user handler) is pending,
                ; _Sys_CheckSignal clears the bit and sets up
                ; _Sys_DeliveredSig + _Sys_HandlerOffset + _Sys_HandlerBank.
                JSR     _Sys_CheckSignal

                ; --- RESTART, PART 1 OF 2 (apple/fgx#105): HARVEST.
                ;     [_u] is reached through the KERNEL direct page and the TCD
                ;     below makes DP the user's, so the u-area must be read here.
                ;     The pushes cannot happen here: they go on the USER stack,
                ;     and S is still the kernel's until the TXS below.  Hence two
                ;     halves.  The statics between them are singletons, which is
                ;     safe only because nothing in between can sleep.
                ;
                ;     THE HARVEST MUST PRECEDE THE TCD: `_Uarea_Cur' reads
                ;     `_curTask' and `_schedTblPtr' off the direct page, and
                ;     after the TCD that page is the USER's.
                ;
                ;     Carry is the syscall's success flag and is live to the RTL.
                ;
                ;     GATED ON A COUNT, because this is the hottest path in the
                ;     kernel -- EVERY syscall exits through here, including the
                ;     per-byte write loops.  An unconditional `JSR _Uarea_Cur`
                ;     costs ~70-90 cycles to answer "no" for the ~99.9% of exits
                ;     with no mark outstanding.  _Sys_RestartLive counts marks
                ;     issued minus marks cleared, so zero means NO TASK ANYWHERE
                ;     has one and the walk can be skipped outright.
                ;
                ;     It is deliberately a system-wide count and not this task's:
                ;     a global can only OVER-estimate (another task's mark makes
                ;     us do a lookup that finds nothing and changes nothing), and
                ;     over-estimating costs a few cycles where under-estimating
                ;     would drop a restart.  A task killed between mark and
                ;     harvest leaves the count high, which degrades to the old
                ;     unconditional cost rather than to a wrong answer.
                PHP
                STZ     _Sys_RestartPend
                LDA     _Sys_RestartLive
                BEQ     @je_noHarvest           ; no mark outstanding anywhere
                JSR     _Uarea_Cur
                BCC     @je_noHarvest
                LDY     #U_RestartFlag
                LDA     [_u],Y
                BEQ     @je_noHarvest
                LDA     #0
                STA     [_u],Y                  ; one restart per mark
                DEC     _Sys_RestartLive
                LDY     #U_RestartA
                LDA     [_u],Y
                STA     _Sys_RestartA
                LDY     #U_RestartX
                LDA     [_u],Y
                STA     _Sys_RestartX
                LDY     #U_RestartY
                LDA     [_u],Y
                STA     _Sys_RestartY
                INC     _Sys_RestartPend
@je_noHarvest   PLP
                STZ    |_kCpState               ; CP_USER: back to user code
                                                ;   (STZ keeps A and the flags)
                LDA     _Sys_UserDP
                TCD
                ; RELOC: capture the handler's return value from the LIVE kernel
                ; bank ($20) into Y NOW, while DBR is still the kernel bank.  The
                ; reload at @je_normalReturn used `LDAL _Sys_SavedA` (baked $02),
                ; but after the PLB below DBR = the user's bank — under relocation
                ; that read the STALE $02 copy, so EVERY syscall returned A=0
                ; (broke posix_spawn's child pid -> init waitpid'd pid 0 -> exit).
                ; TYA at @je_normalReturn reloads it, setting N/Z last (the user's
                ; "STA result / BEQ eof" idiom needs Z to reflect A).
                ; Carry the return value past PLB in a REGISTER (statics are
                ; stale-bank after PLB under reloc).  A-return -> X (free after
                ; TXS), Y-return -> Y, so both survive PLB and a Y-returning
                ; syscall keeps its Y.  @je_normalReturn does TXA (sets N/Z from A).
                LDY     _Sys_SavedRetY          ; Y = handler return Y (survives PLB)
                LDX     _Sys_UserSP
                TXS                             ; SP restored; X now free
                LDX     _Sys_SavedA             ; X = handler return A (DBR still $20)
                PLB                             ; restore caller DBR (clobbers N/Z)

                ; If a signal is to be delivered, JML to the handler
                ; (via a synthesized RTL frame on user stack) instead of
                ; RTLing the original syscall return.  The handler RTLs
                ; on its own to pop the user JSL frame and resume the
                ; post-syscall instruction.
                ;
                ; CONTRACT (load-bearing since 2026-07-06): the delivery
                ; RTL leaves the interrupted syscall's result LIVE —
                ; X = return A, Y = return Y, C = success flag (nothing
                ; below touches them: LDAL/AND/DEC/SEP/REP/PHA/CLI are
                ; all C-preserving).  libc_start.s's _libc_sigtramp saves and
                ; restores all three so the syscall's return survives
                ; the handler chain (oracle c34).
                ;
                ; All loads after PLB must be LONG (LDAL) — DBR is now
                ; the user's bank, so plain abs would mis-read kernel
                ; statics from random user memory.
_we024          LDAL    _Sys_DeliveredSig
                AND     #$00FF
                BNE     @je_deliverSig

                ; --- RESTART with NO HANDLER TO DELIVER TO (apple/fgx#105).
                ;     The mark says the read was interrupted having handed the
                ;     caller nothing; it does NOT say a handler exists.  The
                ;     reachable case is SA_STOP -- SIGTSTP/SIGSTOP/SIGTTIN/
                ;     SIGTTOU (_SigDefAction, signal.s): ^Z a program blocked in
                ;     read(), `fg` it, and BSD resumes the read.  We returned
                ;     EINTR, because the harvest above had already consumed the
                ;     mark and only the delivery arm below acted on it.
                ;
                ;     SA_TERM never arrives here (the task is dead) and SA_IGN
                ;     never marks (_Sig_PendingActionable drops it before the
                ;     sleep wakes -- that is apple/fgx#3, `sleep 2 &`).
                ;
                ;     SAFE BECAUSE OF THE ORDER: _scs_dispatch stops the task
                ;     and swtch's away INSIDE _Sys_CheckSignal, which runs
                ;     BEFORE the harvest -- so these singleton statics were
                ;     filled after the continue, by this task, and nothing
                ;     between there and here can sleep.  Harvesting first would
                ;     have handed us whichever task ran during the stop.
                ;
                ;     No handler intervenes, so this arm needs no thunk: rewind
                ;     the JSL and put the arguments straight back in the
                ;     registers.  C is dead past the BEQ -- the restarted call
                ;     recomputes it -- and LDAL/AND leave it alone before that.
_we025          LDAL    _Sys_RestartPend
                BEQ     @je_normalReturn
                LDA     1,S                     ; JSL frame PC (DBR already pulled)
                SEC
                SBC     #5                      ; JSL is 4 bytes, +1 for RTL's INC
                STA     1,S
_we026          LDAL    _Sys_RestartRewinds     ; DIAGNOSTIC (apple/fgx#105)
                INC
_we027          STAL    _Sys_RestartRewinds
_we028          LDAL    _Sys_RestartNoHnd       ; DIAGNOSTIC: ...on THIS arm
                INC
_we029          STAL    _Sys_RestartNoHnd
_we030          LDAL    _Sys_RestartX
                TAX
_we031          LDAL    _Sys_RestartY
                TAY
_we032          LDAL    _Sys_RestartA           ; A last: it is the first argument
                CLI                             ; mirror @je_normalReturn
                RTL                             ; -> the rewound JSL

@je_deliverSig

                ; --- RESTART, PART 2 OF 2: PUSH, under the handler's frame, so
                ;     the state belongs to this INVOCATION rather than the task.
                ;     _Sys_RestartThunk says why a kernel-side latch cannot work.
                ;
                ;     ARITHMETIC: JSL pushed sig_addr-1, entry INC'd it to
                ;     sig_addr, JSL is four bytes, so the stacked word must read
                ;     sig_addr-5 for RTL to land on the JSL.
                ;
                ;     All loads LONG: DBR is the user's bank past the PLB --
                ;     and each one needs a `_weNNN` marker in the bankpatch
                ;     table, or it reads the pristine $02 LOAD IMAGE and is
                ;     silently always zero.  LDAL is necessary, not sufficient.
                ;
                ;     NO PHP/PLP BRACKET HERE, deliberately.  The contract 25
                ;     lines above keeps C live across delivery, so this looked
                ;     like it wanted one -- and an earlier cut had a one-armed
                ;     bracket plus ten lines defending it.  It guarded nothing:
                ;     LDAL sets only N and Z, BNE sets nothing, so C is never at
                ;     risk in the window.  (A bracket here is worse than
                ;     useless: the restart arm pushes nine bytes, so a closing
                ;     PLP would pull the low byte of the thunk address into P.)
                ;
                ;     C IS clobbered further down by the SEC/SBC, and that is
                ;     fine for a reason stronger than "the handler ignores it":
                ;     _sig_tramp round-trips whatever C it was handed and the
                ;     thunk's RTL never consumes it, so the restarted call
                ;     recomputes its own result regardless of handler behaviour.
_we033          LDAL    _Sys_RestartPend
                BEQ     @je_restartDone
                LDA     1,S                     ; JSL frame PC (DBR already pulled)
                SEC
                SBC     #5
                STA     1,S
_we034          LDAL    _Sys_RestartY           ; [Y][X][A][PB][PC-1]
                PHA
_we035          LDAL    _Sys_RestartX
                PHA
_we036          LDAL    _Sys_RestartA
                PHA
                PHK                             ; thunk PB = live kernel bank
                LDA     #_Sys_RestartThunk-1    ; -1 for RTL's increment
                PHA
_we037          LDAL    _Sys_RestartRewinds     ; DIAGNOSTIC (apple/fgx#105)
                INC
_we038          STAL    _Sys_RestartRewinds
@je_restartDone

                ; Push handler far-target (PB, PCH:PCL-1) on top of the
                ; user JSL frame; RTL pops it and far-jumps to handler.
                SEP     #$20
                MX      %10
_we039          LDAL    _Sys_HandlerBank
                PHA                             ; PB byte
                REP     #$20
                MX      %00
_we040          LDAL    _Sys_HandlerOffset
                DEC                             ; -1 for RTL's increment
                PHA                             ; PCH:PCL-1
_we041          LDAL    _Sys_DeliveredSig       ; A.lo = signum (handler arg)
                AND     #$00FF
                ; Ensure user resumes with IRQs enabled.  The dispatcher does
                ; not save/restore P, so a child's SEI would otherwise survive
                ; a syscall and a task-switch (e.g. exit→parent) and silently
                ; freeze the heartbeat — vbldiag's stray SEI exposed this.
                ; SEI/CLI inside a single syscall handler is fine; the
                ; kernel↔user boundary always re-enables.
                CLI
                RTL                             ; -> handler, A=signum.  Handler
                                                ; RTLs to pop the user JSL frame
                                                ; and resume the post-syscall PC.

@je_normalReturn
                TXA                             ; A = return value (carried in X past
                                                ; PLB); sets N/Z.  Y already holds the
                                                ; handler's Y-return (carried in Y).
                CLI                             ; mirror handler-delivery path
                RTL                             ; restore PB:PCH:PCL (no flag change)

;------------------------------------------------------------------------------
; Module locals for the dispatcher's saved args + handler ptr.
;------------------------------------------------------------------------------
_Sys_CaptureRestartArgs MX %00
;------------------------------------------------------------------------------
; _Sys_CaptureRestartArgs - stash this call's A/X/Y for a possible restart.
;
; Called from a syscall's PROLOGUE, before it can block.  Also clears any stale
; flag, so the mark is always this invocation's.  Preserves A/X/Y/P.
;------------------------------------------------------------------------------
                PHP
                REP     #$30
                MX      %00
                PHA
                PHX
                PHY
                JSR     _Uarea_Cur
                BCC     @cra_done
                LDA     _Sys_SavedA
                LDY     #U_RestartA
                STA     [_u],Y
                LDA     _Sys_SavedX
                LDY     #U_RestartX
                STA     [_u],Y
                LDA     _Sys_SavedY
                LDY     #U_RestartY
                STA     [_u],Y
                ; Clearing a stale flag also has to un-count it, or the exit
                ; path's skip gate stays armed forever and the optimisation
                ; silently stops optimising.
                LDY     #U_RestartFlag
                LDA     [_u],Y
                BEQ     @cra_wasClear
                DEC     _Sys_RestartLive
@cra_wasClear   LDA     #0
                LDY     #U_RestartFlag
                STA     [_u],Y                  ; this invocation is not marked yet
@cra_done       PLY
                PLX
                PLA
                PLP
                RTS

_Sys_MarkRestart MX    %00
;------------------------------------------------------------------------------
; _Sys_MarkRestart - mark this syscall re-enterable (apple/fgx#105).
;
; Call from a site about to return EINTR because a signal arrived AND that has
; delivered NOTHING to the caller -- no bytes into its buffer, no counter
; advanced, nothing it cannot do again.  That precondition is the contract: a
; syscall that already handed something back must return the partial result
; instead (apple/fgx#106 is the other half of this boundary).
;
; Flag only.  The arguments were captured in the prologue, before this syscall
; could block; see _Sys_CaptureRestartArgs for why they cannot be read here.
;
; Preserves A/X/Y/P.  No-op if the task has no u-area (boot).
;------------------------------------------------------------------------------
                PHP
                REP     #$30
                MX      %00
                PHA
                PHX
                PHY
                JSR     _Uarea_Cur
                BCC     @smr_done
                LDY     #U_RestartFlag
                LDA     [_u],Y                  ; idempotent: two marks in one
                BNE     @smr_already            ;   invocation must count ONCE
                INC     _Sys_RestartLive        ; the exit path's skip gate
@smr_already    LDA     #1
                LDY     #U_RestartFlag
                STA     [_u],Y
                INC     _Sys_RestartMarks       ; DIAGNOSTIC (apple/fgx#105)
@smr_done       PLY
                PLX
                PLA
                PLP
                RTS

;------------------------------------------------------------------------------
; _Sys_RestartThunk - reload a restarted syscall's arguments and re-enter it.
;
; FOUR INSTRUCTIONS THE USER RUNS, and they live in the kernel bank on purpose.
; They touch nothing but the stack, and the stack is bank 0 whatever PB says, so
; the bank this executes in is irrelevant -- which buys the whole mechanism
; without spending four bytes of bank 0.  (The one documented hole there,
; $03C7-$03CB, is dead precisely because $03C8 is the floppy ROM driver's
; scratch.)
;
; The exit path leaves this on the user stack, beneath the signal handler's
; frame:
;
;       [Y][X][A][thunk PB][thunk PC-1][handler PB][handler PC-1]  <- SP
;
; so the handler's RTL lands here, the pulls restore the ORIGINAL arguments the
; syscall was called with, and the final RTL pops the JSL frame -- whose PC the
; exit path rewound to the JSL itself.  The syscall re-executes.
;
; WHY NOT RE-ENTRY STATE IN THE KERNEL: because a signal handler makes syscalls.
; libc_start.s's _libc_sigtramp alone issues `JSL SYS_TRAMP / DFB _LS_SETMASK` after
; every handler returns, so a latch consumed at the next syscall entry is
; consumed by THAT one -- it ran with the read's arguments as its mask and ate
; the flag, and the read then re-executed with whatever the tramp's PLX/TXA left
; in A and X.  On the stack the state belongs to the invocation, so nesting and
; longjmp cost nothing.
;------------------------------------------------------------------------------
_Sys_RestartThunk ENT
                MX      %00
                PLA                             ; original A
                PLX                             ; original X
                PLY                             ; original Y
                RTL                             ; -> the rewound JSL

_Sys_RestartLive    DS  2       ; marks issued MINUS marks cleared.  Not a
                                ; diagnostic: the syscall exit path skips the
                                ; u-area walk entirely when this is zero.
_Sys_RestartPend    DS  2
_Sys_RestartA       DS  2
_Sys_RestartX       DS  2
_Sys_RestartY       DS  2
_Sys_RestartMarks   DS  2
_Sys_RestartRewinds DS  2
_Sys_RestartNoHnd   DS  2       ; rewinds taken on the NO-HANDLER arm (SA_STOP)
_Sys_SavedA     DS  2
_Sys_SavedX     DS  2
_Sys_SavedY     DS  2

; _Cred_Set parameters (credentials P2).  Kernel-bank statics rather than
; registers: the core needs all three live across the [_u],Y probes, and A/X/Y
; are consumed by the offset arithmetic.
_credNewId      DS  2                   ; id being set
_credBase       DS  2                   ; u-area offset of the triple's real field
_credEffOnly    DS  2                   ; 0 = set*id, 1 = sete*id
_Sys_SavedRetY  DS  2                   ; handler's RETURN Y (e.g. SYS_LSEEK pos-hi,
                                        ; SYS_MM_ALLOC handle offset).  Carried past
                                        ; the exit PLB so a Y-returning syscall isn't
                                        ; clobbered by the A-in-Y carry (see exit path).
_Sys_SavedSig   DS  2
_Sys_HandlerAddr DS 2
; THESE BUFFERS ARE THE SYSTEM'S NARROWEST PATH POINT, so they are sized to
; MAXPATHLEN and not to anything smaller.  fsparam.h and sys/param.h both set
; MAXPATHLEN 128, namei bounds its own walk by it (vfs_lookup.c) and the far
; bank's staging buffer is FS_FARPATH_MAX 127 + NUL -- a shorter buffer here
; would silently decide a limit the rest of the system does not agree with.
SYS_PATHBUF_MAX EQU 128                 ; buffer bytes = MAXPATHLEN
SYS_PATH_MAX    EQU 127                 ; chars; the buffer holds MAX+1 with NUL
_Sys_PathBuf   DS  SYS_PATHBUF_MAX     ; kernel-bank scratch for path-taking syscalls
_Sys_LinkBuf   DS  SYS_PATHBUF_MAX     ; readlink(2)'s target, staged here for
                                       ;   the same reason the path is: the far
                                       ;   bank's uiomove writes THIS bank
                                        ; (execve, open, stat, unlink, chdir).
                                        ; Caller-saved across one syscall.
_Sys_PathBuf2  DS  SYS_PATHBUF_MAX     ; 2nd path buffer for SYS_RENAME (TO path)
_Sys_BytesRead DS  2                   ; running byte count for SYS_READ
_Sys_RdByte    DS  2                   ; SYS_READ fd=0 scratch (current key)
_Sys_RdFd      DS  2                   ; SYS_READ saved fd (Fs_Read's lookup
                                        ; clobbers _shTmp0 internally)
_Sys_RdRem     DS  2                   ; SYS_READ remaining-bytes counter
_Sys_RdMax     DS  2                   ; SYS_READ original count (return value)
_Sys_WrFd      DS  2                   ; SYS_WRITE saved fd (same hazard)
_Sys_WrRem     DS  2                   ; SYS_WRITE remaining-bytes counter
_Sys_WrMax     DS  2                   ; SYS_WRITE original count (return value)
_sysDevFd      DS  2                   ; _Sys_DevUio: the fd, parked across
                                       ;   the uio build.  UFS 1.7d I3.
_sysVecLen     DS  2                   ; _Sys_UioVec: the vector's byte length
_Sys_WrBufOff  DS  2                   ; SYS_WRITE caller-buf offset (saved
                                        ; across _Fcb_LookupPtr, which clobbers X)
_Sys_RdBufOff  DS  2                   ; SYS_READ caller-buf offset (saved
                                        ; across _Fcb_LookupPtr)
_Sys_WrCdIdx   DS  2                   ; SYS_WRITE chardev idx
_Sys_IoctlFd   DS  2                   ; SYS_IOCTL fd
_Sys_IoctlCmd  DS  2                   ; SYS_IOCTL cmd word
_Sys_RlimPtr   DS  4                   ; SYS_GETRLIMIT/SETRLIMIT: caller's
                                        ;   struct rlimit *, as a long pointer
_Sys_RlimOff   DS  2                   ; ...and the u-area byte offset of the
                                        ;   entry it names
_Sys_IoctlArgLo DS 2                   ; SYS_IOCTL arg-ptr lo16
_Sys_IoctlArgBank DS 2                 ; SYS_IOCTL arg-ptr bank
_Sys_FcntlNb    DS 2                    ; F_SETFL's FIONBIO argument
_Sys_ReOldOff   DS 2                   ; SYS_REALLOC old user-ptr offset
_Sys_ReOldBank  DS 2                   ; SYS_REALLOC old user-ptr bank (low byte)
_Sys_ReNewSize  DS 2                   ; SYS_REALLOC requested new size (bytes)
_Sys_ReCount    DS 2                   ; SYS_REALLOC bytes to copy = min(old,new)
_Sys_ReNewOff   DS 2                   ; SYS_REALLOC new user-ptr offset (saved
                                        ; across Kfree, which overwrites _kmallocResult)
_Sys_ReNewBank  DS 2                   ; SYS_REALLOC new user-ptr bank (low byte)
_Sys_LdRem     DS  2                   ; SYS_LISTDIR buffer size, for the seam call
_Sys_LdBufOff  DS  2                   ; SYS_LISTDIR caller-buf offset, ditto: the
                                        ; path copy clobbers _libcTmp2 between the
                                        ; entry and the call
_Sys_StatDst   DS  2                   ; SYS_STAT caller-bank dst offset (saved
                                        ; across Fs_Stat, which clobbers
                                        ; _libcTmp2 via Path_Resolve)
_Sys_OpenFlags DS  2                   ; SYS_OPEN flags (saved across CopyPath
                                        ; + Fs_Create/Fs_Open's internal _shTmp0
                                        ; clobber)
_Sys_MntFlags  DS  2                   ; SYS_MOUNT flags, saved across the two
                                        ; _Sys_CopyPathToBuf calls
_Sys_MntType   DS  2                   ; SYS_MOUNT filesystem type, likewise
_Sys_AccMode   DS  2                   ; SYS_ACCESS mode, across the path copy
_Sys_AccSvUid  DS  2                   ; effective uid parked across the swap;
                                       ;   $FFFF = no u-area, nothing to undo
_Sys_AccSvGid  DS  2
_Sys_SetaPath  DS  2                   ; SYS_CHMOD/SYS_CHOWN path offset, saved
                                        ; across the four argument pushes that
                                        ; happen before _Sys_CopyPathToBuf
_Sys_OpenMode  DS  2                   ; SYS_OPEN create mode, masked by the
                                        ; u-area's U_Cmask and consulted only on
                                        ; the O_CREAT path (see _Sys_Open)
_utimeAtime    DS  4                   ; utimes(2): epoch access time, staged
_utimeMtime    DS  4                   ;   out of the caller's bank by
                                       ;   _Sys_Utime.  They replaced
                                       ;   _utimeDate/_utimeTime, which held
                                       ;   ONE packed ProDOS date+time and no
                                       ;   access time at all (apple/fgx#343);
                                       ;   those two are gone with the FST that
                                       ;   read them
_Sys_TrncLen   DS  4                   ; SYS_FTRUNCATE new length (24-bit in 4 B),
                                        ; saved across _Fcb_LookupPtr's register use
_Sys_TrncFd    DS  2                   ; SYS_FTRUNCATE fd — the zero-fill loop calls
                                        ; Fs_Write, which uses _shTmp0 for its own fd
_Sys_UserSP    DS  2                   ; caller's user-stack SP across the syscall
                                        ; (set at dispatcher entry; consumed at exit)
_kStkOvfLatch  DS  2                   ; kernel-stack canary breach latch (log once
                                        ; per boot; see the dispatcher entry check)
_kStkSysOflow  DS  2                   ; bank-0 stack campaign 0.2: set when the
                                        ; USER-stack floor check below converts a
                                        ; syscall into exit(134).  Read + cleared
                                        ; by _Sys_Exit so its one message can say
                                        ; WHICH guard fired.
                DO      LATPROBE=1
_kLatTick       DS  2                   ; P0 survey: entry tick (60 Hz low word)
_kLatSw         DS  2                   ; P0 survey: swtch count at entry
_kLatMax        DS  2                   ; P0 survey: worst CPU-bound syscall (ticks)
_kLatMaxSig     DS  2                   ; P0 survey: syscall # of that max
                FIN
_Sys_UserDP    DS  2                   ; caller's DP register at the syscall entry.
                                        ; Saved+restored by dispatcher so the
                                        ; kernel can run with DP=$0000 (where
                                        ; _fd_table_ptr and other long-indirect
                                        ; pointers live) regardless of user DP.
_Sys_CallerBank DS 1                    ; caller's DBR at the time of the JSL
; THE BANK A PATH IS COPIED FROM, seeded from _Sys_CallerBank on every syscall
; and overridden per path by the ones that take TWO (apple/fgx#438).  It used to
; be _Sys_CallerBank directly, which carries ONE bank for a whole call -- true
; while argv was a copy in the caller's data bank, and false the moment
; apple/fgx#301 pointed argv at the kernel's bank-0 frame: `rename(argv[1],
; argv[2])' read the second path from the first one's bank.
_Sys_PathBank   DS 1
_Sys_BlkTmp     DS 2                    ; _Sys_PathBlkArg: the offset it returns
                                        ; (captured from the PHB'd data bank —
                                        ; NOT the PB; see the capture at
                                        ; dispatcher entry) — used by
                                        ; buffer-touching handlers (write /
                                        ; read / getcwd / CopyPathToBuf)
; THE FIVE _gfs* CELLS ARE GONE.  They were SYS_GETFSSTAT's walk state over the
; ProDOS volume table -- slot offset, destination offset, count, limit and a
; name-copy scratch -- and the handler that used them built its struct here, in
; this bank, a field at a time.  It now pushes two arguments and calls the far
; bank, which walks the VFS mount list and writes the caller's buffer through
; MVN.  Ten bytes of KGlobals back with them.

; select(2) scan state.  _selArgOff.._selDeadline is a CONTIGUOUS persistent
; block: Phase 2's yield loop save/restores it on the per-task kernel stack
; (_Sys_SavedA and these statics are NOT in swtch's per-task carryover, so a
; concurrent task's syscall/select would clobber the in-flight scan).  The
; output masks + loop-locals below it are rebuilt each scan (not saved).
_selArgOff     DS  2                    ; argblk offset in caller bank
_selCallerBk   DS  2                    ; caller bank (low byte)
_selNfds       DS  2                    ; fd scan limit = min(nfds, 24)
_selPresent    DS  2                    ; present bits: b0=rd b1=wr b2=ex b3=timeout
_selRdIn       DS  4                    ; input readfds  (32-bit fd_set word)
_selWrIn       DS  4                    ; input writefds
_selExIn       DS  4                    ; input exceptfds
_selDeadline   DS  4                    ; Phase 2: _kSystemTicks deadline
_SEL_STATE_LEN EQU  *-_selArgOff
_selRdOut      DS  4                    ; result readfds  (rebuilt each scan)
_selWrOut      DS  4                    ; result writefds
_selExOut      DS  4                    ; result exceptfds
_selCount      DS  2                    ; ready (fd,set) membership count
_selFd         DS  2                    ; scan cursor
_selBit        DS  4                    ; 32-bit rotating bit (1<<fd)
_selWanted     DS  2                    ; per-fd requested bits (b0 rd,b1 wr,b2 ex)
_selReady      DS  2                    ; per-fd readiness bits from _Sel_Classify
_selTmp        DS  2                    ; bit-in-mask test scratch
_selCdIdx      DS  2                    ; chardev idx for the op _Chardev_Poll
                                        ;   dispatches: the dispatcher clobbers A
                                        ;   working out the table offset, so the
                                        ;   op cannot read it from a register.
                                        ;   Same shape as _Sys_WrCdIdx for write.

;------------------------------------------------------------------------------
; _Syscall_Table - 2-byte handler addresses, indexed by syscall number.
; Slot 0 is reserved (unused).
;------------------------------------------------------------------------------
_Syscall_Table  DA      _Sys_Stub               ; 0:  unused
                DA      _Sys_Exit               ; 1:  SYS_EXIT
                DA      _Sys_Fork               ; 2:  SYS_FORK (fork train Stage F:
                                                ;     snapshot fork, deferred parent)
                DA      _Sys_Read               ; 3:  SYS_READ
                DA      _Sys_Write              ; 4:  SYS_WRITE
                DA      _Sys_Open               ; 5:  SYS_OPEN
                DA      _Sys_Close              ; 6:  SYS_CLOSE
                DA      _Sys_Wait               ; 7:  SYS_WAIT
                DA      _thunk_LdCtl            ; 8:  SYS_LDCTL
                DA      _Sys_Link               ; 9:  SYS_LINK
                DA      _Sys_Unlink             ; 10: SYS_UNLINK
                DA      _Sys_Execve             ; 11: SYS_EXECVE
                DA      _Sys_Chdir              ; 12: SYS_CHDIR
                DA      _Sys_Stub               ; 13: unused
                DA      _Sys_Stub               ; 14: unused
                DA      _Sys_Chmod              ; 15: SYS_CHMOD
                DA      _Sys_Chown              ; 16: SYS_CHOWN
                DA      _Sys_Brk                ; 17: SYS_BRK (fork train Stage S)
                DA      _Sys_Stat               ; 18: SYS_STAT
                DA      _Sys_Lseek              ; 19: SYS_LSEEK
                DA      _Sys_GetPid             ; 20: SYS_GETPID
                DA      _Sys_Mount              ; 21: SYS_MOUNT
                DA      _Sys_Umount             ; 22: SYS_UMOUNT
                DA      _Sys_SetUid             ; 23: SYS_SETUID (2.11BSD number)
                DA      _Sys_GetUid             ; 24: SYS_GETUID
                DA      _Sys_SetGid             ; 25: SYS_SETGID (FGX-local; BSD's
                                                ;     46 is spent on SYS_VFORK)
                DA      _Sys_SetEuid            ; 26: SYS_SETEUID (FGX-local)
                DA      _Sys_SetEgid            ; 27: SYS_SETEGID (FGX-local)
                DA      _Sys_Fstat              ; 28: SYS_FSTAT
                DA      _Sys_Stub               ; 29: unused
                DA      _Sys_Stub               ; 30: unused
                DA      _thunk_RtcRead          ; 31: SYS_RTCREAD  (far bank)
                DA      _Sys_Stub               ; 32: unused (was the RTC write;
                                                ;     settimeofday is 126)
                DA      _Sys_Access             ; 33: SYS_ACCESS
                DA      _Sys_Stub               ; 34: unused
                DA      _Sys_Stub               ; 35: unused
                DA      _Sys_Stub               ; 36: unused
                DA      _Sys_Kill               ; 37: SYS_KILL
                DA      _Sys_Stub               ; 38: unused
                DA      _Sys_GetPpid            ; 39: SYS_GETPPID
                DA      _Sys_Stub               ; 40: unused (was SYS_ISATTY)
                DA      _Sys_Dup                ; 41: SYS_DUP
                DA      _Sys_Stub               ; 42: unused (was SYS_GETCWD --
                                                ;   getwd(3) walks the tree)
                DA      _Sys_PosixSpawn         ; 43: SYS_POSIX_SPAWN
                DA      _Sys_PosixSpawnX        ; 44: SYS_POSIX_SPAWNX (+file_actions)
                DA      _Sys_Stub               ; 45: was SYS_GETARG (slice-3 retired)
                DA      _Sys_Vfork              ; 46: SYS_VFORK (fork train Stage V)
                DA      _Sys_GetGid             ; 47: SYS_GETGID
                DA      _Sys_Signal             ; 48: SYS_SIGNAL
                DA      _Sys_ListDir            ; 49: SYS_LISTDIR
                DA      _Sys_GetKey             ; 50: SYS_GETKEY
                DA      _thunk_Uptime           ; 51: SYS_UPTIME   (far bank)
                DA      _Sys_Ticks              ; 52: SYS_TICKS
                DA      _Sys_KStat              ; 53: SYS_KSTAT (diagnostic)
                DA      _Sys_Stub               ; 54: unused
                DA      _Sys_Border             ; 55: SYS_BORDER
                DA      _Sys_SetPal             ; 56: SYS_SETPAL
                DA      _Sys_FontLoad           ; 57: SYS_FONTLOAD
                DA      _Sys_FontRevert         ; 58: SYS_FONTREVERT
                DA      _Sys_FontName           ; 59: SYS_FONTNAME
                DA      _Sys_Dmesg              ; 60: SYS_DMESG  (diagnostic)
                DA      _Sys_MemInfo            ; 61: SYS_MEMINFO (diagnostic)
                DA      _Sys_Malloc             ; 62: SYS_MALLOC (userland-libc)
                DA      _Sys_Free               ; 63: SYS_FREE   (userland-libc)
                DA      _Sys_Alarm              ; 64: SYS_ALARM  (vi-port slice 3)
                DA      _Sys_Ioctl              ; 65: SYS_IOCTL  (serial-driver slice 1.3)
                DA      _Sys_PollKey            ; 66: SYS_POLLKEY (non-blocking key poll)
                DA      _Sys_GetfsStat          ; 67: SYS_GETFSSTAT (df volume info)
                DA      _Sys_MmAlloc            ; 68: SYS_MM_ALLOC (large MM alloc)
                DA      _Sys_MmFree             ; 69: SYS_MM_FREE
                DA      _Sys_Ifconfig           ; 70: SYS_IFCONFIG (net iface table)
                DA      _Sys_Socket             ; 71: SYS_SOCKET
                DA      _Sys_Bind               ; 72: SYS_BIND
                DA      _Sys_Sendto             ; 73: SYS_SENDTO
                DA      _Sys_Recvfrom           ; 74: SYS_RECVFROM
                DA      _Sys_Setsockopt         ; 75: SYS_SETSOCKOPT
                DA      _Sys_Connect            ; 76: SYS_CONNECT
                DA      _Sys_Send               ; 77: SYS_SEND
                DA      _Sys_Recv               ; 78: SYS_RECV
                DA      _Sys_Yield              ; 79: SYS_YIELD
                DA      _Sys_Setpgid            ; 80: SYS_SETPGID
                DA      _Sys_Getpgrp            ; 81: SYS_GETPGRP
                DA      _Sys_Waitpid            ; 82: SYS_WAITPID
                DA      _Sys_Nanosleep          ; 83: SYS_NANOSLEEP
                DA      _Sys_Listen             ; 84: SYS_LISTEN
                DA      _Sys_Accept             ; 85: SYS_ACCEPT
                DA      _Sys_SoundClaim         ; 86: SYS_SOUND_CLAIM
                DA      _Sys_Procs              ; 87: SYS_PROCS (process enumeration)
                DA      _Sys_Pipe               ; 88: SYS_PIPE (impl in pipe.s)
                DA      _Sys_Dup2               ; 89: SYS_DUP2
                DA      _Sys_SlotScan           ; 90: SYS_SLOTSCAN (boot slot-scan table)
                DA      _Sys_Realloc            ; 91: SYS_REALLOC (userland-libc)
                DA      _Sys_Mkdir              ; 92: SYS_MKDIR (copy path in -> _Fs_Mkdir)
                DA      _Sys_Utime              ; 93: SYS_UTIME (stamp mod date/time)
                DA      _Sys_Rmdir              ; 94: SYS_RMDIR (remove empty dir)
                DA      _Sys_Rename             ; 95: SYS_RENAME (same-dir in-place)
                DA      _Sys_Malloc32           ; 96: SYS_MALLOC32 (32-bit size; M-4)
                DA      _Sys_Fsync              ; 97: SYS_FSYNC (train-3 F4)
                DA      _Sys_Sync               ; 98: SYS_SYNC  (train-3 F4)
                DA      _Sys_Select             ; 99: SYS_SELECT
                DA      _Sys_Shutdown           ; 100: SYS_SHUTDOWN (TCP half-close)
                DA      _Sys_ScreenCtl          ; 101: SYS_SCREEN_CTL (console claim)
                DA      _Sys_SigSetMask         ; 102: SYS_SIGSETMASK (BSD sigblock/
                                                ;      sigsetmask; tcsh pfork race)
                DA      _Sys_Ftruncate          ; 103: SYS_FTRUNCATE
                DA      _Sys_Umask              ; 104: SYS_UMASK
                DA      _Sys_GetRlimit          ; 105: SYS_GETRLIMIT
                DA      _Sys_SetRlimit          ; 106: SYS_SETRLIMIT
                DA      _Sys_SigPause           ; 107: SYS_SIGPAUSE
                DA      _Sys_GetPeerName        ; 108: SYS_GETPEERNAME
                DA      _Sys_GetSockName        ; 109: SYS_GETSOCKNAME
                DA      _thunk_ModLoad          ; 110: SYS_MODLOAD
                DA      _Sys_Lstat              ; 111: SYS_LSTAT
                DA      _Sys_Readlink           ; 112: SYS_READLINK
                DA      _Sys_Symlink            ; 113: SYS_SYMLINK
                DA      _Sys_Statfs             ; 114: SYS_STATFS (df -- #329)
                DA      _Sys_Fchdir             ; 115: SYS_FCHDIR
                DA      _Sys_Reboot             ; 116: SYS_REBOOT
                DA      _Sys_Sysctl             ; 117: SYS_SYSCTL (#410)
                DA      _Sys_GetLogin           ; 118: SYS_GETLOGIN
                DA      _Sys_SetLogin           ; 119: SYS_SETLOGIN
                DA      _Sys_SigProcMask        ; 120: SYS_SIGPROCMASK (the same
                                                ;      routine as 102, which is
                                                ;      how = SIG_SETMASK)
                DA      _Sys_SetITimer          ; 121: SYS_SETITIMER (far slot
                                                ;      76; ITIMER_REAL only)
                DA      _Sys_Readv              ; 122: SYS_READV
                DA      _Sys_Writev             ; 123: SYS_WRITEV
                DA      _thunk_Gtod             ; 124: SYS_GETTIMEOFDAY (tty
                                                ;      slot 44)
                DA      _thunk_Adj              ; 125: SYS_ADJTIME (tty slot 45)
                DA      _thunk_Stod             ; 126: SYS_SETTIMEOFDAY (tty
                                                ;      slot 46)
                DA      _Sys_Fcntl              ; 127: SYS_FCNTL
                DA      _Sys_Flock              ; 128: SYS_FLOCK
                DA      _Sys_Fchown             ; 129: SYS_FCHOWN
                DA      _Sys_Fchmod             ; 130: SYS_FCHMOD

;------------------------------------------------------------------------------
; _Sys_ScreenCtl (SYS_SCREEN_CTL = 101) - console screen claim.  A = 1 claims
; the screen (suspends the console flush so a userland task owns SHR directly),
; A = 0 releases it (repaints the console).  Mirrors SYS_SOUND_CLAIM: the owner
; pid is recorded in _screenOwner and _Exit_Core auto-releases on task death.
; Rendering is gated on VT_RENDER_STATE: value 3 = suspended (Con_RenderRow /
; _Con_RenderCell skip when state >= 2).  MX %00.  Out: C=1, A=0.
;------------------------------------------------------------------------------
GFX_PALTAB      EQU     $01A000                 ; 256 per-line palettes x 32 B, bank $01
                                                ; (above the SHR shadow $2000-$9FFF).
_Sys_ScreenCtl  ENT
                MX      %00
                CMP     #2
                BEQ     @sc_arm
                CMP     #3
                BNE     @sc_not3
                BRL     @sc_disarm
@sc_not3        CMP     #1
                BEQ     @sc_claim
                ; release (A=0): restore the console's video state (the gfx tool
                ; left SHR in 320 mode with palette 0 overwritten), then repaint.
@sc_release     SEP     #$20
                LDA     #0
_kfp351         STAL    KFAR_VT_STATE+VT_RENDER_STATE
                REP     #$20
                STZ     _screenOwner
_kfp111         JSL     KFAR_CON_INITSCBS       ; SCBs back to the mode's 640 template
_kfp112         JSL     KFAR_CON_INSTALLPALETTES ; restore console palettes
_kfp113         JSL     KFAR_CON_RENDERALL      ; repaint text
                BRL     @sc_ok
@sc_claim       LDA     _curTask
                STA     _screenOwner
                SEP     #$20
                LDA     #3                      ; suspended
_kfp352         STAL    KFAR_VT_STATE+VT_RENDER_STATE
                REP     #$20
                BRL     @sc_ok

                ; --- arm (A=2): claim + start the 3200 scanline-palette engine ---
@sc_arm         LDA     _curTask
                STA     _screenOwner
                SEP     #$20
                LDA     #3
_kfp353         STAL    KFAR_VT_STATE+VT_RENDER_STATE   ; suspend console
                REP     #$20
                ; install the generic scanline handler ONCE (not idempotent).
                LDA     _gfxScanInstalled
                BNE     @sc_arm_en
                SEP     #$20
                MX      %10
                PHK
                PLA                             ; A.lo = live kernel bank
                REP     #$20
                MX      %00
                AND     #$00FF
                TAY                             ; Y.lo = handler bank
                LDA     #_GfxScanHnd            ; 16-bit offset
                JSR     _Sim_InstallGeneric
                LDA     #1
                STA     _gfxScanInstalled
@sc_arm_en      ; Set the scanline-interrupt bit ($40) on every 4TH SHR line
                ; (~50 ints/frame). Every-2nd (~100/frame, ~80% CPU at 7 MHz)
                ; SATURATES a 7 MHz machine live: the handler falls behind the
                ; beam, palettes land on wrong lines (whole-frame flashing) and
                ; the foreground starves (keys dead). Every-4th costs half the
                ; load for a 4-line palette granularity -- stable at 7 MHz.
                SEP     #$20
                MX      %10
                LDX     #0
@sc_scb_on      LDA     #$40
                ORA     >$019D00,X
                STAL    $019D00,X
                INX
                INX
                INX
                INX
                CPX     #200
                BCC     @sc_scb_on
                LDA     #$02                    ; VGCINT: scanline enable (bit 1)
                STAL    $E0C023
                LDA     #0
                STAL    $E0C032                 ; clear any pending
                REP     #$20
                MX      %00
                LDA     #1
                STA     _gfxScanArmed
                BRL     @sc_ok

                ; --- disarm (A=3): stop the engine + release the screen ---
@sc_disarm      STZ     _gfxScanArmed
                SEP     #$20
                MX      %10
                LDX     #0
@sc_scb_off     LDA     #$BF                    ; clear SCB bit 6
                AND     >$019D00,X
                STAL    $019D00,X
                INX
                CPX     #200
                BCC     @sc_scb_off
                LDA     #0
                STAL    $E0C023                 ; VGCINT off
                STAL    $E0C032                 ; clear pending
                REP     #$20
                MX      %00
                BRL     @sc_release             ; state=0, owner=0, repaint

@sc_ok          LDA     #0
                SEC
                RTS

;------------------------------------------------------------------------------
; _GfxScanHnd - VGC scanline-interrupt generic-source handler (3200-color).
; Reached via the SIM generic walk: MX %11, DBR=kernel-bank, DP=0. Claims with
; CLC+RTL (serviced), declines with SEC+RTL. On each scanline int it reloads
; hardware palette 0 ($019E00) from GFX_PALTAB[vertcount], acks SCANINT ($C032).
; Sequence per Apple GSFirmware/Diagnostics/DIAG.TESTS.aii.
;------------------------------------------------------------------------------
_GfxScanHnd     ENT
                ; DIAG: count every entry (32-bit, DBR=kernel). 0 after a run =>
                ; handler never wired; astronomically large => ack storm.
                REP     #$20
                MX      %01
                INC     _gfxScanCount
                BNE     @gh_nc
                INC     _gfxScanCount+2
@gh_nc          SEP     #$20
                MX      %11
                LDA     _gfxScanArmed           ; 8-bit (MX %11), DBR=kernel
                BNE     @gh_on
                SEC
                RTL
@gh_on          LDAL    $E0C023                 ; VGCINT
                AND     #$20                    ; bit 5 = scanline status
                BNE     @gh_scan
                SEC                             ; some other VGC int -> decline
                RTL
@gh_scan        REP     #$30
                MX      %00
                LDAL    $E0C02E                 ; vertical count (V1..V8 in low byte)
                AND     #$00FF
                ASL
                ASL
                ASL
                ASL
                ASL                             ; *32
                CLC
                ADC     #$A000                  ; src low16 = GFX_PALTAB + v*32 (bank $01)
                TAX
                LDY     #$9E00                  ; dst = $01:9E00 (hardware palette 0)
                LDA     #31                     ; count-1 (32 bytes)
                MVN     $01,$01                  ; block-move 32 B, bank $01 -> bank $01
                PHK
                PLB                             ; MVN left DBR=$01; restore kernel bank
                SEP     #$20
                MX      %10
                LDA     #0
                STAL    $E0C032                 ; ack: STZ SCANINT
                REP     #$30
                SEP     #$30
                MX      %11
                CLC                             ; claimed
                RTL

;------------------------------------------------------------------------------
; _Sys_Fsync (#97) - fsync(fd): force this file's data + metadata to disk.
; A.lo = fd.  C=1 ok / C=0 + A = EBADF/EIO (incl. a latched switch-away
; write error, reported once).  Non-file fds (console/chardev/pipe/socket/
; dir) are a successful no-op, POSIX-tolerantly.
;------------------------------------------------------------------------------
_Sys_Fsync      MX      %00
                AND     #$00FF
                JSR     Fs_Fsync
                RTS

;------------------------------------------------------------------------------
; _Sys_Sync (#98) - sync(): commit every open regular file's dirty state
; (all tasks' fd tables) + the block bitmap.  Always C=1 — per-file errors
; stay latched on their FCBs for the owner's next write/fsync/close.
;------------------------------------------------------------------------------
_Sys_Sync       MX      %00
                JSR     Fs_SyncAll              ; the descriptors, per task
                ; AND THE MOUNTED FILESYSTEMS, which is what sync(2) MEANS and
                ; what this call did not do until apple/fgx#332.  Fs_SyncAll
                ; walks every task's fd table and fsyncs descriptors; nothing
                ; touched the mount list, so the UFS superblock was never
                ; written back and every block handed out since the last
                ; free-list refill was given away a second time after a
                ; remount.  Reno's sync(2) is this walk and nothing else
                ; (kern/vfs_syscalls.c:268).
                ;
                ; NO ERROR RETURN, upstream's shape: BSD's sync cannot fail,
                ; and a filesystem that will not write is not something the
                ; caller can act on.  C is left as Fs_SyncAll set it.
_kfp983         JSL     KFAR_VFS_SYNC           ; slot 36; bank byte patched
                RTS

;------------------------------------------------------------------------------
; _Sys_Stub - placeholder for unimplemented syscalls.  Returns ENOSYS.
;------------------------------------------------------------------------------
_Sys_Stub       MX      %00
                LDA     #ENOSYS
                CLC
                RTS

;------------------------------------------------------------------------------
; _Sys_Shutdown (#100) - shutdown(fd, how).  _Sys_SavedA = fd, _Sys_SavedX = how.
; TCP half-close: SHUT_WR/SHUT_RDWR (how != 0) send a FIN via net_op_shutdown
; (CR_DISCON), leaving the socket in FIN_WAIT so recv() still drains queued data
; and sees the peer FIN as EOF; the fd stays open (close() frees it).  SHUT_RD
; (how == 0) is a successful no-op (the W5100 can't stop RX).  _Sock_FdToDesc
; validates the fd + socket-ness and stages _sockTmpHw for the net op.
; Out: C=1 ok / C=0 + A=EBADF (bad fd or not a socket).
;------------------------------------------------------------------------------
_Sys_Shutdown   MX      %00
                LDA     _Sys_SavedX             ; how
                AND     #$00FF
                BEQ     @shd_ok                 ; SHUT_RD -> no FIN, succeed
                LDA     _Sys_SavedA             ; fd
                AND     #$00FF
                JSR     _Sock_FdToDesc          ; C=1 + Y=desc + _sockTmpHw / C=0 + A=EBADF
                BCC     @shd_err
                STY     _sockTmpOff
                LDY     #NETOP_Shutdown
                JMP     _Net_Dispatch           ; -> net_op_shutdown -> _Net_Xport_Shutdown
@shd_ok         LDA     #0
                SEC
                RTS
@shd_err        RTS                             ; C=0, A=EBADF from _Sock_FdToDesc

;------------------------------------------------------------------------------
; _Sys_Select (#99) - select(nfds, readfds, writefds, exceptfds, timeout).
; _Sys_SavedA = argblk offset in the caller's bank (_Sys_CallerBank).  The libc
; wrapper marshals the fd_sets in/out and pre-converts timeval->ticks:
;   +0 nfds(2)  +2 present(2; b0=rd b1=wr b2=ex b3=timeout)  +4 readfds(4)
;   +8 writefds(4)  +12 exceptfds(4)  +16 timeout-ticks(4)
; Phase 2: blocking poll + _Sys_Yield loop.  timeout==NULL blocks until ready
; or a signal (EINTR); timeout=={0,0} is a non-blocking poll; else it blocks up
; to the deadline.  Out: A = ready (fd,set) count, C=1 / A=errno (EBADF/EINTR),
; C=0.  The loop keeps only _selArgOff/_selCallerBk live across the yield (saved
; on the per-task kernel stack — these statics are NOT in swtch's carryover);
; every scan re-reads the argblk fresh (stable in the caller bank), and the
; absolute deadline lives in the argblk (+16) which each select call owns.
;------------------------------------------------------------------------------
_Sys_Select     MX      %00
                LDA     _Sys_SavedA
                STA     _selArgOff
                LDA     _Sys_CallerBank
                AND     #$00FF
                STA     _selCallerBk
                JSR     _Sel_SetPtr             ; timeout present -> absolute deadline @+16
                LDY     #2
                LDA     [_libcTmp2],Y
                AND     #8
                BEQ     @sel_loop
                LDY     #16                     ; deadline = now + relative ticks
                LDA     _kSystemTicks
                CLC
                ADC     [_libcTmp2],Y
                STA     _selTmp
                LDY     #18
                LDA     _kSystemTicks+2
                ADC     [_libcTmp2],Y
                STA     [_libcTmp2],Y           ; deadline.hi -> +18
                LDA     _selTmp
                LDY     #16
                STA     [_libcTmp2],Y           ; deadline.lo -> +16
@sel_loop       JSR     _Sel_ReadArgblk
                JSR     _Sel_Scan
                BCC     @sel_err
                LDA     _selCount
                BNE     @sel_ready
                LDA     _selPresent             ; nothing ready
                AND     #8
                BEQ     @sel_chksig             ; no timeout -> block forever
                JSR     _Sel_Expired
                BCS     @sel_timeout
@sel_chksig     JSR     _Sel_SigPending
                BCS     @sel_eintr
                LDA     _selArgOff              ; block: save re-find state
                PHA
                LDA     _selCallerBk
                PHA
                LDA     _selPresent             ; timed select -> yield (deadline poll);
                AND     #8                      ; block-forever -> sleep on WCHAN_SELECT
                BNE     @sel_yield
                INC     _nSelSleepers           ; (the kbd/sock/idle wake sites re-scan us)
                LDA     #WCHAN_SELECT
                JSR     _sleep
                DEC     _nSelSleepers
                BRA     @sel_wake
@sel_yield      JSR     _Sys_Yield
@sel_wake       PLA
                STA     _selCallerBk
                PLA
                STA     _selArgOff
                BRL     @sel_loop
@sel_ready      JSR     _Sel_WriteArgblk
                LDA     _selCount
                SEC
                RTS
@sel_timeout    STZ     _selRdOut               ; timed out: return 0, cleared masks
                STZ     _selRdOut+2
                STZ     _selWrOut
                STZ     _selWrOut+2
                STZ     _selExOut
                STZ     _selExOut+2
                JSR     _Sel_WriteArgblk
                LDA     #0
                SEC
                RTS
@sel_eintr      MX      %00
                LDA     #EINTR
                CLC
                RTS
@sel_err        MX      %00                     ; A = EBADF from _Sel_Scan
                CLC
                RTS

;------------------------------------------------------------------------------
; select(2) argblk helpers.  _Sel_SetPtr points _libcTmp2 at the argblk in the
; caller bank; ReadArgblk loads nfds/present/masks; WriteArgblk stores the
; result masks; Expired reports now>=deadline(@+16); SigPending reports a
; pending signal (EINTR).  All MX %00.
;------------------------------------------------------------------------------
_Sel_SetPtr     MX      %00
                LDA     _selArgOff
                STA     _libcTmp2
                SEP     #$20
                MX      %10
                LDA     _selCallerBk
                STA     _libcTmp2+2
                REP     #$20
                MX      %00
                RTS
_Sel_ReadArgblk MX      %00
                JSR     _Sel_SetPtr
                LDY     #0
                LDA     [_libcTmp2],Y
                CMP     #25
                BCC     @sra_ok
                LDA     #24
@sra_ok         STA     _selNfds
                LDY     #2
                LDA     [_libcTmp2],Y
                STA     _selPresent
                LDY     #4
                LDA     [_libcTmp2],Y
                STA     _selRdIn
                LDY     #6
                LDA     [_libcTmp2],Y
                STA     _selRdIn+2
                LDY     #8
                LDA     [_libcTmp2],Y
                STA     _selWrIn
                LDY     #10
                LDA     [_libcTmp2],Y
                STA     _selWrIn+2
                LDY     #12
                LDA     [_libcTmp2],Y
                STA     _selExIn
                LDY     #14
                LDA     [_libcTmp2],Y
                STA     _selExIn+2
                RTS
_Sel_WriteArgblk MX     %00
                JSR     _Sel_SetPtr
                LDY     #4
                LDA     _selRdOut
                STA     [_libcTmp2],Y
                LDY     #6
                LDA     _selRdOut+2
                STA     [_libcTmp2],Y
                LDY     #8
                LDA     _selWrOut
                STA     [_libcTmp2],Y
                LDY     #10
                LDA     _selWrOut+2
                STA     [_libcTmp2],Y
                LDY     #12
                LDA     _selExOut
                STA     [_libcTmp2],Y
                LDY     #14
                LDA     _selExOut+2
                STA     [_libcTmp2],Y
                RTS
_Sel_Expired    MX      %00                     ; C=1 iff _kSystemTicks >= deadline(@+16)
                JSR     _Sel_SetPtr
                LDY     #16
                LDA     _kSystemTicks
                SEC
                SBC     [_libcTmp2],Y
                LDY     #18
                LDA     _kSystemTicks+2
                SBC     [_libcTmp2],Y           ; C=1 -> no borrow -> now >= deadline
                RTS
_Sel_SigPending MX      %00                     ; C=1 iff a signal is pending (EINTR)
                ; NO TTY-SIDE ARM, AND THERE MUST NOT BE ONE.  `ttyinput'
                ; signals at arrival, so a pending `^C' is already in the
                ; per-task mask below.  An arm that asked the caller's
                ; controlling tty instead would give EINTR to any task whose
                ; ctty had a `^C' waiting, including one outside that line's
                ; foreground process group -- which upstream never interrupts.
                LDA     _curTask
                AND     #$00FF
                BEQ     @ssp_no
                DEC
                ASL
                ASL
                ASL
                ASL
                ASL
                ASL                             ; (pid-1)*64
                CLC
                ADC     #FGX_TASK_TBL_OFF
                TAX
                LDA:    TCB_PendingSig,X
                ORA:    TCB_PendingSig+2,X
                BNE     @ssp_yes
@ssp_no         CLC
                RTS
@ssp_yes        SEC
                RTS

;------------------------------------------------------------------------------
; _Sel_Scan - one non-blocking pass over fd 0..min(nfds,24)-1: classify each
; requested fd, gather readiness, build _selRdOut/_selWrOut/_selExOut +
; _selCount.  Uses a 32-bit rotating bit (_selBit) so word boundaries need no
; special case (a bit lands in exactly one of the two 16-bit halves).  In:
; _selNfds/_selPresent/_selRdIn/WrIn/ExIn.  Out: masks+count; C=1 / C=0+A=EBADF.
;------------------------------------------------------------------------------
_Sel_Scan       MX      %00
                STZ     _selRdOut
                STZ     _selRdOut+2
                STZ     _selWrOut
                STZ     _selWrOut+2
                STZ     _selExOut
                STZ     _selExOut+2
                STZ     _selCount
                STZ     _selFd
                LDA     #1
                STA     _selBit
                STZ     _selBit+2
@sscan_loop        LDA     _selFd
                CMP     _selNfds
                BCC     @sscan_body
                BRL     @sscan_done             ; fd >= nfds (long branch out)
@sscan_body     STZ     _selWanted
                LDA     _selPresent             ; rd wanted?
                AND     #1
                BEQ     @sscan_wr
                LDA     _selRdIn
                AND     _selBit
                STA     _selTmp
                LDA     _selRdIn+2
                AND     _selBit+2
                ORA     _selTmp
                BEQ     @sscan_wr
                LDA     _selWanted
                ORA     #1
                STA     _selWanted
@sscan_wr          LDA     _selPresent             ; wr wanted?
                AND     #2
                BEQ     @sscan_ex
                LDA     _selWrIn
                AND     _selBit
                STA     _selTmp
                LDA     _selWrIn+2
                AND     _selBit+2
                ORA     _selTmp
                BEQ     @sscan_ex
                LDA     _selWanted
                ORA     #2
                STA     _selWanted
@sscan_ex          LDA     _selPresent             ; ex wanted?
                AND     #4
                BEQ     @sscan_have
                LDA     _selExIn
                AND     _selBit
                STA     _selTmp
                LDA     _selExIn+2
                AND     _selBit+2
                ORA     _selTmp
                BEQ     @sscan_have
                LDA     _selWanted
                ORA     #4
                STA     _selWanted
@sscan_have        LDA     _selWanted
                BEQ     @sscan_next                ; fd not in any requested set
                JSR     _Sel_Classify           ; A = ready bits / C=0 EBADF
                BCS     @sscan_cok
                MX      %00                     ; EBADF: bail the scan (A already set)
                CLC
                RTS
@sscan_cok      AND     _selWanted              ; out = wanted & ready
                STA     _selReady
                AND     #1                      ; readable?
                BEQ     @sscan_dwr
                LDA     _selRdOut
                ORA     _selBit
                STA     _selRdOut
                LDA     _selRdOut+2
                ORA     _selBit+2
                STA     _selRdOut+2
                INC     _selCount
@sscan_dwr         LDA     _selReady
                AND     #2                      ; writable?
                BEQ     @sscan_dex
                LDA     _selWrOut
                ORA     _selBit
                STA     _selWrOut
                LDA     _selWrOut+2
                ORA     _selBit+2
                STA     _selWrOut+2
                INC     _selCount
@sscan_dex         LDA     _selReady
                AND     #4                      ; except?
                BEQ     @sscan_next
                LDA     _selExOut
                ORA     _selBit
                STA     _selExOut
                LDA     _selExOut+2
                ORA     _selBit+2
                STA     _selExOut+2
                INC     _selCount
@sscan_next        ASL     _selBit                 ; rotate the 32-bit bit left
                ROL     _selBit+2
                INC     _selFd
                BRL     @sscan_loop
@sscan_done        MX      %00
                SEC
                RTS

;------------------------------------------------------------------------------
; _Sel_Classify - readiness of the fd in _selFd for select.  Out: A = ready
; bits (b0=read, b1=write, b2=except), C=1 / A=EBADF, C=0 (fd not open).
;   console : read = _kKbdRingCount!=0, write = always, except = never
;   socket  : NETOP_SockStatus (read/write per SN_SR/RSR/FSR; except never)
;   pipe/chardev/file : read + write always ready (scope cut), except never
; MX %00 in/out.
;------------------------------------------------------------------------------
_Sel_Classify   MX      %00
                SEP     #$20
                MX      %10
                LDA     _selFd
                JSR     _Fcb_LookupPtr          ; C=1 + _fcbPtr / C=0 A=EBADF
                BCS     @cl_haveFcb
                BRL     @cl_bad                 ; pty P3: chardev arm pushed
                                                ; @cl_bad out of BCC range
@cl_haveFcb     LDY     #FCB_Flags
                LDA     [_fcbPtr],Y
                ; TYPE DISPATCH (UFS 1.2a-6), the last of the ladder and the
                ; site whose order differed most: SOCKET, then CONSOLE, then
                ; CHARDEV.  Five sites, four different orders, every one of
                ; them correct only because a descriptor carries exactly one
                ; type bit -- an invariant none of them stated and all of them
                ; depended on.  Naming the type once is what makes it true by
                ; construction rather than by coincidence.
                ;
                ; BIT rather than AND was this site's way of testing without
                ; destroying the flags byte it had to re-test.  With one
                ; classification there is nothing left to preserve.
                ; DISPATCH THROUGH f_ops ON THE DESCRIPTOR -- UFS 1.7d I2c.
                ;
                ; select is the first op to read its arm OUT OF THE DESCRIPTOR
                ; rather than derive it from FCB_Flags here.  That is the whole
                ; object of the increment: a new descriptor type arrives by
                ; having an f_ops, not by being added to five branch chains.
                ; _Fcb_OpEntry installs f_ops on first use -- the type is not
                ; known when a descriptor is made, because the FS layer sets the
                ; FCB's type bit after _Fcb_Alloc returns -- and every later
                ; operation reads it.
                ;
                ; THE PER-TYPE TABLE STAYS as the fallback, and is still what
                ; the other four ops use.  It answers identically: both roads
                ; lead through _Fcb_ClassifyFlags, one at dispatch and one at
                ; installation.  It goes when the last op is hoisted.
                REP     #$30
                MX      %00
                LDA     _selFd
                AND     #$00FF
                LDX     #FO_SELECT
                JSR     _Fcb_OpEntry
                BCC     @cl_notArm              ; no f_ops, or not ours
                DEC                             ; RTS resumes at the address
                PHA                             ;   AFTER the one it pops
                RTS                             ; -> the arm, in this bank

                ; FAR-BANK OPS: ROUTED.  Reno does not answer select locally
                ; either -- vfs_vnops.c:347 is `vn_select(fp, which) { return
                ; (VOP_SELECT(...)); }', so the filesystem decides.  Answering
                ; here instead gives what `_SelOp_Default' gives, which is right
                ; for a regular file and for /dev/null and WRONG for a device
                ; that can block: a line reached as /dev/tty01 would be reported
                ; readable with no key waiting.
                ;
                ; `spec_select' has something to dispatch to, so the ask is
                ; safe.
@cl_notArm      LDA     _fdOpsFar
                BEQ     @cl_bad
                JMP     _Sys_DevSelect

                ; A DESCRIPTOR WITH NO f_ops IS A BAD DESCRIPTOR, and answering
                ; EBADF is the honest reading rather than a fallback.  Every fd
                ; in the table has a `struct file' -- all five writers mirror,
                ; and boot asserts the two tables agree -- so reaching here
                ; means the descriptor is not one this kernel made.  Guessing a
                ; readiness for it is the one answer select must not give.
@cl_bad         REP     #$30
                MX      %00
                AND     #$00FF                  ; A = EBADF
                CLC
                RTS

_SelOp_Default  MX      %00
                REP     #$30
                MX      %00
                LDA     #%00000011
                SEC
                RTS

_SelOp_Socket   REP     #$30
                MX      %00
                LDA     _selFd
                JSR     _Sock_FdToDesc          ; C=1 + Y=desc + _sockTmpHw / C=0
                BCC     @cl_sockbad
                STY     _sockTmpOff
                JSR     _Loop_StatusTry         ; loopback answers from its rings
                LDA     _loopHandled
                BEQ     @cl_sockhw
                LDA     _loopBits
                AND     #$0007
                SEC
                RTS
@cl_sockhw      LDY     #NETOP_SockStatus
                JSR     _NetThunkExec           ; A = ready bits, C=1 / C=0 ENOSYS
                BCC     @cl_sockbad
                AND     #$0007
                SEC
                RTS
@cl_sockbad     LDA     #0                      ; unresolvable socket -> not ready
                SEC
                RTS

;------------------------------------------------------------------------------
; _Fd_Dup - point the current task's fd slot (A = target fd) at the FCB already
; in _fcbPtr, and bump that FCB's refcount.  The dup
; primitive shared by _Sys_Dup / _Sys_Dup2.  Caller guarantees the slot is free
; (or already closed) and _fcbPtr is a resolved source FCB.
; In:  _fcbPtr = source FCB; A = target fd (M=1); _fdDupSrc = SOURCE fd.
; Out: slot[fd] = _fcbPtr; FCB_RefCount bumped (saturating);
;      the file table mirrored (UFS 1.7d I2c).
; MX:  Caller %10.  Preserves M/X via PHP/PLP.  Preserves X.  Clobbers A,Y,_shTmp0.
;
; _fdDupSrc IS REQUIRED and is not derivable here: after a dup several fds
; share one FCB, so _fcbPtr does not identify which descriptor was copied.
;------------------------------------------------------------------------------
_Fd_Dup         MX      %10
                PHP
                ; RANGE-CHECK, do not MASK.  `AND #$0F` was only ever correct
                ; while the table had <=16 slots.  With FS_MAX_FDS = 30 a dup
                ; onto fd 16+ masked to slot 16-16=0 and overwrote STDIN, while
                ; the real slot stayed zero -- so _Sys_Dup's free-slot scan kept
                ; handing out the SAME fd forever and EMFILE became unreachable
                ; (pipetest: 40 dups all "succeeded" against a 27-slot table).
                CMP     #FS_MAX_FDS
                BCS     @fdd_bad
                STA     _fdDupDst               ; the TARGET fd, kept: _shTmp0
                STZ     _fdDupDst+1             ;   becomes fd*3 two lines down
                                                ;   and the file-table mirror
                                                ;   needs the fd ITSELF.  The
                                                ;   same trap _fcbFreeFd exists
                                                ;   for in _Fcb_Free.
                STA     _shTmp0
                ASL
                CLC
                ADC     _shTmp0                 ; A = fd*3 (8-bit)
                STA     _shTmp0
                STZ     _shTmp0+1               ; clear high for 16-bit Y
                REP     #$10
                MX      %10
                LDY     _shTmp0                 ; slot byte offset
                LDA     _fcbPtr                 ; write the 3-byte FCB ptr
                STA     [_fd_table_ptr],Y
                INY
                LDA     _fcbPtr+1
                STA     [_fd_table_ptr],Y
                INY
                LDA     _fcbPtr+2
                STA     [_fd_table_ptr],Y
                ; bump the refcount: one more descriptor names this FCB
                LDY     #FCB_RefCount
                LDA     [_fcbPtr],Y
                CMP     #$FF
                BEQ     @fdd_mirror             ; saturate (leak, not wrap -> UAF)
                INC
                STA     [_fcbPtr],Y
@fdd_mirror     ; MIRROR IT IN THE FILE TABLE -- UFS 1.7d I2c.  Until this was
                ; here, dup was the writer that could leave a descriptor live
                ; in the fd table and absent from the file table, which is
                ; exactly what stopped the file table from being able to answer
                ; what a descriptor IS.
                ;
                ; A dup'd descriptor is a SECOND REFERENCE to one struct file,
                ; not a copy of it -- Reno's dupit is `u.u_ofile[new] = fp;
                ; fp->f_count++' -- which is why dup'd fds share an offset.
                ;
                ; fddup(pid, oldfd, newfd): right to left, so newfd goes down
                ; first and pid ends nearest the return.
                REP     #$30
                MX      %00
                PHX                             ; the contract preserves X
                LDA     _fdDupDst               ; target fd, saved on entry
                PHA                             ; newfd
                LDA     _fdDupSrc
                AND     #$00FF
                PHA                             ; oldfd
                JSR     _Fcb_OwnerPid
                PHA                             ; pid
_kfp915         JSL     KFAR_VFS_DESCDUP        ; bank byte patched by Far_Init
                TSC
                CLC
                ADC     #6                      ; drop the three arguments
                TCS
                PLX
                PLP
                RTS

                ; The range check refused, so no slot was written and there is
                ; nothing to mirror.  Kept separate from @fdd_mirror precisely
                ; so a rejected dup cannot reach the file table.
@fdd_bad        PLP
                RTS

;------------------------------------------------------------------------------
; _Sys_Dup (#41) - dup(fd).  Returns the lowest free fd that shares fd's FCB.
; In:  caller A = fd  (read from _Sys_SavedA, stable across the FCB helpers).
; Out: A = newfd, C=1; or C=0 + A=errno (EBADF bad fd / EMFILE no free slot).
; MX:  %00 in/out.
;------------------------------------------------------------------------------
_Sys_Dup        MX      %00
                ; resolve + validate fd -> _fcbPtr
                SEP     #$20
                MX      %10
                LDA     _Sys_SavedA
                JSR     _Fcb_LookupPtr
                BCS     @sd_haveFcb
                REP     #$20
                MX      %00
                LDA     #EBADF
                CLC
                RTS
@sd_haveFcb     ; find the LOWEST free fd (16-bit scan: TAY needs 16-bit C).
                ; Scans from 0, not FS_FIRST_USER_FD: POSIX/V7 requires dup (and
                ; open/creat/pipe) to return the lowest available descriptor
                ; INCLUDING 0/1/2 once they are closed -- reserving them is
                ; what broke the classic `close(1); dup(fd);` stdio-rebinding
                ; idiom, which BSD userland uses everywhere and never
                ; error-checks (the ported C shell's doio() restores stdout that
                ; way, silently landed it on fd 3, and lost all terminal output).
                REP     #$30
                MX      %00
                LDX     #0
_Sys_DupFrom    ; fcntl(F_DUPFD) enters here: X = the lowest fd to try,
                ; _fcbPtr = the source, MX %00.
@sd_scan        CPX     #FS_MAX_FDS
                BCS     @sd_full
                TXA
                ASL
                STA     _shTmp0
                TXA
                CLC
                ADC     _shTmp0                 ; A = X*3
                INC
                INC                             ; +2 -> slot bank-byte offset
                TAY
                SEP     #$20
                MX      %10
                LDA     [_fd_table_ptr],Y       ; bank byte: 0 => free
                REP     #$20
                MX      %00
                AND     #$00FF
                BEQ     @sd_free
                INX
                BRA     @sd_scan
@sd_free        ; X = free fd; _fcbPtr = source FCB.  Dup into X.
                LDA     _Sys_SavedA
                AND     #$00FF
                STA     _fdDupSrc               ; the file table is indexed by fd
                SEP     #$20
                MX      %10
                TXA                             ; A = newfd (low 8 of X)
                JSR     _Fd_Dup                 ; preserves X
                REP     #$20
                MX      %00
                TXA                             ; A = newfd
                AND     #$00FF
                SEC
                RTS
@sd_full        REP     #$20
                MX      %00
                LDA     #EMFILE
                CLC
                RTS

;------------------------------------------------------------------------------
; _Sys_Fcntl (#127) - fcntl(fd, cmd, arg).  4.3BSD-Reno kern_descrip.c:128.
; In:  caller A = fd, X = cmd, Y = arg (via _Sys_SavedA/X/Y).
; Out: C=1 + A = the value (0 where fcntl has none); C=0 + A = errno.
;
; F_DUPFD IS _Sys_Dup's SCAN STARTED AT arg: this table decides which numbers
; are free, and fddup clears the new descriptor's close-on-exec byte as Reno's
; dupit does.  F_GETFD and F_SETFD read and write that byte, `*pop' upstream,
; in the far arena where vfs_file.c keeps it (_Fd_Pop).  F_GETFL and F_SETFL
; are the struct file's f_flag, biased by FOPEN (-1) as the open site's
; `fflags = mode - FOPEN' is; F_SETFL may not change the access mode or the
; flock(2) lock bits (FCNTLCANT) and then does the second half of Reno's fset: the new FNDELAY
; goes to the descriptor as ioctl(FIONBIO), through _Sys_Ioctl's dispatch --
; the one that reaches a socket or a pipe as well as a vnode -- and its answer
; is fcntl's, as fset's error is upstream.
;
; F_GETOWN AND F_SETOWN ARE EINVAL, Reno's answer to an unknown command: they
; name the receiver of SIGIO and SIGURG, and FGX sends neither -- the reason
; vfs_ioctl gives for leaving FIOASYNC out.
;------------------------------------------------------------------------------
_Sys_Fcntl      MX      %00
                SEP     #$20
                MX      %10
                LDA     _Sys_SavedA
                JSR     _Fcb_LookupPtr
                REP     #$30
                MX      %00
                BCC     @sfc_badf
                LDA     _Sys_SavedX
                BNE     @sfc_notDup             ; F_DUPFD is 0
                LDX     _Sys_SavedY
                CPX     #FS_MAX_FDS             ; unsigned, so a negative
                BCS     @sfc_inval              ;   arg is refused too
                JMP     _Sys_DupFrom
@sfc_notDup     CMP     #F_SETFD+1
                BCS     @sfc_fl
                ; F_GETFD (1) or F_SETFD (2): the flag byte
                LDA     _Sys_SavedA
                AND     #$00FF
                JSR     _Fd_Pop
                BCC     @sfc_badf
                SEP     #$20
                MX      %10
                LDA     _Sys_SavedX
                CMP     #F_SETFD
                BEQ     @sfc_setfd
                LDA     [_fdFilePtr],Y
                AND     #UF_EXCLOSE
                BRA     @sfc_ret8
@sfc_setfd      LDA     _Sys_SavedY
                AND     #UF_EXCLOSE
                STA     [_fdFilePtr],Y
                LDA     #0
@sfc_ret8       REP     #$30
                MX      %00
                AND     #$00FF
                SEC
                RTS
@sfc_badf       LDA     #EBADF
                CLC
                RTS
@sfc_inval      LDA     #EINVAL
                CLC
                RTS
@sfc_fl         CMP     #F_SETFL+1
                BCS     @sfc_inval              ; F_GETOWN, F_SETOWN, others
                LDA     _Sys_SavedA
                AND     #$00FF
                JSR     _Fcb_FileOf
                BCC     @sfc_badf
                LDY     #F_FLAG
                LDA     _Sys_SavedX
                CMP     #F_SETFL
                BEQ     @sfc_setfl
                LDA     [_fdFilePtr],Y
                DEC                             ; + FOPEN
                SEC
                RTS
@sfc_setfl      LDA     _Sys_SavedY
                INC                             ; - FOPEN
                AND     #$FFFF-FCNTLCANT
                STA     _shTmp1
                LDA     [_fdFilePtr],Y
                AND     #FCNTLCANT
                ORA     _shTmp1
                STA     [_fdFilePtr],Y
                AND     #FNDELAY                ; Reno fset(fp, FNDELAY, ...)
                STA     _Sys_FcntlNb
                LDA     _Sys_SavedA
                AND     #$00FF
                STA     _Sys_IoctlFd
                LDA     #FIONBIO
                STA     _Sys_IoctlCmd
                LDA     #_Sys_FcntlNb
                STA     _Sys_IoctlArgLo
                PHB                             ; the argument is in THIS bank
                PHB
                PLA
                AND     #$00FF
                STA     _Sys_IoctlArgBank
                JMP     _Sys_IoctlStaged

;------------------------------------------------------------------------------
; _Sys_Flock (#128) - flock(fd, how).  4.3BSD-Reno kern_descrip.c:418.
; In:  caller A = fd, X = how (via _Sys_SavedA/X).
; Out: C=1 + A = 0; C=0 + A = errno (EBADF, EOPNOTSUPP, EWOULDBLOCK, EINTR).
;
; Upstream's descriptor checks are _Sys_VnodeFp's: EBADF, then EOPNOTSUPP for
; anything that is not a vnode -- including a console or tty descriptor the
; core opened itself, where upstream would lock its device vnode.  The rest is
; vn_flock (kern_flock.c), which may sleep, interruptibly, waiting for a
; conflicting lock.
;------------------------------------------------------------------------------
_Sys_Flock      MX      %00
                LDX     #ENOTSUP                ; BSD: EOPNOTSUPP, the same 45
                JSR     _Sys_VnodeFp
                BCC     @sfl_err
                LDA     _Sys_SavedX
                PHA                             ; how
                LDA     _fdFilePtr+2
                AND     #$00FF
                PHA                             ; fp: bank, pad
                LDA     _fdFilePtr
                PHA                             ; fp: offset
_kfp1003        JSL     KFAR_VFS_FLOCK          ; bank byte patched by Far_Init
                TAY
                TSC
                CLC
                ADC     #6                      ; drop the three words
                TCS
                TYA
                BNE     @sfl_err
                SEC
                RTS
@sfl_err        CLC
                RTS

;------------------------------------------------------------------------------
; _Sys_Fchown (#129) - fchown(fd, uid, gid).  4.3BSD-Reno vfs_syscalls.c:1234.
;   In: caller A = fd, X = uid, Y = gid (via _Sys_SavedA/X/Y).
; _Sys_Fchmod (#130) - fchmod(fd, mode).  4.3BSD-Reno vfs_syscalls.c:1164.
;   In: caller A = fd, X = mode.
; Out: C=1 + A = 0; C=0 + A = errno (EBADF, EINVAL, EROFS, EPERM).
;
; ONE BODY WITH TWO HEADS, _Sys_Chmod and _Sys_Chown's shape for the same
; reason: vn_fsetattr (kern_fsetattr.c) takes both, with $FFFF -- VA_UNSET --
; in the fields a head does not mean.  Reno's getvnode is _Sys_VnodeFp, and a
; descriptor that is not a vnode's is its EINVAL.
;------------------------------------------------------------------------------
_Sys_Fchown     MX      %00
                LDX     #EINVAL                 ; getvnode's answer for a
                JSR     _Sys_VnodeFp            ;   descriptor that is not a
                BCC     _Sys_FsetaErr           ;   vnode's
                LDA     _Sys_SavedY
                PHA                             ; gid
                LDA     _Sys_SavedX
                PHA                             ; uid
                PEA     $FFFF                   ; mode: leave it
                BRA     _Sys_FsetaTail

_Sys_Fchmod     MX      %00
                LDX     #EINVAL
                JSR     _Sys_VnodeFp
                BCC     _Sys_FsetaErr
                PEA     $FFFF                   ; gid: leave it
                PEA     $FFFF                   ; uid: leave it
                LDA     _Sys_SavedX
                PHA                             ; mode

_Sys_FsetaTail  LDA     _fdFilePtr+2
                AND     #$00FF
                PHA                             ; fp: bank, pad
                LDA     _fdFilePtr
                PHA                             ; fp: offset
_kfp1004        JSL     KFAR_VFS_FSETATTR       ; bank byte patched by Far_Init
                TAY
                TSC
                CLC
                ADC     #10                     ; drop the five words
                TCS
                TYA
                BNE     _Sys_FsetaErr
                SEC
                RTS
_Sys_FsetaErr   CLC
                RTS

;------------------------------------------------------------------------------
; _Sys_VnodeFp - the struct file of a vnode descriptor, 4.3BSD-Reno's
; getvnode (kern/vfs_syscalls.c:1678) for flock(2), fchmod(2) and fchown(2).
; In:  _Sys_SavedA = fd; X = the errno a descriptor that is not a vnode's
;      answers (flock's EOPNOTSUPP, getvnode's EINVAL).
; Out: C=1, _fdFilePtr = the struct file; C=0, A = errno (EBADF, or X's).
;
; The checks are made on the struct file the core already reads
; (_Fcb_FileOf).  THE TEST IS f_ops, NOT f_type ALONE: a mirrored descriptor is
; DTYPE_VNODE with its FCB in f_data until its first read or write installs its
; real type, so a fresh pipe reads as a vnode.  A vnode's descriptor names
; `vnops', the one vector outside this bank (_Fcb_OpEntry's distinction), so
; the vector's bank decides: null or this bank's is not a vnode.  A console or
; tty descriptor the core opened itself is refused for that reason, where
; upstream would find its device vnode.
;------------------------------------------------------------------------------
_Sys_VnodeFp    MX      %00
                PHX                             ; the not-a-vnode errno
                SEP     #$20
                MX      %10
                LDA     _Sys_SavedA
                JSR     _Fcb_LookupPtr
                REP     #$30
                MX      %00
                BCC     @svf_badf
                LDA     _Sys_SavedA
                AND     #$00FF
                JSR     _Fcb_FileOf
                BCC     @svf_badf
                LDY     #F_TYPE
                LDA     [_fdFilePtr],Y
                CMP     #DTYPE_VNODE
                BNE     @svf_not
                LDY     #F_OPS+2
                LDA     [_fdFilePtr],Y
                AND     #$00FF                  ; the vector's bank
                BEQ     @svf_not                ; no vector yet
                STA     _shTmp1
                PHK
                PHK
                PLA
                AND     #$00FF
                CMP     _shTmp1
                BEQ     @svf_not                ; a legacy vector: not a vnode
                PLX
                SEC
                RTS
@svf_badf       PLX
                LDA     #EBADF
                CLC
                RTS
@svf_not        PLA                             ; the caller's errno
                CLC
                RTS

;------------------------------------------------------------------------------
; _Sys_Dup2 (#89) - dup2(old,new).  Makes new share old's FCB, closing new
; first if it was open.  In: caller A = old, X = new (via _Sys_SavedA/X).
; Out: A = new, C=1; or C=0 + A=EBADF (bad old / new out of range).
; MX:  %00 in/out.
;------------------------------------------------------------------------------
_Sys_Dup2       MX      %00
                ; range-check new
                LDA     _Sys_SavedX
                AND     #$00FF
                CMP     #FS_MAX_FDS
                BCC     @sd2_rangeOk
                LDA     #EBADF
                CLC
                RTS
@sd2_rangeOk    ; validate old
                SEP     #$20
                MX      %10
                LDA     _Sys_SavedA
                JSR     _Fcb_LookupPtr
                BCS     @sd2_oldOk
                REP     #$20
                MX      %00
                LDA     #EBADF
                CLC
                RTS
@sd2_oldOk      ; old == new -> no-op, return new
                LDA     _Sys_SavedA
                CMP     _Sys_SavedX             ; 8-bit (low byte) compare
                BNE     @sd2_diff
                REP     #$20
                MX      %00
                LDA     _Sys_SavedX
                AND     #$00FF
                SEC
                RTS
@sd2_diff       MX      %10                     ; runtime M here is 8 (the SEP at
                ; @sd2_rangeOk); Merlin's LINEAR state says 16, because the
                ; old==new arm just above widens and then RTSes.  An immediate
                ; between here and the next realignment would assemble at the
                ; wrong width.
                ; close new if currently open (probe via LookupPtr; clobbers _fcbPtr)
                LDA     _Sys_SavedX
                JSR     _Fcb_LookupPtr
                BCC     @sd2_newFree
                ; CLOSE IT, do not just drop a reference.  This was a bare
                ; _Fcb_Free, which decrements FCB_RefCount and Kfrees the FCB at
                ; zero while running NO teardown -- the socket, pipe and chardev
                ; arms all live in Fs_Close.  So
                ;
                ;     dup2(sock, B); close(sock); dup2(other, B)
                ;
                ; dropped the LAST reference to the socket here: the W5100 slot
                ; and the loopback rings leaked and the peer never saw EOF, and
                ; for a pipe the peer was never woken.  apple/fgx#131 made
                ; Fs_Close honour the refcount, which named Fs_Close as THE place
                ; the last reference dies; this was the one site where the count
                ; could reach zero somewhere else (apple/fgx#134).
                ;
                ; The result is discarded: dup2 does not report the close, and
                ; POSIX says the same.
                REP     #$20
                MX      %00
                LDA     _Sys_SavedX
                AND     #$00FF
                JSR     Fs_Close
                SEP     #$20
                MX      %10
@sd2_newFree    ; re-resolve old (helpers above clobbered _fcbPtr), then dup into new
                REP     #$20
                MX      %00
                LDA     _Sys_SavedA
                AND     #$00FF
                STA     _fdDupSrc               ; the file table is indexed by fd
                SEP     #$20
                MX      %10
                LDA     _Sys_SavedA
                JSR     _Fcb_LookupPtr          ; old still valid -> _fcbPtr
                LDA     _Sys_SavedX
                JSR     _Fd_Dup                 ; slot[new] = _fcbPtr; bump
                REP     #$20
                MX      %00
                LDA     _Sys_SavedX
                AND     #$00FF
                SEC
                RTS

;------------------------------------------------------------------------------
; _Sys_Sysctl (#117) - sysctl(2): the machdep node, kern.clockrate and
; kern.boottime in the tty bank, the vm node here, and every other name in the
; far bank's root_sysctl.  apple/fgx#410, apple/fgx#529.
;
; In:  A = caller-bank offset of libc's twelve-word argument block.  Six
;      arguments do not fit three registers, so the call arrives by reference
;      and each handler reads and writes the block IN PLACE, in the caller's
;      bank.  SYS_SELECT (99) is marshalled the same way.
; Out: C=1 and A=0, or C=0 and A=errno.
;
; THE CREDENTIAL IS READ HERE, which is the only reason this stub does more
; than push and call.  Upstream tests `suser()' and `u.u_procp->p_pid != 1'
; inside kern_sysctl (kern_sysctl.c:100 and :233); the far bank has no u-area
; to read, so the pid and the EFFECTIVE uid go across as arguments and the
; policy stays with the leaf.
;
; NO U-AREA MEANS ROOT, matching `_Sys_GetUid's @gu_root arm: pid 0 is the
; kernel bringing itself up and is not subject to its own mode bits.
;------------------------------------------------------------------------------
_Sys_Sysctl     MX      %00
                ; NAME[0] PICKS THE SUBSYSTEM, as 2.11BSD's __sysctl switches on
                ; it (kern_sysctl.c:112-135).  CTL_VM (2) is answered in this
                ; bank, where the counters, the tasks and the coremap are.  CTL_MACHDEP (7) is the kernel
                ; clock's, in the tty bank (tod_sysctl), which asks the uid
                ; itself, and so are kern.clockrate (CTL_KERN 1, KERN_CLOCKRATE
                ; 12) and kern.boottime (KERN_BOOTTIME 21), the clock's rate
                ; and its boot reading; everything else goes on to root_sysctl.
                PHB
                TAX                             ; the block's offset
                SEP     #$20
                MX      %10
                LDA     _Sys_CallerBank
                PHA
                PLB                             ; DBR = the caller's bank
                REP     #$20
                MX      %00
                LDA     |$0000,X                ; name[0]
                CMP     #7                      ; CTL_MACHDEP (h/sysctl.h:94)
                BEQ     @sc_tod
                CMP     #2                      ; CTL_VM (h/sysctl.h:89)
                BEQ     @sc_vm
                CMP     #1                      ; CTL_KERN
                BNE     @sc_notod
                LDA     |$0002,X                ; name[1]
                CMP     #12                     ; KERN_CLOCKRATE
                BEQ     @sc_tod
                CMP     #21                     ; KERN_BOOTTIME
                BEQ     @sc_tod
@sc_notod       PLB
                BRA     @sc_far
@sc_vm          PLB
                TXA
                JMP     _Sys_VmSysctl
@sc_tod         PLB
                TXA
                LDX     _Sys_CallerBank
_ktp104         JSL     KTTY_TOD_SYSCTL
                RTS
@sc_far         TXA
                ; root_sysctl(pid, uid, blk), fcc right to left: blk first.
                PHA                             ; park the block offset
                SEP     #$20
                MX      %10
                LDA     #0
                PHA                             ; blk: pad
                LDA     _Sys_CallerBank
                PHA                             ;      bank -- the CALLER's
                REP     #$30
                MX      %00
                ; 3,S AND NOT 5,S: PHA put the offset two bytes down, then the
                ; pad and bank bytes put two more on top of THOSE, so the
                ; parked word begins three bytes above S.  5,S reads past it
                ; into the caller's frame -- a clean build, a plausible
                ; pointer, and every call answering EINVAL because the block
                ; it read was not the block libc filled.  Measured.  The same
                ; arithmetic as `_Sys_Statfs' below, which parks a word the
                ; same way.
                LDA     3,S
                PHA                             ;      offset
                ; ...the effective uid.
                JSR     _Uarea_Cur
                BCC     @sc_root
                LDY     #U_Uid
                LDA     [_u],Y
                BRA     @sc_haveUid
@sc_root        LDA     #0
@sc_haveUid     PHA
                ; ...and the pid LAST, being the first argument.  `_curTask'
                ; and not `_Fcb_OwnerPid': there is no descriptor in this call,
                ; and the identity upstream tests is `u.u_procp->p_pid', which
                ; is the running process.
                LDA     _curTask
                AND     #$00FF
                PHA
_kfp995         JSL     KFAR_VFS_SYSCTL         ; slot 72; bank byte patched
                TAY                             ; park the errno; TSC needs A
                TSC
                CLC
                ADC     #10                     ; 8 argument bytes + the parked
                TCS                             ;   block offset word
                TYA
                BNE     @sc_err
                SEC                             ; A = 0, C = 1
                RTS
@sc_err         CLC
                RTS                             ; A = errno passthrough

;------------------------------------------------------------------------------
; _Sys_VmSysctl - sysctl(2)'s CTL_VM node: 2.11BSD's vm_sysctl
; (sys/kern_sysctl.c:423), with two leaves of FGX's own.
;
; In:  A = the block's offset in the caller's bank (layout: root_sysctl.c),
;      DBR = the kernel bank.
; Out: C=1 and A=0, or C=0 and A=errno.
;
;   VM_METER   1  struct vmtotal, computed when asked: upstream's `#ifdef
;                 notsure' arm, since FGX keeps no five-second copy.
;   VM_COREMAP 4  the coremap, NMAP {size, addr} pieces in pages (bank.s).
;   VM_SUM     5  FGX's: struct vmsum, the counters sched.s keeps.
;   VM_CPTIME  6  FGX's: long cp_time[CPUSTATES].
; 2.11BSD's vmstat reads `sum' and `cp_time' through /dev/kmem, which FGX
; does not have yet (apple/fgx#538); these two leaves serve them until it
; does.  VM_LOADAVG and VM_SWAPMAP answer EOPNOTSUPP: FGX keeps no load
; average and has no swap.
;
; THE CHECKS ARE UPSTREAM'S, IN ITS ORDER: a write needs the super user
; (__sysctl, :100), the name has 2..CTL_MAXNAME parts (:105), every name
; below CTL_VM is a leaf (vm_sysctl, ENOTDIR), and each leaf is a read-only
; structure through sysctl_rdstruct (:648): ENOMEM for an oldlen too small,
; EPERM for a new value, then the size and the copy.
;
; THE STRUCTURE GOES STRAIGHT TO THE CALLER'S oldp, block words 10 (offset)
; and 11 (bank), since it does not fit the block's 8 value bytes; oldp may be
; on the caller's stack, in another bank than the block.  SYSCTL_COPIED in
; the flags word tells libc so.  Every leaf is an even number of bytes, copied by words.
;------------------------------------------------------------------------------
VM_METER        EQU     1               ; h/vmparam.h:21
VM_COREMAP      EQU     4               ; h/vmparam.h:24
VM_SUM          EQU     5               ; FGX's, past 2.11BSD's VM_MAXID
VM_CPTIME       EQU     6
SYSCTL_OLDP     EQU     $0001           ; the block's flags word (libc)
SYSCTL_NEWP     EQU     $0002
SYSCTL_COPIED   EQU     $0004           ; out: the value is at oldp
VMT_SIZE        EQU     44              ; sizeof (struct vmtotal), sys/vmmeter.h
VMS_SIZE        EQU     56              ; sizeof (struct vmsum)
                ERR     VMS_SIZE-1/SYS_PATHBUF_MAX  ; both are built in _Sys_PathBuf

_Sys_VmSysctl   MX      %00
                STA     _libcTmp2               ; [_libcTmp2] = the block
                SEP     #$20
                MX      %10
                LDA     _Sys_CallerBank
                STA     _libcTmp2+2
                REP     #$20
                MX      %00
                LDY     #6
                LDA     [_libcTmp2],Y           ; flags
                AND     #SYSCTL_NEWP
                BEQ     @vm_len
                JSR     _Uarea_Cur              ; `!suser()'
                BCC     @vm_len                 ; no u-area: the kernel, root
                LDY     #U_Uid
                LDA     [_u],Y
                BEQ     @vm_len
@vm_eperm       LDA     #EPERM
                CLC
                RTS
@vm_len         LDY     #4
                LDA     [_libcTmp2],Y           ; namelen
                CMP     #12+1                   ; CTL_MAXNAME
                BCS     @vm_einval
                CMP     #2
                BCS     @vm_name
@vm_einval      LDA     #EINVAL
                CLC
                RTS
@vm_name        BEQ     @vm_leaf
                LDA     #ENOTDIR
                CLC
                RTS
@vm_leaf        LDY     #2
                LDA     [_libcTmp2],Y           ; name[1]
                CMP     #VM_METER
                BEQ     @vm_meter
                CMP     #VM_COREMAP
                BEQ     @vm_coremap
                CMP     #VM_SUM
                BEQ     @vm_sum
                CMP     #VM_CPTIME
                BEQ     @vm_cptime
                LDA     #ENOTSUP
                CLC
                RTS
@vm_coremap     LDX     #_coremap
                LDA     #KMem_Coremap_end-_coremap
                BRA     @vm_rdstruct
@vm_cptime      LDX     #_cp_time
                LDA     #CPUSTATES*4
                BRA     @vm_rdstruct
@vm_sum         ; struct vmsum: v_swtch, v_trap, v_syscall, v_intr, then ten
                ; counters FGX has no event for, all longs.
                JSR     _Vm_Zero
                LDA    |_vmSwtch
                STA     _Sys_PathBuf+0
                LDA    |_vmSwtch+2
                STA     _Sys_PathBuf+2
                LDA    |_vmSyscall
                STA     _Sys_PathBuf+8
                LDA    |_vmSyscall+2
                STA     _Sys_PathBuf+10
                LDA    |_vmIntr
                STA     _Sys_PathBuf+12
                LDA    |_vmIntr+2
                STA     _Sys_PathBuf+14
                LDX     #_Sys_PathBuf
                LDA     #VMS_SIZE
                BRA     @vm_rdstruct
@vm_meter       JSR     _Vm_Total
                LDX     #_Sys_PathBuf
                LDA     #VMT_SIZE

@vm_rdstruct    STA     _shTmp0                 ; len
                STX     _shTmp1                 ; source
                LDY     #6
                LDA     [_libcTmp2],Y           ; flags
                AND     #SYSCTL_OLDP
                BEQ     @vm_old
                LDY     #8
                LDA     [_libcTmp2],Y           ; *oldlenp
                CMP     _shTmp0
                BCS     @vm_old
                LDA     #ENOMEM                 ; `if (oldp && *oldlenp < len)'
                CLC
                RTS
@vm_old         LDY     #6
                LDA     [_libcTmp2],Y
                BIT     #SYSCTL_NEWP
                BEQ     @vm_ro
                LDA     #EPERM                  ; `if (newp) return (EPERM)'
                CLC
                RTS
@vm_ro          ORA     #SYSCTL_COPIED
                STA     [_libcTmp2],Y
                LDY     #8
                LDA     _shTmp0
                STA     [_libcTmp2],Y           ; `*oldlenp = len'
                LDY     #6
                LDA     [_libcTmp2],Y
                AND     #SYSCTL_OLDP
                BEQ     @vm_done                ; size only
                LDY     #22
                LDA     [_libcTmp2],Y           ; oldp's bank, word 11
                TAX
                LDY     #20
                LDA     [_libcTmp2],Y           ; oldp's offset, word 10
                STA     _libcTmp2
                SEP     #$20
                MX      %10
                TXA
                STA     _libcTmp2+2
                REP     #$20
                MX      %00
                LDX     _shTmp1
                LDY     #0
@vm_copy        LDA:    $0000,X                 ; `copyout(sp, oldp, len)'
                STA     [_libcTmp2],Y
                INX
                INX
                INY
                INY
                CPY     _shTmp0
                BCC     @vm_copy
@vm_done        LDA     #0
                SEC
                RTS

; _Vm_Zero - clear the larger of the two structures built in _Sys_PathBuf.
_Vm_Zero        MX      %00
                LDX     #VMS_SIZE-2
@vz_loop        STZ     _Sys_PathBuf,X
                DEX
                DEX
                BPL     @vz_loop
                RTS

;------------------------------------------------------------------------------
; _Vm_Total - 2.11BSD's vmtotal() (sys/vm_sched.c), into _Sys_PathBuf as a
; struct vmtotal (h/vmmeter.h), in pages, the coremap's unit:
;    +0 t_rq     +2 t_dw     +4 t_sl     +6 t_sw      (shorts)
;    +8 t_vm    +12 t_avm   +16 t_rm    +20 t_arm
;   +24 t_vmtxt +28 t_avmtxt +32 t_rmtxt +36 t_armtxt +40 t_free (kb)
; Everything past the shorts is 4 bytes: longs, and size_ts, which are 32
; bits on FGX (sys/types.h) where 2.11BSD's are 16.  The pool is at most a
; few hundred banks, so every page count fits a word and only t_vm and t_avm
; ever carry into theirs.
;
; A process's memory is its private banks, 256 pages each (TCB_BankList);
; upstream's is p_dsize + p_ssize + USIZE.  Text is the shared-text table's,
; added as upstream adds it.  Kernel tasks are skipped (SSYS) and zombies
; hold nothing.  Runnable tasks are t_rq; blocked and stopped ones are
; t_sl.  FGX keeps neither a sleep time nor a record of which sleeps are
; uninterruptible, so every process counts as active (avm = vm, arm = rm)
; and t_dw is 0; with no swap, t_sw is 0 and everything is resident.
; t_free is the coremap's free pages in kb: upstream's averaged `avefree'
; is not kept.
; Caller MX %00, DBR = the kernel bank.  Clobbers A/X/Y, _shTmp0/1.
;------------------------------------------------------------------------------
_Vm_Total       MX      %00
                JSR     _Vm_Zero
                LDX     #0
@vt_free        LDA     _coremap,X              ; size; 0 ends the map
                BEQ     @vt_procs
                CLC
                ADC     _Sys_PathBuf+40
                STA     _Sys_PathBuf+40
                INX
                INX
                INX
                INX
                BRA     @vt_free
@vt_procs       LSR     _Sys_PathBuf+40
                LSR     _Sys_PathBuf+40         ; pages / 4 = kb
                LDX     #FGX_TASK_TBL_OFF
@vt_proc        LDA:    TCB_Status,X
                BEQ     @vt_next                ; a free slot
                CMP     #TASK_ZOMBIE
                BEQ     @vt_next
                LDA:    TCB_Flags,X
                AND     #TFLAG_KERNEL           ; `if (p->p_flag & SSYS)'
                BNE     @vt_next
                LDA:    TCB_Status,X
                CMP     #TASK_BLOCKED
                BEQ     @vt_sl
                CMP     #TASK_STOPPED
                BEQ     @vt_sl
                INC     _Sys_PathBuf+0          ; t_rq
                BRA     @vt_mem
@vt_sl          INC     _Sys_PathBuf+4          ; t_sl
@vt_mem         TXA
                CLC
                ADC     #TCB_BankList
                TAY
                LDA     #8
                STA     _shTmp1
                STZ     _shTmp0
@vt_bank        LDA:    $0000,Y
                AND     #$00FF
                BEQ     @vt_bnext
                LDA     _shTmp0
                CLC
                ADC     #256
                STA     _shTmp0
@vt_bnext       INY
                DEC     _shTmp1
                BNE     @vt_bank
                LDA     _shTmp0
                CLC
                ADC     _Sys_PathBuf+16
                STA     _Sys_PathBuf+16         ; t_rm
                LDA     _shTmp0
                CLC
                ADC     _Sys_PathBuf+8
                STA     _Sys_PathBuf+8          ; t_vm
                BCC     @vt_next
                INC     _Sys_PathBuf+10
@vt_next        TXA
                CLC
                ADC     #TCB_SIZE
                TAX
                CPX     #FGX_TASK_TBL_OFF+{TASK_MAX_SLOTS*TCB_SIZE}
                BCC     @vt_proc
                LDA     _Sys_PathBuf+8          ; every process is active:
                STA     _Sys_PathBuf+12         ;   t_avm = t_vm
                LDA     _Sys_PathBuf+10
                STA     _Sys_PathBuf+14
                LDA     _Sys_PathBuf+16
                STA     _Sys_PathBuf+20         ;   t_arm = t_rm
_ktp127         JSL     KTTY_TEXT_TOTAL         ; A vmtxt, X avmtxt, Y armtxt
                STA     _Sys_PathBuf+24         ; t_vmtxt
                STA     _Sys_PathBuf+32         ; t_rmtxt
                STX     _Sys_PathBuf+28         ; t_avmtxt
                STY     _Sys_PathBuf+36         ; t_armtxt
                ; Upstream's tail: each total takes its text figure.
                CLC
                ADC     _Sys_PathBuf+8          ; t_vm += t_vmtxt
                STA     _Sys_PathBuf+8
                BCC     @vt_avm
                INC     _Sys_PathBuf+10
@vt_avm         TXA
                CLC
                ADC     _Sys_PathBuf+12         ; t_avm += t_avmtxt
                STA     _Sys_PathBuf+12
                BCC     @vt_rm
                INC     _Sys_PathBuf+14
@vt_rm          LDA     _Sys_PathBuf+32
                CLC
                ADC     _Sys_PathBuf+16         ; t_rm += t_rmtxt
                STA     _Sys_PathBuf+16
                TYA
                CLC
                ADC     _Sys_PathBuf+20         ; t_arm += t_armtxt
                STA     _Sys_PathBuf+20
                RTS

;------------------------------------------------------------------------------
; _Sys_Statfs (#114) - statfs(2): the filesystem a path lives on.
;
; In:  A = caller-bank offset of the path
;      X = caller-bank offset of a `struct statfs' (100 bytes)
; Out: C=1 and A=0, or C=0 and A=errno.
;
; NO LEGACY ARM.  Every other path syscall in this file tries the mounted root
; and FALLS THROUGH to the ProDOS resolver on a miss, because a machine whose
; boot volume was ProDOS had to keep working.  statfs(2) is new today and has
; never had a ProDOS answer to fall back to -- the thing it would have fallen
; back to is the volume table SYS_GETFSSTAT just stopped walking.
;
; THE STRUCT GOES STRAIGHT TO THE CALLER'S BANK, uncopied by this bank: see
; SYS_GETFSSTAT above and the slot comment in include/kfar.s.
;------------------------------------------------------------------------------
_Sys_Statfs     MX      %00
                PHX                             ; park the caller's sbp offset
                JSR     _Sys_CopyPathToBuf      ; A = path -> _Sys_PathBuf
                BCC     @sfs_plok
                PLX                             ; give back the parked sbp
                JMP     _Sys_PathTooLong
@sfs_plok
                ; root_statfs(pid, path, sbp), fcc right to left: sbp first.
                SEP     #$20
                MX      %10
                LDA     #0
                PHA                             ; sbp: pad
                LDA     _Sys_CallerBank
                PHA                             ;      bank -- the CALLER's
                REP     #$30
                MX      %00
                ; 3,S AND NOT 5,S: PHX put two bytes down, then the pad and
                ; bank bytes put two more on top of them, so the parked word
                ; is at 3,S.  5,S reads past it into the caller's frame -- a
                ; clean build, a plausible pointer, and nothing written where
                ; the caller looks.  The same arithmetic as _Sys_GetfsStat
                ; below, which parks a word the same way.
                LDA     3,S                     ;      offset (the parked X)
                PHA
                ; ...then the path, which lives in THIS bank -- PHK, not the
                ; caller's bank, because CopyPathToBuf staged it here.
                SEP     #$20
                MX      %10
                LDA     #0
                PHA                             ; path: pad
                PHK                             ;       bank
                REP     #$30
                MX      %00
                LDA     #_Sys_PathBuf
                PHA                             ;       offset
                ; AND THE pid LAST, BEING THE FIRST ARGUMENT.  _Fcb_OwnerPid
                ; and not _curTask, for the reason _Fs_RootStat gives: a
                ; service running inside spawn is about the CHILD.
                JSR     _Fcb_OwnerPid
                PHA
_kfp979         JSL     KFAR_VFS_ROOTSTATFS     ; bank byte patched by Far_Init
                TAY                             ; park the errno; TSC needs A
                TSC
                CLC
                ADC     #12                     ; 10 argument bytes + the parked
                TCS                             ;   sbp offset word
                TYA
                BNE     @sfs_err
                SEC                             ; A = 0, C = 1
                RTS
@sfs_err        CLC
                RTS                             ; A = errno passthrough

;------------------------------------------------------------------------------
; _Sys_GetfsStat (#67) - a struct statfs for every mounted filesystem.
;
; In:  A = caller-bank offset of the struct statfs[] buffer (0 to just count)
;      X = bufsize in BYTES (not entries)
;      Y = flags (accepted and ignored -- see getfsstat(2) BUGS)
; Out: C=1, A = number of mounts written, or the total when A was 0 on entry.
;
; IT ENUMERATES THE FILESYSTEM MOUNT LIST, which is not the SmartPort volume
; table (`_fsMountTable').  On a machine whose root is UFS that table is empty,
; so a handler reading it answers zero mounts having done everything correctly
; -- every layer reports success and df(1) prints nothing (apple/fgx#329).
;
; THE STRUCT IS 4.3BSD-Reno's, 100 bytes: the declaration the kernel carries in
; src/kernel/vfs/mount.h and the one userland gets from <sys/mount.h>.
; tools/check_statfs_layout.py compares the two.
;
; NOTHING IS STAGED IN THIS BANK.  The buffer is the caller's and the far bank
; writes it directly through uio_copy's MVN; a core-bank scratch would have
; cost 100 bytes of a bank with a few hundred free.  So the whole handler is
; the argument push and one JSL.
;
;------------------------------------------------------------------------------
_Sys_GetfsStat  MX      %00
                ; vfs_getfsstat(sbp, bufsize), fcc right to left: bufsize first.
                PHX                             ; bufsize (int)
                ; ...then the far pointer, offset last of the four bytes pushed
                ; so it lands lowest.  THE BANK IS THE CALLER'S, not PHK: this
                ; buffer belongs to the process that made the call.
                PHA                             ; park the offset
                SEP     #$20
                MX      %10
                LDA     #0
                PHA                             ; sbp: pad
                LDA     _Sys_CallerBank
                PHA                             ;      bank
                REP     #$30
                MX      %00
                LDA     3,S                     ;      offset (the parked copy)
                PHA
_kfp980         JSL     KFAR_VFS_GETFSSTAT      ; bank byte patched by Far_Init
                TAY                             ; park the count; TSC needs A
                TSC
                CLC
                ADC     #8                      ; 6 argument bytes + the parked
                TCS                             ;   offset word
                TYA
                SEC                             ; the handler does not fail
                RTS


;------------------------------------------------------------------------------
; Slot-scan record layout (shared with uthernet.s for Pass 2).
;------------------------------------------------------------------------------
SLREC_SZ        EQU     7                       ; _slotTab record size: flags + sig[6]
SLF_OCCUPIED    EQU     $01
SLF_W5100       EQU     $02
SLF_HASROM      EQU     $04
SLF_BOUND       EQU     $08                     ; (a later task sets; unused here)

;------------------------------------------------------------------------------
; _Sys_SlotScan (#90) - copy the boot slot-scan table into the caller's buffer.
;   In:  A = caller-bank offset of the buffer, X = bufsize bytes.
;   Out: C=1, A = bytes written (SLOTSCAN_WIRE=50), or A=0 if bufsize < 50.
;   Wire: [0]=_u2Slot; [1..49]=_slotTab (7 x {flags, sig[6]}).
; Runs DBR=kernel-bank, kernel DP; caller's data bank in _Sys_CallerBank.
;------------------------------------------------------------------------------
SLOTSCAN_WIRE   EQU     50                      ; 1 + 7*7
_Sys_SlotScan   MX      %00
                CPX     #SLOTSCAN_WIRE
                BCS     @ss_room
                LDA     #0                      ; buffer too small -> 0 written
                SEC
                RTS
@ss_room        STA     _libcTmp2               ; dst offset
                SEP     #$20
                MX      %10
                LDA     _Sys_CallerBank
                STA     _libcTmp2+2             ; dst long ptr = callerbank:offset
                ; byte 0 = detected slot
                LDY     #0
                LDA     |_u2Slot
                STA     [_libcTmp2],Y
                ; bytes 1..49 = _slotTab (X = src 0..48, Y = dst 1..49)
                LDX     #0
@ss_cp          CPX     #SLREC_SZ*7
                BCS     @ss_done
                LDA     |_slotTab,X
                INY
                STA     [_libcTmp2],Y
                INX
                BRA     @ss_cp
@ss_done        REP     #$30
                MX      %00
                LDA     #SLOTSCAN_WIRE
                SEC
                RTS

;------------------------------------------------------------------------------
; _Sys_GetPid (#20) - return current task's pid in A.
; If no user task is running (_curTask = 0), return 0.
;
; _curTask stores the pid directly (despite the older task.s comment
; that says "TCB offset" — main.s line 281 and process.s lines 278/362
; all STA a pid value).  Just return it.
;------------------------------------------------------------------------------
_Sys_GetPid     MX      %00
                LDA     _curTask
                AND     #$00FF
                SEC
                RTS

;------------------------------------------------------------------------------
; _Sys_GetUid (#24) - return the calling process's REAL uid in A (16-bit).
;
; Real, not effective: 2.11BSD's getuid(2) returns the real id and geteuid(2)
; the effective one.  Nothing can make them differ yet (setuid is P2), but
; reading the right field now means P2 changes no code here.
;
; P1 (2026-07-28): reads the per-task u-area instead of the old machine-wide
; _kProcUid global.  A boot-context caller (_curTask == 0) or a task without a
; u-area gets 0 (root) — the same answer the global gave.
;
; NUMBERING: 24 is 2.11BSD's getuid, per this file's convention (loader.s:131).
; Was 21 until 2026-07-28; 21/22 are BSD's mount/umount and are now reserved for
; the UFS campaign's mount(2).  The move was free: nothing called 21/22 (libc's
; getuid() was a compiled-in `return 0` that never issued the syscall).
;------------------------------------------------------------------------------
; P2: returns BOTH ids — A = real, Y = effective — which is exactly what V7 /
; 2.11BSD's getuid(2) does (r0 = real, r1 = effective).  That is why no
; SYS_GETEUID number exists: libc's geteuid() issues this same call and reads
; the Y return (__syscall_y), the way lseek/waitpid/sbrk already do.  Before
; setuid landed, geteuid() could delegate to getuid() because the two could
; never differ; now they can.
_Sys_GetUid     MX      %00
                JSR     _Uarea_Cur
                BCC     @gu_root
                LDY     #U_Uid
                LDA     [_u],Y
                TAX                             ; stash effective
                LDY     #U_Ruid
                LDA     [_u],Y                  ; A = real
                PHA
                TXA
                TAY                             ; Y = effective
                PLA
                SEC
                RTS
@gu_root        LDA     #0
                TAY                             ; real = effective = 0
                SEC
                RTS

;------------------------------------------------------------------------------
; _Sys_RlimEntry - resolve A = RLIMIT_* index to _Sys_RlimOff, and stage the
; caller's struct rlimit * from Y (offset) + _Sys_CallerBank into _Sys_RlimPtr.
;
; Shared by both rlimit syscalls, which differ only in copy direction.  Out:
; C=1 and both staged, or C=0 + A = errno (EINVAL for a limit this build has no
; slot for, EFAULT for a null pointer).  MX %00.  Clobbers A, Y.
;
; The bound is U_RLIM_NLIMITS, not the caller's idea of it: a userland built
; against a header with more limits than this kernel stores must be REFUSED,
; not quietly given a neighbouring entry.  credprobe walks to the header's
; RLIM_NLIMITS precisely to catch the two counts drifting apart.
;------------------------------------------------------------------------------
_Sys_RlimEntry  MX      %00
                STY     _Sys_RlimPtr            ; caller ptr arrives in Y, the
                                                ;   same slot _Sys_Ioctl takes
                                                ;   its arg pointer in
                CMP     #U_RLIM_NLIMITS
                BCC     @rle_inrange
                LDA     #EINVAL
                CLC
                RTS
@rle_inrange    ; offset = U_Rlimit + index*8
                ASL
                ASL
                ASL
                CLC
                ADC     #U_Rlimit
                STA     _Sys_RlimOff
                SEP     #$20
                MX      %10
                LDA     _Sys_CallerBank
                STA     _Sys_RlimPtr+2
                REP     #$20
                MX      %00
                LDA     _Sys_RlimPtr            ; a null pointer is EFAULT, not
                BNE     @rle_ok                 ;   a fault -- the same answer
                LDA     #EFAULT                 ;   libc's own stub gave
                CLC
                RTS
@rle_ok         SEC
                RTS

;------------------------------------------------------------------------------
; _Sys_RlimStage - copy the parked caller pointer into _libcTmp2 for [ptr],Y.
;
; SEPARATE, AND CALLED LATE, ON PURPOSE.  Long-indirect addressing needs a
; DIRECT PAGE pointer and the direct page is full, so the caller's buffer is
; reached through _libcTmp2 -- the transient scratch every syscall already uses
; for exactly this (see _Sys_Ioctl's FIONREAD arm).  That is what it is for,
; but only while nothing else runs.  Both callers resolve the u-area FIRST and
; call this AFTER, so the scratch is live only across the copy loop with no
; subroutine call inside it.  Holding it across a call is a different thing and
; is how a scratch cell stops being scratch.
; MX %00.  Clobbers A.
;------------------------------------------------------------------------------
_Sys_RlimStage  MX      %00
                LDA     _Sys_RlimPtr
                STA     _libcTmp2
                LDA     _Sys_RlimPtr+2
                STA     _libcTmp2+2
                RTS

;------------------------------------------------------------------------------
; _Sys_GetRlimit (#105) - copy this process's limit `A` into *Y.
; In: A = RLIMIT_*, Y = struct rlimit * offset, caller bank = DBR at entry.
; Out: A = 0, C=1; or A = errno, C=0.  See loader.s for why this is not
; 2.11BSD's 144.
;
; EIGHT BYTES, COPIED AS FOUR WORDS.  rlim_cur then rlim_max, in the struct's
; own order -- there is no marshalling to get wrong because the u-area holds
; them in exactly the layout userland declares.
;------------------------------------------------------------------------------
_Sys_GetRlimit  MX      %00
                JSR     _Sys_RlimEntry
                BCS     @grl_go
                RTS                             ; A = errno, C=0
@grl_go         JSR     _Uarea_Cur
                BCC     @grl_nouarea
                JSR     _Sys_RlimStage          ; scratch goes live HERE -- see it
                LDX     #0                      ; X = byte index within the entry
@grl_L          TXA
                CLC
                ADC     _Sys_RlimOff
                TAY
                LDA     [_u],Y                  ; u-area word
                PHA
                TXA
                TAY
                PLA
                STA     [_libcTmp2],Y        ; caller's word
                INX
                INX
                CPX     #U_RLIM_ENTLEN
                BCC     @grl_L
                LDA     #0
                SEC
                RTS
; No u-area is the boot context, which has no limits to report.  Answer
; "unlimited" rather than an error, the same shape _Sys_GetUid uses when it has
; no u-area: the neutral value, not a failure a caller must handle.
@grl_nouarea    JSR     _Sys_RlimStage
                LDY     #0
                LDA     #$FFFF
                STA     [_libcTmp2],Y
                LDY     #4
                STA     [_libcTmp2],Y
                LDY     #2
                LDA     #$7FFF
                STA     [_libcTmp2],Y
                LDY     #6
                STA     [_libcTmp2],Y
                LDA     #0
                SEC
                RTS

;------------------------------------------------------------------------------
; _Sys_SetRlimit (#106) - store *Y into this process's limit `A`.
;
; STORED, AND ENFORCED WHERE THERE IS SOMETHING TO ENFORCE.  RLIMIT_DATA is
; read by _Sys_Brk (process.s), the break path Reno checks at kern_mman.c:342;
; RLIMIT_FSIZE's reader arrives with the UFS write path.  The rest are storage,
; which is what makes `limit`/`ulimit` in a shell report back what they were
; told -- see the slot list in include/kernel.s for which is which.
;
; NO PERMISSION CHECK, and that is a DEVIATION worth naming: BSD lets only root
; raise rlim_max, and refuses any process that tries to raise its hard limit
; (Reno kern_resource.c).  Now that RLIMIT_DATA is enforced there IS something
; to protect, and the guard belongs here -- apple/fgx#400 holds it.
;------------------------------------------------------------------------------
_Sys_SetRlimit  MX      %00
                JSR     _Sys_RlimEntry
                BCS     @srl_go
                RTS
@srl_go         JSR     _Uarea_Cur
                BCC     @srl_nouarea
                JSR     _Sys_RlimStage
                LDX     #0
@srl_L          TXA
                TAY
                LDA     [_libcTmp2],Y        ; caller's value
                PHA
                TXA
                CLC
                ADC     _Sys_RlimOff
                TAY
                PLA
                STA     [_u],Y                  ; into the u-area
                INX
                INX
                CPX     #U_RLIM_ENTLEN
                BCC     @srl_L
@srl_nouarea    LDA     #0                      ; boot context: accept, discard
                SEC
                RTS

;------------------------------------------------------------------------------
; _Sys_Umask (#104) - set the file-creation mask, return the previous one.
;
; In: A = new mask.  Out: A = the mask that was in force, C=1.  Never fails.
;
; THE MASK MOVED FROM LIBC TO THE KERNEL, and that is the whole point of the
; syscall.  libc kept it in a static, which meant it did not survive exec and
; the kernel could not see it -- so nothing could ever APPLY it.  BSD keeps it
; in the u-area for both reasons: it inherits across fork, survives exec (no
; exec path in either ancestor touches u_cmask), and is read by every creating
; syscall -- open, creat, mknod, mkfifo, symlink, mkdir (Reno
; vfs_syscalls.c:560, 657, 709, 805, 1518).
;
; NOTHING APPLIES IT YET, and saying so is part of shipping it: FGX's current
; file creation runs through ProDOS, which has no permission bits to mask.  The
; apply sites arrive with the UFS write path.  What this delivers now is the
; storage, with the right lifetime -- which is what the ports will read.
;
; Masked to 07777, as both ancestors do (2.11BSD ufs_syscalls2.c:205, Reno
; vfs_syscalls.c:1635).  libc's old static masked to 0777 and so dropped the
; setuid/setgid/sticky bits from a mask that named them.
;------------------------------------------------------------------------------
_Sys_Umask      MX      %00
                AND     #$0FFF                  ; new & 07777
                TAX                             ; stash it; _Uarea_Cur needs A
                JSR     _Uarea_Cur
                BCC     @um_nouarea
                LDY     #U_Cmask
                LDA     [_u],Y                  ; A = the previous mask
                PHA
                TXA
                STA     [_u],Y
                PLA
                SEC
                RTS
; No u-area means no per-process state to report, which is the same answer
; _Sys_GetUid gives in the same situation: the neutral value, not an error.
; umask(2) has no failure return in any BSD -- it cannot fail -- so inventing
; one here would be a shape no caller checks for.
@um_nouarea     LDA     #0
                SEC
                RTS

;------------------------------------------------------------------------------
; _Sys_ApplyCmask - remove the file-creation mask.  In: A = the mode asked for.
; Out: A = the mode to create with.  Clobbers X, Y.  Never fails.
;
; THE APPLY SITE _Sys_Umask's HEADER PROMISED.  That routine shipped the
; storage in 2.6 and said in as many words that "nothing applies it yet ...
; the apply sites arrive with the UFS write path".  The write path arrived and
; the apply sites did not, so every process has carried a mask no creating
; syscall ever read.
;
; IT BELONGS IN THE SYSCALL LAYER AND NOT IN THE FILESYSTEM, which is where
; both ancestors put it: 4.3BSD-Reno masks in kern/vfs_syscalls.c -- open at
; :559 (`cmode = ((uap->crtmode &~ u.u_cmask) & 07777) &~ S_ISVTX') and mkdir
; at :1518 (`vattr.va_mode = (uap->dmode & 0777) &~ u.u_cmask') -- never in
; ufs/.  The mask lives in the u-area, which is this bank's; vfs.mod would
; have to reach back across the seam to read it.
;
; THE TWO CALLERS KEEP DIFFERENT WIDTHS and that asymmetry is upstream's:
; open keeps 07777 and clears the sticky bit, mkdir keeps 0777.  Each does its
; own AND; this routine only removes the mask.
;
; No u-area means no mask, which is _Sys_Umask's own answer in the same
; situation: the neutral value, not an error.
;------------------------------------------------------------------------------
_Sys_ApplyCmask MX      %00
                TAX                             ; park the mode; _Uarea_Cur needs A
                JSR     _Uarea_Cur
                BCC     @ac_nomask
                LDY     #U_Cmask
                LDA     [_u],Y                  ; A = the mask in force
                EOR     #$FFFF                  ; ~mask
                PHA
                TXA
                AND     1,S                     ; mode &~ mask
                PLY                             ; drop ~mask; Y is dead here
                RTS
@ac_nomask      TXA                             ; the mode exactly as asked
                RTS

;------------------------------------------------------------------------------
; _Sys_GetGid (#47) - return the calling process's REAL gid in A (16-bit).
; Same u-area sourcing, real-vs-effective reasoning and numbering history as
; _Sys_GetUid (was 22).  47 is 2.11BSD's getgid.  (BSD's setgid=46 is already
; spent on SYS_VFORK, so setgid lands FGX-local when the set*id family arrives.)
;------------------------------------------------------------------------------
_Sys_GetGid     MX      %00
                JSR     _Uarea_Cur
                BCC     @gg_root
                LDY     #U_Gid
                LDA     [_u],Y
                TAX                             ; stash effective
                LDY     #U_Rgid
                LDA     [_u],Y                  ; A = real
                PHA
                TXA
                TAY                             ; Y = effective
                PLA
                SEC
                RTS
@gg_root        LDA     #0
                TAY
                SEC
                RTS

;------------------------------------------------------------------------------
; _Sys_GetLogin (#118) / _Sys_SetLogin (#119) - the SESSION's login name.
;
; 2.11BSD usr/sys/sys/kern_prot.c:165-213, ported whole.  getlogin copies
; u_login out to the caller's buffer, capped at its own size:
;
;       if (uap->namelen > sizeof (u.u_login))
;               uap->namelen = sizeof (u.u_login);
;       error = copyout(u.u_login, uap->namebuf, uap->namelen);
;
; and setlogin is super-user only, with upstream's reason given in as many
; words at :181-186: "It is not clear whether this should be allowed if the
; process is not the `session leader' (the `login' process).  But since 2.11
; doesn't have sessions and it's almost impossible to know if a process is
; `login' or not we simply restrict this call to the super user."  FGX has no
; sessions either, so it takes the same rule rather than inventing one.
;
; WHY THIS IS A SYSCALL AND NOT A LIBRARY TRICK.  The name belongs to the
; SESSION and must outlive a change of identity -- getlogin(2)'s manual says
; so: "inherited by all processes descended from the login shell.  (This is
; true even if some of those processes assume another user ID, for example when
; su(1) is used.)"  Nothing derivable from the caller can answer that: the
; passwd entry for the current uid changes under su, which is the one case the
; manual calls out, and an /etc/utmp record is keyed by TERMINAL, so a process
; with no controlling tty among its first three descriptors has none to find.
; The u-area is the only place that survives fork, exec and setuid together.
;
; THE NAME IS NOT NECESSARILY NUL-TERMINATED, which is upstream's shape:
; sixteen characters fill u_login exactly.  setlogin zero-fills first and
; copies at most U_LOGIN_LEN, so a short name is padded and a long one is
; truncated; getlogin hands back bytes and libc's buffer is one longer than it
; ever asks for, so the terminator is the one it was born with.
;
; Args:    getlogin  A = dst offset in caller's bank, X = size
;          setlogin  A = name offset in caller's bank (NUL-terminated)
; Returns: getlogin  C=1 + A = bytes placed (0 = no name set)
;          setlogin  C=1 + A = 0, or C=0 + A = EPERM
;------------------------------------------------------------------------------
_slDst          DA      0
_slCnt          DA      0

_Sys_GetLogin   MX      %00
                STA     _slDst
                STX     _slCnt
                JSR     _Uarea_Cur
                BCC     @sgl_none               ; no u-area: no name
                LDA     _slCnt
                CMP     #U_LOGIN_LEN+1
                BCC     @sgl_cap
                LDA     #U_LOGIN_LEN
@sgl_cap        STA     _slCnt
                BEQ     @sgl_done               ; asked for nothing
                LDA     _slDst
                STA     _libcTmp2
                SEP     #$20
                MX      %10
                LDA     _Sys_CallerBank
                STA     _libcTmp2+2
                REP     #$20
                MX      %00
                LDY     #0
@sgl_copy       CPY     _slCnt
                BCS     @sgl_done
                PHY
                TYA
                CLC
                ADC     #U_Login
                TAY
                SEP     #$20
                MX      %10
                LDA     [_u],Y                  ; the u-area byte
                STA     [_libcTmp2]             ; into the caller's bank
                REP     #$20
                MX      %00
                PLY
                INC     _libcTmp2
                INY
                BRA     @sgl_copy
@sgl_done       LDA     _slCnt
                SEC
                RTS
@sgl_none       LDA     #0
                SEC
                RTS

_Sys_SetLogin   MX      %00
                STA     _slDst                  ; the caller's string
                JSR     _Suser
                BCC     @ssl_perm
                JSR     _Uarea_Cur
                BCC     @ssl_perm               ; nobody's name to write
                LDA     _slDst
                STA     _libcTmp2
                SEP     #$20
                MX      %10
                LDA     _Sys_CallerBank
                STA     _libcTmp2+2
                REP     #$20
                MX      %00
                ; ZERO FIRST, then copy up to the cap and stop at the NUL --
                ; upstream bzero's a temporary and bcopy's the whole field, so
                ; a short name leaves no tail of the previous one behind.
                LDY     #0
@ssl_zero       CPY     #U_LOGIN_LEN
                BCS     @ssl_copy0
                PHY
                TYA
                CLC
                ADC     #U_Login
                TAY
                SEP     #$20
                MX      %10
                LDA     #0
                STA     [_u],Y
                REP     #$20
                MX      %00
                PLY
                INY
                BRA     @ssl_zero
@ssl_copy0      LDY     #0
@ssl_copy       CPY     #U_LOGIN_LEN
                BCS     @ssl_done
                SEP     #$20
                MX      %10
                LDA     [_libcTmp2]
                REP     #$20
                MX      %00
                AND     #$00FF
                BEQ     @ssl_done               ; the NUL: the rest stays zero
                PHY
                PHA
                TYA
                CLC
                ADC     #U_Login
                TAY
                PLA
                SEP     #$20
                MX      %10
                STA     [_u],Y
                REP     #$20
                MX      %00
                PLY
                INC     _libcTmp2
                INY
                BRA     @ssl_copy
@ssl_done       LDA     #0
                SEC
                RTS
@ssl_perm       LDA     #EPERM
                CLC
                RTS

;------------------------------------------------------------------------------
; _Suser - is the current task privileged?  Out: C=1 = root, C=0 = not.
; Clobbers A, Y.  MX %00.
;
; Privilege is the EFFECTIVE uid, not the real one — that is the whole point of
; an effective id, and it is what a future setuid binary would raise.
;
; A task with no u-area (boot context, _curTask == 0) is treated as PRIVILEGED:
; that is kernel context, which has always been able to do anything.  Note the
; asymmetry with _Cred_Set below, which treats "no u-area" as EPERM — there the
; question is "whose credentials would I even be writing?", and the answer is
; nobody's.
;
; This is the single chokepoint every future enforcement site should call
; (plan §2.6), so P6 has one predicate to audit rather than N open-coded
; comparisons against uid 0.
;------------------------------------------------------------------------------
_Suser          MX      %00
                JSR     _Uarea_Cur
                BCC     @su_yes                 ; no u-area = kernel context
                LDY     #U_Uid
                LDA     [_u],Y
                BEQ     @su_yes
                CLC
                RTS
@su_yes         SEC
                RTS

;------------------------------------------------------------------------------
; _Cred_Set - shared core for setuid/setgid/seteuid/setegid (#23/25/26/27).
;
; In:  _credNewId  = the id to set
;      _credBase   = u-area offset of the triple's REAL field (U_Ruid/U_Rgid);
;                    effective is +U_CRED_EFF, saved-set is +U_CRED_SAVED
;      _credEffOnly= 0 -> set*id semantics, 1 -> sete*id semantics
; Out: C=1 + A=0 on success; C=0 + A=EPERM if not permitted.  MX %00.
;
; POSIX rule (4.3BSD+), not V7's:
;   root            -> set*id sets all three; sete*id sets effective only
;   non-root        -> permitted only if the new id equals the REAL or the
;                      SAVED-SET id, and then ONLY the effective id moves
;   otherwise       -> EPERM
;
; The saved-set clause is what lets a process drop privilege and regain it,
; and it is live: exec adopts a set-id image's owner into the EFFECTIVE id and
; rewrites the saved set from it (_Ev_CredOnExec, process.s), so a setuid
; program runs with real != effective and may move between the two.  su(1) is
; the caller that depends on both halves -- it keeps the real uid of the person
; who typed it, which is how it knows to demand a password, while holding root
; effectively.
;------------------------------------------------------------------------------
_Cred_Set       MX      %00
                STA     _credNewId
                STX     _credBase
                STY     _credEffOnly
                JSR     _Uarea_Cur
                BCC     @cs_perm                ; no u-area -> nothing to set
                JSR     _Suser                  ; reloads _u (same task) — fine
                BCS     @cs_root
                ; --- non-root: new id must match real or saved-set ---
                LDY     _credBase               ; +U_CRED_REAL
                LDA     [_u],Y
                CMP     _credNewId
                BEQ     @cs_setEff
                LDA     _credBase
                CLC
                ADC     #U_CRED_SAVED
                TAY
                LDA     [_u],Y
                CMP     _credNewId
                BEQ     @cs_setEff
@cs_perm        LDA     #EPERM
                CLC
                RTS
@cs_root        ; --- root: sete*id still moves the effective id only ---
                LDA     _credEffOnly
                BNE     @cs_setEff
                LDY     _credBase               ; real = new
                LDA     _credNewId
                STA     [_u],Y
                LDA     _credBase
                CLC
                ADC     #U_CRED_SAVED
                TAY
                LDA     _credNewId
                STA     [_u],Y                  ; saved-set = new
                ; fall through — effective moves in every permitted case
@cs_setEff      LDA     _credBase
                CLC
                ADC     #U_CRED_EFF
                TAY
                LDA     _credNewId
                STA     [_u],Y
                LDA     #0
                SEC
                RTS

;------------------------------------------------------------------------------
; setuid(2) #23 / setgid(2) #25 / seteuid(2) #26 / setegid(2) #27.
; A = new id.  Thin shims over _Cred_Set; see its header for the rule.
;
; 23 is 2.11BSD's setuid.  setgid does NOT get BSD's 46 — that number was
; already spent on FGX-local SYS_VFORK — so it takes 25, keeping the credential
; block contiguous at 23..27 around getuid's 24.
;------------------------------------------------------------------------------
_Sys_SetUid     MX      %00
                LDX     #U_Ruid
                LDY     #0
                BRL     _Cred_Set

_Sys_SetGid     MX      %00
                LDX     #U_Rgid
                LDY     #0
                BRL     _Cred_Set

_Sys_SetEuid    MX      %00
                LDX     #U_Ruid
                LDY     #1
                BRL     _Cred_Set

_Sys_SetEgid    MX      %00
                LDX     #U_Rgid
                LDY     #1
                BRL     _Cred_Set

;------------------------------------------------------------------------------
; _Sys_GetPpid (#39) - return parent's pid in A.  _curTask is the pid;
; convert to TCB offset via Task_Lookup, then read TCB_ParentID.
;------------------------------------------------------------------------------
_Sys_GetPpid    MX      %00
                LDA     _curTask
                AND     #$00FF
                BEQ     @gpp_zero
                JSR     Task_Lookup
                BCC     @gpp_zero
                LDA:     TCB_ParentID,X
                AND     #$00FF
                SEC
                RTS
@gpp_zero       LDA     #0
                SEC
                RTS

; _Sys_Exit (#1) and _Sys_Wait (#7) live in src/kernel/process.s now.

;------------------------------------------------------------------------------
; _Sys_Write (#4) - A = fd, X = buf (16-bit, in caller's bank), Y = count.
; _Sys_Writev (#123) - A = fd, X = the iovec array (caller's bank), Y = iovcnt.
;
; _Sys_Read's shape, writing: build the task's uio, then _Sys_WrUio looks up
; fd -> FCB and hands it to the descriptor's FO_WRITE once -- a vnode crosses
; to the far bank, a socket or a pipe runs its arm here.  One fo_write for a
; whole vector is what keeps another writer from landing between its entries.
; Bad fd / empty slot -> EBADF.
;
; Returns: A = count, C=1 on success.  A mid-stream failure returns the SHORT
; COUNT with C=1 whenever any byte landed, and C=0 + A=errno only when none did
; (apple/fgx#106, matching Fs_WriteN and POSIX).
;------------------------------------------------------------------------------
_Sys_Writev     MX      %00
                AND     #$00FF
                STA     _Sys_WrFd
                LDA     #UIO_WRITE
                JSR     _Sys_UioVec             ; C=0 + A = EINVAL
                BCS     _Sys_WrUio
                RTS

_Sys_Write      MX      %00
                AND     #$00FF
                STA     _Sys_WrFd               ; fd (Fs_Write's lookup clobbers
                                                ; _shTmp0/1/2 internally — use
                                                ; dedicated kernel-bank statics)
                STX     _Sys_WrBufOff           ; caller-bank buf offset
                STY     _Sys_WrMax              ; total byte count (return value)
                STY     _Sys_WrRem              ; running counter
                TXA                             ; A = buffer
                TYX                             ; X = count
                LDY     #UIO_WRITE
                JSR     _Sys_UioOne             ; u.u_ttyuio: one entry
_Sys_WrUio      MX      %00                     ; writev(2) joins here
                SEP     #$20
                MX      %10
                LDA     _Sys_WrFd
                JSR     _Fcb_LookupPtr          ; sets _fcbPtr or returns EBADF
                BCS     @sw_haveFcb
                REP     #$20
                MX      %00
                LDA     #EBADF
                CLC
                RTS
@sw_haveFcb     MX      %10
                LDY     #FCB_Flags
                LDA     [_fcbPtr],Y
                ; TYPE DISPATCH (UFS 1.2a-4).  This routine asked what kind of
                ; descriptor it had FOUR TIMES: two masks stored as booleans,
                ; then TWO MORE re-reads of FCB_Flags -- each with its own
                ; SEP/REP pair -- to test SOCKET and then PIPE.  Three loads of
                ; the same byte through the same pointer, and four chances for
                ; the answers to disagree.
                ;
                ; Now: one read, one classification, one branch chain over the
                ; result.  Both of those statics are gone now: the type lives
                ; on the descriptor as f_type, which is where BSD keeps it.
                ; THE CHARDEV CACHING MOVED INTO THE CHARDEV ARM -- UFS 1.7d
                ; I2c.  _Sys_WrCdIdx is a chardev-only value, and classifying
                ; here to decide whether to compute it meant asking the type of
                ; every descriptor on every write to answer a chardev question.
                ; _Sys_WrType went with it; nothing read it.
@sw_notCd       REP     #$30                    ; restore M=0 AND X=0
                MX      %00
                ; DISPATCH THROUGH f_ops ON THE DESCRIPTOR.  The arm comes off
                ; the descriptor itself, and `_Fcb_OpEntry' is the one place
                ; that knows how to get it.  The arms find the uio in the
                ; u-area (_Sys_UUio).
                LDA     _Sys_WrFd
                AND     #$00FF
                LDX     #FO_WRITE
                JSR     _Fcb_OpEntry
                BCC     @sw_notArm
                DEC                             ; RTS resumes at the address
                PHA                             ;   AFTER the one it pops
                RTS                             ; -> the arm, in this bank

                ; FAR-BANK OPS: the whole write crosses -- UFS 1.7d I3.  See
                ; the matching note at the read site; the reason is the same
                ; and the tail-jump contract is the same.
@sw_notArm      LDA     _fdOpsFar
                BEQ     @sw_noops
                LDA     _Sys_WrFd
                AND     #$00FF
                JMP     _Sys_DevUio

                ; No f_ops means no descriptor this kernel made: every fd in
                ; the table has a `struct file', and boot asserts the two
                ; tables agree.  EBADF rather than a guess.
@sw_noops       SEP     #$20
                MX      %10
                LDA     #EBADF
                STA     _errno
                REP     #$30
                MX      %00
                LDA     #EBADF
                CLC
                RTS

; rename(2), truncate(2) and utimes(2) are the VFS's; there is no legacy write
; path behind them (apple/fgx#343).
;
; AN UNIMPLEMENTED CALL ANSWERS ENOSYS AND NOT EIO: ENOSYS is the honest
; reading, where EIO would say the filesystem tried and failed.


_WrOp_Socket      ; FCB_FL_SOCKET fd: write == sorw(fp, uio) == sosend(so, 0, uio, 0).
                ; 2.11BSD sys_generic.c:529 -- no address, no flags, and the
                ; transport is the socket's to choose, which net.mod does.
                LDA     _Sys_WrFd
                JSR     _Sock_FdToDesc          ; C=1 + Y=desc + _sockTmpHw / C=0
                BCC     @sw_sockErr
                STY     _sockTmpOff
                JSR     _Sys_UUio               ; _libcTmp2 = &u.u_ttyuio
                JSR     _Sock_StageUio
                STZ     _sockSendFlags
                LDY     #NETOP_SoWrite
                JMP     _Net_Dispatch
@sw_sockErr     MX      %00
                CLC
                RTS

;------------------------------------------------------------------------------
; _Sock_StageUio - _sockUio = the syscall's uio (_libcTmp2, from _Sys_UUio), and no
; source address wanted.  MX %00.
;------------------------------------------------------------------------------
_Sock_StageUio  MX      %00
                LDA     _libcTmp2
                STA     _sockUio
                LDA     _libcTmp2+2
                AND     #$00FF
                STA     _sockUioBank
                STZ     _sockSrcOff             ; read/write name no address
                STZ     _soHasDst
                RTS

_WrOp_Pipe        ; FCB_FL_PIPE fd: write == pipe_rw(fp, uio) with UIO_WRITE.
                JSR     _Sys_UUio               ; _libcTmp2 = &u.u_ttyuio
                LDA     _libcTmp2               ; the uio the ring moves through
                STA     _pipeUio
                LDA     _libcTmp2+2
                AND     #$00FF
                STA     _pipeUioBank
                LDA     _Sys_WrFd
                AND     #$00FF
                JMP     _Pipe_Write             ; -> A=bytes/C

;------------------------------------------------------------------------------
; _Sys_Ioctl (#65) - device control on an fd.
;
; In:  A.lo = fd, X = cmd, Y = arg-ptr lo16.  Caller pushed arg-bank
;      onto the stack before the COP.
; Out: C=1 + A=0 on success; C=0 + A=errno on failure.
;
; Dispatch: look up the FCB and call the descriptor's FO_IOCTL arm.  A vnode
; descriptor crosses to the VFS, and a device node comes back through
; KSVC_CDIOCTL into `_Io_CdThenTty'.
;
; The (cmd, arg) plumb-through to the chardev op uses static slots —
; _Chardev_Dispatch only natively passes Y (=minor) to the op, so we
; stash cmd + arg in _Sys_Ioctl* before dispatch and the chardev op
; reads them back.
;------------------------------------------------------------------------------
_Sys_Ioctl      MX      %00
                STA     _Sys_IoctlFd
                STX     _Sys_IoctlCmd
                STY     _Sys_IoctlArgLo
                ; Pull arg-bank byte from caller stack (1 byte under our
                ; native-mode return frame; mirrors _Sys_Write's saving of
                ; the buf bank via _Sys_CallerBank — see syscall dispatch
                ; entry).  For slice 1 we just stash it; the null chardev
                ; ignores the arg pointer entirely.
                LDA     _Sys_CallerBank
                STA     _Sys_IoctlArgBank

                ; FCB lookup.  fcntl(F_SETFL) joins here with the four
                ; _Sys_Ioctl* cells staged for a FIONBIO.
_Sys_IoctlStaged SEP    #$20
                MX      %10
                LDA     _Sys_IoctlFd
                JSR     _Fcb_LookupPtr
                BCS     @si_haveFcb
                REP     #$20
                MX      %00
                LDA     #EBADF
                CLC
                RTS
@si_haveFcb     MX      %10
                ; FIOCLEX AND FIONCLEX ARE THE DESCRIPTOR'S, not the object's:
                ; Reno answers them in ioctl() before any dispatch
                ; (kern/sys_generic.c: `*pop |= UF_EXCLOSE' / `&= ~UF_EXCLOSE'),
                ; and they are fcntl(F_SETFD) under another name.
                REP     #$30
                MX      %00
                LDA     _Sys_IoctlCmd
                LDY     #1                      ; close on exec
                CMP     #FIOCLEX
                BEQ     @si_clex
                DEY                             ; stay open across exec
                CMP     #FIONCLEX
                BNE     @si_ckDone
@si_clex        PHY
                LDA     _Sys_IoctlFd
                AND     #$00FF
                JSR     _Fd_Pop
                PLA                             ; (leaves the carry alone)
                BCC     @si_clexRet             ; no far table: nothing to mark
                SEP     #$20
                MX      %10
                STA     [_fdFilePtr],Y
                REP     #$30
                MX      %00
@si_clexRet     LDA     #0
                SEC
                RTS
@si_ckDone      SEP     #$20
                MX      %10
                LDY     #FCB_Flags
                LDA     [_fcbPtr],Y
                ; DISPATCH THROUGH f_ops ON THE DESCRIPTOR.
                ; X is free here -- the tty arm loads it itself and the chardev
                ; arm works through Y -- so this site needs no ordering care.
                REP     #$30
                MX      %00
                LDA     _Sys_IoctlFd
                AND     #$00FF
                LDX     #FO_IOCTL
                JSR     _Fcb_OpEntry
                BCC     @si_notArm
                DEC
                PHA
                RTS

                ; FAR-BANK OPS: ROUTED.  An ioctl's third argument is a
                ; caller-bank POINTER and it crosses as an opaque address: FGX
                ; ioctl numbers are SIXTEEN BITS -- TIOCGETP is $7408, the low
                ; half of _IOR('t', 8, struct sgttyb) with the size bits cut
                ; off -- so there is no IOCPARM_LEN to size a copy with, the way
                ; Reno sizes one around its own dispatch.  Every chardev ioctl
                ; op reads the caller's argument through
                ; _Sys_IoctlArgLo/_Sys_IoctlArgBank and nothing between this
                ; line and the driver dereferences it, so the copy is exactly
                ; the one read and write already make.
@si_notArm      LDA     _fdOpsFar
                BEQ     @si_noops
                JMP     _Sys_DevIoctl

@si_noops       LDA     #EBADF
                CLC
                RTS

_IoOp_TtyAtX    ENT                             ; tty ioctls on the line at X
                MX      %00                     ;   (a tty byte offset); arg
                                                ;   points at caller-bank data
                                                ;   per command.  `_Io_CdThenTty'
                                                ;   jumps here (apple/fgx#267)
@si_ttyX        ; pty P1a: X = tty entry byte offset (idx * TTY_SIZE), preserved
                ; across the whole dispatch (no handler loads X before use; the
                ; sgttyb/tchars copy loops ADVANCE it in lockstep with Y).
                LDA     _Sys_IoctlCmd
                CMP     #TIOCISCONS
                BNE     @si_ck_notty
                JMP     @si_iscons                  ; *arg = (X == 0)
                ; EVERY ARM FROM HERE IS BNE+JMP, not BEQ.  It was forced once,
                ; when adding the TIOCNOTTY check pushed the pgrp pair's targets
                ; out of BEQ range, and it is kept now that only three arms are
                ; left: uniform BNE+JMP means the next ioctl added here cannot
                ; re-break the ones above it.
@si_ck_notty    CMP     #TIOCNOTTY
                BNE     @si_ck_dgname
                JMP     @si_dtch
                ; THE SGTTY SURFACE IS `ttioctl's, not this block's, and the
                ; state it acts on lives in the tty bank: t_chars for
                ; TIOCGETC/SETC/GLTC/SLTC (2.11BSD tty.c:611-626), t_winsize for
                ; TIOCGWINSZ/SWINSZ (tty.c:556-566, :1670), and t_flags -- ONE
                ; LONG whose low word is sg_flags and whose high word is the
                ; local mode word -- for TIOCGETP/SETP/SETN and
                ; TIOCLGET/LSET/LBIS/LBIC (tty.c:1554-1600, :1628-1646;
                ; ioctl.h:175-189 defines every L* bit as `((int)(BIT>>16))').
                ; The pgrp pair is there too, with upstream's two guards
                ; (tty.c:1655-1667): `kc_spgok' is the whole of the
                ; pfind/inferior ownership test, and TIOCSPGRP is in the SIGTTOU
                ; background list at tty.c:1439.
                ;
                ; What this block answers is FGX's own: TIOCISCONS and FIODGNAME
                ; have no 2.11BSD counterpart, and TIOCNOTTY is pure process
                ; state that upstream answers in tty_tty.c:58 before any
                ; dispatch.
@si_ck_dgname   CMP     #FIODGNAME
                BNE     @si_ck_sti
                JMP     @si_dgname
@si_ck_sti      ; TIOCSTI IS THE ONE COMMAND HELD BACK from the tty bank, and
                ; the reason is the `flag' argument rather than the command:
                ; ttioctl gates it on `(flag & FREAD) == 0' for a non-root
                ; caller, and FGX's FCB records only a WRITE bit, so the
                ; descriptor mode that test wants is not derivable here yet.
                ; ENOTTY is what it has always answered; routing it on a
                ; fabricated flag would turn an inert divergence into a
                ; permission check that silently always passes.  See _Tty_Ioctl.
                CMP     #TIOCSTI
                BNE     @si_kc
_IoOp_Notty       LDA     #ENOTTY
                CLC
                RTS
@si_kc          ; EVERYTHING ELSE IS THE DISCIPLINE'S -- apple/fgx#108 T3
                ; stage 2.  The three arms above are FGX's own (TIOCISCONS and
                ; FIODGNAME have no 2.11BSD counterpart, and TIOCNOTTY is pure
                ; process state that upstream answers in tty_tty.c:58 before
                ; any dispatch); everything else goes to the tty bank's
                ; ttioctl, which is upstream's own order -- tty_pty.c:508-527
                ; takes the driver's commands first and falls through for the
                ; rest.
                ;
                ; A $FFFF BACK IS NOT AN ERROR.  It is ttioctl's own default
                ; arm (`usr/sys/sys/tty.c:571', `return (-1);'), meaning the
                ; discipline did not know the command either -- so it lands on
                ; the same ENOTTY the core would have given, and an errno stays
                ; distinguishable from it.
                JSR     @si_argp
                MX      %00         ; argp returns REP\'d (assembler state, not code)
                TXA                             ; X is the tty BYTE offset per
                JSR     _Se_TtyOffToIdx         ;   @si_ttyX; the slot takes an
                JSR     _Tty_Ioctl              ;   INDEX
                CMP     #0
                BEQ     @si_kcOk
                CMP     #$FFFF
                BEQ     _IoOp_Notty
                CLC                             ; A is an errno from the bank
                RTS
@si_kcOk        JMP     @si_ok0
@si_dtch        ; TIOCNOTTY: give up the controlling terminal.
                ;     u.u_ttyp = 0; u.u_ttyd = 0; u.u_procp->p_pgrp = 0;
                ;                       -- 2.11BSD tty_tty.c:57-62
                ; TAKES NO ARGUMENT and reads NOTHING from this tty -- BSD's
                ; handler is pure process state, which is why accepting it on
                ; any tty fd is the same thing BSD does on /dev/tty.  The node
                ; bought BSD only proof-that-you-have-a-ctty; FGX has no such
                ; node and does not need one.  X (the tty offset) is untouched.
                JSR     _Se_TtyDetach
                JMP     @si_ok0

@si_iscons      ; TIOCISCONS: *arg = 1 for a CONSOLE tty -- tty[0] and, since
                ; slice D, the virtual consoles at tty[3..4].  A pty slave
                ; (X = TTY_SIZE or 2*TTY_SIZE) is not a console.
                ;
                ; THE VCs ANSWER 1 BECAUSE THEY ARE CONSOLES.  An earlier cut
                ; answered 0 for them, reasoning that a shell would then use
                ; plain byte reads instead of the SYS_GETKEY console editor and
                ; so could not steal keystrokes from the console on screen.
                ; That was working around a missing controlling-tty binding
                ; rather than describing the device -- and it made a VC session
                ; behave unlike the console session it is meant to be.  The
                ; binding now exists (SE_Flags ctty bits, acquired at open) and
                ; SYS_GETKEY is gated on it, so the honest answer is the correct
                ; one.
                JSR     @si_argp
                MX      %00         ; argp returns REP\'d (assembler state, not code)
                TXA                                 ; A = tty offset
                BEQ     @si_iscons1
                CMP     #TTY_SIZE*3                 ; ttyv1
                BEQ     @si_iscons1
                CMP     #TTY_SIZE*4                 ; ttyv2
                BEQ     @si_iscons1
                CMP     #TTY_SIZE*6                 ; ttyv3
                BEQ     @si_iscons1
                LDA     #0
                BRA     @si_iconsW
@si_iscons1     LDA     #1
@si_iconsW      STA     [_libcTmp2]                 ; *arg (16-bit, caller bank)
                JMP     @si_ok0

@si_dgname      ; FIODGNAME: copy tty[X]'s device name to *arg, NUL-terminated,
                ; at most TTYNAME_MAX bytes.  X is a BYTE OFFSET (idx*TTY_SIZE),
                ; so recover the index by repeated subtract -- the same trick
                ; _Sig_TtyOffset uses in the other direction, and NTTY is small
                ; enough that this runs at most NTTY-1 times.
                JSR     @si_argp
                MX      %00         ; argp returns REP\'d (assembler state, not code)
                TXA                                 ; A = tty byte offset
                LDY     #0
@si_dgnIdx      CMP     #TTY_SIZE
                BCC     @si_dgnHave
                SEC
                SBC     #TTY_SIZE
                INY
                BRA     @si_dgnIdx
@si_dgnHave     TYA                                 ; A = tty index
                ASL                                 ; * TTYNAME_MAX (8)
                ASL
                ASL
                TAX                                 ; X = record offset
                SEP     #$20
                MX      %10
                LDY     #0
@si_dgnL        LDA     _ttyNames,X
                STA     [_libcTmp2],Y               ; STA preserves LDA's Z flag
                BEQ     @si_dgnDone                 ; copied the NUL: done
                INX
                INY
                CPY     #TTYNAME_MAX-1
                BCC     @si_dgnL
                LDA     #0                          ; oversized name: terminate
                STA     [_libcTmp2],Y
@si_dgnDone     JMP     @si_ok0

@si_argp        ; Shared by every tty ioctl handler (code-size dedup 2026-07-27
                ; -- the kernel bank is at its ceiling): _libcTmp2 = caller arg
                ; far-ptr from _Sys_IoctlArgLo/_Sys_IoctlArgBank.  MX %00 in/out.
                LDA     _Sys_IoctlArgLo
                STA     _libcTmp2
                SEP     #$20
                MX      %10
                LDA     _Sys_IoctlArgBank
                STA     _libcTmp2+2
                REP     #$20
                MX      %00
                RTS
@si_ok0         ; Shared success tail: A=0, C=1.  The leading REP is a no-op for
                ; handlers already in 16-bit M, so both the byte-copy (%10) and
                ; word (%00) handlers JMP here.
                REP     #$20
                MX      %00
                LDA     #0
                SEC
                RTS

;------------------------------------------------------------------------------
; _IoOp_Socket - socket ioctls (FCB_FL_SOCKET fd).  Resolves the descriptor, then:
;   FIONBIO    *arg != 0 -> set SOCK_NB (non-blocking), else clear
;   FIONREAD   *arg <- RX bytes available (NETOP_SockStatus stashes -> _sockRxLen)
;   SIOCATMARK *arg <- 0 (W5100 exposes no TCP urgent)
;   SIOCGIF*   the 'i' group, net.mod's net_op_ifioctl (2.11BSD ifioctl)
; All return C=1 + A=0, or C=0 + A=EBADF/ENOTTY.  MX %00 entry.
;------------------------------------------------------------------------------
_IoOp_Socket        SEP     #$20
                MX      %10
                LDA     _Sys_IoctlFd
                REP     #$30
                MX      %00
                AND     #$00FF
                JSR     _Sock_FdToDesc          ; C=1 Y=desc + _sockTmpHw / C=0
                BCS     @sis_desc
                LDA     #EBADF
                CLC
                RTS
@sis_desc       STY     _sockTmpOff
                LDA     _Sys_IoctlCmd
                AND     #$FF00
                CMP     #SIOC_IF_GROUP          ; SIOCGIF*: net.mod's ifioctl
                BNE     @sis_notif
                LDY     #NETOP_IfIoctl
                JMP     _NetThunkExec
@sis_notif      LDA     _Sys_IoctlCmd
                CMP     #FIONBIO
                BEQ     @sis_nbio
                CMP     #FIONREAD
                BEQ     @sis_nread
                CMP     #SIOCATMARK
                BEQ     @sis_atmark
                LDA     #ENOTTY
                CLC
                RTS
@sis_nbio       LDA     _Sys_IoctlArgLo         ; *arg on/off
                STA     _libcTmp2
                SEP     #$20
                MX      %10
                LDA     _Sys_IoctlArgBank
                STA     _libcTmp2+2
                REP     #$20
                MX      %00
                LDA     [_libcTmp2]
                BEQ     @sis_nbclr
                LDA     _sockTmpOff             ; set SOCK_NB
                CLC
                ADC     #SOCK_Flags
                TAY
                SEP     #$20
                MX      %10
                LDA     [_sockTablePtr],Y
                ORA     #SOCK_NB
                STA     [_sockTablePtr],Y
                REP     #$30
                MX      %00
                LDA     #0
                SEC
                RTS
@sis_nbclr      LDA     _sockTmpOff             ; clear SOCK_NB
                CLC
                ADC     #SOCK_Flags
                TAY
                SEP     #$20
                MX      %10
                LDA     [_sockTablePtr],Y
                AND     #$FF-SOCK_NB
                STA     [_sockTablePtr],Y
                REP     #$30
                MX      %00
                LDA     #0
                SEC
                RTS
@sis_nread      ; LOOPBACK FIRST, exactly as _Sel_Classify does -- and this
                ; arm is why apple/fgx#97 was a live defect rather than a
                ; latent one.  A loopback descriptor has NO W5100 socket
                ; behind it (SOCK_HwIdx is the sentinel SOCK_HW_LOOP), so
                ; asking the chip for socket $FE's RX_RSR reads open bus on a
                ; machine with no card.  #97's own write-up reasoned that
                ; loopback fds never reach SockStatus because _Sel_Classify
                ; pre-checks; that is true of select(2) and was never true
                ; here.  The bytes live in the Rx ring, and _Loop_StatusTry
                ; already walks it for the readable bit, so it now leaves the
                ; resident count in _loopRxLen on the way past.
                JSR     _Loop_StatusTry
                LDA     _loopHandled
                BEQ     @sisn_hw
                LDA     _loopRxLen              ; ONE tail below, one source of
                STA     _sockRxLen              ;   the count: a second copy of
                BRA     @sisn_arg               ;   the store is a second answer
@sisn_hw        LDY     #NETOP_SockStatus       ; populates _sockRxLen (RX_RSR)
                JSR     _NetThunkExec
@sisn_arg       LDA     _Sys_IoctlArgLo
                STA     _libcTmp2
                SEP     #$20
                MX      %10
                LDA     _Sys_IoctlArgBank
                STA     _libcTmp2+2
                REP     #$20
                MX      %00
                LDA     _sockRxLen
                STA     [_libcTmp2]             ; *arg = bytes available
                LDA     #0
                SEC
                RTS
@sis_atmark     LDA     _Sys_IoctlArgLo
                STA     _libcTmp2
                SEP     #$20
                MX      %10
                LDA     _Sys_IoctlArgBank
                STA     _libcTmp2+2
                REP     #$20
                MX      %00
                LDA     #0
                STA     [_libcTmp2]             ; *arg = 0 (no OOB mark)
                SEC
                RTS

_Io_CdThenTty   ENT
                MX      %00
                JSR     _SyTty_Resolve          ; /dev/tty -> the caller's line
                STA    |_ioCdIdx                ; the op preserves nothing, and
                                                ;   A carries its result back
                JSR     _Chardev_Ioctl
                BCS     @ct_ret                 ; C=1: the device answered
                CMP     #ENOTTY
                BNE     @ct_ret                 ; a real errno: that IS the answer
                LDA    |_ioCdIdx
                JSR     _Chardev_TtyOff         ; is this chardev a tty LINE?
                BCC     @ct_noTty               ; no -- a master, or not a tty
                TAX                             ; X = its tty byte offset, which
                JMP     _IoOp_TtyAtX            ;   is that block's contract
@ct_noTty       ; A PTY MASTER IS NOT A TTY LINE, AND THE WINDOW SIZE STILL
                ; HAS TO REACH ITS SLAVE (apple/fgx#150, on the vnode road).
                ; `_Chardev_TtyOff' is right to refuse a master -- it has no
                ; line of its own -- but in BSD both ends share one `struct
                ; tty', so `ioctl(master, TIOCSWINSZ)' IS a set on the line the
                ; child reads.  telnetd needs it for NAWS; winsz(8) measures
                ; it.
                ;
                ; AND A MASTER'S TIOCFLUSH IS THE SLAVE'S FLUSH (apple/fgx
                ; #241), for the same reason and from the same paragraph of
                ; upstream: `ptyioctl' has NO TIOCFLUSH arm -- its master
                ; switch is TIOCPKT, TIOCUCNTL, TIOCREMOTE and
                ; TIOCSETP/SETN/SETD and nothing else
                ; (vendor/2.11BSD/usr/sys/sys/tty_pty.c:483-511) -- so the
                ; command falls through to `error = ttioctl(tp, cmd, data,
                ; flag)' at tty_pty.c:526, where `tp' IS the slave's line.
                ;
                ; ONLY THESE THREE COMMANDS, for the reason the sibling arm
                ; gives: widening a master's whole ioctl surface would give it
                ; a second, competing view of state the slave owns.
                LDA     _Sys_IoctlCmd
                CMP     #TIOCGWINSZ
                BEQ     @ct_mwin
                CMP     #TIOCSWINSZ
                BEQ     @ct_mwin
                CMP     #TIOCFLUSH
                BNE     @ct_mrefuse
@ct_mwin        LDA    |_ioCdIdx
                CMP     _ptyMasterIdx0
                BEQ     @ct_m0
                CMP     _ptyMasterIdx1
                BEQ     @ct_m1
                BRA     @ct_mrefuse
@ct_m0          LDX     #TTY_SIZE               ; master of pair 0 -> tty[1]
                JMP     _IoOp_TtyAtX
@ct_m1          LDX     #TTY_SIZE*2             ; master of pair 1 -> tty[2]
                JMP     _IoOp_TtyAtX
@ct_mrefuse     ; _Chardev_TtyOff clobbered A, so the refusal is rebuilt rather
                ; than carried.  It is the same ENOTTY the device gave.
                LDA     #ENOTTY
                CLC
@ct_ret         RTS

;------------------------------------------------------------------------------
; _Sys_UioOne - build this task's one-entry uio over the caller's buffer.
;
; In:  MX %00.  A = buffer offset, X = length, Y = UIO_READ or UIO_WRITE; the
;      buffer's bank is _Sys_CallerBank.
; Out: _libcTmp0/1 = &u.u_ttyiov and _libcTmp2 = &u.u_ttyuio, both far.
;      uio_offset starts at 0 and uio_resid at the length.  Clobbers A, Y.
;
; This is what 2.11BSD's read()/write() do before rwuio (sys_generic.c:84-100):
; one aiov over (buf, count), uio_iovcnt = 1.  _Sys_UioVec is readv(2)'s and
; writev(2)'s, over the copied vector; every arm under them takes either.
;------------------------------------------------------------------------------
_Sys_UioOne     MX      %00
                PHY                             ; 5,S = rw
                PHX                             ; 3,S = length
                PHA                             ; 1,S = base
                LDA     _u                      ; &u.u_ttyiov
                CLC
                ADC     #U_TtyIov
                STA     _libcTmp0
                LDA     _u                      ; &u.u_ttyuio
                CLC
                ADC     #U_TtyUio
                STA     _libcTmp2
                SEP     #$20
                MX      %10
                LDA     _u+2                    ; the u-area's BANK: the u-area
                STA     _libcTmp1               ;   never crosses a bank, so the
                STA     _libcTmp2+2             ;   carry cannot reach it
                REP     #$30
                MX      %00
                PLA
                LDY     #U_TtyIov
                STA     [_u],Y                  ; iov_base lo16
                LDA     _Sys_CallerBank
                AND     #$00FF
                LDY     #U_TtyIov+2
                STA     [_u],Y                  ; iov_base bank (pad 0)
                LDA     1,S
                LDY     #U_TtyIov+4
                STA     [_u],Y                  ; iov_len
                LDY     #U_TtyUio+UIO_RESID
                STA     [_u],Y
                PLA                             ; drop the length
                LDA     _libcTmp0
                LDY     #U_TtyUio
                STA     [_u],Y                  ; uio_iov lo16
                LDA     _libcTmp1
                AND     #$00FF
                LDY     #U_TtyUio+2
                STA     [_u],Y                  ; uio_iov bank (pad 0)
                LDA     #1
                LDY     #U_TtyUio+4
                STA     [_u],Y                  ; uio_iovcnt
                LDA     #0
                LDY     #U_TtyUio+6
                STA     [_u],Y                  ; uio_offset, both halves -- the
                LDY     #U_TtyUio+8             ;   tty read's DELIVERED COUNT, not
                STA     [_u],Y                  ;   a file position
                LDY     #U_TtyUio+12
                STA     [_u],Y                  ; uio_segflg = UIO_USERSPACE
                PLA                             ; rw
                LDY     #U_TtyUio+UIO_RW
                STA     [_u],Y
                RTS

;------------------------------------------------------------------------------
; _Sys_UioVec - build this task's uio over the caller's iovec array.
; In:  MX %00.  A = UIO_READ or UIO_WRITE, X = the array's offset, Y = iovcnt;
;      the array's bank is _Sys_CallerBank.
; Out: C=1: u.u_ttyuio built over u.u_aiov.  C=0: A = EINVAL.
;      Clobbers A, X, Y, _libcTmp0-2, _sysVecLen.
;
; 2.11BSD readv()/writev() and rwuio() (sys_generic.c:57-79, :127-151): an
; iovcnt past aiov[16] is EINVAL, the vector is COPIED in, and the lengths are
; summed into uio_resid before anything moves.  The copy is what uiomove then
; advances, so the caller's own array is never written.  A total the read(2)
; return cannot carry -- past 32767, the count and -errno sharing one word --
; is EINVAL, where upstream's test is the wider uio_resid; read(2) refuses the
; same counts for the same reason (vfs_syscalls.c rwcommon).
;------------------------------------------------------------------------------
_Sys_UioVec     MX      %00
                PHA                             ; 1,S = rw
                CPY     #UIO_MAXIOV+1           ; unsigned, as upstream's is
                BCC     @uv_cnt
                PLA                             ; drop rw
                LDA     #EINVAL
                CLC
                RTS
@uv_cnt         PHY                             ; 1,S = iovcnt, 3,S = rw
                STX     _libcTmp0               ; [_libcTmp0] = the caller's array
                SEP     #$20
                MX      %10
                LDA     _Sys_CallerBank
                STA     _libcTmp1
                LDA     _u+2
                STA     _libcTmp2+2             ; [_libcTmp2] = &u.u_aiov
                REP     #$30
                MX      %00
                LDA     _u
                CLC
                ADC     #U_Aiov
                STA     _libcTmp2
                TYA                             ; 6 * iovcnt bytes
                ASL
                STA     _sysVecLen
                ASL
                CLC
                ADC     _sysVecLen
                STA     _sysVecLen
                LDY     #0
@uv_copy        CPY     _sysVecLen
                BCS     @uv_sum
                LDA     [_libcTmp0],Y
                STA     [_libcTmp2],Y
                INY
                INY
                BRA     @uv_copy
@uv_sum         LDA     #0                      ; the lengths, off the COPY
                LDY     #4                      ; iov_len within an entry
@uv_add         CPY     _sysVecLen
                BCS     @uv_total
                CLC
                ADC     [_libcTmp2],Y
                BCS     @uv_inval2
                INY
                INY
                INY
                INY
                INY
                INY
                BRA     @uv_add
@uv_total       CMP     #0
                BMI     @uv_inval2              ; past 32767
                LDY     #U_TtyUio+UIO_RESID
                STA     [_u],Y
                LDA     _libcTmp2
                LDY     #U_TtyUio
                STA     [_u],Y                  ; uio_iov lo16
                LDA     _u+2
                AND     #$00FF
                LDY     #U_TtyUio+2
                STA     [_u],Y                  ; uio_iov bank (pad 0)
                PLA
                LDY     #U_TtyUio+4
                STA     [_u],Y                  ; uio_iovcnt
                LDA     #0
                LDY     #U_TtyUio+6
                STA     [_u],Y                  ; uio_offset, both halves
                LDY     #U_TtyUio+8
                STA     [_u],Y
                LDY     #U_TtyUio+12
                STA     [_u],Y                  ; uio_segflg = UIO_USERSPACE
                PLA                             ; rw
                LDY     #U_TtyUio+UIO_RW
                STA     [_u],Y
                SEC
                RTS
@uv_inval2      PLA                             ; drop iovcnt
                PLA                             ; drop rw
                LDA     #EINVAL
                CLC
                RTS

;------------------------------------------------------------------------------
; _Sys_UUio - _libcTmp2 = &u.u_ttyuio, the uio the syscall built.  MX %00.
; Clobbers A.  The arms take it from here rather than from a static, so a sleep
; inside the transfer cannot hand them another task's.
;------------------------------------------------------------------------------
_Sys_UUio       MX      %00
                LDA     _u
                CLC
                ADC     #U_TtyUio
                STA     _libcTmp2
                SEP     #$20
                MX      %10
                LDA     _u+2
                STA     _libcTmp2+2
                REP     #$30
                MX      %00
                RTS


;------------------------------------------------------------------------------
; _Task_VforkFirstRun - a vfork child's first run (fork train Stage V).
;
; Reached like _Task_FirstRun: swtch RTS's into the child's primed kernel
; stack (Task_PrimeKernStackAt).  At this point swtch has already restored
; the dispatcher carryover globals (_Sys_UserSP/_Sys_UserDP/_Sys_CallerBank)
; from the child's SE fields — which _Sys_Vfork set to copies of the
; parent's, so they denote the shared user frame inside the libc vfork stub.
;
; Replays the dispatcher's normal-return tail with A=0 + C=1: the child
; resumes at the instruction after the trap's DFB, exactly as if the vfork
; syscall had returned 0 -- CLI included.  swtch reaches here with IRQs
; masked, and a child that kept them masked would run its syscalls masked
; until one returned normally: an execve would run whole with the heartbeat
; off, and the system clock would lose those ticks (apple/fgx#502).  2.11BSD's child
; leaves through the same syscall() return as every other call, restoring
; the user-mode ps from the trap frame (pdp/trap.c syscall, kern_fork.c
; fork1).  DBR here = kernel bank (swtch runs kernel code);
; the PLB below pops the caller DBR byte from the dispatcher's 4-byte user-
; stack frame [DBR,PCL,PCH,PB], which is still pristine — the child is its
; FIRST consumer; the parent's copy rides the parent's kernel stack
; (_Sys_Vfork stash) precisely because the child scribbles it afterward.
;
; Signal check is skipped (vs the real tail): a signal arriving between
; READY and first-run stays pending and delivers at the child's next
; syscall boundary — deferred, not lost.
;------------------------------------------------------------------------------
_Task_VforkFirstRun ENT
                MX      %00
                REP     #$30
                STZ    |_kCpState               ; CP_USER: the child runs user code
                LDA     _Sys_UserDP
                TCD
                LDY     #0                      ; no secondary return word
                LDX     _Sys_UserSP
                TXS
                PLB                             ; caller DBR (frame byte 1)
                LDA     #0                      ; the child's vfork() = 0
                SEC                             ; success
                CLI                             ; user runs with IRQs enabled, as
                                                ; at @je_normalReturn: swtch got
                                                ; here masked
                RTL                             ; resume past the trap's DFB

;------------------------------------------------------------------------------
; _Sys_Execve (#11) - replace caller with new program.
;
; A = path string offset within the caller's bank, X = arg-block offset, Y =
; the arg-block's bank.  The block is argv then envp, a far pointer each --
; BSD's `struct execa' less the path (2.11BSD usr/sys/sys/kern_exec.c:31).
;
; A TWO-LINE SHIM ONTO `_Sys_ExecveVfork', which owns the argv/envp staging,
; the fresh DP page and the rollback.  Ownership of the outgoing image is the
; only thing that differs between callers, and its header covers that.
;
; Returns: only on failure.  C=0 + A=errno, caller intact (BSD execve(2)).
;------------------------------------------------------------------------------
_Sys_Execve     MX      %00
                STX     _ps_argBlk              ; arg-block offset ...
                STY     _ps_argBlkBank          ;   ... and its bank
                JMP     _Sys_ExecveVfork

;------------------------------------------------------------------------------
; _Sys_DevRead / _Sys_DevWrite / _Sys_DevUio - hand a read or write on a FAR-OPS
; descriptor to the far bank.  UFS 1.7d I3.
;
; WHAT CROSSES IS THE TASK'S uio, u.u_ttyuio, and nothing else: dev_rw is
; 2.11BSD's rwuio (sys_generic.c:127-171), which takes the uio read(), write(),
; readv() and writev() built and calls fo_rw once.  _Sys_DevRead/_Sys_DevWrite
; build a one-entry uio over (buffer, count) first, as read() and write() do;
; _Sys_DevUio crosses with the one already built, which is the vector calls'
; entry and the read(2)/write(2) far arms'.
;
; THE BUFFERS ARE COMPLETE 24-BIT POINTERS.  The far bank's uiomove copies
; through them with no arm of its own: on a 65816 there is one address space
; and a bank is part of an address, so a user pointer needs COMPLETING, not
; converting.  _Sys_UioOne completes it from _Sys_CallerBank.
;
; In:  _Sys_DevRead/_Sys_DevWrite: A = fd (16-bit), X = caller-bank buffer
;      offset, Y = byte count.  _Sys_DevUio: A = fd, u.u_ttyuio built.
; Out: C=1 and A = bytes moved; C=0 and A = errno, also stored in _errno.
; MX:  %00 in and out.  Clobbers A, X, Y, _sysDevFd, _libcTmp0-2, _errno.
;------------------------------------------------------------------------------
_Sys_DevRead    MX      %00
                STA     _sysDevFd
                TXA                             ; A = buffer
                TYX                             ; X = count
                LDY     #UIO_READ
                BRA     @dv_uio
_Sys_DevWrite   MX      %00
                STA     _sysDevFd
                TXA
                TYX
                LDY     #UIO_WRITE
@dv_uio         JSR     _Sys_UioOne             ; _libcTmp2 = &u.u_ttyuio
                LDA     _sysDevFd
_Sys_DevUio     MX      %00
                STA     _sysDevFd
                ; dev_rw(pid, fd, uio): fcc reads right to left, so the LAST
                ; argument is pushed first.  uio is a 4-byte fcc pointer -- pad,
                ; bank, then offset, the offset being its lowest address.
                SEP     #$20
                MX      %10
                LDA     #0
                PHA                             ;      pad
                LDA     _u+2
                PHA                             ;      bank: the u-area's
                REP     #$30
                MX      %00
                LDA     _u
                CLC
                ADC     #U_TtyUio
                PHA                             ;      offset
                LDA     _sysDevFd
                PHA                             ; fd
                JSR     _Fcb_OwnerPid           ; not _curTask -- see fcb.s
                PHA                             ; pid, nearest the return
_kfp917         JSL     KFAR_VFS_DEVRW          ; bank byte patched by Far_Init
                TAY                             ; park the answer; TSC needs A
                TSC
                CLC
                ADC     #8                      ; drop the copy -- caller cleans
                TCS
                TYA
                BMI     @dv_err
                SEC
                RTS
                ; NEGATIVE MEANS -errno, and the two cannot collide: no errno
                ; is zero and no count is negative.  dev_rw returns the COUNT
                ; in preference to the errno when a transfer moved bytes and
                ; then failed, so reaching here means nothing moved.
@dv_err         EOR     #$FFFF
                INC                             ; A = errno
                SEP     #$20
                MX      %10
                STA     _errno
                REP     #$30
                MX      %00
                AND     #$00FF
                CLC
                RTS

;------------------------------------------------------------------------------
; _Sys_DevIoctl / _Sys_DevSelect - hand an ioctl or a select on a FAR-OPS
; descriptor to the far bank.  UFS 1.7d I4.
;
; TWO ENTRY POINTS AND ONE BODY, as _Sys_DevRead/_Sys_DevWrite are, and here
; the economy is not a nicety: the core bank had 92 bytes free when this was
; written.  The entries differ only in which fd they load and which boolean
; they push, and the body pushes the ioctl staging unconditionally -- garbage
; on the select side, which the far entry's own note explains is cheaper to
; copy than to branch around.
;
; THE ARGUMENTS ARE ALREADY STAGED AND ARE NOT PASSED IN.  _Sys_Ioctl stores
; fd, cmd and the argument pointer in its first four instructions, BEFORE it
; classifies the descriptor, so by the time a far-ops descriptor lands here
; they hold this ioctl's values.  The select side reads _selFd, which
; _Sel_Classify has likewise already set.  Nothing needs re-deriving.
;
; In:  nothing -- see above.  MX %00.
; Out: ioctl:  C=1 + A=0 on success; C=0 + A=errno (also stored in _errno).
;      select: C=1 + A = the readiness bits the select arms return (1 readable,
;              2 writable, 4 exceptional); C=0 + A=errno.  Same contract as
;              _SelOp_Default and the ioctl arms, so both sites tail jump here.
; MX:  %00 in and out.  Clobbers A, X, Y, _sysDevFd, _errno.
;------------------------------------------------------------------------------
_Sys_DevSelect  MX      %00
                PEA     $0000                   ; isioctl = 0.  Pushed FIRST:
                LDA     _selFd                  ;   fcc reads right to left, so
                BRA     @di_args                ;   the last argument is the
_Sys_DevIoctl   MX      %00                     ;   deepest.
                PEA     $0001
                LDA     _Sys_IoctlFd
@di_args        AND     #$00FF
                STA     _sysDevFd
                ; data: a 4-byte fcc pointer -- pad, bank, then offset, because
                ; the offset is the LOWEST address within it and the stack grows
                ; down.  The bank is the CALLER's, never a `^' literal.
                SEP     #$20
                MX      %10
                LDA     #0
                PHA                             ;      pad
                LDA     _Sys_IoctlArgBank
                PHA                             ;      bank
                REP     #$30
                MX      %00
                LDA     _Sys_IoctlArgLo
                PHA                             ;      offset
                LDA     _Sys_IoctlCmd
                PHA                             ; com
                LDA     _sysDevFd
                PHA                             ; fd
                JSR     _Fcb_OwnerPid           ; not _curTask -- see fcb.s
                PHA                             ; pid, nearest the return
_kfp964         JSL     KFAR_VFS_DEVIOCTLSEL    ; bank byte patched by Far_Init
                TAY                             ; park the answer; TSC needs A
                TSC
                CLC
                ADC     #12                     ; drop the copy -- caller cleans
                TCS
                TYA
                BMI     @di_err
                SEC
                RTS
                ; NEGATIVE MEANS -errno, and nothing it could collide with is
                ; negative: an ioctl answers 0 on success and select answers a
                ; three-bit mask.  dev_rw's convention, for dev_rw's reason.
@di_err         EOR     #$FFFF
                INC                             ; A = errno
                SEP     #$20
                MX      %10
                STA     _errno
                REP     #$30
                MX      %00
                AND     #$00FF
                CLC
                RTS

;------------------------------------------------------------------------------
; _Sys_CopyPathToBuf - copy null-term path from caller bank to _Sys_PathBuf.
; Input:  A = path offset within FGX_USER_BASE.
; Caller MX %00; on return MX %00 and DBR=kernel-bank ($02 = assembly ORG).
;
; MX:       Caller %00.  Returns %00.
; Returns:  C=0 the whole path is in the buffer, Y = its length.
;           C=1 the path is longer than SYS_PATH_MAX and NOTHING usable is in
;           the buffer -- the caller must fail with ENAMETOOLONG and must not
;           look at it.  `_Sys_PathTooLong' is that return.
; Clobbers: A, Y (Y returns = path length copied).  X preserved.
;           `_libcTmp2` clobbered — used as the path-walk long pointer.
;           Caller MUST re-establish _libcTmp2 if it was holding a long
;           pointer to caller-buffer memory.  Hit during slice-2 ls debug.
;
; THE OVERLONG PATH IS REPORTED AND NOT TRUNCATED (apple/fgx#436).  This used
; to stop at the buffer, write a NUL and return success, so a path past the
; limit was looked up as a DIFFERENT, SHORTER name: usually ENOENT for a file
; that exists, and -- when the truncation happened to land on another real
; name -- the wrong file acted on.  namei has always bounded its own walk and
; answered ENAMETOOLONG (vfs_lookup.c); it simply never saw the full path,
; because this stage had already shortened it.
;
; 2.11BSD ANSWERS ENOENT HERE, NOT ENAMETOOLONG, and the difference is worth
; recording because the obvious assumption is the other way.  namei copies the
; path with `copyinstr(ndp->ni_dirp, path, MAXPATHLEN, (u_int *)0)'
; (usr/sys/sys/ufs_namei.c:157-165) and copyinstr's contract is "Returns zero
; on success, EFAULT on user memory management trap, ENOENT if maxlength
; exceeded" (usr/sys/pdp/mch_copy.s:430-434, `mov $ENOENT,r0' at :463).
; 2.11BSD spends ENAMETOOLONG on two OTHER conditions: one path COMPONENT over
; MAXNAMLEN (ufs_namei.c:204-207) and a symlink expansion that would overflow
; MAXPATHLEN (:773-776).  FGX answers ENAMETOOLONG for the whole-path case
; because its namei is the 4.3BSD-Reno port, which returns the error from its
; own MAXPATHLEN bound, and because this stage must agree with the check
; downstream of it rather than with a different BSD's.
;------------------------------------------------------------------------------
_Sys_CopyPathToBuf MX %00
                ; A = 16-bit src offset within caller's bank (= _Sys_CallerBank).
                ; Build [_libcTmp2] long-pointer: lo+hi from A, bank from caller.
                STA     _libcTmp2               ; lo word
                LDY     #0
                SEP     #$20
                MX      %10
                LDA     _Sys_PathBank
                STA     _libcTmp2+2
@cp_L           LDA     [_libcTmp2]             ; byte at path_bank:offset
                STA     _Sys_PathBuf,Y          ; abs,Y under DBR=kernel-bank ($02 = ORG)
                BEQ     @cp_done
                ; Advance long pointer.
                REP     #$20
                MX      %00
                LDA     _libcTmp2
                INC
                STA     _libcTmp2
                SEP     #$20
                MX      %10
                INY
                CPY     #SYS_PATH_MAX
                BCC     @cp_L
                ; SYS_PATH_MAX chars and still no NUL: it does not fit.
                REP     #$20
                MX      %00
                SEC
                RTS
@cp_done        REP     #$20
                MX      %00
                CLC
                RTS

;------------------------------------------------------------------------------
; _Sys_CopyPathToBuf2 - identical to _Sys_CopyPathToBuf but targets the second
; path buffer (_Sys_PathBuf2).  Used by SYS_RENAME to hold the TO path while the
; FROM path is processed.  A = path offset within the caller bank.
; Same carry contract: C=1 means the path is over SYS_PATH_MAX.
;------------------------------------------------------------------------------
_Sys_CopyPathToBuf2 MX %00
                STA     _libcTmp2               ; lo word
                LDY     #0
                SEP     #$20
                MX      %10
                LDA     _Sys_PathBank
                STA     _libcTmp2+2
@cp2_L          LDA     [_libcTmp2]
                STA     _Sys_PathBuf2,Y
                BEQ     @cp2_done
                REP     #$20
                MX      %00
                LDA     _libcTmp2
                INC
                STA     _libcTmp2
                SEP     #$20
                MX      %10
                INY
                CPY     #SYS_PATH_MAX
                BCC     @cp2_L
                REP     #$20
                MX      %00
                SEC
                RTS
@cp2_done       REP     #$20
                MX      %00
                CLC
                RTS

;------------------------------------------------------------------------------
; _Sys_PathTooLong - the shared ENAMETOOLONG return for a path that did not fit.
;
; Every `JSR _Sys_CopyPathToBuf' is followed by a carry test that lands here on
; overflow, and `tools/check_path_copy.py' fails the build if one is not -- a
; site added without the test is exactly the silent truncation apple/fgx#436
; was.  Reached by JMP, never JSR: it returns as the HANDLER, on a stack that
; still holds only the handler's own return address, which is why the two sites
; that push before copying (_Sys_Statfs, _Sys_Rename's second path) unwind
; themselves first rather than coming here directly.
;
; MX %00 in, and the syscall failure shape out: C=0 with A = errno.
;------------------------------------------------------------------------------
_Sys_PathTooLong MX     %00
                LDA     #ENAMETOOLONG
                CLC
                RTS

;------------------------------------------------------------------------------
; _Sys_PathBlkArg - take one far pointer out of a syscall's argument block.
;
; In:  Y = byte offset of the pointer within the block; the block itself is at
;      `_Sys_SavedA' in `_Sys_CallerBank', which is SYS_SELECT's convention
;      (see _Sys_Select) and the one apple/fgx#303 widened execve to.
; Out: A = the path's offset, `_Sys_PathBank' = the path's OWN bank, so the
;      copy that follows reads it wherever it actually lives.
;
; THIS IS WHAT LETS ONE SYSCALL TAKE TWO PATHS IN TWO BANKS.  A path used to
; arrive as a bare 16-bit offset read from `_Sys_CallerBank', and _Sys_Link's
; header said what that cost: "one `_Sys_CallerBank' cannot describe two banks
; anyway."  It did not bite while argv was a copy in the caller's data bank;
; apple/fgx#301 pointed argv at the kernel's bank-0 frame and `rename(argv[1],
; argv[2])' began reading its second path from the first one's bank.
;
; Caller + exit MX %00.  Clobbers A/Y and _libcTmp2.
;------------------------------------------------------------------------------
_Sys_PathBlkArg MX      %00
                PHY
                LDA     _Sys_SavedA             ; block offset
                STA     _libcTmp2
                SEP     #$20
                MX      %10
                LDA     _Sys_CallerBank         ; the BLOCK is co-bank with DBR
                STA     _libcTmp2+2
                REP     #$20
                MX      %00
                PLY
                LDA     [_libcTmp2],Y           ; +0/+1 = the path's offset
                STA     _Sys_BlkTmp
                INY
                INY
                SEP     #$20
                MX      %10
                LDA     [_libcTmp2],Y           ; +2 = the path's bank
                STA     _Sys_PathBank
                REP     #$20
                MX      %00
                LDA     _Sys_BlkTmp
                RTS

;------------------------------------------------------------------------------
; _Sys_Open (#5) - open(path, flags, mode) → fd.
; A = path offset, X = flags, Y = mode.
;
; Honours: O_CREAT  → try Fs_Create first, fall back to Fs_Open if EEXIST.
;          O_APPEND → after open, seek the FCB position to EOF so the next
;                     SYS_WRITE extends the file rather than overwriting.
;------------------------------------------------------------------------------
_Sys_Open       MX      %00
                ; Save flags (X) since CopyPathToBuf clobbers it.  Stash in a
                ; dedicated slot — _shTmp0 gets eaten by Fs_Create/Fs_Open's
                ; internal _Fcb_LookupPtr.
                STX     _Sys_OpenFlags
                STY     _Sys_OpenMode
                JSR     _Sys_CopyPathToBuf
                BCC     @open_plok
                JMP     _Sys_PathTooLong
@open_plok

                ; --- THE CREATE MODE, MASKED WHERE RENO MASKS IT ---
                ; `cmode = ((uap->crtmode &~ u.u_cmask) & 07777) &~ S_ISVTX'
                ; (4.3BSD-Reno kern/vfs_syscalls.c:559).  The two ANDs are one
                ; here: 07777 &~ 01000 is $0DFF.  Unconditional, as upstream's
                ; is -- vn_open consults cmode only on its FCREAT arm, so an
                ; ordinary open computes a value nothing reads.
                ;
                ; A TWO-ARGUMENT open(2) LANDS WHATEVER WAS IN Y HERE, and that
                ; is 2.11BSD's bargain too: its stub passes three words whether
                ; the caller supplied three or not.  Harmless without O_CREAT,
                ; a caller bug with it, on both systems.
                LDA     _Sys_OpenMode
                JSR     _Sys_ApplyCmask         ; &~ u_cmask
                AND     #$0DFF                  ; & 07777, &~ S_ISVTX
                STA     _Sys_OpenMode

                ; --- THE ROOT, WITH THE CALLER'S OWN FLAGS -- apple/fgx#318 ---
                ; BEFORE THE O_CREAT BRANCH: vn_open honours FCREAT, FTRUNC
                ; and FEXCL itself, so whoever claims the name owns the whole
                ; open.  A root hook below that branch never sees a create --
                ; `Fs_Create' meets the path first and the legacy resolver
                ; answers for a volume it does not own.
                ;
                ; Fs_Open's OWN root hook is a different one and passes FS_FREAD
                ; alone: it serves Load_Binary and Mod_LoadConf, which carry no
                ; O_ flags.  On this path it is reached second and misses, which
                ; costs one call and a branch.
                LDA     _Sys_OpenFlags
                INC                             ; fmode = flags + 1 (Reno's
                                                ;   `mode - FOPEN'; kern/
                                                ;   vfs_syscalls.c:559 and
                                                ;   include/fs.s)
                LDX     #_Sys_PathBuf
                LDY     _Sys_OpenMode           ; the masked create mode
                JSR     _Fs_RootOpen
                BCS     @op_gotFd
                ; A REFUSAL IS AN ANSWER; A MISS IS NOT (UFS 2.6).  Without
                ; this the permission checks are unreachable: `_Fs_RootOpen'
                ; returns C=0 for BOTH "not my name" and "mine, and no", this
                ; site read only the CARRY, and so an EACCES from `ufs_access'
                ; fell through to the legacy ProDOS resolver -- which has no
                ; permission model and opened the file anyway.
                ;
                ; MEASURED, because it looked like the check never ran: with
                ; kc_curuid forced to 77, `echo x > /etc/version' still
                ; answered 0.  The check HAD refused; the refusal was being
                ; discarded one frame up.
                ;
                ; THE ROOT'S ANSWER IS FINAL, whatever it is.  There is one
                ; namespace: every device is an inode on the root, and a name
                ; the root does not have is a name that is not there.
                ;
                ; THE TEST IS AGAINST ZERO AND NOT AGAINST A PARTICULAR ERRNO,
                ; which is `Fs_Open's own root hook's rule (fs.s, "THE TEST IS
                ; AGAINST ZERO AND NOT AGAINST ENXIO"): `_Fs_RootOpen' has
                ; already folded "no root mounted" into zero, so a machine with
                ; no root falls through to the legacy resolver and everything
                ; else is the root's answer.
                ;
                ; A WRONG ERRNO IS NOT COSMETIC, because callers BRANCH on it
                ; -- elvis keeps the filename it was given only when a failed
                ; open reports exactly ENOENT (apple/fgx#318).
                CMP     #0
                BEQ     @op_notDev
                BRL     @op_done                ; C=0, A = the root's errno
@op_gotFd       RTS                             ; C=1, A = fd
@op_notDev      ; NO ROOT MOUNTED, and nothing answers after that.
                ; `_Fs_RootOpen' folds root_open's ROUTING answer -- ENXIO --
                ; into zero for a caller that once had a legacy resolver to try
                ; next.  There is none, so the fold is undone here and the
                ; caller gets what root_open said.
                ;
                ; O_CREAT, O_EXCL and O_APPEND are the ROOT's business now:
                ; root_open takes the create mode, and FAPPEND is applied per
                ; write by `vn_write' (vfs_vnops.c:480), which is upstream's
                ; arrangement rather than a seek at open time.
                LDA     #ENXIO
@op_done        CLC                     ; error-only; success exits at @op_gotFd
                RTS

;------------------------------------------------------------------------------
; _Sys_Read (#3) - read(fd, buf, count) -> bytes_read.
; A = fd, X = buf offset (in caller bank), Y = count.
; _Sys_Readv (#122) - readv(fd, iov, iovcnt) -> bytes_read.
; A = fd, X = the iovec array's offset (in caller bank), Y = iovcnt.
;
; 2.11BSD's shape (sys_generic.c:38-79): each builds the task's uio -- one
; entry over the buffer, or the copied vector -- and _Sys_RdUio is rwuio: look
; up fd -> FCB and hand the uio to the descriptor's FO_READ ONCE.  A vnode
; crosses to the far bank; a socket or a pipe runs its arm here.
; Bad fd / empty slot -> EBADF.
;------------------------------------------------------------------------------
_Sys_Readv      MX      %00
                JSR     _Sys_CaptureRestartArgs ; see _Sys_Read's note
                AND     #$00FF
                STA     _Sys_RdFd
                LDA     #UIO_READ
                JSR     _Sys_UioVec             ; C=0 + A = EINVAL
                BCS     _Sys_RdUio
                RTS

_Sys_Read       MX      %00
                ; RESTART ARGS, CAPTURED HERE AND NOWHERE LATER (apple/fgx#105).
                ; The mark sites are past a _sleep, and syscall.s's own note at
                ; the select block says _Sys_SavedA and its neighbours are NOT in
                ; swtch's per-task carryover -- a concurrent task's syscall
                ; overwrites them while this read is blocked.  Capturing at the
                ; EINTR site therefore captured ANOTHER TASK's arguments, and a
                ; foreign X is a buffer offset into this caller's own bank: a
                ; memory-corruption class, not a wrong return value.  So the
                ; capture happens before the syscall can block, into per-task
                ; storage, and the mark sites only raise the flag.
                JSR     _Sys_CaptureRestartArgs
                AND     #$00FF
                STA     _Sys_RdFd               ; fd (caller's A; survives Fs_Read)
                STX     _Sys_RdBufOff           ; caller-bank buf offset (saved
                                                ; across _Fcb_LookupPtr)
                STY     _Sys_RdRem              ; running count
                STY     _Sys_RdMax              ; total (return value)
                STZ     _Sys_BytesRead
                TXA                             ; A = buffer
                TYX                             ; X = count
                LDY     #UIO_READ
                JSR     _Sys_UioOne             ; u.u_ttyuio: one entry
_Sys_RdUio      MX      %00                     ; readv(2) joins here
                SEP     #$20
                MX      %10
                LDA     _Sys_RdFd
                JSR     _Fcb_LookupPtr
                BCS     @rd_haveFcb
                REP     #$20
                MX      %00
                LDA     #EBADF
                CLC
                RTS
@rd_haveFcb     MX      %10
                REP     #$20
                MX      %00
                ; DISPATCH THROUGH f_ops ON THE DESCRIPTOR.  Same shape as
                ; write's; the arms find the uio in the u-area (_Sys_UUio).
                LDA     _Sys_RdFd
                AND     #$00FF
                LDX     #FO_READ
                JSR     _Fcb_OpEntry
                BCC     @rd_notArm
                DEC
                PHA
                RTS

                ; A DESCRIPTOR WHOSE OPS ARE IN ANOTHER BANK HAS NO ARM HERE --
                ; UFS 1.7d I3.  /dev's nodes name `vnops', which is far-bank C,
                ; and the offset in their f_ops means nothing in this bank: the
                ; PHA/RTS above would land at that offset in the CORE bank.  So
                ; the whole read crosses instead, to the same vfs_read the seam
                ; self-test drives.  The contract is identical -- C=1 and A =
                ; bytes moved, C=0 and A = errno.
@rd_notArm      LDA     _fdOpsFar
                BEQ     @rd_noops
                LDA     _Sys_RdFd
                AND     #$00FF
                JSR     _Sys_DevUio
                BCS     @rd_devRet
                ; EINTR IS A RESTART, 2.11BSD rwuio (sys_generic.c:152-162):
                ; a sleep interrupted with `uio_resid == count' returns and the
                ; call is re-entered.  An error here already means nothing
                ; moved -- dev_rw answers the count in preference once any
                ; byte has -- which is _Sys_MarkRestart's precondition.
                CMP     #EINTR
                BNE     @rd_devErr
                JSR     _Sys_MarkRestart
@rd_devErr      CLC
@rd_devRet      RTS

@rd_noops       SEP     #$20
                MX      %10
                LDA     #EBADF
                STA     _errno
                REP     #$30
                MX      %00
                LDA     #EBADF
                CLC
                RTS

_RdOp_Pipe        ; FCB_FL_PIPE fd: read == pipe_rw(fp, uio) with UIO_READ.
                JSR     _Sys_UUio               ; _libcTmp2 = &u.u_ttyuio
                LDA     _libcTmp2
                STA     _pipeUio
                LDA     _libcTmp2+2
                AND     #$00FF
                STA     _pipeUioBank
                LDA     _Sys_RdFd
                AND     #$00FF
                JMP     _Pipe_Read              ; -> A=bytes(0=EOF)/C
_RdOp_Socket      ; FCB_FL_SOCKET fd: read == sorw(fp, uio) == soreceive(so, 0, uio, 0).
                LDA     _Sys_RdFd
                JSR     _Sock_FdToDesc          ; C=1 + Y=desc + _sockTmpHw / C=0
                BCC     @rd_sockErr
                STY     _sockTmpOff
                JSR     _Sys_UUio               ; _libcTmp2 = &u.u_ttyuio
                JSR     _Sock_StageUio
                STZ     _sockRecvFlags          ; the transports honour SOCK_NB
                LDY     #NETOP_SoRead
                JMP     _Net_Dispatch
@rd_sockErr     MX      %00
                CLC
                RTS


;------------------------------------------------------------------------------
; _Sys_Close (#6) - close(fd).
;------------------------------------------------------------------------------
_Sys_Close      MX      %00
                AND     #$00FF
                JSR     Fs_Close
                RTS

;------------------------------------------------------------------------------
; _Sys_Lseek (#19) - lseek(fd, offset, whence).
;
; Args (caller MX %00):
;   A.lo = fd, A.hi = whence (SEEK_SET=0, SEEK_CUR=1, SEEK_END=2)
;   X    = offset.lo16 (bits 0..15)
;   Y    = offset.hi16 (bits 16..31)
;
; Returns:
;   C=1: A = newpos.lo16, Y = newpos.hi16
;   C=0: A = errno (EBADF, ESPIPE, EINVAL, EIO)
;
; Note on Y vs X: the dispatcher's exit path overwrites X with _Sys_UserSP
; for the TXS that restores caller SP, so any X returned by the handler is
; lost.  Y survives the exit, so Fs_Lseek returns the position's high word
; in Y instead.
;
; THE OFFSET IS A SIGNED 32-BIT off_t, 2.11BSD's own width for it, so a
; backwards SEEK_CUR is expressible -- see Fs_Lseek's header for the
; upstream citation.
;------------------------------------------------------------------------------
_Sys_Lseek      MX      %00
                ; A holds packed (whence:hi | fd:lo).  Stash, extract whence,
                ; then narrow A to fd for Fs_Lseek.
                STA     _shTmp0
                XBA
                AND     #$00FF
                STA     _fsLsWhence
                LDA     _shTmp0
                AND     #$00FF
                JSR     Fs_Lseek
                RTS

;------------------------------------------------------------------------------
; _Sys_Unlink (#10) - unlink(path).
;------------------------------------------------------------------------------
_Sys_Unlink     MX      %00
                JSR     _Sys_CopyPathToBuf
                BCC     @unl_plok
                JMP     _Sys_PathTooLong
@unl_plok
                ; --- THE ROOT'S unl -- apple/fgx#318 ---
                ; root_unl(pid, path), fcc right to left: the path goes down
                ; first and pid ends nearest the return.  SIX ARGUMENT BYTES,
                ; which is what the seam entry drops.
                SEP     #$20
                MX      %10
                LDA     #0
                PHA                             ; path: pad
                PHK                             ;       bank -- the LIVE one,
                                                ;       never a `^' literal
                REP     #$30
                MX      %00
                PEA     _Sys_PathBuf            ;       offset
                JSR     _Fcb_OwnerPid           ; not _curTask -- see fcb.s
                PHA                             ; pid
_kfp970         JSL     KFAR_VFS_ROOTUNLINK
                TAY                             ; park the errno; TSC needs A
                TSC
                CLC
                ADC     #6                      ; drop the copy -- caller cleans
                TCS
                TYA
                BNE     @unl_err
                SEC                             ; 0 = done
                RTS
@unl_err     AND     #$00FF
                CLC
                RTS


;------------------------------------------------------------------------------
; _Sys_Mkdir (#92) - mkdir(path, mode).  A = path (caller bank), X = mode; the
; path is copied into the kernel's path buffer.
;------------------------------------------------------------------------------
_Sys_Mkdir      MX      %00
                ; THE MODE ARRIVES IN X, NAMED RATHER THAN GUESSED.  This
                ; routine's header said A.lo and was wrong: libc's
                ; mkdir(path, mode) passes it third through __syscall_db, which
                ; is X.  It is stashed before _Sys_CopyPathToBuf, which
                ; clobbers X.
                STX     _Sys_OpenMode           ; SYS_OPEN's cell; the two
                                                ;   creating syscalls never
                                                ;   overlap in one trap
                JSR     _Sys_CopyPathToBuf
                BCC     @mkd_plok
                JMP     _Sys_PathTooLong
@mkd_plok

                ; --- THE ROOT'S mkdir -- apple/fgx#318 ---
                ; root_mkdir(pid, path, mode): mode is the RIGHTMOST argument
                ; and so goes down FIRST.  EIGHT ARGUMENT BYTES.
                ;
                ; THE MODE IS THE CALLER'S NOW, MASKED THE WAY RENO MASKS IT:
                ; `vattr.va_mode = (uap->dmode & 0777) &~ u.u_cmask'
                ; (kern/vfs_syscalls.c:1518).  0777 AND NOT 07777 -- mkdir
                ; keeps three digits where open keeps four, which is upstream's
                ; asymmetry and not a slip.  It was hardcoded 0777 while
                ; ProDOS had no mode bits to put a mode in, and that is what
                ; made every new directory drwxrwxrwx with the umask ignored.
                LDA     _Sys_OpenMode
                AND     #$01FF                  ; & 0777
                JSR     _Sys_ApplyCmask         ; &~ u_cmask
                PHA                             ; mode
                SEP     #$20
                MX      %10
                LDA     #0
                PHA                             ; path: pad
                PHK                             ;       bank
                REP     #$30
                MX      %00
                PEA     _Sys_PathBuf            ;       offset
                JSR     _Fcb_OwnerPid
                PHA                             ; pid
_kfp971         JSL     KFAR_VFS_ROOTMKDIR
                TAY
                TSC
                CLC
                ADC     #8                      ; four words, not three
                TCS
                TYA
                BNE     @mkd_err
                SEC
                RTS
@mkd_err        AND     #$00FF
                CLC
                RTS

;------------------------------------------------------------------------------
; _Sys_Fchdir (#115) - fchdir(fd).  A = fd (low byte).
;------------------------------------------------------------------------------
_Sys_Fchdir     MX      %00
                AND     #$00FF
                PHA                             ; fd
                JSR     _Fcb_OwnerPid           ; not _curTask -- see fcb.s
                PHA                             ; pid
_kfp988         JSL     KFAR_VFS_FCHDIR
                TAY                             ; park the errno; TSC needs A
                TSC
                CLC
                ADC     #4                      ; drop the copy -- caller cleans
                TCS
                TYA
                BNE     @fch_err
                SEC                             ; 0 = done
                RTS
@fch_err        AND     #$00FF
                CLC
                RTS

;------------------------------------------------------------------------------
_Sys_Utime      MX      %00
                ; A = path offset, X = times offset -- BOTH in the caller's data
                ; bank, which is stat(2)'s model and is why the ABI changed: two
                ; 32-bit epoch times do not fit in X and Y, and the pair that did
                ; fit was a PACKED ProDOS date and time with no access time at
                ; all.  libc stages the path in _libc_lstrBufB and the two
                ; time_t in _libc_lstrBufA, so one _Sys_CallerBank serves both.
                STX     _shTmp1                 ; times offset, before the copy
                JSR     _Sys_CopyPathToBuf      ; clobbers X/Y
                BCC     @utm_plok
                JMP     _Sys_PathTooLong
@utm_plok

                ; Read the two time_t out of the caller's bank into kernel
                ; statics.  [_libcTmp2] = caller_bank : times offset.
                LDA     _shTmp1
                STA     _libcTmp2
                SEP     #$20
                MX      %10
                LDA     _Sys_CallerBank
                STA     _libcTmp2+2
                REP     #$30
                MX      %00
                LDY     #0
                LDA     [_libcTmp2],Y
                STA     _utimeAtime
                LDY     #2
                LDA     [_libcTmp2],Y
                STA     _utimeAtime+2
                LDY     #4
                LDA     [_libcTmp2],Y
                STA     _utimeMtime
                LDY     #6
                LDA     [_libcTmp2],Y
                STA     _utimeMtime+2

                ; --- root_utimes(pid, path, atime, mtime) -- UFS 2.7 ---
                ; fcc right to left: mtime goes down first, then atime, then the
                ; path, and pid ends nearest the return.  FOURTEEN ARGUMENT
                ; BYTES, which is what the seam entry drops.
                LDA     _utimeMtime+2
                PHA                             ; mtime: hi word
                LDA     _utimeMtime
                PHA                             ;        lo word
                LDA     _utimeAtime+2
                PHA                             ; atime: hi word
                LDA     _utimeAtime
                PHA                             ;        lo word
                SEP     #$20
                MX      %10
                LDA     #0
                PHA                             ; path: pad
                PHK                             ;       bank -- the LIVE one,
                                                ;       never a `^' literal
                REP     #$30
                MX      %00
                PEA     _Sys_PathBuf            ;       offset
                JSR     _Fcb_OwnerPid           ; not _curTask -- see fcb.s
                PHA                             ; pid
_kfp987         JSL     KFAR_VFS_UTIMES
                TAY                             ; park the errno; TSC needs A
                TSC
                CLC
                ADC     #14                     ; drop the copy -- caller cleans
                TCS
                TYA
                BNE     @utm_err
                SEC                             ; 0 = done
                RTS
@utm_err        AND     #$00FF
                CLC
                RTS

;------------------------------------------------------------------------------
; _Sys_Rmdir (#94) - rmdir(path): remove an empty directory.  Path ptr in X
; (caller bank), copied to bank-$02, then _Fs_Rmdir.  Mirrors _Sys_Unlink.
;------------------------------------------------------------------------------
; _Sys_Access (#33) - access(path, mode).  A = path offset, X = mode.
;
; UFS campaign 2.6, apple/fgx#320 and #324.  Ported from 2.11BSD's saccess()
; (usr/sys/sys/ufs_syscalls.c:383); 4.3BSD-Reno's (kern/vfs_syscalls.c:911) was
; read beside it and vfs_access records where the two diverge.
;
; THE ID SWAP IS THE WHOLE POINT OF THE SYSCALL AND IT HAPPENS HERE.  access(2)
; answers for the REAL ids, not the effective ones, so a setuid program can ask
; what the person running it may do rather than what it may do itself.  Both
; upstreams implement that by ASSIGNMENT around the body -- 2.11BSD's
; `u.u_uid = u.u_ruid' and Reno's `cred->cr_uid = p->p_ruid' -- and this does
; the same.  It is done in the CORE because the u-area is the core's; the check
; itself runs in the far bank and reads the effective ids back through
; kc_curuid/kc_curgid, so it needs no argument and no cred.
;
; THE RESTORE MUST HAPPEN ON EVERY PATH, which is why the errno is parked
; across it: leaving a process with its effective ids set to its real ones is a
; privilege LOSS that would show up later and somewhere else.  $FFFF in the
; saved uid means there was no u-area to swap (boot context), so there is
; nothing to put back.
_Sys_Access     MX      %00
                STX     _Sys_AccMode
                JSR     _Sys_CopyPathToBuf
                BCC     @acc_plok
                JMP     _Sys_PathTooLong
@acc_plok
                JSR     _Sys_AccSwapIn
                ; root_access(pid, path, fmode), fcc right to left: fmode goes
                ; down first and pid ends nearest the return.  EIGHT ARGUMENT
                ; BYTES, which is what the seam entry drops.
                LDA     _Sys_AccMode
                PHA                             ; fmode
                SEP     #$20
                MX      %10
                LDA     #0
                PHA                             ; path: pad
                PHK                             ;       bank -- the LIVE one
                REP     #$30
                MX      %00
                PEA     _Sys_PathBuf            ;       offset
                JSR     _Fcb_OwnerPid           ; not _curTask -- see fcb.s
                PHA                             ; pid
_kfp991         JSL     KFAR_VFS_ACCESS         ; bank byte patched by Far_Init
                TAY                             ; park the errno; TSC needs A
                TSC
                CLC
                ADC     #8                      ; drop the copy -- caller cleans
                TCS
                TYA
                PHA                             ; keep it across the restore
                JSR     _Sys_AccSwapOut
                PLA
                BNE     @acc_err
                SEC                             ; 0 = permitted
                RTS
@acc_err        AND     #$00FF
                CLC
                RTS

; _Sys_AccSwapIn / _Sys_AccSwapOut - effective ids <-> real ids, saved aside.
_Sys_AccSwapIn  MX      %00
                LDA     #$FFFF
                STA     _Sys_AccSvUid           ; assume no u-area
                JSR     _Uarea_Cur
                BCC     @asi_none
                LDY     #U_Uid
                LDA     [_u],Y
                STA     _Sys_AccSvUid
                LDY     #U_Gid
                LDA     [_u],Y
                STA     _Sys_AccSvGid
                LDY     #U_Ruid
                LDA     [_u],Y
                LDY     #U_Uid
                STA     [_u],Y                  ; effective := real
                LDY     #U_Rgid
                LDA     [_u],Y
                LDY     #U_Gid
                STA     [_u],Y
@asi_none       RTS

_Sys_AccSwapOut MX      %00
                LDA     _Sys_AccSvUid
                CMP     #$FFFF
                BEQ     @aso_none               ; nothing was swapped
                JSR     _Uarea_Cur
                BCC     @aso_none
                LDA     _Sys_AccSvUid
                LDY     #U_Uid
                STA     [_u],Y
                LDA     _Sys_AccSvGid
                LDY     #U_Gid
                STA     [_u],Y
@aso_none       RTS

_Sys_Rmdir      MX      %00
                JSR     _Sys_CopyPathToBuf
                BCC     @rmd_plok
                JMP     _Sys_PathTooLong
@rmd_plok
                ; --- THE ROOT'S rmd -- apple/fgx#318 ---
                ; root_rmd(pid, path), fcc right to left: the path goes down
                ; first and pid ends nearest the return.  SIX ARGUMENT BYTES,
                ; which is what the seam entry drops.
                SEP     #$20
                MX      %10
                LDA     #0
                PHA                             ; path: pad
                PHK                             ;       bank -- the LIVE one,
                                                ;       never a `^' literal
                REP     #$30
                MX      %00
                PEA     _Sys_PathBuf            ;       offset
                JSR     _Fcb_OwnerPid           ; not _curTask -- see fcb.s
                PHA                             ; pid
_kfp972         JSL     KFAR_VFS_ROOTRMDIR
                TAY                             ; park the errno; TSC needs A
                TSC
                CLC
                ADC     #6                      ; drop the copy -- caller cleans
                TCS
                TYA
                BNE     @rmd_err
                SEC                             ; 0 = done
                RTS
@rmd_err     AND     #$00FF
                CLC
                RTS


;------------------------------------------------------------------------------
; _Sys_Rename (#95) - rename(from, to).  A = argblk offset: +0 from, +4 to,
; each a FAR pointer (apple/fgx#438).  Old shape: A = FROM, X = TO, one bank.
; offset (both in the caller bank).  Copies both into kernel-bank buffers and
; calls _Fs_Rename, which resolves TO first (staged canonical -> _renDstPath),
; then FROM (canonical left in _fsPathScratch for the module's walkPath).
;------------------------------------------------------------------------------
_Sys_Rename     MX      %00
                ; A = argblk offset: +0 the first path, +4 the second, each a
                ; FAR pointer naming its own bank (apple/fgx#438).
                ;--- Copy TO path into _Sys_PathBuf2. ---
                LDY     #4
                JSR     _Sys_PathBlkArg
                JSR     _Sys_CopyPathToBuf2     ; TO -> _Sys_PathBuf2
                BCC     @ren1_plok
                JMP     _Sys_PathTooLong
@ren1_plok
                ;--- Copy FROM path into _Sys_PathBuf. ---
                LDY     #0
                JSR     _Sys_PathBlkArg
                JSR     _Sys_CopyPathToBuf      ; FROM -> _Sys_PathBuf
                BCC     @ren2_plok
                JMP     _Sys_PathTooLong
@ren2_plok
                ; --- THE ROOT'S rename -- rename(2) at last.
                ; root_rename(pid, from, to), fcc right to left: `to' goes down
                ; first and pid ends nearest the return.  TEN ARGUMENT BYTES,
                ; which is what the seam entry drops.
                SEP     #$20
                MX      %10
                LDA     #0
                PHA                             ; to: pad
                PHK                             ;     bank -- the LIVE one
                REP     #$30
                MX      %00
                PEA     _Sys_PathBuf2           ;     offset
                SEP     #$20
                MX      %10
                LDA     #0
                PHA                             ; from: pad
                PHK                             ;       bank
                REP     #$30
                MX      %00
                PEA     _Sys_PathBuf            ;       offset
                JSR     _Fcb_OwnerPid           ; not _curTask -- see fcb.s
                PHA                             ; pid
_kfp976         JSL     KFAR_VFS_ROOTRENAME
                TAY                             ; park the errno; TSC needs A
                TSC
                CLC
                ADC     #10                     ; drop the copy -- caller cleans
                TCS
                TYA
                BNE     @ren_err
                SEC                             ; 0 = done
                RTS
@ren_err     AND     #$00FF
                CLC
                RTS

;------------------------------------------------------------------------------
; _Sys_Mount (#21) - mount(type, dir, flags, data).  A = caller-bank offset of
; libc's four-word argument block: [0] type [2] dir offset [4] flags [6] data
; offset, both strings in the caller bank.
;
; 2.11BSD's NUMBER AND 4.3BSD-Reno's ARGUMENTS.  2.11BSD's slot is `3, smount,
; /*  21 = mount */' (usr/sys/sys/init_sysent.c:131) over `{ char *fspec; char
; *freg; int flags; }', and it has no type because a 2.11BSD kernel has one
; filesystem.  Reno's is `mount(type, dir, flags, data)' (kern/vfs_syscalls.c)
; and this kernel has a type switch, so Reno's wins.  Four arguments do not fit
; three registers, which is why the block: SYS_SYSCTL is marshalled the same
; way.
;
; `data' IS STAGED AS A STRING, the device path, because that is what the one
; filesystem type reads from it -- ufs_mount's header says why a UFS `data' is
; not Reno's `struct ufs_args'.  A filesystem whose `data' is a structure
; changes this copy.
;
; dvp IS ZERO -- namei's convention for the system root -- so the mount point
; must be ABSOLUTE.  mount(8) resolves relative names itself; fstab(5) lines
; are absolute by construction.
;
; EIGHTEEN ARGUMENT BYTES, and the seam entry copies nine words.
;------------------------------------------------------------------------------
_Sys_Mount      MX      %00
                ; MUST BE SUPER USER, which is both upstreams' first act:
                ; 2.11BSD gates mount AND umount in the one routine that
                ; resolves the device for them -- `if (!suser()) return
                ; (u.u_error);' in getmdev (usr/sys/sys/ufs_mount.c:331, called
                ; from smount at :28 and umount at :274) -- and 4.3BSD-Reno
                ; writes it out at the head of each, under the comment "Must be
                ; super user" (kern/vfs_syscalls.c:63 and :209).
                ;
                ; BEFORE THE BLOCK IS READ, so a refusal reads nothing of the
                ; caller's; the block offset is stashed first because _Suser
                ; clobbers A and Y.
                ;
                ; IT IS GATED HERE AND NOT IN vfs_mountat because _Suser is the
                ; chokepoint this kernel keeps for the purpose, and the far
                ; bank would have to reach the u-area across the seam to ask
                ; the same question.
                ;
                ; WITHOUT IT AN UNPRIVILEGED CALLER COULD BRING ITS OWN ROOT:
                ; exec honours a set-user-ID bit since apple/fgx#416, so a
                ; volume carrying a set-user-ID-root shell is a root shell to
                ; anyone who can mount it.  MNT_NOSUID exists but is the
                ; CALLER's to pass, so it defends nothing here.
                JSR     _Suser
                BCS     @mnt_priv
                LDA     #EPERM
                CLC
                RTS
                ; THE BLOCK IS {type(2), flags(2), dir(4), data(4)} AND THE
                ; TWO PATHS ARE FAR POINTERS (apple/fgx#438).  They were bare
                ; 16-bit offsets read from _Sys_CallerBank, which is one bank
                ; for the whole call -- and mount(8) passes a path from argv,
                ; which apple/fgx#301 moved to the kernel's bank-0 frame, while
                ; the block itself is a libc static in the data bank.  One bank
                ; could not name both, so `mount /dev/sd1 /mnt' answered ENOENT
                ; for a device that was there.
@mnt_priv       LDA     _Sys_SavedA             ; [_libcTmp2] = caller_bank:block
                STA     _libcTmp2
                SEP     #$20
                MX      %10
                LDA     _Sys_CallerBank         ; the BLOCK is co-bank with DBR
                STA     _libcTmp2+2
                REP     #$30
                MX      %00
                LDY     #0
                LDA     [_libcTmp2],Y
                STA     _Sys_MntType            ; [0] type
                LDY     #2
                LDA     [_libcTmp2],Y
                STA     _Sys_MntFlags           ; [2] flags
                LDY     #4                      ; [4] dir, a far pointer
                JSR     _Sys_PathBlkArg
                JSR     _Sys_CopyPathToBuf2     ; DIR -> _Sys_PathBuf2
                BCC     @mnt1_plok
                JMP     _Sys_PathTooLong
@mnt1_plok
                LDY     #8                      ; [8] data, a far pointer
                JSR     _Sys_PathBlkArg
                JSR     _Sys_CopyPathToBuf      ; DATA -> _Sys_PathBuf
                BCC     @mnt2_plok
                JMP     _Sys_PathTooLong
@mnt2_plok

                ; vfs_mountat(pid, dvp, type, dir, flags, data), fcc right to
                ; left: data goes down first and pid ends nearest the return.
                SEP     #$20
                MX      %10
                LDA     #0
                PHA                             ; data: pad
                PHK                             ;       bank -- the LIVE one
                REP     #$30
                MX      %00
                PEA     _Sys_PathBuf            ;       offset (the device)
                LDA     _Sys_MntFlags
                PHA                             ; flags
                SEP     #$20
                MX      %10
                LDA     #0
                PHA                             ; dir: pad
                PHK                             ;      bank
                REP     #$30
                MX      %00
                PEA     _Sys_PathBuf2           ;      offset
                LDA     _Sys_MntType
                PHA                             ; type
                PEA     $0000                   ; dvp hi: null = the system root
                PEA     $0000                   ; dvp lo
                JSR     _Fcb_OwnerPid
                PHA                             ; pid
_kfp984         JSL     KFAR_VFS_MOUNT
                TAY
                TSC
                CLC
                ADC     #18
                TCS
                TYA
                BNE     @mnt_err
                SEC                             ; 0 = done
                RTS
@mnt_err        AND     #$00FF
                CLC
                RTS

;------------------------------------------------------------------------------
; _Sys_Umount (#22) - umount(spec).  A = SPEC offset in the caller bank.
;
; ONE ARGUMENT AND IT IS THE DEVICE, which is 2.11BSD's interface rather than
; Reno's: `1, umount, /*  22 = umount */' over `unmount1(uap->fspec)'.  Reno's
; unmount(2) takes the mount POINT instead, and the disagreement is visible
; from userland -- vfs_unmountdev's header carries which ancestor won and why
; (umount(8) normalises to `f_mntfromname' before calling, so a kernel taking
; the directory could not run the tool verbatim).
;
; NO FLAGS, and upstream has none either.  vfs_unmountdev takes them because
; vfs_dounmount below it does; zero is what MNT_FORCE's absence looks like.
;------------------------------------------------------------------------------
_Sys_Umount     MX      %00
                ; MUST BE SUPER USER -- see _Sys_Mount above; 2.11BSD gates
                ; both calls in the one getmdev (usr/sys/sys/ufs_mount.c:331)
                ; and Reno writes it out again at kern/vfs_syscalls.c:209.
                ;
                ; THE SPEC OFFSET IS PARKED ACROSS THE CALL: it arrives in A and
                ; _Suser clobbers A and Y.
                PHA
                JSR     _Suser
                PLA
                BCS     @umt_priv
                LDA     #EPERM
                CLC
                RTS
@umt_priv
                JSR     _Sys_CopyPathToBuf      ; SPEC -> _Sys_PathBuf
                BCC     @umn_plok
                JMP     _Sys_PathTooLong
@umn_plok

                ; vfs_unmountdev(pid, spec, flags): flags down first.  EIGHT
                ; ARGUMENT BYTES.
                PEA     $0000                   ; flags = 0
                SEP     #$20
                MX      %10
                LDA     #0
                PHA                             ; spec: pad
                PHK                             ;       bank
                REP     #$30
                MX      %00
                PEA     _Sys_PathBuf            ;       offset
                JSR     _Fcb_OwnerPid
                PHA                             ; pid
_kfp985         JSL     KFAR_VFS_UNMOUNTDEV
                TAY
                TSC
                CLC
                ADC     #8
                TCS
                TYA
                BNE     @umn_err
                SEC
                RTS
@umn_err        AND     #$00FF
                CLC
                RTS

;------------------------------------------------------------------------------
; _Sys_Link (#9) - link(target, linkname).  A = argblk offset: +0 target,
; +4 linkname, each a FAR pointer naming its own bank (apple/fgx#438).
;
; 2.11BSD's own number -- `2, link, /*   9 = link */' (usr/sys/sys/
; init_sysent.c:119) -- and the table slot had been kept for it.
;
; _Sys_Symlink's SHAPE EXACTLY, and both paths are copied into kernel-bank
; buffers for its reason: the far bank cannot read the caller's bank, and one
; `_Sys_CallerBank' cannot describe two banks anyway -- which is why each path
; arrives as a far pointer in an argument block now (apple/fgx#438).
;
; BUT BOTH ARE PATHS HERE, WHICH symlink's TARGET IS NOT.  A symlink's target
; is the link's CONTENTS and is written uninterpreted; link(2) resolves both
; names, the first with FOLLOW so that linking a symlink links what it points
; at.  Same copying, different meaning, and vfs_link's header carries the walk.
;------------------------------------------------------------------------------
_Sys_Link       MX      %00
                ; A = argblk offset: +0 the first path, +4 the second, each a
                ; FAR pointer naming its own bank (apple/fgx#438).
                LDY     #4
                JSR     _Sys_PathBlkArg
                JSR     _Sys_CopyPathToBuf2     ; LINKNAME -> _Sys_PathBuf2
                BCC     @lnk1_plok
                JMP     _Sys_PathTooLong
@lnk1_plok
                LDY     #0
                JSR     _Sys_PathBlkArg
                JSR     _Sys_CopyPathToBuf      ; TARGET   -> _Sys_PathBuf
                BCC     @lnk2_plok
                JMP     _Sys_PathTooLong
@lnk2_plok

                ; root_link(pid, target, linkname), fcc right to left:
                ; linkname goes down first.  TEN ARGUMENT BYTES.
                SEP     #$20
                MX      %10
                LDA     #0
                PHA                             ; linkname: pad
                PHK                             ;           bank -- the LIVE one
                REP     #$30
                MX      %00
                PEA     _Sys_PathBuf2           ;           offset
                SEP     #$20
                MX      %10
                LDA     #0
                PHA                             ; target: pad
                PHK                             ;         bank
                REP     #$30
                MX      %00
                PEA     _Sys_PathBuf            ;         offset
                JSR     _Fcb_OwnerPid
                PHA                             ; pid
_kfp982         JSL     KFAR_VFS_ROOTLINK
                TAY
                TSC
                CLC
                ADC     #10
                TCS
                TYA
                BNE     @lnk_err
                SEC                             ; 0 = done
                RTS
@lnk_err        AND     #$00FF
                CLC
                RTS

;------------------------------------------------------------------------------
; _Sys_Chmod (#15) - chmod(path, mode).   A = path offset, X = mode.
; _Sys_Chown (#16) - chown(path, uid, gid).  A = path, X = uid, Y = gid.
;
; 2.11BSD's OWN NUMBERS, from its dispatch table: `2, chmod, /* 15 = chmod */'
; and `3, chown, /* 16 = chown; now 3 args */' (usr/sys/sys/init_sysent.c:125).
; Both slots were _Sys_Stub and had been kept for these.
;
; ONE BODY WITH TWO HEADS, which is the shape one slot down as well:
; root_setattr takes both syscalls because 4.3BSD-Reno's chmod and chown are
; the same seven lines with a different vattr field set.  $FFFF is VA_UNSET --
; vnode.h's -1 -- and a field carrying it is LEFT ALONE, so each head fills its
; own and marks the other absent.  That is also how `chown f -1 20' reaches the
; group without touching the owner.
;
; THE TWO HEADS DISAGREE ABOUT SYMLINKS AND UPSTREAM IS WHY.  chmod resolves
; with FOLLOW and chown WITHOUT (Reno kern/vfs_syscalls.c:1136 against :1204):
; a symlink has no mode worth changing so chmod means the target, and a symlink
; DOES have an owner so 4.3BSD's chown means the link itself.  It reads like an
; inconsistency and is not.
;
; THE FOUR INTS GO DOWN BEFORE THE PATH IS COPIED, because they are in
; registers that _Sys_CopyPathToBuf clobbers and the path offset is the only
; thing that needs a cell.  Pushing early is free: fcc wants them deepest
; anyway, being the rightmost arguments.  FOURTEEN ARGUMENT BYTES.
;------------------------------------------------------------------------------
_Sys_Chmod      MX      %00
                STA     _Sys_SetaPath
                LDA     #$FFFF                  ; VA_UNSET
                PHA                             ; gid: leave it
                PHA                             ; uid: leave it
                PHX                             ; mode
                PEA     $0001                   ; follow: chmod means the TARGET
                BRA     _Sys_SetattrTail

_Sys_Chown      MX      %00
                STA     _Sys_SetaPath
                PHY                             ; gid
                PHX                             ; uid
                LDA     #$FFFF
                PHA                             ; mode: leave it
                PEA     $0000                   ; follow: chown means the LINK

_Sys_SetattrTail LDA    _Sys_SetaPath
                JSR     _Sys_CopyPathToBuf
                BCC     @sa_plok
                JMP     _Sys_PathTooLong
@sa_plok
                SEP     #$20
                MX      %10
                LDA     #0
                PHA                             ; path: pad
                PHK                             ;       bank -- the LIVE one
                REP     #$30
                MX      %00
                PEA     _Sys_PathBuf            ;       offset
                JSR     _Fcb_OwnerPid
                PHA                             ; pid
_kfp981         JSL     KFAR_VFS_ROOTSETATTR
                TAY
                TSC
                CLC
                ADC     #14
                TCS
                TYA
                BNE     @sa_err
                SEC                             ; 0 = done
                RTS
@sa_err         AND     #$00FF
                CLC
                RTS

;------------------------------------------------------------------------------
; _Sys_Symlink (#113) - symlink(target, linkname).  A = argblk offset: +0
; target, +4 linkname, each a FAR pointer (apple/fgx#438).  Both are copied into
; kernel-bank buffers, exactly as SYS_RENAME copies its two, and for the same
; reason: the far bank cannot read the caller's bank.
;
; THE TARGET IS NOT A PATH TO RESOLVE.  It is the link's CONTENTS, written into
; the inode uninterpreted, so it gets a buffer and no walk.
;------------------------------------------------------------------------------
_Sys_Symlink    MX      %00
                ; A = argblk offset: +0 the first path, +4 the second, each a
                ; FAR pointer naming its own bank (apple/fgx#438).
                LDY     #4
                JSR     _Sys_PathBlkArg
                JSR     _Sys_CopyPathToBuf2     ; LINKNAME -> _Sys_PathBuf2
                BCC     @sym1_plok
                JMP     _Sys_PathTooLong
@sym1_plok
                LDY     #0
                JSR     _Sys_PathBlkArg
                JSR     _Sys_CopyPathToBuf      ; TARGET   -> _Sys_PathBuf
                BCC     @sym2_plok
                JMP     _Sys_PathTooLong
@sym2_plok

                ; root_symlink(pid, target, linkname, mode), fcc right to left:
                ; the mode goes down first.  TWELVE ARGUMENT BYTES.  The mode
                ; is Reno's `0777 &~ u.u_cmask' (vfs_syscalls.c:805), masked
                ; here because the u-area is this bank's.
                LDA     #$01FF                  ; 0777
                JSR     _Sys_ApplyCmask
                PHA                             ; mode
                SEP     #$20
                MX      %10
                LDA     #0
                PHA                             ; linkname: pad
                PHK                             ;           bank -- the LIVE one
                REP     #$30
                MX      %00
                PEA     _Sys_PathBuf2           ;           offset
                SEP     #$20
                MX      %10
                LDA     #0
                PHA                             ; target: pad
                PHK                             ;         bank
                REP     #$30
                MX      %00
                PEA     _Sys_PathBuf            ;         offset
                JSR     _Fcb_OwnerPid
                PHA                             ; pid
_kfp977         JSL     KFAR_VFS_ROOTSYMLINK
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                BNE     @sym_err
                SEC                             ; 0 = done
                RTS
@sym_err     AND     #$00FF
                CLC
                RTS

;------------------------------------------------------------------------------
; _Sys_Ftruncate (#103) - ftruncate(fd, length).  A = fd (low byte),
; X = length bits 0..15, Y = length bits 16..23 (ProDOS EOF is 24-bit).
; The length is stashed before Fs_Truncate, whose _Fcb_LookupPtr needs A.
;------------------------------------------------------------------------------
_Sys_Ftruncate  MX      %00
                STX     _Sys_TrncLen            ; lo 16 bits
                STY     _Sys_TrncLen+2          ; hi 8 (bits 16..23; 24..31 ignored)
                AND     #$00FF                  ; A = fd
                STA     _Sys_TrncFd
                ; --- root_ftruncate(pid, fd, length) -- UFS 2.7 ---
                ; fcc right to left: the length goes down first, then the fd,
                ; and pid ends nearest the return.  EIGHT ARGUMENT BYTES, which
                ; is what the seam entry drops.
                LDA     _Sys_TrncLen+2
                PHA                             ; length: hi word
                LDA     _Sys_TrncLen
                PHA                             ;         lo word
                LDA     _Sys_TrncFd
                PHA                             ; fd
                JSR     _Fcb_OwnerPid           ; not _curTask -- see fcb.s
                PHA                             ; pid
_kfp986         JSL     KFAR_VFS_FTRUNCATE
                TAY                             ; park the errno; TSC needs A
                TSC
                CLC
                ADC     #8                      ; drop the copy -- caller cleans
                TCS
                TYA
                BNE     @ftr_err
                SEC                             ; 0 = done
                RTS
@ftr_err        AND     #$00FF
                CLC
                RTS

;------------------------------------------------------------------------------
; _Sys_Chdir (#12) - chdir(path).
;------------------------------------------------------------------------------
_Sys_Chdir      MX      %00
                JSR     _Sys_CopyPathToBuf
                BCC     @chd_plok
                JMP     _Sys_PathTooLong
@chd_plok
                LDX     #_Sys_PathBuf
                JSR     Fs_Chdir
                RTS


;------------------------------------------------------------------------------
; _Sys_Procs (SYS_PROCS = 87) - procs(buf, max) -> count.
;
; A = caller-bank buf offset; X = max records.  Fills buf with up to `max`
; PROCINFO_SIZE records {pid, ppid, pgid, state, name[16]} -- the kernel (pid 0,
; synthetic) followed by every live task slot.  Returns A = count, C=1.  MX %00.
;
; Caller-bank writes use [_libcTmp2] (= CallerBank:cursor), the _Sys_Getcwd idiom.
; Name bytes read from the heap name table via [_kCopyPtr], pre-biased by
; -PI_Name so one Y indexes both heap source and record dest.
;------------------------------------------------------------------------------
_Sys_Procs      MX      %00
                STA     _libcTmp2               ; record cursor lo = buf offset
                SEP     #$20
                LDA     _Sys_CallerBank
                STA     _libcTmp2+2
                REP     #$20
                STX     _shTmp0                 ; max records
                STZ     _shTmp1                 ; count = 0
                LDA     _shTmp0
                BEQ     @prc_done                ; max 0 -> nothing
                ; --- pid 0: the kernel (synthetic record) ---
                JSR     _sp_emitKernel
                ; --- live user task slots ---
                LDX     #FGX_TASK_TBL_OFF
                STZ     _shTmp2                 ; slot counter
@prc_L           LDA     _shTmp1
                CMP     _shTmp0
                BCS     @prc_done                ; buffer full
                LDA:    TCB_Status,X
                AND     #$00FF
                BEQ     @prc_next                ; UNUSED slot -> skip
                JSR     _sp_emitTcb             ; emit (X = TCB); preserves X
@prc_next        TXA
                CLC
                ADC     #TCB_SIZE
                TAX
                INC     _shTmp2
                LDA     _shTmp2
                CMP     #TASK_MAX_SLOTS
                BCC     @prc_L
@prc_done        LDA     _shTmp1                 ; count
                SEC
                RTS

;--- _sp_emitTcb: emit one record for the task at TCB X.  Preserves X. ---
_sp_emitTcb     MX      %00
                LDA:    TCB_TaskID,X
                AND     #$00FF
                STA     _libcTmp0               ; pid (scratch)
                LDY     #PI_Pid
                STA     [_libcTmp2],Y
                LDA:    TCB_ParentID,X
                LDY     #PI_PPid
                STA     [_libcTmp2],Y
                LDA:    TCB_Status,X
                LDY     #PI_State
                STA     [_libcTmp2],Y
                ; pgid = SE_PGroup[(pid-1)<<5]
                LDA     _libcTmp0
                DEC
                ASL
                ASL
                ASL
                ASL
                ASL                             ; (pid-1)<<5 = seoff
                CLC
                ADC     #SE_PGroup
                TAY
                LDA     [_schedTblPtr],Y
                LDY     #PI_PGid
                STA     [_libcTmp2],Y
                ; --- bank-0 stack: reservation + measured high-water mark ---
                ; The arena pair stays 0 here; only the pid-0 record carries it.
                LDA:    TCB_StackSize,X
                LDY     #PI_StkSize
                STA     [_libcTmp2],Y
                JSR     Task_StkHwm             ; A = peak bytes, X preserved
                LDY     #PI_StkHwm
                STA     [_libcTmp2],Y
                LDA     #0
                LDY     #PI_ArenaUsed
                STA     [_libcTmp2],Y
                LDY     #PI_ArenaFree
                STA     [_libcTmp2],Y
                ; --- heap: the high-water break at (dataBank:HEAP_HWM) ---
                ; The allocator's own cell, so this is the state itself and not a
                ; reconstruction.  _kCopyPtr is free here -- the name-source block
                ; below rebuilds it from scratch.
                ; A member of a fork's image group that is not holding the live
                ; banks keeps its own in its bank home (Img_DataBank).
                STZ     _kCopyPtr               ; long ptr = dataBank:$0000
                JSR     Img_DataBank            ; A = its bank; X kept
                SEP     #$20
                MX      %10
                STA     _kCopyPtr+2
                REP     #$30
                MX      %00
                AND     #$00FF
                BEQ     @prc_noHeap             ; no data bank -> report 0
                LDY     #HEAP_HWM
                LDA     [_kCopyPtr],Y           ; A = the high-water break
                BRA     @prc_haveHeap
@prc_noHeap     LDA     #0
@prc_haveHeap   LDY     #PI_HeapHwm
                STA     [_libcTmp2],Y

                ; --- the controlling terminal's NAME ---
                ; SEF_CTTY holds "tty index + 1" in bits 8..10, 0 = none.  The
                ; name is copied out of _ttyNames at TTYNAME_MAX stride, the
                ; table and stride FIODGNAME copies from, so the two answer
                ; alike; a task with no terminal gets a field of NULs.
                ;
                ; The sched-entry offset is rebuilt here rather than kept from
                ; the block above: every scratch word is spoken for, and _libcTmp0
                ; still holds the pid.  _kCopyPtr is not free -- the name block
                ; below builds it -- so nothing is parked in it.
                LDA     _libcTmp0
                DEC
                ASL
                ASL
                ASL
                ASL
                ASL                             ; (pid-1)<<5 = seoff
                CLC
                ADC     #SE_Flags
                TAY
                LDA     [_schedTblPtr],Y
                AND     #SEF_CTTY_MASK
                BEQ     @prc_noTty              ; A = 0: the field pads with NULs
                XBA                             ; bits 8..10 -> A.lo = index+1;
                                                ;   A.hi = the masked-out low byte, 0
                DEC                             ; stored as index+1
                ASL
                ASL
                ASL                             ; * TTYNAME_MAX (8)
                PHX                             ; X = the caller's TCB
                TAX
                SEP     #$20
                MX      %10
                LDY     #PI_TtyName
@prc_ttyL       LDA     _ttyNames,X
                STA     [_libcTmp2],Y
                INX
                INY
                CPY     #PI_TtyName+TTYNAME_MAX
                BCC     @prc_ttyL
                REP     #$20
                MX      %00
                PLX
                BRA     @prc_ttyDone
@prc_noTty      SEP     #$20
                MX      %10
                LDY     #PI_TtyName
@prc_ttyZ       STA     [_libcTmp2],Y           ; A.lo = 0 from the AND above
                INY
                CPY     #PI_TtyName+TTYNAME_MAX
                BCC     @prc_ttyZ
                REP     #$20
                MX      %00
@prc_ttyDone
                ; name source: _kCopyPtr = _procNameTblPtr + (pid<<4) - PI_Name
                LDA     _libcTmp0
                ASL
                ASL
                ASL
                ASL                             ; pid<<4
                SEC
                SBC     #PI_Name                ; -8 (align name[0] to record off 8)
                CLC
                ADC     _procNameTblPtr
                STA     _kCopyPtr
                SEP     #$20
                LDA     _procNameTblPtr+2
                ADC     #0
                STA     _kCopyPtr+2
                REP     #$20
                BRA     _sp_emitTail

;--- _sp_emitKernel: emit the synthetic pid-0 (kernel) record. ---
_sp_emitKernel  MX      %00
                ; THE RECORD IS ZEROED FIRST and only the cells that are not
                ; zero are written after.  The caller's buffer is its own
                ; memory and arrives with whatever was in it, so a field this
                ; routine does not write is not zero -- it is stale.
                ;
                ; Zero is also the honest answer for most of them: pid/ppid/pgid
                ; 0, no sbrk heap, no controlling terminal -- and for the stack
                ; pair ON PURPOSE.  The kernel runs on per-task kernel stacks
                ; and on the boot stack, none of them carved from
                ; FGX_STK_ARENA, so there is no honest per-pid number to put
                ; there and ps(1) prints `-' on this row rather than a made-up
                ; size.  What pid 0 CAN report is the arena itself, which is
                ; the figure the bank-0 campaign tracks ("123/147 pages") --
                ; the two cells below.
                LDA     #0
                LDY     #0
@prc_kzL        STA     [_libcTmp2],Y
                INY
                INY
                CPY     #PROCINFO_SIZE
                BCC     @prc_kzL
                LDY     #PI_State
                LDA     #TASK_RUNNING           ; kernel shown as R
                STA     [_libcTmp2],Y
                JSR     Task_StkArenaUsed       ; A = pages in use (clobbers X/Y)
                STA     _libcTmp0               ; scratch: free only for pid 0
                LDY     #PI_ArenaUsed
                STA     [_libcTmp2],Y
                LDA     #FGX_STK_ARENA_PAGES
                SEC
                SBC     _libcTmp0               ; total - used = free
                LDY     #PI_ArenaFree
                STA     [_libcTmp2],Y
                ; name source = nameTbl[0] - PI_Name = base - 8
                LDA     _procNameTblPtr
                SEC
                SBC     #PI_Name
                STA     _kCopyPtr
                SEP     #$20
                LDA     _procNameTblPtr+2
                SBC     #0                      ; borrow into bank
                STA     _kCopyPtr+2
                REP     #$20
                ; fall through to _sp_emitTail

;--- _sp_emitTail: copy 16 name bytes, advance cursor, count++.  Preserves X. ---
_sp_emitTail    MX      %00
                LDY     #PI_Name                ; Y = 8 (record name offset)
@prc_nameL      SEP     #$20
                LDA     [_kCopyPtr],Y           ; name[Y-8] (_kCopyPtr pre-biased -8)
                STA     [_libcTmp2],Y
                REP     #$20
                INY
                CPY     #PI_Name+PROC_NAME_MAX  ; 8 + 16 = 24
                BCC     @prc_nameL
                ; advance the record cursor by PROCINFO_SIZE; count++
                CLC
                LDA     _libcTmp2
                ADC     #PROCINFO_SIZE
                STA     _libcTmp2
                SEP     #$20
                LDA     _libcTmp2+2
                ADC     #0
                STA     _libcTmp2+2
                REP     #$20
                INC     _shTmp1
                RTS

;------------------------------------------------------------------------------
; _Sys_Stat (#18) - stat a path into a caller-bank buffer.
;
; Args:    A = path offset within caller's bank (NUL-term)
;          X = dst offset within caller's bank (must hold STAT_SIZE bytes)
; Returns: C=1 + A = STAT_SIZE (bytes written) on success.
;          C=0 + A = errno from Fs_Stat on failure (ENOENT, ENOTDIR,
;          ENAMETOOLONG, EINVAL, EIO).
;
; WHAT GOES OUT IS `struct stat', built by the kernel in the BSD layout
; (include/fs.s, the STX_ block).  The loop is a byte copy of `_fsStatBuf';
; libc copies the 32 bytes again into the caller's own struct.
;------------------------------------------------------------------------------
_Sys_Stat       ENT
                MX      %00
                ; Save dst offset (X) — Fs_Stat clobbers _libcTmp2 transitively
                ; via Path_Resolve, so we re-establish the long pointer after.
                STX     _Sys_StatDst
                JSR     _Sys_CopyPathToBuf      ; A = path → _Sys_PathBuf
                BCC     @ss_plok
                JMP     _Sys_PathTooLong
@ss_plok
                LDX     #_Sys_PathBuf
                JSR     Fs_Stat
                BCS     @ss_ok
                CLC
                RTS                             ; A = errno passthrough

@ss_ok          ; Build _libcTmp2 = caller_bank:dst.
                LDA     _Sys_StatDst
                STA     _libcTmp2
                SEP     #$20
                MX      %10
                LDA     _Sys_CallerBank
                STA     _libcTmp2+2
                ; Copy STAT_SIZE bytes from _fsStatBuf,Y to caller.
                LDY     #0
@ss_copy        LDA     _fsStatBuf,Y
                STA     [_libcTmp2]
                REP     #$20
                MX      %00
                INC     _libcTmp2
                SEP     #$20
                MX      %10
                INY
                CPY     #STAT_SIZE
                BCC     @ss_copy
                REP     #$20
                MX      %00
                LDA     #STAT_SIZE
                AND     #$00FF
                SEC
                RTS

;------------------------------------------------------------------------------
; _Sys_Lstat (#111) - lstat a path into a caller-bank buffer.
;
; Args:    A = path offset within caller's bank (NUL-term)
;          X = dst offset within caller's bank (must hold STAT_SIZE bytes)
; Returns: C=1 + A = STAT_SIZE (bytes written) on success.
;          C=0 + A = errno from Fs_Stat on failure (ENOENT, ENOTDIR,
;          ENAMETOOLONG, EINVAL, EIO).
;
; IDENTICAL TO _Sys_Stat BUT FOR `Fs_Lstat', which is the whole of lstat(2):
; the walk does not follow a final symlink.  Everything below -- the path copy,
; the caller-bank pointer, the 32-byte copy out -- is stat's.
;
; WHAT GOES OUT IS `struct stat', built by the kernel in the BSD layout
; (include/fs.s, the STX_ block).  The loop is a byte copy of `_fsStatBuf';
; libc copies the 32 bytes again into the caller's own struct.
;------------------------------------------------------------------------------
_Sys_Lstat      ENT
                MX      %00
                ; Save dst offset (X) — Fs_Stat clobbers _libcTmp2 transitively
                ; via Path_Resolve, so we re-establish the long pointer after.
                STX     _Sys_StatDst
                JSR     _Sys_CopyPathToBuf      ; A = path → _Sys_PathBuf
                BCC     @sl_plok
                JMP     _Sys_PathTooLong
@sl_plok
                LDX     #_Sys_PathBuf
                JSR     Fs_Lstat
                BCS     @sl_ok
                CLC
                RTS                             ; A = errno passthrough

@sl_ok          ; Build _libcTmp2 = caller_bank:dst.
                LDA     _Sys_StatDst
                STA     _libcTmp2
                SEP     #$20
                MX      %10
                LDA     _Sys_CallerBank
                STA     _libcTmp2+2
                ; Copy STAT_SIZE bytes from _fsStatBuf,Y to caller.
                LDY     #0
@sl_copy        LDA     _fsStatBuf,Y
                STA     [_libcTmp2]
                REP     #$20
                MX      %00
                INC     _libcTmp2
                SEP     #$20
                MX      %10
                INY
                CPY     #STAT_SIZE
                BCC     @sl_copy
                REP     #$20
                MX      %00
                LDA     #STAT_SIZE
                AND     #$00FF
                SEC
                RTS

;------------------------------------------------------------------------------
; _Sys_Readlink (#112) - read a symbolic link's target into a caller-bank buffer.
;
; Args:    A = path offset within caller's bank (NUL-term)
;          X = dst offset within caller's bank
;          Y = dst size
; Returns: C=1 + A = bytes placed.  C=0 + A = errno; EINVAL when the name is
;          not a symlink, which is what a caller's S_IFLNK guard expects.
;
; THE TARGET LANDS IN THE KERNEL'S PATH BUFFER FIRST and is copied out, rather
; than being written to the caller's bank directly: root_readlink builds a uio
; with UIO_SYSSPACE, and the far bank's uiomove writes this bank.  The same
; staging every other path syscall here does, for the same reason.
;------------------------------------------------------------------------------
_Sys_Readlink   ENT
                MX      %00
                STX     _Sys_StatDst            ; the caller's buffer
                STY     _Sys_ReadlinkSz
                JSR     _Sys_CopyPathToBuf      ; A = path -> _Sys_PathBuf
                BCC     @srl_plok
                JMP     _Sys_PathTooLong
@srl_plok
                ; Cap the read at the scratch buffer, then at the caller's ask.
                LDA     _Sys_ReadlinkSz
                CMP     #SYS_PATHBUF_MAX
                BCC     @srl_sz
                LDA     #SYS_PATHBUF_MAX
@srl_sz         PHA
                LDX     #_Sys_PathBuf
                LDY     #_Sys_LinkBuf
                PLA
                JSR     Fs_Readlink
                BCS     @srl_ok
                CLC
                RTS                             ; A = errno passthrough

@srl_ok         STA     _Sys_ReadlinkSz         ; A = the count placed
                ; Build _libcTmp2 = caller_bank:dst and copy the target out.
                LDA     _Sys_StatDst
                STA     _libcTmp2
                SEP     #$20
                MX      %10
                LDA     _Sys_CallerBank
                STA     _libcTmp2+2
                LDY     #0
@srl_copy       CPY     _Sys_ReadlinkSz
                BCS     @srl_done
                LDA     _Sys_LinkBuf,Y
                STA     [_libcTmp2]
                REP     #$20
                MX      %00
                INC     _libcTmp2
                SEP     #$20
                MX      %10
                INY
                BRA     @srl_copy
@srl_done       REP     #$30
                MX      %00
                LDA     _Sys_ReadlinkSz
                SEC
                RTS

_Sys_ReadlinkSz DA      0

;------------------------------------------------------------------------------
; _Sys_Fstat (#28) - stat an OPEN FD into a caller-bank buffer.
;
; Args:    A = fd (read from _Sys_SavedA, the fd-syscall convention)
;          X = dst offset within caller's bank (must hold STAT_SIZE bytes)
; Returns: C=1 + A = STAT_SIZE (bytes written) on success.
;          C=0 + A = EBADF when the fd is not open.
;
; The descriptor's struct file answers, as in Reno's fstat (kern/
; kern_descrip.c): a vnode through vn_stat, the same conversion stat(2) uses,
; and a socket or pipe through soo_stat -- root_fstat in the far bank.  An fd
; that is not open is EBADF.
;------------------------------------------------------------------------------
_Sys_Fstat      ENT
                MX      %00
                STX     _Sys_StatDst            ; same dst slot as SYS_STAT
                LDA     _Sys_SavedA
                AND     #$00FF                  ; fd
                JSR     _Fs_RootFstat           ; C=1 + X = #_fsStatBuf
                BCS     @sf_copyOut
                RTS                             ; C=0 + A = the errno
                ; --- copy STAT_SIZE bytes to caller_bank:dst (as _Sys_Stat does).
@sf_copyOut     REP     #$20
                MX      %00
                LDA     _Sys_StatDst
                STA     _libcTmp2
                SEP     #$20
                MX      %10
                LDA     _Sys_CallerBank
                STA     _libcTmp2+2
                LDY     #0
@sf_copy        LDA     _fsStatBuf,Y
                STA     [_libcTmp2]
                REP     #$20
                MX      %00
                INC     _libcTmp2
                SEP     #$20
                MX      %10
                INY
                CPY     #STAT_SIZE
                BCC     @sf_copy
                REP     #$20
                MX      %00
                LDA     #STAT_SIZE
                AND     #$00FF
                SEC
                RTS

;------------------------------------------------------------------------------
; _Sys_ListDir (#49) - enumerate a directory's entries into caller's buffer.
;
; Args:    A = path offset within caller's bank (NUL-term)
;          X = output buffer offset within caller's bank
;          Y = buffer size in bytes
; Returns: A = total bytes written (incl. trailing NUL terminator), C=1.
;          C=0 + A = errno from root_listdir on failure (path doesn't exist,
;          isn't a directory, etc.).
;
; Output format: each entry name is NUL-terminated; an extra trailing NUL
; (i.e. a zero-length entry) marks end of list.  Truncates cleanly if the
; buffer fills mid-listing.
;
; Slice-2 dirent shape: name only.  Type/size/attributes deferred to slice-3.
;------------------------------------------------------------------------------
_Sys_ListDir    ENT
                MX      %00
                ; Save Y (buf-max) and X (caller-bank buf offset) across
                ; _Sys_CopyPathToBuf, which clobbers _libcTmp2 and Y.
                STY     _Sys_LdRem              ; buffer size
                STX     _Sys_LdBufOff           ; caller-bank buf offset
                JSR     _Sys_CopyPathToBuf      ; A = path → _Sys_PathBuf
                BCC     @lsd_plok
                JMP     _Sys_PathTooLong
@lsd_plok

                ; THE MOUNTED ROOT ANSWERS FIRST.  A miss falls through and
                ; does not fail, exactly as Fs_Open's and Fs_Stat's hooks do,
                ; so a machine whose boot volume is ProDOS still reaches the
                ; legacy FST below and this can only add a capability.
                ;
                ; INLINE, AND NOT A `_Fs_Root*' HELPER LIKE ITS TWO SIBLINGS.
                ; This is the only one of the three with exactly one call site,
                ; so the wrapper would be a PHP/PLP/RTS bracket and a JSR spent
                ; to reach it -- about a dozen bytes of the bank that has the
                ; fewest.  MX %00 is already established here.
                ;
                ; RELATIVE NAMES TOO, AND THE PID IS WHAT MAKES THAT SAFE.  A
                ; relative name does not simply miss: namei with a NULL starting
                ; directory resolves it against the ROOT, which is a WRONG
                ; ANSWER rather than a failure -- `pwd' (getwd walks up with `.'
                ; and `..') would come back naming a file in `/'.  The pid below
                ; reaches `vfs_cdir', so the walk starts where the process is.
                ; apple/fgx#295.
                ;
                ; `_Sys_PathBuf' TAKES PHK -- the LIVE bank, never a `^'
                ; literal -- while the output buffer is the CALLER's, built
                ; from `_Sys_LdBufOff' and `_Sys_CallerBank'.  dev_rw's header
                ; carries why a user pointer on this machine must be COMPLETE
                ; rather than translated.
                LDA     _Sys_LdRem              ; size
                PHA
                SEP     #$20                    ; buf: the CALLER's bank
                MX      %10
                LDA     #0
                PHA                             ;      pad
                LDA     _Sys_CallerBank
                PHA                             ;      bank
                REP     #$30
                MX      %00
                LDA     _Sys_LdBufOff
                PHA                             ;      offset
                SEP     #$20                    ; path: this bank
                MX      %10
                LDA     #0
                PHA                             ;      pad
                PHK                             ;      bank -- the LIVE one
                REP     #$30
                MX      %00
                LDA     #_Sys_PathBuf
                PHA                             ;      offset
                ; AND THE pid LAST, BEING THE FIRST ARGUMENT.  `_Fcb_OwnerPid'
                ; and not `_curTask', as every other hook here does.
                JSR     _Fcb_OwnerPid
                PHA
_kfp908         JSL     KFAR_VFS_ROOTLISTDIR    ; bank byte patched by Far_Init
                ; DROP THE TWELVE ARGUMENT BYTES: the seam entry drops its own
                ; copy and the caller cleans the original.
                TAY                             ; park the result; TSC needs A
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                BMI     @ld_err                 ; negative is -errno
                SEC
                RTS                             ; A = bytes written
@ld_err         ; THE MOUNTED ROOT IS THE ONLY DIRECTORY READER, so its
                ; answer is the answer: there is no second enumerator left to
                ; fall through to.  root_listdir returns -errno and the syscall
                ; convention is C=0 with the errno itself, so negate it here.
                EOR     #$FFFF
                INC
                AND     #$00FF
                CLC
                RTS

;------------------------------------------------------------------------------
; _Sys_GetKey (#50) - read one raw key from the console (blocking).
;
; No echo, no line discipline, no buffering past the kernel's keyboard
; queue.  Userland line editors (sh, more, vi, …) call this in a loop
; and handle echoing + arrows / ctrl chars themselves.
;
; Returns: C=1 + A = key byte (low 8 bits).  No error path.
;
; Apple key codes worth knowing for callers:
;   $08  left arrow
;   $0A  down arrow
;   $0B  up arrow
;   $0D  Enter
;   $15  right arrow
;   $7F  delete / backspace
;------------------------------------------------------------------------------
_Sys_GetKey     ENT
                MX      %00
                ; NOT THE CONSOLE'S TERMINAL AT ALL?  Fail, do not wait
                ; (apple/fgx#151, #117).  _Vc_CttyIsActive answers no for a
                ; background virtual console, for a pty, AND for a task with no
                ; controlling terminal, and those deserve different treatment:
                ; the VC should wait its turn at the screen, while the other two
                ; are waiting for something that cannot happen, so the sleep
                ; below would park the caller forever on a ring that is not its
                ; terminal.  ENOTTY says exactly that, and it is what lets a
                ; program discover it should be reading its own fd instead.
                JSR     _Vc_CttyNoKeys
                BCC     @sgk_wait
                LDA     #ENOTTY
                CLC
                RTS
                ; CONTROLLING-TERMINAL GATE (apple/fgx#41).  This syscall
                ; dequeues from the SHARED keyboard ring with no discipline in
                ; between, so without a gate a shell on a background virtual
                ; console eats the keystrokes the user is aiming at the console
                ; they are looking at -- typed commands arrived truncated, the
                ; tail swallowed by the second shell.
                ;
                ; A task with NO controlling tty (ctty none) is every pre-slice-D
                ; caller, and is served as before.  A task that acquired one by
                ; opening a tty is served only while that tty is the console on
                ; screen; otherwise it sleeps, exactly as the line discipline
                ; does for a background VC.
@sgk_wait       JSR     _Vc_CttyIsActive
                BCS     @sgk_go
                LDA     #WCHAN_KBD
                LDX     #4
                JSR     _sleep
                BCS     @sgk_intr               ; interrupted: report EINTR
                BRA     @sgk_wait
@sgk_go
                ; THE CONTROLLING TERMINAL, NOT THE RING -- T6 increment 4b.
                ; `_Key_Ctty's header carries the whole reasoning and the
                ; upstream it is a port of.
                JSR     _Key_Ctty
                BCC     @sgk_notty              ; no controlling terminal
                LDX     #0                      ; blocking: the discipline waits
                JSR     _Key_Read
                BCC     @sgk_rderr
                RTS                             ; C=1 + A = the key
@sgk_rderr      CMP     #0
                BEQ     @sgk_intr               ; nothing delivered on a blocking
                CLC                             ;   read: treat as interrupted
                RTS                             ; the discipline's own errno
@sgk_notty      LDA     #ENOTTY
                CLC
                RTS
@sgk_intr       LDA     #EINTR                  ; signal pending: the dispatcher's
                CLC                             ;   _Sys_CheckSignal acts on it next
                RTS

;------------------------------------------------------------------------------
; _Sys_PollKey (#66) - non-blocking read of one raw key from the console.
;
; Returns: C=1 + A = key byte (low 8 bits) if a key was queued;
;          C=0 + A = 0 if the keyboard ring is empty.
; Wraps Con_PollKey (heartbeat-fed ring; NOT a direct $E0C000 read).  Lets
; interactive foreground tools poll the keyboard without blocking.  Clobbers X
; (like _Sys_GetKey); dispatcher entered DBR=kernel-bank ($02 = ORG) so the kernel-bank ring is reachable.
;------------------------------------------------------------------------------
;------------------------------------------------------------------------------
; _Key_Ctty - resolve the caller's controlling terminal for SYS_GETKEY /
; SYS_POLLKEY.  T6 increment 4b.
;
; THIS IS `tty_tty.c's FIRST LINE, and the increment is the rest of it.
; Upstream's whole answer to "a program needs its terminal" is
;
;       if (u.u_ttyp == NULL) return (ENXIO);
;       return ((*cdevsw[major(u.u_ttyd)].d_read)(u.u_ttyd, uio, flag));
;                       -- vendor/2.11BSD/usr/sys/sys/tty_tty.c:30-37
;
; and 2.11BSD has NO keyboard ring and NO getkey syscall to reconcile with it:
; grep the kernel.  Bytes enter the discipline where they ARRIVE and every
; consumer reads a tty.  These two syscalls grew into the gap `/dev/tty' now
; fills, and until this increment they dequeued `_kKbdRing' -- a SECOND copy of
; the keystroke that no fd named, so a program on a pty read the PHYSICAL
; CONSOLE, which is what `ptykey' measures.
;
; THE RING HAD ALSO STOPPED BEING HONEST.  Until 4b's flip every tty read
; drained it (the pump's `_Tty_GetByte' was its consumer); with the pump gone
; nothing does, so it saturated at KBD_RING_SZ and served keys minutes old.
;
; In:  MX %00.  Out: C=1 + A = the tty index; C=0 when there is none, which is
;      upstream's `u.u_ttyp == NULL' arm.  Clobbers X, Y.
;------------------------------------------------------------------------------
_Key_Ctty       MX      %00
                JSR     _Se_CurCtty             ; u.u_ttyp
                CMP     #NTTY                   ; $FFFF (none) fails this too
                BCC     @kc_have
                CLC
                RTS
@kc_have        SEC
                RTS

;------------------------------------------------------------------------------
; _Key_Read - one raw byte from the resolved line.  In: A = tty index,
; X = nonblock.  Out: C=1 + A = the byte; C=0 + A = errno (0 = no key).
;------------------------------------------------------------------------------
_Key_Read       MX      %00
_ktp059         JSL     KTTY_KC_TTGETRAW        ; slot 40; byte / $FFFF / $FFFE
                CMP     #$FFFE
                BCS     @kr_none                ; -1 none, -2 interrupted
                AND     #$00FF
                SEC
                RTS
@kr_none        CMP     #$FFFE
                BNE     @kr_nokey
                LDA     #EINTR
                CLC
                RTS
@kr_nokey       LDA     #0                      ; no key waiting
                CLC
                RTS

_Sys_PollKey    ENT
                MX      %00
                ; A pty ctty -- or none at all -- gets "no key" AND yields
                ; (apple/fgx#151, #117), the same answer a background caller
                ; gets.  Con_PollKey's gate already returns empty for both;
                ; routing through @spk_bg is what stops a poll loop from
                ; busy-spinning on that empty answer forever.
                JSR     _Vc_CttyNoKeys
                BCS     @spk_bg
                JSR     _Tty_CurIsFg            ; FOREGROUND only: a background caller
                BCC     @spk_bg                 ;   (e.g. `ping ... &`) gets "no key" AND
                                                ;   yields -- so it can't grab ^C, steal the
                                                ;   fg shell's keys, or STARVE it
                ; THE CONTROLLING TERMINAL, NOT THE RING -- see `_Key_Ctty'.
                JSR     _Key_Ctty
                BCC     @spk_bg                 ; no controlling terminal: as before
                LDX     #1                      ; poll: answer at once
                JSR     _Key_Read
                BCS     @spk_got
                LDA     #0                      ; no key (EWOULDBLOCK or nothing)
                CLC
@spk_got        RTS
@spk_bg         JSR     _Sys_Yield              ; a bg key-poll loop (ping's wait_ticks) must
                LDA     #0                      ;   yield, else it busy-spins and the shell
                CLC                             ;   blocked on WCHAN_KBD never wakes (the
                RTS                             ;   per-switch kbd wake, sched.s, needs swtch)

;------------------------------------------------------------------------------
; _Sys_SoundClaim (SYS_SOUND_CLAIM = 86) - the caller claims the DOC, so the
; kernel stops it (Sound_StopDoc) when the caller terminates.  MX %00.
; Out: C=1 + A=0.
;
; STAYS IN THE CORE BANK while the rest of the sound driver moved to the far
; bank (2026-08-01).  It is a syscall handler -- the dispatch table at :575 holds
; 2-byte offsets with the core bank implied -- and it touches two core statics,
; _curTask and _docOwner.  Moving it needs the core-side thunk mechanism, which
; the BRAM clock task builds.  The DOC-programming routines it is named after
; touch neither static, which is what made the split clean.
;------------------------------------------------------------------------------
_Sys_SoundClaim ENT
                MX      %00
                LDA     _curTask
                STA     _docOwner
                LDA     #0
                SEC
                RTS


;==============================================================================
; _Sys_KStkReport - report a dead kernel-stack canary, out of line.
;
; Called with the latch already set, so it runs at most once per boot.  Reads
; D and the per-page identity cells directly; the caller has not disturbed
; either.  apple/fgx#120.
;==============================================================================
_Sys_KStkReport MX      %00
                LDA     #@sks_Msg
                STA     _conStrPtr
                JSR     Kern_LogStrNoEOL
                LDA     _curTask                ; the DP page's own identity...
                JSR     Kern_LogHex16
                LDA     #@sks_Msg2
                STA     _conStrPtr
                JSR     Kern_LogStrNoEOL
                LDA    |_kCurPid                ; ...beside the kernel bank's
                JSR     Kern_LogHex16
                LDA     #@sks_Msg3
                STA     _conStrPtr
                JSR     Kern_LogStrNoEOL
                TDC                             ; ...and which DP page we are ON
                JSR     Kern_LogHex16
                ; The slot page the scheduler published, and its identity cell
                ; read ABSOLUTELY rather than through D: it is stamped with the
                ; bound task's pid when the slot is seeded (task.s _Slot_Seed)
                ; and never written again, so a page that disagrees with
                ; _kCurPid was written by something after that.
                LDA     #@sks_Msg4
                STA     _conStrPtr
                JSR     Kern_LogStrNoEOL
                LDAL   KFGX_CUR_KDP
                JSR     Kern_LogHex16
                LDA     #@sks_Sp
                STA     _conStrPtr
                JSR     Kern_LogStrNoEOL
                ; LDAL/TAX AND NOT `LDXL': LDX has no absolute-long mode on the
                ; 65816, and the page has to come from bank 0 now.
                LDAL   KFGX_CUR_KDP
                TAX
                LDAL    $000000+_curTask,X
                JSR     Kern_LogHex16
                JSR     Kern_LogEOL
                ; THREE numbers, because one cannot tell the two failures apart.
                ; _curTask lives in the task's direct page and _kCurPid is the
                ; kernel bank's absolute copy of the same fact, so:
                ;   they AGREE and are sane   -> the canary really was overrun
                ;   they DISAGREE             -> we are reading the wrong page,
                ;                                and D says which one
                ; apple/fgx#120 reported "pid $4481", which is not a task at all
                ; -- and with only that number there is no way to tell whether
                ; the stack died or the identity did.  Also: the label said
                ; "pid" while the value has always been _curTask.
                RTS                     ; BEFORE the literals, not after: the
                                        ; ASC bytes below are DATA, and falling
                                        ; into them executes them.
@sks_Msg     ASC     "!! KSTK CANARY DEAD curTask ",00
@sks_Msg2    ASC     " kCurPid ",00
@sks_Msg3    ASC     " D ",00
@sks_Msg4    ASC     " kdp ",00
@sks_Sp      ASC     "/",00

;==============================================================================
; _Sys_KStat (#53) - copy a 16-byte kernel-stat struct into caller's buffer.
;
; Diagnostic syscall.  Layout (little-endian 32-bit fields):
;   [0..3]   total Kmalloc count   (sum of ARENA_ALLOCS across arenas)
;   [4..7]   total Kfree   count   (sum of ARENA_FREES  across arenas)
;   [8..11]  current bytes USED    (sum of ARENA_USED   across arenas)
;   [12..15] total Blk_Read count  (_kBlkReadCount, raw 32-bit)
;
; Per-arena fields are 16-bit; the high word is always zero in the output
; for fields 0..2.  Field 3 is a true 32-bit counter.
;
; ABI: caller passes 16-byte buffer offset in A.
;==============================================================================
; RTC syscall thunks -- core-resident stubs for far-bank handlers.
;
; The dispatch table below holds `DA <handler>`: 2-byte offsets with the CORE
; bank implied.  A far-bank handler therefore cannot be named there directly, so
; each gets an 8-byte stub here.  8 bytes of thunk relocates 245 bytes of
; handler, and the ratio only improves for bigger handlers -- which is what makes
; this the door to moving more of syscall.s.
;
; X CARRIES THE CALLER BANK.  `_Sys_CallerBank' is an absolute static in THIS
; bank that far code cannot reach without a patched LDAL, so it is loaded here
; and passed in X rather than building that machinery for one symbol.  X is
; loaded 16-bit over a 1-byte static, so its high byte is junk; the far side
; reads it back with an 8-bit TXA and ignores that.
;
; A is untouched -- it carries the syscall argument.
;==============================================================================
_thunk_Uptime   MX      %00
                LDX     _Sys_CallerBank
_kfp021         JSL     KFAR_SYS_UPTIME         ; bank byte patched by Far_Init
                RTS

_thunk_RtcRead  MX      %00
                LDX     _Sys_CallerBank
_kfp022         JSL     KFAR_SYS_RTCREAD
                RTS

; gettimeofday(2): the kernel clock, in the tty bank (tty/kern_time.c).  The
; slot's stub sets its own DBR and D, so this is the RTC thunk's shape.
; SYS_LDCTL (8): the shared-library registry (shared libc SP4).  The body is
; in the tty bank; ld.mod answers through LD_TRAMP, ENOSYS until it loads.
_thunk_LdCtl    MX      %00
_ktp106         JSL     KTTY_LD_CTL
                RTS

_thunk_Gtod     MX      %00
                LDX     _Sys_CallerBank
_ktp100         JSL     KTTY_TOD_GTOD
                RTS

; SETTING THE CLOCK IS SUPER USER ONLY, both halves.  2.11BSD's setthetime()
; opens with `if (!suser()) return;' and settimeofday sets the zone only
; `if (uap->tzp && suser())' (usr/sys/sys/kern_time.c:80 and :67); suser()
; sets EPERM either way.  Asked here, in the core bank where _Suser lives and
; before the tty call, so a refused call touches nothing.
_thunk_Stod     MX      %00
                PHA                             ; the argument; _Suser clobbers A
                JSR     _Suser
                PLA
                BCS     @stod_priv
                LDA     #EPERM
                CLC
                RTS
@stod_priv      LDX     _Sys_CallerBank
_ktp102         JSL     KTTY_TOD_STOD
                RTS

; adjtime(2) is super user only too: 2.11BSD kern_time.c:123, `if
; (!suser()) return;', and FreeBSD's the same.  _thunk_Stod's shape.
_thunk_Adj      MX      %00
                PHA
                JSR     _Suser
                PLA
                BCS     @adj_priv
                LDA     #EPERM
                CLC
                RTS
@adj_priv       LDX     _Sys_CallerBank
_ktp103         JSL     KTTY_TOD_ADJ
                RTS

; SYS_MODLOAD needs BOTH index registers for arguments, so unlike the RTC
; thunks above this one does not spend X on the caller bank -- the far side
; reads _Sys_CallerBank itself through a patched LDAL, which costs a far patch
; entry and no core.  5 bytes rather than 8.
;
; THE RESOLVERS RUN HERE, AND THE PLACE IS THE POINT.  The four
; `*_LoadOpsPtr' routines rewrite fixed call sites from a module's vtable, and
; main.s runs them only at boot -- so a module streamed in later would be
; REGISTERED BUT UNREACHABLE without this call (apple/fgx#309).
;
; THEY RUN WITH THE SYSCALL'S DIRECT PAGE, which is why they cannot run on the
; far side of the seam.  `_Pty_LoadOpsPtr' walks the chardev table through
; `_cdTablePtr' (DP $30) and stages the vtable in `_libcTmp2' (DP $54), both
; from include/dpmap.s -- and `_Far_ModLoad' runs on FGX_DP_KERNELC, fcc's
; register file.  Calling them from `_FarSh_ModRegister' would store a module
; bank through whatever those offsets happen to hold there.  A thunk is
; on the kernel DP already: `_Sys_KStat' below reads _libcTmp2 at exactly this
; point in the call.
;
; ALL THREE, WITH NO DISPATCH ON WHICH.  Each one asks the registry for its own
; vtype and does nothing when it is absent, so they SELECT THEMSELVES -- a
; VTDR carrying two vtables resolves both, which a single-vtype branch would
; not.  Re-running one that already succeeded is a no-op by construction:
; _Net_ rewrites a saved pointer with the value it just read, _Ram_ rewrites
; two JSL operands with theirs, and _Pty_ scans for the STUB table addresses,
; which are no longer there to find.
;
; A `begin' or `data' chunk pays three registry lookups for nothing, since only
; `end' can append a row.  Gating on the subcommand costs more core bytes than
; the lookups cost cycles: A holds it on entry and is the return value on exit,
; so it would have to be parked across the JSL.
_thunk_ModLoad  MX      %00
_kfp968         JSL     KFAR_SYS_MODLOAD
                BCC     @tml_out        ; failed: nothing was registered
                PHA                     ; @fml_ok leaves A alone; keep it
                JSR     _Ram_LoadOpsPtr
                JSR     _Pty_LoadOpsPtr
                JSR     _Net_LoadOpsPtr
                PLA
                SEC                     ; the resolvers each end in SEC/CLC
@tml_out        RTS

;==============================================================================
_Sys_KStat      ENT
                MX      %00
                PHP
                SEI                             ; atomic w.r.t. any IRQ-side INC
                STA     _shTmp0                 ; preserve dst offset for return
                STA     _libcTmp2               ; lo word of long-pointer
                SEP     #$20
                MX      %10
                LDA     _Sys_CallerBank
                STA     _libcTmp2+2
                REP     #$20
                MX      %00

                ; --- Field 0: total allocs ---
                LDY     #ARENA_ALLOCS
                JSR     _KS_SumFieldY
                JSR     _KS_Emit24Z

                ; --- Field 1: total frees ---
                LDY     #ARENA_FREES
                JSR     _KS_SumFieldY
                JSR     _KS_Emit24Z

                ; --- Field 2: bytes USED ---
                LDY     #ARENA_USED
                JSR     _KS_SumFieldY
                JSR     _KS_Emit24Z

                ; --- Field 3: _kBlkReadCount, 32-bit ---
                LDY     #0
@ks_brL         LDA     _kBlkReadCount,Y
                SEP     #$20
                MX      %10
                STA     [_libcTmp2]
                REP     #$20
                MX      %00
                INC     _libcTmp2
                INY
                CPY     #4
                BCC     @ks_brL

                LDA     _shTmp0                 ; return value = original dst
                PLP
                SEC
                RTS

;------------------------------------------------------------------------------
; _KS_SumFieldY - sum the 16-bit arena field at Y across all arenas.
;                  Result in _ksSum (24-bit; high byte at _ksSum+2).
;------------------------------------------------------------------------------
_KS_SumFieldY   MX      %00
                PHX
                STZ     _ksSum
                SEP     #$20
                MX      %10
                STZ     _ksSum+2
                REP     #$20
                MX      %00
                LDX     #0
@kssf_L         CPX     Kmem_ArenaCount
                BCS     @kssf_done
                STY     _shTmp0                 ; preserve field offset across helper
                JSR     _Kmem_ArenaPtr          ; X arena idx -> _libcDstPtr
                LDY     _shTmp0
                LDA     (_libcDstPtr),Y
                CLC
                ADC     _ksSum
                STA     _ksSum
                BCC     @kssf_noHi
                SEP     #$20
                MX      %10
                LDA     _ksSum+2
                CLC
                ADC     #1
                STA     _ksSum+2
                REP     #$20
                MX      %00
@kssf_noHi      INX
                BRA     @kssf_L
@kssf_done      LDY     _shTmp0                 ; restore Y so caller's Y is intact
                PLX
                RTS

;------------------------------------------------------------------------------
; _KS_Emit24Z - write _ksSum (24-bit) followed by a zero byte (4 bytes total)
;                via [_libcTmp2]; advances _libcTmp2 by 4.  Caller MX %00.
;------------------------------------------------------------------------------
_KS_Emit24Z     MX      %00
                ; Bytes 0+1 from _ksSum lo word
                SEP     #$20
                MX      %10
                LDA     _ksSum
                STA     [_libcTmp2]
                REP     #$20
                MX      %00
                INC     _libcTmp2
                SEP     #$20
                MX      %10
                LDA     _ksSum+1
                STA     [_libcTmp2]
                REP     #$20
                MX      %00
                INC     _libcTmp2
                ; Byte 2 from _ksSum+2
                SEP     #$20
                MX      %10
                LDA     _ksSum+2
                STA     [_libcTmp2]
                REP     #$20
                MX      %00
                INC     _libcTmp2
                ; Byte 3 = 0 (sums never overflow 24 bits in practice)
                SEP     #$20
                MX      %10
                LDA     #0
                STA     [_libcTmp2]
                REP     #$20
                MX      %00
                INC     _libcTmp2
                RTS

;------------------------------------------------------------------------------
; _Sys_Border (#55) - set IIgs border color.
;
; Args:    A.lo = color index 0..15
; Returns: C=1 + A=0 always.
;
; Writes the low nibble of $E0C034 (IIgs BORDER soft switch); high nibble is
; preserved so other VGCINT bits the ROM may have set stay put.
;------------------------------------------------------------------------------
_Sys_Border     MX      %00
                AND     #$000F                  ; clamp to 4 bits
                STA     _shTmp0
                SEP     #$20
                MX      %10
                LDAL    $E0C034
                AND     #$F0                    ; preserve high nibble (other VGC bits)
                ORA     _shTmp0
                STAL    $E0C034
                REP     #$20
                MX      %00
                LDA     #0
                SEC
                RTS

;------------------------------------------------------------------------------
; _Sys_SetPal (#56) - rewrite palette 0's foreground or background slots
; to a 12-bit RGB value.
;
; Args:    A.lo = role  (0 = foreground, 1 = background)
;          X    = 12-bit RGB (bits 11..8 R, 7..4 G, 3..0 B; high nibble unused)
; Returns: C=1 + A=0 on success, or C=0 + A=EINVAL for bad role.
;
; Palette 0 is the screen's default palette (every row's SCB points at it by
; default).  In 640 mode the 16-entry palette is split into 4 pixel-position
; groups, so a "uniform fg" must replicate the same RGB across slots 3/7/11/15
; and a "uniform bg" across slots 0/4/8/12.  SCBs that themed-SGR escapes
; later switch to a different palette are unaffected, but text rendered
; before that escape uses palette 0.
;
; SHR palettes live at $019E00 (bank-$01 shadow of $E19E00); palette 0
; starts at $019E00.
;------------------------------------------------------------------------------
_Sys_SetPal     MX      %00
                AND     #$00FF
                STA     _shTmp0                 ; role byte
                STX     _shTmp1                 ; 12-bit RGB
                CMP     #2
                BCC     @sysp_roleOK
                LDA     #EINVAL
                CLC
                RTS
@sysp_roleOK      ; Pick slot list based on role.
                LDA     _shTmp0
                BEQ     @sysp_doFg                ; role 0 = fg
                ; role 1 = bg
                LDA     #_SysPal_BgSlots
                STA     _shTmp2
                BRA     @sysp_writeLoop
@sysp_doFg        LDA     #_SysPal_FgSlots
                STA     _shTmp2
@sysp_writeLoop   ; Walk the 4-byte slot-offset table at (_shTmp2); for each
                ; byte offset, write _shTmp1 (RGB word) at $019E00 + offset.
                SEP     #$20
                MX      %10
                LDY     #0
@sysp_L           LDA     (_shTmp2),Y             ; 1-byte slot offset
                STA     _shTmp0                 ; stash for 16-bit reload below
                REP     #$20
                MX      %00
                LDA     _shTmp0
                AND     #$00FF
                CLC
                ADC     #$9E00                  ; palette base offset within bank $01
                TAX
                LDA     _shTmp1                 ; 16-bit RGB
                STAL    $010000,X
                SEP     #$20
                MX      %10
                INY
                CPY     #4
                BCC     @sysp_L
                REP     #$20
                MX      %00
                LDA     #0
                SEC
                RTS

;------------------------------------------------------------------------------
; Palette-0 slot offsets, indexed by 640-mode pixel-position group.
;
; Foreground:  slots 1, 5, 9, 13   (matches the default _conAttr=1, which
;                                   tells the renderer to draw glyph fg
;                                   pixels with value 1 in each byte
;                                   position; that selects palette entry
;                                   `byte_position*4 + 1`.  See
;                                   docs/history/audits/video-color-model.md and
;                                   _Con_BuildAllPreExpFonts.)
; Background: slots 0, 4, 8, 12    (value 0 in each byte position; matches
;                                   the default _conAttr=1's bg=0 nibble.)
;
; Slots 2/6/10/14 and 3/7/11/15 are not visible at the default attr; they
; come into play only when SGR escapes or programmatic Con_SetFg/Con_SetBg
; pick a different variant.
;
; Each palette slot is a 2-byte word, so byte offset = slot*2 from palette
; base ($019E00).  These tables are byte-indexed; _Sys_SetPal walks them.
;------------------------------------------------------------------------------
_SysPal_FgSlots DFB     1*2,5*2,9*2,13*2
_SysPal_BgSlots DFB     0*2,4*2,8*2,12*2

;------------------------------------------------------------------------------
; _Sys_FontLoad (#57) - load a bitmap font from a .FNT file.
;
; Args:    A = caller-bank offset of NUL-term path
; Returns: C=1 + A=0 on success.
;          C=0 + A=errno on failure (Fs_Open / read / FGXF magic-version).
;
; Side effect: writes the basename of the path (last component, .fnt
; extension stripped, lowercased) into CurrentFontName.  On failure
; CurrentFontName is unchanged.
;------------------------------------------------------------------------------
_Sys_FontLoad   MX      %00
                JSR     _Sys_CopyPathToBuf      ; path → _Sys_PathBuf
                BCC     @sfl_plok
                JMP     _Sys_PathTooLong
@sfl_plok
                LDX     #_Sys_PathBuf
_kfp127         JSL     KFAR_CON_LOADFONTFROMFILE ; C=0 ok, C=1 fail (note inverted)
                BCC     @sfl_ok
                ; A = error code; propagate as failure.
                AND     #$00FF
                CLC
                RTS
@sfl_ok         JSR     _Sys_FontStoreBasename
                LDA     #0
                SEC
                RTS

;------------------------------------------------------------------------------
; _Sys_FontStoreBasename - walk _Sys_PathBuf, find the last component (after
; the final '/'), copy it into CurrentFontName (lowercased, ≤15 chars + NUL,
; stop at first '.').  Internal helper; caller MX %00.
;------------------------------------------------------------------------------
_Sys_FontStoreBasename MX %00
                ; Find offset of byte just past the last '/'.
                SEP     #$20
                MX      %10
                LDX     #0                      ; running scan idx
                LDY     #0                      ; last "after-/" idx (basename start)
@sfb_scanL      LDA     _Sys_PathBuf,X
                BEQ     @sfb_scanDone
                CMP     #'/'
                BNE     @sfb_scanNext
                ; Found '/' — basename starts at X+1.
                INX
                STX     _shTmp0                 ; remember
                TXY                             ; Y = basename start
                BRA     @sfb_scanContinue
@sfb_scanNext   INX
@sfb_scanContinue
                CPX     #SYS_PATH_MAX
                BCC     @sfb_scanL
@sfb_scanDone   ; Y = offset within _Sys_PathBuf where basename begins.
                ; Copy bytes to CurrentFontName, lowercasing A-Z, stopping at
                ; first '.' or NUL, max 15 chars then NUL-terminate.
                LDX     #0                      ; dst idx in CurrentFontName
@sfb_copyL      CPX     #15
                BCS     @sfb_copyEnd
                LDA     _Sys_PathBuf,Y
                BEQ     @sfb_copyEnd
                CMP     #'.'
                BEQ     @sfb_copyEnd
                CMP     #'A'
                BCC     @sfb_store
                CMP     #'Z'+1
                BCS     @sfb_store
                CLC
                ADC     #$20                    ; uppercase → lowercase
@sfb_store      STA     CurrentFontName,X
                INX
                INY
                BRA     @sfb_copyL
@sfb_copyEnd    LDA     #0
                STA     CurrentFontName,X
                REP     #$20
                MX      %00
                RTS

;------------------------------------------------------------------------------
; _Sys_FontRevert (#58) - revert to the built-in default font.
;
; Returns: C=1 + A=0 always.
;
; Con_RevertToDefault already clears CurrentFontName (writes a NUL at byte 0).
;------------------------------------------------------------------------------
_Sys_FontRevert MX      %00
_kfp128         JSL     KFAR_CON_REVERTTODEFAULT
                LDA     #0
                SEC
                RTS

;------------------------------------------------------------------------------
; _Sys_FontName (#59) - copy CurrentFontName (NUL-term) into caller buffer.
;
; Args:    A = caller-bank buf offset
;          X = buf size (bytes; ≥ 1 to leave room for NUL)
; Returns: C=1 + A = bytes copied (including the NUL terminator).
;
; Caller MX %00.  Builds a long pointer in _libcTmp2 to walk the destination.
;------------------------------------------------------------------------------
_Sys_FontName   MX      %00
                STA     _libcTmp2               ; lo word = caller offset
                STX     _shTmp0                 ; buf size
                SEP     #$20
                MX      %10
                LDA     _Sys_CallerBank
                STA     _libcTmp2+2
                REP     #$20
                MX      %00
                ; Walk: copy CurrentFontName[Y] for Y = 0..14, stopping at NUL.
                ; Then write a final NUL.  Total bytes written ≤ min(buf_size,
                ; 16).
                LDY     #0
@sfn_L          CPY     _shTmp0
                BCS     @sfn_truncEnd
                CPY     #16
                BCS     @sfn_endNul
                SEP     #$20
                MX      %10
                LDA     CurrentFontName,Y
                STA     [_libcTmp2]
                BEQ     @sfn_done
                REP     #$20
                MX      %00
                ; Advance long pointer.
                LDA     _libcTmp2
                INC
                STA     _libcTmp2
                INY
                BRA     @sfn_L
@sfn_endNul     ; Source ran 15 chars without NUL — write a final NUL if room.
                REP     #$20
                MX      %00
                CPY     _shTmp0
                BCS     @sfn_truncEnd
                SEP     #$20
                MX      %10
                LDA     #0
                STA     [_libcTmp2]
@sfn_done       REP     #$20
                MX      %00
                INY                             ; count the terminator we wrote
                TYA
                SEC
                RTS
@sfn_truncEnd   ; Buffer ran out before terminator could be written.  Return
                ; what we did write; caller can detect truncation if needed.
                REP     #$20
                MX      %00
                TYA
                SEC
                RTS

;==============================================================================
; _Sys_Dmesg (#60) - copy the kernel-log ring buffer into caller's bank.
;
; Walks _kernLogBuf chronologically: if _kernLogWrap==1 it emits
; [_kernLogHead..KMEM_LOGBUF_SIZE) first, then [0.._kernLogHead).
; Stops when either source exhausts or `max` bytes have been copied.
;
; ABI:
;   In:  A = caller-bank buf offset (16-bit).
;        X = max bytes to copy (16-bit).  0 means "no copy, just probe".
;   Out: C=1 + A = bytes copied.
;==============================================================================
_Sys_Dmesg      ENT
                MX      %00
                PHP
                REP     #$30
                MX      %00

                ; Build long pointer to caller_bank:A in _libcTmp2.
                STA     _libcTmp2
                SEP     #$20
                MX      %10
                LDA     _Sys_CallerBank
                STA     _libcTmp2+2
                REP     #$20
                MX      %00

                STX     _dmesgMaxBytes
                STZ     _dmesgCopied

                ; Phase A: if wrap=1, copy [_kernLogHead..LOGBUF_SIZE).
                SEP     #$20
                MX      %10
                LDA     |_kernLogWrap           ; Wave-A: dmesg reader tracks log.s (live bank)
                CMP     #$01
                REP     #$20
                MX      %00
                BNE     @dmsg_phaseB

                LDA     _kernLogHead
                STA     _dmesgSrcIdx
@dmsg_phA_L       LDA     _dmesgSrcIdx
                CMP     #KMEM_LOGBUF_SIZE
                BCS     @dmsg_phaseB
                LDA     _dmesgCopied
                CMP     _dmesgMaxBytes
                BCS     @dmsg_done
                LDY     _dmesgSrcIdx
                SEP     #$20
                MX      %10
                LDA     [_kLogBufPtr],Y         ; ring now in heap (_kLogBufPtr)
                STA     [_libcTmp2]
                REP     #$20
                MX      %00
                INC     _libcTmp2
                INC     _dmesgSrcIdx
                INC     _dmesgCopied
                BRA     @dmsg_phA_L

@dmsg_phaseB      ; Copy [0..head).
                STZ     _dmesgSrcIdx
@dmsg_phB_L       LDA     _dmesgSrcIdx
                CMP     _kernLogHead
                BCS     @dmsg_done
                LDA     _dmesgCopied
                CMP     _dmesgMaxBytes
                BCS     @dmsg_done
                LDY     _dmesgSrcIdx
                SEP     #$20
                MX      %10
                LDA     [_kLogBufPtr],Y         ; ring now in heap (_kLogBufPtr)
                STA     [_libcTmp2]
                REP     #$20
                MX      %00
                INC     _libcTmp2
                INC     _dmesgSrcIdx
                INC     _dmesgCopied
                BRA     @dmsg_phB_L

@dmsg_done        LDA     _dmesgCopied
                PLP
                SEC
                RTS

;==============================================================================
; _Sys_MemInfo (#61) - diagnostic readout of Kmalloc/Kfree state.
;
; ABI on entry (MX %00):
;   A.lo = subcmd (0..4).  A.hi reserved (must be 0).
;   X    = caller-bank buffer offset.
;   Y    = buffer size in bytes (max output).
;
; ABI on return:
;   C=1, A = bytes written     success.
;   C=0, A = errno              EINVAL on unknown subcmd.
;
; Subcmds:
;   0 = type stats     8 × 16 B records: { name[8], inuse, count, calls, peak }
;   1 = arena stats    ArenaCount × 16 B records (= Kmem_Arenas verbatim).
;   2 = chunk walk     stream of 8 B records: { bank, flags, off, size, type }
;                      flags bit 0 = free, bit 1 = guard corrupt.
;   3 = (retired)      EINVAL.  It was a bank map of a pre-relocation table;
;                      vm.coremap and vm.meter (sysctl) describe the pool.
;   4 = guard audit    same record format as #2, only corrupt chunks emitted.
;
; All records are little-endian.  Caller-side parsing should index by
; (bytes_written / sizeof_record) to know how many entries returned.
;==============================================================================
_Sys_MemInfo    ENT
                MX      %00
                PHP
                REP     #$30
                MX      %00
                STA     _mi_subcmd              ; save subcmd
                STX     _mi_dstOff              ; caller-bank offset (write cursor)
                STY     _mi_bufRem              ; bytes remaining in caller buf
                STX     _mi_dstOff0             ; original offset (for return)
                STZ     _mi_written             ; total bytes emitted

                ; Build [_libcTmp2] = caller_bank : dst_off (running cursor).
                STX     _libcTmp2
                SEP     #$20
                MX      %10
                LDA     _Sys_CallerBank
                STA     _libcTmp2+2
                REP     #$20
                MX      %00

                LDA     _mi_subcmd
                AND     #$00FF
                CMP     #7
                BCC     @mi_inRange
                LDA     #EINVAL
                PLP
                CLC
                RTS

@mi_inRange     ASL                             ; *2 = word index
                TAX
                JMP     (_MI_Dispatch,X)

_MI_NoSub       LDA     #EINVAL                 ; a retired subcmd
                PLP
                CLC
                RTS

_MI_Dispatch    DA      _MI_TypeStats           ; 0
                DA      _MI_ArenaStats          ; 1
                DA      _MI_ChunkWalk           ; 2
                DA      _MI_NoSub               ; 3 (retired: the bank map)
                DA      _MI_GuardAudit          ; 4
                DA      _MI_BlkTab              ; 5 (train-2: arena block table)
                DA      _MI_MMStats             ; 6 (train-2: the MM's own totals)

;------------------------------------------------------------------------------
; _MI_MMStats (subcmd 6) - the Memory Manager's OWN view: TotalMem ($1002),
; FreeMem ($1802), MaxBlock ($1C02) — three longs (lo16,hi16 each), 12 bytes.
; The cross-check for "malloc is fully MM-backed": TOTAL−FREE is everything
; in use machine-wide (FGX claims + system), FREE is what growth can still
; NewHandle.  All three are ROM-resident MM calls ("Errors: None").
;------------------------------------------------------------------------------
_MI_MMStats     MX      %00
                PHA                             ; result space hi
                PHA                             ; result space lo
                LDX     #$1D02                  ; _TotalMem (manual p522's
                                                ; "$1002" is an OCR D→0
                                                ; misread; $1002 is
                                                ; DisposeHandle)
                JSL     $E10000
                PLA
                STA     _mi_rec+0
                PLA
                STA     _mi_rec+2
                PHA
                PHA
                LDX     #$1B02                  ; _FreeMem ($1802 is
                                                ; GetHandleSize — facing-page
                                                ; OCR bleed in the manual scan)
                JSL     $E10000
                PLA
                STA     _mi_rec+4
                PLA
                STA     _mi_rec+6
                PHA
                PHA
                LDX     #$1C02                  ; _MaxBlock
                JSL     $E10000
                PLA
                STA     _mi_rec+8
                PLA
                STA     _mi_rec+10
                LDA     #_mi_rec
                STA     _libcSrcPtr
                SEP     #$20
                MX      %10
                _BANKK
                STA     _libcSrcPtr+2
                REP     #$20
                MX      %00
                LDA     #12
                JSR     _MI_Emit
                JMP     _MI_Done

;------------------------------------------------------------------------------
; _MI_BlkTab (subcmd 5) - raw copy of the arena BLOCK TABLE (train-2 M-1..4):
; BLKTAB_ROWS rows x 8 B {base bank, bank count, kind, pad, MM handle lo16,
; hi16}.
; kind: 0=free row, 1=boot REST claim, 2=MM kernel-arena bank, 3=MM
; user-grant bank, 4=dedicated big-malloc block.  vmstat -m renders it
; (kind names live userland-side).  Emits 0 bytes before _BlkTab_Init.
;------------------------------------------------------------------------------
_MI_BlkTab      MX      %00
                SEP     #$20
                MX      %10
                LDA     _kBlkTabBase+2          ; table published yet?
                REP     #$20
                MX      %00
                AND     #$00FF
                BEQ     @mibt_done              ; no → 0 bytes
                ; _libcSrcPtr = the heap-resident table (24-bit); _MI_Emit
                ; reads via [_libcSrcPtr] so the heap bank is reached directly.
                TAX                             ; bank byte (word-clean)
                LDA     _kBlkTabBase
                STA     _libcSrcPtr
                SEP     #$20
                MX      %10
                TXA
                STA     _libcSrcPtr+2
                REP     #$20
                MX      %00
                LDA     #BLKCACHE_OFF           ; BLKTAB_ROWS x 8 B
                JSR     _MI_Emit
@mibt_done      JMP     _MI_Done

;------------------------------------------------------------------------------
; Tail shared by every subcmd: PLP / SEC / RTS with A = bytes written.
;------------------------------------------------------------------------------
_MI_Done        MX      %00
                LDA     _mi_written
                PLP
                SEC
                RTS

;------------------------------------------------------------------------------
; _MI_Emit - copy A bytes from kernel-static (_libcSrcPtr long pointer) into
;            caller buffer at [_libcTmp2].  Decrements _mi_bufRem; aborts the
;            current loop via C=0 if buf would overflow.
;
; In:  A = byte count, _libcSrcPtr = source long pointer.
; Out: C=1 success; C=0 if buf overflowed (caller falls through to _MI_Done).
;      _libcTmp2 advanced by A; _libcSrcPtr advanced by A; _mi_written += A;
;      _mi_bufRem -= A.
;------------------------------------------------------------------------------
_MI_Emit        MX      %00
                CMP     _mi_bufRem
                BCC     @miE_fit
                BEQ     @miE_fit
                CLC
                RTS
@miE_fit        STA     _mi_thisCnt
                LDY     #0
@miE_L          CPY     _mi_thisCnt
                BCS     @miE_done
                SEP     #$20
                MX      %10
                LDA     [_libcSrcPtr],Y
                STA     [_libcTmp2]
                REP     #$20
                MX      %00
                INC     _libcTmp2
                INY
                BRA     @miE_L
@miE_done       ; advance source by Y
                CLC
                LDA     _libcSrcPtr
                ADC     _mi_thisCnt
                STA     _libcSrcPtr
                BCC     @miE_noHi
                SEP     #$20
                MX      %10
                LDA     _libcSrcPtr+2
                INC
                STA     _libcSrcPtr+2
                REP     #$20
                MX      %00
@miE_noHi       ; accumulate counters
                LDA     _mi_written
                CLC
                ADC     _mi_thisCnt
                STA     _mi_written
                LDA     _mi_bufRem
                SEC
                SBC     _mi_thisCnt
                STA     _mi_bufRem
                SEC
                RTS

;==============================================================================
; Subcmd 0: type stats.
; Emit 8 records × 16 B = 128 B max.  Each record:
;   +0  name[8]    (truncated/null-padded from Kmem_TypeNames[i])
;   +8  inuse:2    bytes
;   +10 count:2    chunks
;   +12 calls:2    cumulative
;   +14 peak:2     bytes
;==============================================================================
_MI_TypeStats   MX      %00
                LDX     #0                      ; type index
@mits_L         CPX     #KMEM_TYPE_COUNT
                BCS     @mits_done
                ; --- Name (8 bytes, padded) ---
                JSR     _MI_EmitTypeName        ; writes 8 bytes via _MI_Emit
                BCC     @mits_done              ; buf full → return what we have
                ; --- Four 2-byte fields (16 bytes total record so far is 8) ---
                ; Build source ptr to Kmem_TypeStats[X], emit 8 bytes.
                PHX
                TXA
                ASL
                ASL
                ASL                             ; *8 = KMEM_TYPE_REC_SIZE
                CLC
                ADC     #Kmem_TypeStats
                STA     _libcSrcPtr
                SEP     #$20
                MX      %10
                _BANKK
                STA     _libcSrcPtr+2
                REP     #$20
                MX      %00
                LDA     #KMEM_TYPE_REC_SIZE
                JSR     _MI_Emit
                PLX
                BCC     @mits_done
                INX
                BRA     @mits_L
@mits_done      JMP     _MI_Done

;------------------------------------------------------------------------------
; _MI_EmitTypeName - emit 8 bytes of type-X's name, NUL-padded.
; In: X = type index (preserved).  Out: C=1 if 8 bytes written, C=0 if buf
; overflow.
;------------------------------------------------------------------------------
_MI_EmitTypeName MX     %00
                PHX
                ; src ptr to ASC string lives in Kmem_TypeNames[X] (16-bit ptr).
                TXA
                ASL                             ; *2
                TAX
                LDA     Kmem_TypeNames,X
                STA     _libcSrcPtr
                SEP     #$20
                MX      %10
                _BANKK
                STA     _libcSrcPtr+2
                REP     #$20
                MX      %00
                ; Read up to 8 bytes; stop at NUL, then pad with zeros.
                LDY     #0
                LDA     _mi_bufRem
                CMP     #8
                BCS     @mietn_fit
                ; Not enough room for full 8 bytes.
                PLX
                CLC
                RTS
@mietn_fit      ; Copy chars
@mietn_L        CPY     #8
                BCS     @mietn_done
                SEP     #$20
                MX      %10
                LDA     [_libcSrcPtr],Y
                BEQ     @mietn_pad              ; NUL → switch to padding
                STA     [_libcTmp2]
                REP     #$20
                MX      %00
                INC     _libcTmp2
                INY
                BRA     @mietn_L
@mietn_pad      ; A=0 already.  Write 0 bytes until Y=8.
@mietn_padL     STA     [_libcTmp2]
                REP     #$20
                MX      %00
                INC     _libcTmp2
                INY
                CPY     #8
                BCS     @mietn_done
                SEP     #$20
                MX      %10
                LDA     #0
                BRA     @mietn_padL
@mietn_done     REP     #$20
                MX      %00
                ; Accumulate
                LDA     _mi_written
                CLC
                ADC     #8
                STA     _mi_written
                LDA     _mi_bufRem
                SEC
                SBC     #8
                STA     _mi_bufRem
                PLX
                SEC
                RTS

;==============================================================================
; Subcmd 1: arena stats.  Just memcpy Kmem_Arenas[0..ArenaCount-1].
;==============================================================================
_MI_ArenaStats  MX      %00
                LDA     #Kmem_Arenas
                STA     _libcSrcPtr
                SEP     #$20
                MX      %10
                _BANKK
                STA     _libcSrcPtr+2
                REP     #$20
                MX      %00
                LDA     Kmem_ArenaCount
                AND     #$00FF
                ASL
                ASL
                ASL
                ASL                             ; *16 = KMEM_ARENA_SIZE
                JSR     _MI_Emit
                JMP     _MI_Done

;==============================================================================
; Subcmd 2/4: chunk walk / guard audit.
; Both iterate every chunk in every arena.  Subcmd 2 emits all chunks;
; subcmd 4 emits only chunks whose guard byte != $A5.  Record format (8 B):
;   +0 bank
;   +1 flags  (bit 0 = free, bit 1 = guard corrupt)
;   +2 off    (chunk header offset within bank)
;   +4 size   (CH_SIZE — user-data size)
;   +6 type   (CH_TYPE — M_* index)
;==============================================================================
_MI_ChunkWalk   MX      %00
                STZ     _mi_auditOnly
                BRA     _MI_Walk
_MI_GuardAudit  MX      %00
                LDA     #1
                STA     _mi_auditOnly
_MI_Walk        MX      %00
                LDX     #0                      ; arena index
@miw_aL         CPX     Kmem_ArenaCount
                BCC     @miw_aGo
                JMP     _MI_Done
@miw_aGo        ; Fetch arena[X].bank into _mi_bank, .first into _mi_off.
                JSR     _Kmem_ArenaPtr          ; _libcDstPtr = &arena[X]
                LDY     #ARENA_BANK
                LDA     (_libcDstPtr),Y
                AND     #$00FF
                STA     _mi_bank
                LDY     #ARENA_FIRST
                LDA     (_libcDstPtr),Y
                STA     _mi_off
                PHX                             ; save arena idx across chunk loop
@miw_cL         LDA     _mi_off
                BNE     @miw_cGo
                JMP     @miw_aNext              ; off=0 = end of chunk chain
@miw_cGo        ; Build long pointer to chunk header: bank << 16 | off
                LDA     _mi_off
                STA     _libcSrcPtr
                SEP     #$20
                MX      %10
                LDA     _mi_bank
                STA     _libcSrcPtr+2
                REP     #$20
                MX      %00
                ; Read CH_SIZE, CH_TYPE, CH_NEXT via [_libcSrcPtr],Y.
                LDY     #CH_SIZE
                LDA     [_libcSrcPtr],Y
                STA     _mi_chSize
                LDY     #CH_TYPE
                LDA     [_libcSrcPtr],Y
                STA     _mi_chType
                LDY     #CH_NEXT
                LDA     [_libcSrcPtr],Y
                STA     _mi_chNext
                ; Determine flags: bit 0 = free (type==0); bit 1 = guard bad.
                STZ     _mi_chFlags
                LDA     _mi_chType
                AND     #$00FF
                BNE     @miw_notFree
                LDA     _mi_chFlags
                ORA     #$0001
                STA     _mi_chFlags
@miw_notFree    ; Read guard byte at off + CH_HEADER_LEN + CH_SIZE.
                ; Used chunks only (free chunks don't have meaningful guard).
                LDA     _mi_chType
                AND     #$00FF
                BEQ     @miw_guardSkip
                CLC
                LDA     _mi_off
                ADC     #CH_HEADER_LEN
                CLC
                ADC     _mi_chSize
                STA     _libcSrcPtr             ; reuses _libcSrcPtr (lo word)
                ; bank still in _libcSrcPtr+2 from above.
                LDY     #0
                SEP     #$20
                MX      %10
                LDA     [_libcSrcPtr],Y
                CMP     #CH_GUARD
                REP     #$20
                MX      %00
                BEQ     @miw_guardSkip
                LDA     _mi_chFlags
                ORA     #$0002
                STA     _mi_chFlags
@miw_guardSkip  ; Audit-only mode: skip non-corrupt chunks.
                LDA     _mi_auditOnly
                AND     #$00FF
                BEQ     @miw_emit
                LDA     _mi_chFlags
                AND     #$0002
                BEQ     @miw_advChunk
@miw_emit       ; Build the 8-byte record at _mi_rec, then emit it.
                SEP     #$20
                MX      %10
                LDA     _mi_bank
                STA     _mi_rec+0
                LDA     _mi_chFlags
                STA     _mi_rec+1
                REP     #$20
                MX      %00
                LDA     _mi_off
                STA     _mi_rec+2
                LDA     _mi_chSize
                STA     _mi_rec+4
                LDA     _mi_chType
                STA     _mi_rec+6
                ; Source pointer for this 8-byte record.
                LDA     #_mi_rec
                STA     _libcSrcPtr
                SEP     #$20
                MX      %10
                _BANKK
                STA     _libcSrcPtr+2
                REP     #$20
                MX      %00
                LDA     #8
                JSR     _MI_Emit
                BCS     @miw_advChunk
                PLX                             ; balance the earlier PHX
                JMP     _MI_Done
@miw_advChunk   LDA     _mi_chNext
                STA     _mi_off
                JMP     @miw_cL
@miw_aNext      PLX
                INX
                JMP     @miw_aL

;==============================================================================
; _Sys_Malloc (#62) - SYS_MALLOC userland allocator entry.
;
; Thin wrapper over Kmalloc(size, M_ANON).  Userland gets a 24-bit
; pointer into one of the kernel heap banks ($07-$09); userland uses
; LDAL/STAL to access.  When per-task user heap lands (post-MVP),
; this becomes a per-task arena lookup; for now everything routes
; through the shared kernel arenas.
;
; Input:    A = size (16-bit, bytes).  MX %00.
; Output:   C=1 + A.lo = bank, X = offset; or
;           C=0 + A = errno (ENOMEM if heap full, EINVAL if size=0).
; Preserves caller M/X via the syscall dispatcher.
;------------------------------------------------------------------------------
_Sys_Malloc     MX      %00
                LDX     #0                      ; zero-extend the legacy 16-bit
                                                ; size (M-4) and fall through —
                                                ; $F000..$FFFF legacy requests now
                                                ; succeed via a dedicated MM block
                                                ; instead of ENOMEM.
;------------------------------------------------------------------------------
; _Sys_Malloc32 (#96) - SYS_MALLOC32: 32-bit-size userland allocator (M-4).
;
; Input:    A = size lo16, X = size hi16.  MX %00.
; Output:   C=1 + A.lo = bank, Y = offset (0 = dedicated MM block); or
;           C=0 + A = errno (ENOMEM / EINVAL).
; Sizes below KMALLOC_BIG_THRESH (with hi16 = 0) ride the byte-grain
; Kmalloc arenas exactly as before; anything bigger gets a dedicated MM
; block via _Kmalloc_Big (kind=4 block-table row; free lists never cross
; block boundaries).
;------------------------------------------------------------------------------
_Sys_Malloc32   MX      %00
                CPX     #0
                BNE     @sm_big                 ; >64KB → dedicated block
                CMP     #KMALLOC_BIG_THRESH
                BCS     @sm_big                 ; $F000..$FFFF → dedicated block
                LDX     #M_ANON
                JSR     Kmalloc
                BCC     @sm_fail
                ; Success: _kmallocResult holds 24-bit user ptr (lo, mid, bank).
                ; Return offset in Y (NOT X): dispatcher exit's LDX _Sys_UserSP
                ; clobbers handler-return X (see
                ; feedback_syscall_dispatcher_x_clobber_at_exit.md).  Bank in
                ; A.lo as documented.
                LDY     _kmallocResult          ; offset (lo+mid as 16-bit)
                SEP     #$20
                MX      %10
                LDA     _kmallocResult+2        ; bank byte → A.lo
                REP     #$20
                MX      %00
                AND     #$00FF
                SEC
                RTS
@sm_fail        ; Kmalloc set A = errno (ENOMEM / EINVAL); fall through.
                CLC
                RTS
@sm_big         JMP     _Kmalloc_Big            ; same C/A/Y return contract

;==============================================================================
; _Sys_Free (#63) - SYS_FREE userland deallocator entry.
;
; Thin wrapper over Kfree.  Takes the 24-bit user ptr (bank, offset) the
; caller got from SYS_MALLOC and stuffs it into _kmallocResult before
; calling Kfree (which is the kernel's free-by-DP-ptr convention).
;
; Input:    A.lo = bank, X = offset.  MX %00.
; Output:   C=1 ok.  Kfree silently logs HEAP CORRUPT on bad ptr / double-
;           free; the syscall still returns C=1 (no clean errno path today).
;           NULL ptr (bank=0 offset=0) is a no-op, returns C=1.
;------------------------------------------------------------------------------
_Sys_Free       MX      %00
                ; Stash the 24-bit ptr into _kmallocResult (DP slot).  Use
                ; plain STA/STX (DP-relative); STAL would target bank 0 and
                ; miss the kernel DP page entirely.
                STX     _kmallocResult          ; offset (lo+mid)
                SEP     #$20
                MX      %10
                STA     _kmallocResult+2        ; bank
                REP     #$20
                MX      %00
                CPX     #0
                BNE     @sf_kfree
                ; Offset 0: NULL or a dedicated big block (M-4) — big blocks
                ; are the ONLY allocations at bank:0000; arena chunks always
                ; sit past their chunk header.  Never hand an offset-0 ptr to
                ; Kfree (it would read a phantom header and log HEAP CORRUPT).
                AND     #$00FF
                BEQ     @sf_done                ; NULL free is a no-op
                ; Only the OWNER may dispose a big block (#11).  A snapshot-fork
                ; child runs in the parent's image and inherits its big blocks
                ; IN PLACE; if the child's free disposed one, the bank would go
                ; back to the Memory Manager while the parent's snapshot still
                ; expected to be restored into it.  Ignoring the child's free is
                ; not a leak and not a special case -- it is exactly snapshot-
                ; fork semantics, the same rollback its data-bank writes get.
                PHA                             ; the bank
                JSR     _BlkRow_OwnerOf
                BCC     @sf_notOurs             ; no live row: stale/double free
                CMP     _curTask
                BNE     @sf_notOurs
                PLA
                JSR     _Kfree_Big              ; lookup-miss (double-free of a
                                                ; big block) = silent no-op
                SEC
                RTS
@sf_notOurs     PLA
@sf_done        SEC
                RTS
@sf_kfree       JSR     Kfree
                SEC
                RTS

;==============================================================================
; _Sys_Realloc (#91) - SYS_REALLOC: resize a SYS_MALLOC block, preserving
; contents.  Implemented as Kmalloc(new) + copy(min(old,new)) + Kfree(old).
; Grow-in-place is a future optimization; alloc+copy+free is always correct
; and reuses the existing allocator without touching the free list.
;
; Input:    A.lo = old bank, X = old offset, Y = new size (bytes).  MX %00.
;           NULL old ptr (bank=0, offset=0) -> behaves as malloc(new).
; Output:   C=1 + A.lo = bank, Y = offset (offset in Y, NOT X — the dispatcher
;           exit clobbers handler-return X, same as _Sys_Malloc);
;           C=0 + A = errno (ENOMEM; the OLD block is left intact, per the C
;           realloc contract — caller's pointer stays valid on failure).
;------------------------------------------------------------------------------
_Sys_Realloc    MX      %00
                ; Stash inputs (Kmalloc/Kfree clobber A/X/Y + the DP scratch).
                STX     _Sys_ReOldOff
                STY     _Sys_ReNewSize
                AND     #$00FF
                STA     _Sys_ReOldBank

                ; realloc(NULL, n) == malloc(n): null iff bank=0 AND offset=0.
                LDA     _Sys_ReOldBank
                BNE     @re_haveOld
                LDA     _Sys_ReOldOff
                BNE     @re_haveOld
                LDA     _Sys_ReNewSize
                LDX     #M_ANON
                JSR     Kmalloc
                BCS     @re_n1ok                ; success
                BRL     @re_fail                ; fail (far — BCC can't reach)
@re_n1ok        BRL     @re_return              ; _kmallocResult = new block

@re_haveOld     ; A dedicated BIG block (offset 0, M-4) has no chunk header —
                ; the CH_SIZE read below would be a phantom and the Kfree at
                ; the end would corrupt-log.  Realloc of a big block is not
                ; supported (libc guards the size side; this guards the old-
                ; pointer side): fail EINVAL, old block left intact.
                LDA     _Sys_ReOldOff
                BNE     @re_notBig
                LDA     #EINVAL
                BRL     @re_fail
@re_notBig      ; old user size = CH_SIZE field of the chunk header, which sits
                ; CH_HEADER_LEN below the user pointer (see Kfree).
                LDA     _Sys_ReOldOff
                SEC
                SBC     #CH_HEADER_LEN
                STA     _libcTmp2
                SEP     #$20
                MX      %10
                LDA     _Sys_ReOldBank
                STA     _libcTmp2+2
                REP     #$20
                MX      %00
                LDY     #CH_SIZE
                LDA     [_libcTmp2],Y           ; A = old user size
                ; count = min(old_size, new_size)
                CMP     _Sys_ReNewSize
                BCC     @re_haveCount           ; old < new -> copy all of old (A)
                LDA     _Sys_ReNewSize          ; old >= new -> copy only new bytes
@re_haveCount   STA     _Sys_ReCount

                ; Allocate the new block.
                LDA     _Sys_ReNewSize
                LDX     #M_ANON
                JSR     Kmalloc
                BCS     @re_n2ok                ; success
                BRL     @re_fail                ; ENOMEM: old left intact, A=errno
@re_n2ok        ; Save the new ptr — Kfree below overwrites _kmallocResult.
                LDA     _kmallocResult
                STA     _Sys_ReNewOff
                SEP     #$20
                MX      %10
                LDA     _kmallocResult+2
                STA     _Sys_ReNewBank
                REP     #$20
                MX      %00

                ; Copy _Sys_ReCount bytes old -> new, byte-at-a-time via two
                ; long DP pointers (src=_libcTmp2, dst=_kmallocResult).  Bank-
                ; agnostic (bank lives in the pointer), no MVN/self-mod.
                LDA     _Sys_ReOldOff
                STA     _libcTmp2               ; src offset
                SEP     #$20
                MX      %10
                LDA     _Sys_ReOldBank
                STA     _libcTmp2+2             ; src bank
                REP     #$20
                MX      %00
                LDY     #0
                SEP     #$20                    ; 8-bit A for the byte copy; X/Y stay 16-bit
                MX      %10
@re_copyL       CPY     _Sys_ReCount            ; Y (16-bit) >= count?  CPY width = X flag = 16
                BCS     @re_copyDone
                LDA     [_libcTmp2],Y
                STA     [_kmallocResult],Y
                INY
                BRA     @re_copyL
@re_copyDone    REP     #$20
                MX      %00

                ; Free the old block (set _kmallocResult = old ptr first).
                LDA     _Sys_ReOldOff
                STA     _kmallocResult
                SEP     #$20
                MX      %10
                LDA     _Sys_ReOldBank
                STA     _kmallocResult+2
                REP     #$20
                MX      %00
                JSR     Kfree

                ; Restore _kmallocResult = new ptr for the shared return path.
                LDA     _Sys_ReNewOff
                STA     _kmallocResult
                SEP     #$20
                MX      %10
                LDA     _Sys_ReNewBank
                STA     _kmallocResult+2
                REP     #$20
                MX      %00

@re_return      ; Return like _Sys_Malloc: Y = offset, A.lo = bank, C=1.
                LDY     _kmallocResult
                SEP     #$20
                MX      %10
                LDA     _kmallocResult+2
                REP     #$20
                MX      %00
                AND     #$00FF
                SEC
                RTS
@re_fail        CLC                             ; A = errno (Kmalloc set it)
                RTS

;==============================================================================
; _Sys_MmAlloc (#68) - SYS_MM_ALLOC: large Memory-Manager allocation.
;
; Thin _NewHandle wrapper for the resident NTP module (may be >64 KB / span
; banks).  Block attr $C018 = locked|fixed with NO no-cross bit, so the MM may
; place the block across bank boundaries (the resident song needs a flat 24-bit
; space).  $C018 is the standard "general locked buffer" attribute used by real
; IIgs code (e.g. BloodySimpleInterfaceManager).  Returns the HANDLE; userland
; derefs it for the 24-bit base (locked|fixed → the master pointer is stable).
;
; Input:    A = size lo16, X = size hi16.  MX %00.
; Output:   C=1 + A.lo = handle bank, Y = handle offset; or
;           C=0 + A = ENOMEM.  (Offset in Y not X — dispatcher exit clobbers
;           handler-return X; feedback_syscall_dispatcher_x_clobber_at_exit.)
;------------------------------------------------------------------------------
_Sys_MmAlloc    MX      %00
                ; --- _NewHandle Pascal frame.  Result space pushed first; size
                ;     is taken from the live A (lo) / X (hi) before they change. ---
                PEA     $0000                   ; +2 result handle lo placeholder
                PEA     $0000                   ; +2 result handle hi placeholder
                PHX                             ; +2 blockSize hi (caller X)
                PHA                             ; +2 blockSize lo (caller A)
                LDA     _kFgxUserID
                PHA                             ; +2 userID
                PEA     $C008                   ; +2 attr = attrLocked|attrFixed|
                                                ;   attrNoSpec.  NO attrNoCross ($0010)
                                                ;   so a >64 KB block MAY span banks
                                                ;   (bits per Toolbox Ref vol1 p488).
                PEA     $0000                   ; +2 locationPtr hi (ignored)
                PEA     $0000                   ; +2 locationPtr lo (ignored)
                LDX     #$0902                  ; _NewHandle
                JSL     $E10000
                BCS     @mma_fail
                ; Toolbox popped the 12 input bytes; 4-byte handle on top:
                ;   1,S = handle lo (offset), 3,S = handle hi (bank in lo byte).
                LDA     1,S
                TAY                             ; return handle offset in Y
                LDA     3,S                     ; handle hi word
                PLX                             ; pop handle lo
                PLX                             ; pop handle hi
                AND     #$00FF                  ; A.lo = handle bank
                SEC
                RTS
@mma_fail       ; _NewHandle left the (null) result space on the stack; pop it.
                PLX
                PLX
                LDA     #ENOMEM
                CLC
                RTS

;==============================================================================
; _Sys_MmFree (#69) - SYS_MM_FREE: release a SYS_MM_ALLOC block.
;
; Input:    A.lo = handle bank, X = handle offset.  MX %00.
; Output:   C=1.
;------------------------------------------------------------------------------
_Sys_MmFree     MX      %00
                ; Push handle (4-byte): hi word ($00bb, bank in lo byte) first,
                ; lo word (offset, in X) on top — Toolbox arg convention.
                AND     #$00FF
                PHA                             ; handle hi (pushed first)
                PHX                             ; handle lo = offset (top)
                LDX     #$1002                  ; _DisposeHandle
                JSL     $E10000
                SEC
                RTS

;==============================================================================
; END syscall.s
;==============================================================================
