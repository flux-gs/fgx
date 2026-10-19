;==============================================================================
; task.s - TCB allocator + current-task pointer.
;
; Slice 2 of program-execution.  Establishes the task model that the
; cooperative/preemptive scheduler will plug into later.  v1 has no
; scheduler — exactly one user task runs at a time, with parents BLOCKED
; while their children execute.
;
; Public:
;   Task_Init      Zero the task table at boot.  Called from FGX_Entry.
;   Task_Alloc     Find a free TCB slot and return its 16-bit offset (within
;                  the kernel bank) in X.  C=1 ok, C=0 + A=EAGAIN if table full.
;   Task_Free      X = TCB offset.  Mark the slot UNUSED.
;   Task_Lookup    A = pid.  Return TCB offset in X.  C=1 ok, C=0 if no
;                  task with that pid.
;
; Layout:
;   FGX_TASK_TBL = \$020800 (build ORG; relocated to the live kernel bank).
;                  16 slots × 64 bytes = 1024 bytes ($400).
;   PID = idx + 1 (so PID 1 = first user task = init).
;
; Current task:
;   _curTask DP slot ($9E) holds the 16-bit kernel-bank offset of the current
;   TCB, or $0000 when no user task is running (kernel context / idle).
;==============================================================================

FGX_TASK_TBL_OFF EQU    $0800               ; offset of FGX_TASK_TBL within the kernel bank
TASK_MAX_SLOTS  EQU     NPROC               ; single knob (cfg/system.cfg kernel.nproc)

;------------------------------------------------------------------------------
; Task_Init - zero the task table.  Called from FGX_Entry early.
; Caller MX %00.  Preserves caller MX via PHP/PLP.
;------------------------------------------------------------------------------
Task_Init       ENT
                MX      %00
                PHP
                REP     #$30
                MX      %00
                ; Reloc: the task table lives in the kernel bank, and the MVN below
                ; both (a) zeroed the STALE $02 copy under relocation and (b) left
                ; DBR=$02 (dst bank), leaking it to every caller after us (Kmem_Init
                ; etc.).  Fix: DBR=kernel-bank (PHK/PLB) for the self-mod store, patch
                ; the MVN src+dst bank operands to the live kernel bank (PHK) so it
                ; zeros the RELOCATED table, and the MVN then leaves DBR=kernel-bank
                ; (= dst) — no leak.  Behavior-identical at $02 (PHK=$02).
                PHK
                PLB                             ; DBR = kernel bank (self-mod target)
                SEP     #$20
                MX      %10
                PHK
                PLA                             ; A.lo = live kernel bank
                STA     @ti_mvn+1               ; patch MVN dst bank
                STA     @ti_mvn+2               ; patch MVN src bank
                REP     #$30
                MX      %00
                ; Zero TASK_MAX_SLOTS * TCB_SIZE bytes via STZ + MVN.
                STZ     FGX_TASK_TBL_OFF        ; first byte = 0 (DBR=kernel bank)
                LDA     #{TASK_MAX_SLOTS*TCB_SIZE}-2
                LDX     #FGX_TASK_TBL_OFF
                LDY     #FGX_TASK_TBL_OFF+1
@ti_mvn         MVN     $02,$02                 ; src+dst banks patched -> kernel bank
                ; MVN leaves DBR = dst = kernel bank (no $02 leak).
                ; Zero the user-stack arena page map (all pages free).  DBR is
                ; the kernel bank here, so the abs,X store hits the live copy.
                SEP     #$20
                MX      %10
                LDX     #FGX_STK_ARENA_PAGES-1
@ti_zmap        STZ     _stkArenaMap,X
                DEX
                BPL     @ti_zmap
                REP     #$30
                MX      %00
                ; The user-image tables: every task resident, no home, no swap
                ; bank.  HERE, before init's stack is carved -- the carve marks
                ; init resident, and a later zeroing would make its first
                ; re-pick look for a home it never needed.
                JSR     Uimg_Init
                ; _curTask = 0 (no user task running yet).
                STZ     _curTask
                PLP
                RTS

;------------------------------------------------------------------------------
; Task_Alloc - find first free TCB slot, mark it READY, set TaskID.
;
; Output: C=1 + X = TCB offset within the kernel bank (\$02 = build ORG).
;         C=0 + A = EAGAIN if table is full.
; Caller MX %00.
;------------------------------------------------------------------------------
Task_Alloc      ENT
                MX      %00
                PHP
                REP     #$30
                MX      %00
                ; Round-robin scan (2026-07-27): start at _taskAllocCur, the
                ; slot AFTER the previous allocation, so a just-freed slot is
                ; not immediately re-issued.  Instant pid reuse aliased BSD job
                ; control: a vfork'd pipeline runs its children SEQUENTIALLY,
                ; both got the same pid, and tcsh's pchild/pfind matched the
                ; first proclist entry twice -- the second member stayed
                ; PRUNNING and pjwait polled forever.  pid stays slot+1, so
                ; every (pid-1)-indexed fast path is unchanged.
                LDY     _taskAllocCur           ; candidate slot (0..NPROC-1)
                LDA     #TASK_MAX_SLOTS
                STA     _shTmp0                 ; tries (caller-saved DP scratch)
@ta_L           CPY     #TASK_MAX_SLOTS         ; wrap candidate
                BCC     @ta_inb
                LDY     #0
@ta_inb         TYA                             ; X = FGX_TASK_TBL_OFF + slot*64
                ASL
                ASL
                ASL
                ASL
                ASL
                ASL
                CLC
                ADC     #FGX_TASK_TBL_OFF
                TAX
                LDA:     TCB_Status,X            ; abs,X under DBR=kernel-bank
                BEQ     @ta_found               ; TASK_UNUSED = 0
                INY
                DEC     _shTmp0
                BNE     @ta_L
                LDA     #EAGAIN
                PLP
                CLC
                RTS
@ta_found       LDA     #TASK_READY
                STA:     TCB_Status,X
                INY                             ; Y = pid = slot+1
                TYA
                STA     _taskAllocCur           ; cursor = slot+1 = next start
                                                ; (== TASK_MAX_SLOTS wraps at
                                                ; the next scan's CPY)
                STA:     TCB_TaskID,X
                ; Phase 2 slice 2.1: zero TCB_BankList so a recycled slot
                ; doesn't carry banks owned by the previous occupant.
                ; _Sys_Exit walks this list to Bank_Free at task end —
                ; stale entries would double-free.
                LDA     #0
                STA:     TCB_BankList+0,X
                STA:     TCB_BankList+2,X
                STA:     TCB_BankList+4,X
                STA:     TCB_BankList+6,X
                ; Clear this pid's signal ENTRY slot.  Stale on pid reuse;
                ; the kernel now posts SIGCHLD at every child exit (2026-07-27), so
                ; a recycled slot would deliver into the PREVIOUS occupant's
                ; handler offset in the NEW task's code bank.  Y = pid here
                ; (stored to TCB_TaskID above); handler idx = (pid-1)*2.
                ; [_sigHndPtr] is kernel-DP -- Task_Alloc runs in syscall/boot
                ; context, after _AllocSigHnd.
                DEY
                TYA
                ASL                             ; (pid-1)*2 = ENTRY index
                CLC
                ADC     #SIGHND_ENTRY_OFF
                TAY
                PHX                             ; balances the PLX at the end of
                                                ;   this routine -- it used to
                                                ;   guard the handler-table loop
                                                ;   counter and now just keeps
                                                ;   the caller's X, which the
                                                ;   exit still pulls
                LDA     #0
                STA     [_sigHndPtr],Y
                ; + zero the 32-bit signal mask -- NOTE the different stride:
                ; masks are (pid-1)*4 at SIGHND_MASK_OFF, not (pid-1)*2.  Same
                ; pid-reuse hazard: a stale mask would silently suppress the
                ; NEW occupant's signals.
                LDA     _taskAllocCur           ; == pid (stored above)
                DEC
                ASL
                ASL                             ; (pid-1)*4
                CLC
                ADC     #SIGHND_MASK_OFF
                TAY
                LDA     #0
                STA     [_sigHndPtr],Y
                INY
                INY
                STA     [_sigHndPtr],Y
                ; + zero the 32-bit SIG_IGN mask (same (pid-1)*4 stride, table
                ; at SIGHND_IGN_OFF = MASK_OFF+32): a recycled pid must not
                ; inherit the previous occupant's ignored signals.
                TYA
                CLC
                ADC     #SIGHND_IGN_OFF-SIGHND_MASK_OFF-2
                TAY
                LDA     #0
                STA     [_sigHndPtr],Y
                INY
                INY
                STA     [_sigHndPtr],Y
                ; + zero the 32-bit CATCH mask (apple/fgx#58; same (pid-1)*4
                ; stride, one 64 B table further on).  This is the one that
                ; MUST be scrubbed: a stale bit would make delivery jump to the
                ; ENTRY slot for a signal the new occupant never installed --
                ; the pid-reuse hazard the five handler tables carried, now in
                ; one place instead of five.
                TYA
                CLC
                ADC     #SIGHND_CATCH_OFF-SIGHND_IGN_OFF-2
                TAY
                LDA     #0
                STA     [_sigHndPtr],Y
                INY
                INY
                STA     [_sigHndPtr],Y
                LDA     _taskAllocCur
                DEC
                ASL
                ASL
                ASL
                ASL
                ASL
                CLC
                ADC     #SE_PGroup
                TAY
                LDA     #0
                STA     [_schedTblPtr],Y
                ; + zero this slot's ALARM state (apple/fgx#474).  The same
                ; pid-reuse hazard as the four masks above, and the only one of
                ; these tables that is NOT in the signal block: nothing clears
                ; `_kAlarmTicks' when a task exits -- `_Sig_AlarmDeliver's own
                ; comment says so -- and the heartbeat keeps counting it down
                ; whether the slot is live or not.  That guard tests whether the
                ; slot is UNUSED, which a REUSED slot is not, so a countdown left
                ; behind by the previous occupant posts SIGALRM to this one, and
                ; SIGALRM's default action terminates.  Upstream zeroes the
                ; equivalent where it hands out a process:
                ;     rpp->p_realtimer.it_value = 0;
                ;               -- vendor/2.11BSD/usr/sys/sys/kern_fork.c:165
                ; The EXPIRY FLAG first, because it is indexed by (pid-1) and the
                ; counter by (pid-1)*4, so one read of the pid serves both.  One
                ; byte per task, hence the 8-bit store: a 16-bit one would clear
                ; the NEXT task's flag too.  Clearing it closes the window where
                ; the counter reached zero while the slot was dead, leaving
                ; `_kAlarmFired' set and waiting, and this allocation hands the
                ; slot over before swtch consumes it -- `_Sig_AlarmDeliver' would
                ; then find a LIVE slot and deliver the dead task's expiry here.
                LDA     _taskAllocCur           ; == pid (stored above)
                DEC                             ; (pid-1)
                TAY
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _kAlarmFired,Y
                REP     #$20
                MX      %00
                TYA
                ASL                             ; (pid-1)*2
                TAX
                LDA     #0                      ; REP widened A; its high byte is
                                                ;   whatever the hidden B held
                STA     _kAlarmReload,X         ; setitimer(2)'s interval, same
                                                ;   hazard: a recycled pid must
                                                ;   not inherit a REPEAT either
                TXA
                ASL                             ; (pid-1)*4
                TAY
                LDA     #0
                STA     _kAlarmTicks,Y
                STA     _kAlarmTicks+2,Y
                ; ld.mod: a fresh slot uses no library (shared libc SP4).
                LDA     _taskAllocCur           ; == pid
_ktp110         JSL     KTTY_LD_TALLOC
                PLX
                PLP
                SEC
                RTS

;------------------------------------------------------------------------------
; _Task_FreeBanks - Bank_Free every non-zero entry in TCB_BankList[0..7]
; and zero the slot.  Called from _Sys_Exit before marking the task
; ZOMBIE.  Phase 2 slice 2.1 contract: a single-bank FGX1 task touches
; only slot 0; FGX2 multi-bank tasks (slice 2.3+) populate 0..n-1.
;
; Input:  X = TCB offset within the kernel bank (\$02 = build ORG).
; Output: TCB_BankList[0..7] = all zeros; banks returned to the pool.
;         A/Y clobbered.  X = TCB offset (preserved — Bank_Free PHX/PHY's
;         per its docs).  Caller MX %00.
;
; Unrolled across the 8 slots: ~6 instructions × 8 = ~50 lines, but each
; block is trivially correct and the abs+X addressing stays simple.
;------------------------------------------------------------------------------
_Task_FreeBanks ENT
                MX      %00
                PHP
                REP     #$30
                MX      %00

                ; The text it ran loses its reference (2.11BSD exit -> xfree).
                LDA:    TCB_TaskID,X
                PHX
                LDX     #0
_ktp121         JSL     KTTY_TEXT_SET
                PLX

                ; Stay at M=0/X=0 throughout so JSR Bank_Free (which
                ; declares MX %00) matches static MX-tracking.  Each LDA
                ; reads a 16-bit word — the bank byte is the low half;
                ; AND #$00FF before the zero test masks the high byte
                ; (which belongs to the NEXT slot, but we'll iterate to
                ; it separately so reading it now is harmless).
                ;
                ; Phase ordering: free all non-zero slots first, then
                ; bulk-zero the entire 8-byte array at the end via 4
                ; M=0 word-STZs.  Doing per-slot clears mid-loop would
                ; need an M=8 island (since STZ at M=0 zeros 2 bytes
                ; and would clobber the next slot's bank byte before we
                ; could read it).  Bulk-zero at the end avoids the
                ; island entirely.

                LDA:    TCB_BankList+0,X
                AND     #$00FF
                BEQ     @tfb_s1
                JSR     Bank_Free
@tfb_s1         LDA:    TCB_BankList+1,X
                AND     #$00FF
                BEQ     @tfb_s2
                JSR     Bank_Free
@tfb_s2         LDA:    TCB_BankList+2,X
                AND     #$00FF
                BEQ     @tfb_s3
                JSR     Bank_Free
@tfb_s3         LDA:    TCB_BankList+3,X
                AND     #$00FF
                BEQ     @tfb_s4
                JSR     Bank_Free
@tfb_s4         LDA:    TCB_BankList+4,X
                AND     #$00FF
                BEQ     @tfb_s5
                JSR     Bank_Free
@tfb_s5         LDA:    TCB_BankList+5,X
                AND     #$00FF
                BEQ     @tfb_s6
                JSR     Bank_Free
@tfb_s6         LDA:    TCB_BankList+6,X
                AND     #$00FF
                BEQ     @tfb_s7
                JSR     Bank_Free
@tfb_s7         LDA:    TCB_BankList+7,X
                AND     #$00FF
                BEQ     @tfb_zero
                JSR     Bank_Free

@tfb_zero       ; Bulk-zero TCB_BankList[0..7] (4 word stores at M=0).
                LDA     #0
                STA:    TCB_BankList+0,X
                STA:    TCB_BankList+2,X
                STA:    TCB_BankList+4,X
                STA:    TCB_BankList+6,X

                PLP
                RTS

;------------------------------------------------------------------------------
; Task_Free - mark a TCB slot UNUSED and free what it holds.
; Input:  X = TCB offset within the kernel bank (\$02 = build ORG).
; Caller MX %00.
;------------------------------------------------------------------------------
Task_Free       ENT
                MX      %00
                PHP
                REP     #$30
                MX      %00
                JSR     Task_FreeFdTable        ; Kfree fd table (if allocated)
                JSR     Task_FreeStack          ; the user stack, direct page included
                JSR     Task_FreeKernStack      ; dispose MM-allocated kernel stack (Phase 3)
                JSR     Task_FreeUarea          ; Kfree the u-area (Phase 3)
                ; Clear sched-entry flags so a recycled slot has no stale SEF_*.
                TXA
                SEC
                SBC     #FGX_TASK_TBL_OFF
                LSR
                CLC
                ADC     #SE_Flags
                TAY
                LDA     #0
                STA     [_schedTblPtr],Y
                ; Clear the process-name slot (hygiene for a recycled slot).
                ; _kCopyPtr = _procNameTblPtr + (pid<<4); name[0] = NUL.
                LDA:    TCB_TaskID,X
                AND     #$00FF
                ASL
                ASL
                ASL
                ASL
                CLC
                ADC     _procNameTblPtr
                STA     _kCopyPtr
                SEP     #$20
                LDA     _procNameTblPtr+2
                ADC     #0
                STA     _kCopyPtr+2
                LDA     #0
                STA     [_kCopyPtr]
                REP     #$20
                LDA     #TASK_UNUSED
                STA:     TCB_Status,X
                PLP
                SEC
                RTS

;------------------------------------------------------------------------------
; Task_InheritCwd - copy the CURRENT (parent) task's cwd into the child's slot.
; The child inherits the parent's working directory at spawn (BSD fork copies
; fd_cdir).  Source = parent's current cwd via [_fsCwdPtr]; dest = child slot via
; [_kCopyPtr] = _cwdTblPtr + (childpid<<7).
;
; Input:  A = child pid (16-bit).  MX %00.  Clobbers A,X,Y.
;------------------------------------------------------------------------------
Task_InheritCwd ENT
                MX      %00
                ; THE CHILD PID IS SAVED BEFORE THE FIRST INSTRUCTION TOUCHES
                ; IT.  The vnode half at @tic_done needs it, and A does not
                ; survive: the shift chain below consumes it to build the string
                ; slot's address and the copy loop then uses A for bytes, so at
                ; @tic_done it holds the NUL that ended the copy.  Passing that
                ; as the child pid is a call to vfs_cdirfork(_, 0), which its
                ; range test answers by returning -- silently, and the child
                ; then resolves every relative name against the root while
                ; `pwd' prints the directory it did not get.
                PHA
                ; --- AND THE CWD VNODE, which is the same inheritance --------
                ;
                ; 4.3BSD-Reno kern_fork.c:272, `VREF(u.u_cdir)'.  The string
                ; copied above is the ProDOS-era cwd; vfs.mod holds the VNODE
                ; one, and a child that inherited one but not the other would
                ; resolve `.profile' against a different directory from the one
                ; `pwd' prints.
                ;
                ; HERE AND NOT AT THE THREE CALL SITES.  Fork, spawn and boot's
                ; launch of init all reach this routine to inherit a cwd, so
                ; this is where "the child inherits the parent's cwd" already
                ; means both halves -- and the core bank pays for the call once
                ; instead of three times, which is what the room allows.
                ;
                ; A IS THE CHILD PID AND `_curTask' IS THE PARENT, which is the
                ; same pair the copy above used: `_fsCwdPtr' names the CURRENT
                ; task's slot.  At boot `_curTask' is still 0 (main.s:1067) and
                ; that is not a special case -- vfs_cdirfork reads an
                ; out-of-range parent as "nothing to inherit", which leaves the
                ; child null, which means the root.  Reno spells the same thing
                ; `u.u_cdir = rootdir' at init_main.c:183.
                LDA     1,S                     ; the child pid, saved at entry
                AND     #$00FF
                PHA                             ; cpid: fcc reads its arguments
                                                ;   right to left, so the LAST
                LDA     _curTask                ;   one goes down FIRST
                AND     #$00FF
                PHA                             ; ppid
_kfp965         JSL     KFAR_VFS_CDIRFORK       ; slot 49; returns void
                PLA                             ; the caller pops its arguments
                PLA
                PLA                             ; and the saved child pid
                RTS

;------------------------------------------------------------------------------
; Task_InheritName - copy the CURRENT (parent) task's process name into the
; child's slot.  2.11BSD keeps the name in the u-area (u_comm, h/user.h) and
; fork copies the whole u-area to the child (sys/kern_fork.c, newproc:
; `copy(a1, rpp->p_addr, USIZE)'), so a child is its parent's name until
; execve renames it (kern_exec.c).  A daemon that forks and never execs --
; syslogd, inetd, update, cron -- is therefore listed by ps under its own name.
;
; Input:  A = child pid (16-bit).  MX %00.  Clobbers A,X,Y, _kCopyPtr, _tsnPath.
;------------------------------------------------------------------------------
Task_InheritName ENT
                MX      %00
                AND     #$00FF
                ASL
                ASL
                ASL
                ASL
                TAX                             ; X = child slot offset
                LDA     _curTask
                AND     #$00FF
                ASL
                ASL
                ASL
                ASL
                TAY                             ; Y = parent slot offset
                LDA     _procNameTblPtr         ; _kCopyPtr = the table
                STA     _kCopyPtr
                LDA     _procNameTblPtr+2
                STA     _kCopyPtr+2             ; (bank byte; the high byte
                                                ;  lands in _tsnPath, reset next)
                LDA     #PROC_NAME_MAX/2
                STA     _tsnPath                ; word count
@tin_copy       LDA     [_kCopyPtr],Y           ; parent's word
                PHY
                TXY
                STA     [_kCopyPtr],Y           ; -> child's
                PLY
                INX
                INX
                INY
                INY
                DEC     _tsnPath
                BNE     @tin_copy
                RTS

;------------------------------------------------------------------------------
; Task_SetName - set the child's process name = basename(path), lowercased.
; The name feeds ps.  Source path is a kernel-bank NUL-term string (reached via
; DBR); dest is the heap name slot via [_kCopyPtr] = _procNameTblPtr + (childpid<<4).
;
; Input:  A = child pid (16-bit); X = kernel-bank ptr to the NUL-term spawn path.
;         MX %00.  Clobbers A,X,Y.
;------------------------------------------------------------------------------
Task_SetName    ENT
                MX      %00
                STX     _tsnPath                ; DP word: path offset (kernel bank via DBR)
                ; _kCopyPtr = _procNameTblPtr + (childpid << 4)
                AND     #$00FF
                ASL
                ASL
                ASL
                ASL
                CLC
                ADC     _procNameTblPtr         ; + heap base low word
                STA     _kCopyPtr
                SEP     #$20
                LDA     _procNameTblPtr+2        ; bank byte + carry
                ADC     #0
                STA     _kCopyPtr+2
                REP     #$20
                ; Pass 1: find basename start = index just past the last '/'.
                LDX     #0                      ; X = basename start offset (0 = whole)
                LDY     #0
@tsn_scan       SEP     #$20
                LDA     (_tsnPath),Y            ; path[Y], kernel bank via DBR
                REP     #$20
                AND     #$00FF
                BEQ     @tsn_scanDone           ; end of path
                CMP     #'/'
                BNE     @tsn_scanNext
                INY                             ; basename starts after the '/'
                TYX
                BRA     @tsn_scan
@tsn_scanNext   INY
                BRA     @tsn_scan
@tsn_scanDone   ; Advance _tsnPath by the basename offset so source & dest share Y.
                TXA
                CLC
                ADC     _tsnPath
                STA     _tsnPath                ; _tsnPath -> basename (in-bank; short paths)
                ; Pass 2: copy basename -> name slot, lowercasing A-Z.
                LDY     #0
@tsn_copy       SEP     #$20
                LDA     (_tsnPath),Y            ; basename[Y]
                CMP     #'A'
                BCC     @tsn_store
                CMP     #'Z'+1
                BCS     @tsn_store
                CLC
                ADC     #$20                    ; uppercase -> lowercase
@tsn_store      STA     [_kCopyPtr],Y           ; -> name slot[Y] (heap)
                REP     #$20
                AND     #$00FF
                BEQ     @tsn_done               ; copied the NUL
                INY
                CPY     #PROC_NAME_MAX-1
                BCC     @tsn_copy
                SEP     #$20                    ; cap: force NUL
                LDA     #0
                STA     [_kCopyPtr],Y
                REP     #$20
@tsn_done       RTS

;------------------------------------------------------------------------------
; Task_AllocStack - carve N bank-0 pages for a task's user stack from the
; fixed FGX_STK_ARENA via a first-fit page allocator, NOT the Memory Manager:
; the canonical TN#27 $00/0800 claim leaves the MM no free bank-0 page, and
; 65816 stacks must live in bank 0.  Every task carves here, init included
; (main.s).  vi-port slice 2: stack_pages_hint -> 1..MAX pages.
;
; THE DIRECT PAGE COMES WITH IT: the reservation is N+1 pages, and its first
; page is the task's user direct page, zeroed, immediately below the stack --
; so it parks and returns with the stack, and a process costs no fixed bank-0
; page.  TCB_DirectPage names it and TCB_StackBase is the page above.
;
; Input:  X = TCB offset within the kernel bank ($02 = build ORG; slot already
;             Task_Alloc'd).
;         A.lo = pages requested (0 -> default 1; clamp to [1, MAX]).
; Output: C=1, TCB_StackBase,X = page address (bank-0 offset),
;         TCB_StackSize,X = pages * 256, TCB_DirectPage,X = StackBase - 256,
;         TCB_StackHandle,X = 0 (no MM handle; Task_FreeStack frees by arena
;         bounds, not by handle).  The task is RESIDENT: its bytes are at
;         their own addresses.
;         C=0 + A = ENOMEM if no run is free and none can be taken over (the
;         tier-2 arm below, _Uimg_Overlap).
; Caller MX %00.  Preserves X.
;------------------------------------------------------------------------------
; Two-ended first-fit threshold (arena B1, 2026-07-31): a request of this many
; pages or more is allocated from the TOP of the arena, smaller ones from the
; bottom.  8 splits today's userland where lifetime actually differs -- sh(10),
; vi(15), tar(17) and tcsh(56) take the top; grep/sed/wc/cat (2-4) and every
; other pipeline stage take the bottom.  Purely a fragmentation heuristic: it
; changes WHERE a stack lands, never whether the allocation succeeds.
TASK_STACK_BIG_PAGES EQU 8

TASK_STACK_MAX_PAGES EQU 83            ; ~21 KB per-task cap.  Raised 16->32 at
                                       ; P3-3 3.2 (locals moved to the hw stack;
                                       ; a single >4KB frame — e.g. two 2KB
                                       ; arrays — needs 17 pages), 32->56 for
                                       ; tcsh, then 56->83 on 2026-07-28 so tcsh
                                       ; fits UNCLAMPED: its stack model wants
                                       ; 21,194 B = 83 pages (worst path 12,578
                                       ; + pad 128 + cycle reserve 8,488) and it
                                       ; was being clamped to 56, i.e. sized to
                                       ; a floor rather than a fit.
                                       ; Affordable now only because
                                       ; allowance-sizing (2026-07-26) put bsh
                                       ; back at 23 pages instead of the 57 that
                                       ; cap-sizing gave it: 83 + 23 = 106 of the
                                       ; arena's 126 (FGX_STK_ARENA_PAGES), and
                                       ; +elvis (14) = 120 still fits.  Ceiling,
                                       ; not a footprint: stacks are alloc'd
                                       ; sized-to-need, so typical tasks stay 1
                                       ; page.  Arena over-subscription is
                                       ; bounded by clean ENOMEM spawn-fail
                                       ; below.  Keep in sync with fgx_ld's
                                       ; MAX_STACK_PAGES / stack_measure's
                                       ; DEFAULT_MAX_PAGES.

Task_AllocStack ENT
                MX      %00
                PHP
                REP     #$30
                MX      %00
                PHX                             ; +2 save TCB offset

                ; --- Normalize page count (0 -> 1; clamp to [1, MAX]).
                AND     #$00FF
                BNE     @tas_havePages
                LDA     #1
@tas_havePages  CMP     #TASK_STACK_MAX_PAGES+1
                BCC     @tas_pagesOK
                LDA     #TASK_STACK_MAX_PAGES
@tas_pagesOK    INC                             ; +1 GUARD page below the stack
                                                ; (2026-07-18 probe/fix: user
                                                ; frames + safepoint/yield pushes
                                                ; can exceed the calibrated fcc
                                                ; floor margin; the extra page
                                                ; absorbs the spill instead of a
                                                ; NEIGHBOR task's stack page)
                STA     _tas_npages             ; N+1 pages of stack (guarded)
                INC
                STA    |_tas_rpages             ; +1: the direct page below it
                STZ    |_ui_over                ; tier 1 until the scans fail

                ; --- TWO-ENDED first-fit scan of _stkArenaMap for N contiguous
                ;     free pages.  X = page index, Y = current free-run length.
                ;     (M=8 byte reads of the map; X/Y stay 16-bit.)
                ;
                ; BIG stacks are taken from the TOP of the arena and small ones
                ; from the BOTTOM.  Rationale (arena B1, 2026-07-31): THE ARENA
                ; CAN NEVER BE COMPACTED -- fcc frames hold absolute bank-0
                ; addresses (the prologue PEIs _fcc_fb, and &local escapes into
                ; DP cells, the heap and kernel-held syscall args), so a stack
                ; cannot be moved once it exists.  Fragmentation is therefore
                ; PERMANENT and must be prevented rather than repaired.
                ;
                ; Today's workloads are LIFO-ish (shell spawns child, child
                ; exits) so plain first-fit stays clean; long-lived login
                ; sessions ending in arbitrary order do not, and would strand
                ; a deep shell in the middle of the arena splitting the free
                ; space every short-lived tool needs.  Size is a proxy for
                ; lifetime here -- shells and editors are big and long-lived,
                ; pipeline stages are small and short-lived.  It is a heuristic,
                ; and TASK_STACK_BIG_PAGES is its knob.
                SEP     #$20
                MX      %10
                LDA     _tas_npages
                CMP     #TASK_STACK_BIG_PAGES
                BCS     @tas_scanDown
                LDX     #0
                LDY     #0
@tas_scan       LDA:    _stkArenaMap,X          ; 0 = free
                BNE     @tas_runReset
                INY                             ; extend the free run
                CPY    |_tas_rpages
                BEQ     @tas_runFound
                BRA     @tas_runNext
@tas_runReset   LDY     #0
@tas_runNext    INX
                CPX     #FGX_STK_ARENA_PAGES
                BCC     @tas_scan
                BRA     @tas_noRoom

                ; Descending scan for big stacks.  X walks DOWN, so when the run
                ; completes X is already the LOWEST page of it -- no firstpage
                ; arithmetic, unlike the ascending path below.  X is 16-bit
                ; (only M is narrowed), so DEX past 0 wraps to $FFFF and BPL
                ; ends the scan after index 0 has been tested.
@tas_scanDown   LDX     #FGX_STK_ARENA_PAGES-1
                LDY     #0
@tas_scanD      LDA:    _stkArenaMap,X          ; 0 = free
                BNE     @tas_runResetD
                INY
                CPY    |_tas_rpages
                BEQ     @tas_runFoundD
                BRA     @tas_runNextD
@tas_runResetD  LDY     #0
@tas_runNextD   DEX
                BPL     @tas_scanD
                BRA     @tas_noRoom

@tas_runFoundD  ; X = lowest page of the run (descending scan).
                REP     #$30
                MX      %00
                TXA
                STA     _tas_firstpage
                BRA     @tas_haveFirst

@tas_noRoom     ; --- No N-page free run.  TIER 2: place the range OVER tasks
                ; that are not running and can be parked, if the request is
                ; big enough to be allowed to (TASK_STK_OVER_MIN).  The
                ; overlapped tasks are parked here, in this context, so the
                ; paint and the argv staging that follow write over nobody's
                ; live bytes; each comes back to its own addresses when the
                ; scheduler next picks it.  Section 5.2 of the design.
                REP     #$30
                MX      %00
                LDA     1,S
                TAX                             ; X = TCB offset
                JSR     _Uimg_Overlap           ; C=1 + _tas_firstpage, or C=0
                BCS     @tas_haveFirst
                JSR     _Tas_LogNoRoom          ; say WHY (out of line: keeping
                                                ; this inline pushed the scan's
                                                ; BEQ out of branch range)
                PLX                             ; restore TCB offset
                LDA     #ENOMEM
                PLP
                CLC
                RTS

@tas_runFound   ; X = last page of the run; firstpage = X - N + 1.
                REP     #$30
                MX      %00
                TXA
                SEC
                SBC    |_tas_rpages
                INC                             ; A = firstpage
                STA     _tas_firstpage

@tas_haveFirst  ; _tas_firstpage set by either scan, or by the overlap arm.
                LDA     _tas_firstpage

                ; --- Count the pages reserved.  The map holds a COUNT per
                ;     page, because reservations may overlap: a page is free
                ;     only when nobody reserves it.
                TAX                             ; X = firstpage
                LDY    |_tas_rpages
                SEP     #$20
                MX      %10
@tas_mark       INC:    _stkArenaMap,X
                INX
                DEY
                BNE     @tas_mark
                REP     #$30
                MX      %00

                ; --- page = FGX_STK_ARENA + (firstpage<<8); base = page + 256;
                ;     size = N<<8 bytes.
                PLX                             ; X = TCB offset (the PHX'd value)
                LDA     _tas_firstpage
                XBA                             ; firstpage << 8 (page-aligned)
                CLC
                ADC     #FGX_STK_ARENA
                STA:    TCB_DirectPage,X        ; the direct page: the first page
                CLC
                ADC     #256
                STA:    TCB_StackBase,X         ; the stack: the rest
                PHA                             ; save base for return
                LDA     _tas_npages
                XBA                             ; N << 8 = bytes
                STA:    TCB_StackSize,X
                LDA     #0
                STA:    TCB_StackHandle,X       ; arena-managed: no MM handle
                STA:    TCB_StackHandle+2,X
                STA:    TCB_StackBank,X         ; stack lives in bank 0
                ; Where the image is built: bank 0, or -- for a range placed
                ; while somebody pinned still holds it -- the task's home.
                ; Every carve sets this one way or the other, so a patch
                ; never leaks from one task to the next.
                PHX
                LDA    |_ui_over
                CMP     #2
                BEQ     @tas_stageHome
                JSR     _Uimg_StageZero         ; clobbers A/X/Y
                BRA     @tas_staged
@tas_stageHome  JSR     _Uimg_StageAt
@tas_staged     PLX
                ; Resident -- the bytes are at their own addresses -- unless
                ; the image is built in the home, in which case the task
                ; starts out parked and its first pick brings it in.  Decided
                ; before the page is zeroed, because where the page lives
                ; follows from it.
                LDA:    TCB_TaskID,X
                AND     #$00FF
                DEC
                TAY
                LDA    |_ui_over
                CMP     #2
                BEQ     @tas_parked
                SEP     #$20
                MX      %10
                LDA     #1
                STA    |_uiResident,Y
                REP     #$20
                MX      %00
                BRA     @tas_resSet
@tas_parked     SEP     #$20
                MX      %10
                LDA     #0
                STA    |_uiResident,Y
                REP     #$20
                MX      %00
@tas_resSet     ; The direct page, zeroed where it lives, so user code starts
                ; with clean scratch and an unseeded floor of 0.
                JSR     Uimg_DPPtr              ; _libcTmp2 -> the page
                LDA     #0
                LDY     #254
@tas_zdp        STA     [_libcTmp2],Y
                DEY
                DEY
                BPL     @tas_zdp
                JSR     _Tas_PaintStack         ; bank0-stack 0.1: high-water mark
                JSR     _Tas_HwmInit            ; ...and the sampled one
                ; No longer private if the range was taken over other tasks:
                ; the sampled mark reports it from here on (_Tas_HwmInit
                ; started it private).
                LDA    |_ui_over
                BEQ     @tas_private
                LDA:    TCB_TaskID,X
                AND     #$00FF
                JSR     _Tas_MarkShared         ; preserves X
@tas_private    PLA                             ; A = base (return)
                PLP
                SEC
                RTS

;------------------------------------------------------------------------------
; Task_FreeStack - free a task's user-stack pages back to FGX_STK_ARENA, the
; direct page below them included.
;
; Input:  X = TCB offset within the kernel bank ($02 = build ORG).
; Effect: If TCB_StackBase,X is inside the arena [FGX_STK_ARENA, +PAGES*256),
;         release that task's pages in _stkArenaMap (a COUNT per page: another
;         reservation overlapping them keeps them reserved), give back the
;         home image if it mirrors this range, and zero the StackBase/Size/
;         Handle cells.  A base outside the arena (an unset 0) is left alone
;         -- idempotent.  The range is read as StackBase - 256, not from
;         TCB_DirectPage: exec frees the old stack by naming its base and
;         size in the TCB, and the page was always the one below.
;
; THE HOME IS KEYED ON THE RANGE, NOT THE PID.  exec carves the new image's
; stack before freeing the old one, for the same pid, and frees the old one by
; naming it in the TCB for the duration of this call: a home freed by pid alone
; would be the NEW range's.  _uiHomeBase says which range a home mirrors.
; Caller MX %00.  Preserves X.
;------------------------------------------------------------------------------
Task_FreeStack  ENT
                MX      %00
                PHP
                REP     #$30
                MX      %00
                ; Only arena-allocated stacks are freed here.
                LDA:    TCB_StackBase,X
                CMP     #FGX_STK_ARENA
                BCC     @tfs_done               ; below the arena (unset 0)
                CMP     #FGX_STK_ARENA+{FGX_STK_ARENA_PAGES*256}
                BCS     @tfs_done               ; at/above the arena end
                JSR     _Tas_ReportHwm          ; bank0-stack 0.1 (before the
                                                ; pages go back to the map)
                ; The home image, if it mirrors THIS range.
                LDA:    TCB_TaskID,X
                AND     #$00FF
                DEC
                ASL
                TAY
                LDA    |_uiHomeBase,Y
                CLC
                ADC     #256                    ; a home mirrors from the page
                CMP:    TCB_StackBase,X
                BNE     @tfs_noHome
                LDA:    TCB_TaskID,X
                AND     #$00FF
                JSR     Uimg_HomeFree           ; preserves X
@tfs_noHome     LDA:    TCB_StackBase,X
                ; firstpage = (base - 256 - ARENA) >> 8 ; pages = StackSize >> 8
                ; + 1 for the direct page.
                SEC
                SBC     #FGX_STK_ARENA+256
                XBA
                AND     #$00FF
                STA     _tas_firstpage
                LDA:    TCB_StackSize,X
                XBA
                AND     #$00FF
                INC
                STA     _tas_npages
                ; Release map[firstpage .. firstpage+npages-1].
                PHX                             ; save TCB offset
                LDX     _tas_firstpage
                LDY     _tas_npages
                SEP     #$20
                MX      %10
@tfs_clr        DEC:    _stkArenaMap,X
                INX
                DEY
                BNE     @tfs_clr
                REP     #$30
                MX      %00
                PLX                             ; restore TCB offset
                LDA     #0
                STA:    TCB_StackBase,X
                STA:    TCB_StackSize,X
                STA:    TCB_StackHandle,X
                STA:    TCB_StackHandle+2,X
@tfs_done       PLP
                RTS

;------------------------------------------------------------------------------
; Task_Lookup - find a TCB by pid.
; Input:  A = pid (low byte significant).
; Output: C=1 + X = TCB offset.  C=0 if no task with that pid.
; Caller MX %00.
;------------------------------------------------------------------------------
Task_Lookup     ENT
                MX      %00
                PHP
                REP     #$30
                MX      %00
                AND     #$00FF
                BEQ     @tl_nope                ; pid 0 not a real task
                CMP     #TASK_MAX_SLOTS+1
                BCS     @tl_nope
                DEC                             ; idx = pid - 1
                ASL
                ASL
                ASL
                ASL
                ASL
                ASL                             ; idx * 64 (TCB_SIZE)
                CLC
                ADC     #FGX_TASK_TBL_OFF
                TAX
                LDA:     TCB_Status,X
                BEQ     @tl_nope
                PLP
                SEC
                RTS
@tl_nope        PLP
                CLC
                RTS

;------------------------------------------------------------------------------
; Task_AllocFdTable - Kmalloc a 24-byte fd table for the task at TCB X.
;
; Input:  X = TCB offset within the kernel bank ($02 = build ORG; slot already
;             Task_Alloc'd).
; Output: C=1 + TCB_FdTablePtr,X populated (3-byte long ptr); table zeroed.
;         C=0 + A = ENOMEM if Kmalloc fails (caller should Task_Free).
; Caller MX %00.  Preserves X.
;
; Slice-3 B.2: per-task fd tables.  PID 1 boots with an empty table and
; keeps it: init opens what it needs, as 2.11BSD's does.  Child tasks get an
; empty table from this routine; _Sys_PosixSpawn memcpys the parent's
; table into it so the child inherits fd 0/1/2 (and any extra parent
; fds) without ever sharing a slot.  Clobbers _libcTmp2 (Kmalloc + deref
; scratch).
;------------------------------------------------------------------------------
Task_AllocFdTable ENT
                MX      %00
                PHP
                REP     #$30
                MX      %00
                PHX                             ; save caller's TCB offset
                LDA     #FS_MAX_FDS*3
                LDX     #M_FS
                JSR     Kmalloc
                BCS     @taf_ok
                PLX                             ; restore TCB offset
                LDA     #ENOMEM
                PLP
                CLC
                RTS
@taf_ok         PLX                             ; X = TCB offset
                LDA     _kmallocResult
                STA:    TCB_FdTablePtr,X
                STA     _libcTmp2               ; seed deref ptr lo word
                SEP     #$20
                MX      %10
                LDA     _kmallocResult+2
                STA:    TCB_FdTablePtr+2,X
                STA     _libcTmp2+2             ; bank for [_libcTmp2],Y
                REP     #$30
                MX      %00
                ; Zero the 24-byte table.  Y counts bytes 0..23.
                SEP     #$20
                MX      %10
                LDY     #0
                LDA     #0
@taf_zL         STA     [_libcTmp2],Y
                INY
                CPY     #FS_MAX_FDS*3
                BCC     @taf_zL
                REP     #$30
                MX      %00
                PLP
                SEC
                RTS

;------------------------------------------------------------------------------
; Task_FreeFdTable - Kfree the fd table for the task at TCB X (if any).
;
; Input:  X = TCB offset within the kernel bank ($02 = build ORG).
; Effect: If TCB_FdTablePtr,X is non-zero, drop the references the table still
;         holds (via _Fcb_DropRefs), then Kfree the table and zero the 3-byte
;         slot.  Idempotent.  The drop walk is the inverse of _Fcb_InheritRefs:
;         at NORMAL task exit the slots were already closed+zeroed by
;         _Sys_CloseAllFds, so it is a no-op; on a FAILED-spawn rollback (which
;         reaches Task_Free WITHOUT _Sys_CloseAllFds) the slots still point at
;         the inherited FCBs, and dropping their refs here is what stops a leaked
;         pipe write-end ref from wedging the @fc_pipe teardown gate forever
;         (the spawned-writer pipeline deadlock).
; Caller MX %00.  Preserves X.  Clobbers _kmallocResult, _libcTmp2, _fcbPtr,
;         _shTmp0 (the last two via _Fcb_DropRefs).
;------------------------------------------------------------------------------
Task_FreeFdTable ENT
                MX      %00
                PHP
                REP     #$30
                MX      %00
                ; Read 24-bit ptr; if bank=0, table was never allocated.
                LDA:    TCB_FdTablePtr,X
                STA     _kmallocResult
                STA     _libcTmp2               ; table base for the drop walk
                SEP     #$20
                MX      %10
                LDA:    TCB_FdTablePtr+2,X
                STA     _kmallocResult+2
                STA     _libcTmp2+2
                AND     #$FF
                BEQ     @tff_done               ; bank=0 → nothing to free
                REP     #$30
                MX      %00
                LDA:    TCB_TaskID,X            ; the pid, for the file table
                AND     #$00FF                  ;   below -- read HERE because X
                PHA                             ;   is the TCB offset only now
                PHX                             ; save TCB offset across drop + Kfree
                JSR     _Fcb_DropRefs           ; release refs this table still holds
                JSR     Kfree
                PLX
                ; Zero the slot (3 bytes; high byte of 4-byte word is unused
                ; padding — leave alone).
                SEP     #$20
                MX      %10
                LDA     #0
                STA:    TCB_FdTablePtr,X
                STA:    TCB_FdTablePtr+1,X
                STA:    TCB_FdTablePtr+2,X
                REP     #$30
                MX      %00

                ; AND THE FILE TABLE'S DESCRIPTORS -- UFS 1.7d I2b, the same
                ; invariant one layer down: freeing a task's fd table releases
                ; what that table held.
                ;
                ; LAST, AFTER EVERY HEAP TOUCH, and deliberately: _Fcb_DropRefs
                ; walks the table through _libcTmp2 and Kfree consumes
                ; _kmallocResult, both of them core-bank scratch that a call
                ; into another bank has no contract to preserve.  Put between
                ; them, this produced a heap double-free storm.
                ;
                ; At a NORMAL exit _Sys_CloseAllFds has already closed every
                ; slot through _Fcb_Free, so fdfreeall walks a null array and
                ; does nothing.  The path it is here for is the FAILED-SPAWN
                ; ROLLBACK, which reaches Task_Free without ever calling
                ; _Sys_CloseAllFds -- the same asymmetry _Fcb_DropRefs exists
                ; for, leaking `struct file's for the same reason.
                ; X IS PART OF THIS ROUTINE'S CONTRACT ("Preserves X", above)
                ; and the far C does not honour it -- fcc uses X freely.  The
                ; cost of forgetting: Task_Free carried on with a wrecked TCB
                ; offset and freed things that were not its, which the heap
                ; reported as "free of a non-heap pointer" from four call sites
                ; away.
                PHX
_kfp914         JSL     KFAR_VFS_DESCFREEALL    ; bank byte patched by Far_Init
                REP     #$30
                MX      %00
                PLX
                PLA                             ; drop the pid argument
                BRA     @tff_ret
@tff_done       REP     #$30                    ; no table, so nothing was
                MX      %00                     ;   pushed and nothing is owed
@tff_ret        PLP
                RTS

;==============================================================================
; Phase 3a — per-task kernel context (kernel stack + u-area).
;
; Stored in the Kmalloc'd scheduler-state table (SE_*, include/kernel.s),
; reached via [_schedTblPtr],Y with Y = sched_off + SE_field.  Because
; SE_SIZE = TCB_SIZE/2 = 32, a task's sched_off is the cheap
; (TCB_offset - FGX_TASK_TBL_OFF) >> 1.  All four take X = TCB offset and
; preserve X (NewHandle/Kfree PHX/PHY per their docs).  Caller MX %00.
;==============================================================================

;------------------------------------------------------------------------------
; Task_AllocKernStack - a task's kernel image starts REBASABLE: it has no slot
; until the scheduler picks it (_Slot_Ensure), when any free slot will do and
; the page is seeded from the template.  Here the task is marked so and its
; sched-entry cells are cleared.  Nothing is allocated and nothing can fail.
;
; Out: C=1 always.  Preserves X.
;------------------------------------------------------------------------------
Task_AllocKernStack ENT
                MX      %00
                PHP
                REP     #$30
                MX      %00
                PHX
                PHY
                LDA:    TCB_TaskID,X
                AND     #$00FF
                DEC
                TAY                             ; Y = pid-1
                SEP     #$20
                MX      %10
                LDA     #FGX_KSLOT_NONE
                STA    |_kSlotOf,Y
                REP     #$20
                MX      %00
                ; SE_KernSP, SE_KernStkHandle and SE_KernStkBase all zero: no
                ; resume SP until a slot is seeded, no handle ever, no base
                ; until then.
                TXA
                SEC
                SBC     #FGX_TASK_TBL_OFF
                LSR
                TAY                             ; Y = seoff = SE_KernSP
                LDA     #0
                STA     [_schedTblPtr],Y
                INY
                INY
                STA     [_schedTblPtr],Y        ; handle lo
                INY
                INY
                STA     [_schedTblPtr],Y        ; handle hi
                INY
                INY
                STA     [_schedTblPtr],Y        ; SE_KernStkBase
                PLY
                PLX
                PLP
                SEC
                RTS

;------------------------------------------------------------------------------
; _Slot_SeedDP - give the page at Y a fresh copy of the kernel direct page,
; stamped with pid A.
;
; In:  A = pid (high byte clear), Y = the slot page's address.  MX %00.
; Out: A/X/Y clobbered.
;
; COPIED FROM THE TEMPLATE, not zeroed.  The kernel direct page is not all
; scratch: $20-$4F are heap base pointers and $F0-$FF table pointers, all
; established once at boot and identical for every task, so every copy is a
; correct copy.  A zeroed page would give the task a null _schedTblPtr and a
; null dev_table_ptr.
;
; The identity is then stamped over the copy: the page's _curTask must read
; the pid, because that is what every "which task am I" site relies on.
; Copying it from the template would leave the page claiming to be pid 0.
;------------------------------------------------------------------------------
_Slot_SeedDP    MX      %00
                PHA                             ; pid
                PHY                             ; the page
                LDX     #FGX_DP_KKERN           ; source = the template
                LDA     #255                    ; 256 bytes
                MVN     $00,$00
                _DBRK                           ; MVN leaves DBR on the dest bank
                PLA                             ; the page
                CLC
                ADC     #_curTask               ; + the identity cell
                TAX
                PLA                             ; pid
                STAL    $000000,X               ; the page's _curTask = pid
                RTS

;------------------------------------------------------------------------------
; Task_PrimeKernStack - make a task's first swtch land at _Task_FirstRun
; (which RTLs into the task's user entry).
;
; swtch resumes a task with `LDA SE_KernSP / TCS / RTS`, so a first run is a
; faked frame: the entry address (RTS form) in the top two bytes of the
; task's kernel stack and SE_KernSP two below it.  The frame is RECORDED here,
; in _kPrimeEntry, and written when the task has a stack to write it into:
; at once if the task is resident in a slot (exec re-priming itself, standing
; on that very stack -- the frame goes above its own frames), otherwise by the
; scheduler when it binds a slot (_Slot_Seed).  The frame holds no address
; into the stack, so a task that has only this is REBASABLE: any slot will do.
;
; In:  X = TCB offset.  Caller MX %00.  Preserves X.
; Out: the task's first run recorded.  Clobbers A, Y, _pksEntry.
;
; Task_PrimeKernStackAt (fork train Stage V): same, but the first-run target
; comes in A (= entry_address - 1, RTS convention) instead of the hardwired
; _Task_FirstRun -- the vfork child's first run must exit through the syscall
; dispatcher (A=0 return), not RTL into a fresh entry point.
;------------------------------------------------------------------------------
Task_PrimeKernStack ENT
                MX      %00
                LDA     #_Task_FirstRun-1       ; classic spawn first-run
                ; fall through
Task_PrimeKernStackAt ENT
                MX      %00
                STA     _pksEntry
                PHP
                REP     #$30
                MX      %00
                PHX
                PHY
                LDA:    TCB_TaskID,X
                AND     #$00FF
                STA    |_ks_pid
                DEC
                ASL
                TAY
                LDA     _pksEntry
                STA    |_kPrimeEntry,Y          ; recorded, for the bind
                ; Resident right now?  Then the frame goes into its slot.
                LDA    |_ks_pid
                DEC
                TAX
                SEP     #$20
                MX      %10
                LDA    |_kSlotOf,X
                CMP     #FGX_KSLOT_NONE
                BEQ     @pks_later
                REP     #$20
                MX      %00
                AND     #$00FF
                STA    |_ks_slot
                TAX
                SEP     #$20
                MX      %10
                LDA    |_kSlotOwner,X
                CMP    |_ks_pid
                BNE     @pks_later              ; parked: its restore would
                                                ;   bring the old frames back
                                                ;   over this one, and only a
                                                ;   running task primes itself
                REP     #$20
                MX      %00
                JSR     _Slot_WriteFrame        ; _ks_pid's frame into _ks_slot
@pks_later      REP     #$30
                MX      %00
                PLY
                PLX
                PLP
                RTS

;==============================================================================
; KERNEL-IMAGE SLOTS -- the kernel side of bank 0 as a cache.
;
; A task's kernel image is its kernel direct page plus its kernel stack.  It
; lives in a SLOT while the task is inside the kernel: FGX_KSLOT_COUNT of
; them, slot s being the page FGX_KSLOT_DP + s*256 and FGX_KSLOT_STK bytes of
; stack at FGX_STK_KTASKS + s*FGX_KSLOT_STK.  A slot is bound when the
; scheduler picks the task (_Slot_Ensure, from swtch, on the scheduler's own
; stack) and the running task is always bound: the dispatcher finds its page
; and stack in _kCurKDP / _kCurKStkTop / _kCurKStkBase.
;
; THREE STATES per task, in two byte tables:
;   rebasable   _kSlotOf = FGX_KSLOT_NONE.  Never run, or re-primed by exec
;               into a first-run frame: any free slot will do, and the bind
;               seeds the page from the template and writes the frame.
;   resident    _kSlotOf = s and _kSlotOwner[s] = pid.  Its bytes are in the
;               slot.  A task asleep inside the kernel stays resident until
;               somebody needs its slot.
;   parked      _kSlotOf = s and _kSlotOwner[s] is somebody else, or free.
;               Its page and the live part of its stack, [SE_KernSP, top],
;               are in its home image, FGX_KHOME_STRIDE bytes per pid in the
;               bank _kHomeBank, and they come back to the SAME slot when it
;               next runs, because its frames hold absolute addresses.
;               Whoever holds the slot then is parked first; that is always
;               possible, because the only unparkable task is the running
;               one, and it is being switched away from.
;
; NEVER FROM AN INTERRUPT.  Binding, parking and restoring happen in swtch
; and at boot, in task context with interrupts masked.
;
; SCRATCH IS ABSOLUTE.  Restoring an image rewrites a slot page, and that
; page may be the one D names at the time (the outgoing task's), so nothing
; here keeps state in a direct-page cell once a copy has started; the klog
; lines are written first, while the page is still the caller's.
;==============================================================================
_kSlotOwner     DS      FGX_KSLOT_COUNT ; per slot: pid whose image is in it, 0 = free
_kSlotOf        DS      TASK_MAX_SLOTS  ; per pid-1: slot bound or tied to, or FGX_KSLOT_NONE
_kPrimeEntry    DS      TASK_MAX_SLOTS*2 ; per pid-1: first-run entry (RTS form)
_kSlotDP        DS      FGX_KSLOT_COUNT*2 ; per slot: direct page address
_kSlotBase      DS      FGX_KSLOT_COUNT*2 ; per slot: stack base (the canary word)
_kSlotTop       DS      FGX_KSLOT_COUNT*2 ; per slot: stack top
_kHomeBank      DS      2               ; the bank holding every parked image
_kSlotCursor    DS      2               ; victim rotation
_kCurKStkTop    ENT
                DS      2               ; ...and its kernel stack's top
_kCurKStkBase   ENT
                DS      2               ; ...and its base, the canary word
_ks_pid         DS      2               ; the task being bound or restored
_ks_slot        DS      2               ; its slot
_ks_vpid        DS      2               ; the holder being parked
_ks_zero        DS      2               ; _Slot_Copy: bank-0 address
_ks_home        DS      2               ; _Slot_Copy: home-bank address
_ks_len         DS      2               ; _Slot_Copy: bytes - 1
_ks_dir         DS      2               ; _Slot_Copy: 0 = to home, 1 = to bank 0
_ks_seoff       DS      2               ; sched-entry offset scratch
_ks_bank        DS      2               ; _Slot_Copy: the home bank

;------------------------------------------------------------------------------
; _Slot_Init - the tables, and the home bank.  Boot, before any task exists;
; the slot stacks were painted and canaried by main.s before boot moved onto
; the top one.  Preserves X.
;------------------------------------------------------------------------------
_Slot_Init      ENT
                MX      %00
                PHX
                PHY
                LDX     #0
                SEP     #$20
                MX      %10
                LDA     #0
@si_own         STA    |_kSlotOwner,X          ; every slot free
                INX
                CPX     #FGX_KSLOT_COUNT
                BCC     @si_own
                LDX     #0
                LDA     #FGX_KSLOT_NONE
@si_of          STA    |_kSlotOf,X             ; every pid rebasable
                INX
                CPX     #TASK_MAX_SLOTS
                BCC     @si_of
                REP     #$30
                MX      %00
                ; per-slot addresses: page, stack base, stack top
                LDX     #0                      ; X = slot*2
                LDA     #FGX_KSLOT_DP
                STA    |_ks_zero                ; the next page
                LDA     #FGX_STK_KTASKS
                STA    |_ks_home                ; the next stack base
@si_addr        LDA    |_ks_zero
                STA    |_kSlotDP,X
                CLC
                ADC     #256
                STA    |_ks_zero
                LDA    |_ks_home
                STA    |_kSlotBase,X
                CLC
                ADC     #FGX_KSLOT_STK-1
                STA    |_kSlotTop,X
                INC
                STA    |_ks_home
                INX
                INX
                CPX     #FGX_KSLOT_COUNT*2
                BCC     @si_addr
                STZ    |_kSlotCursor
                ; the home bank: one Bank_Alloc bank, a FGX_KHOME_STRIDE image
                ; per pid.  genconfig.py refuses an NPROC that does not fit.
                JSR     Bank_Alloc              ; C=1 + A = bank; preserves X/Y
                BCS     @si_haveBank
                LDA     #@si_msgNoBank
                STA     _conStrPtr
                JSR     Kern_LogStr
                JMP     _Kern_Halt
@si_haveBank    STA    |_kHomeBank
                PLY
                PLX
                RTS
@si_msgNoBank   ASC     'kslot: no bank for the home images',00

;------------------------------------------------------------------------------
; _Slot_Ensure - make the task at X resident in a slot, and publish it.
;
; In:  X = TCB offset of the task about to run.  MX %00, DBR = kernel bank,
;      interrupts off, S on the switch stack (or boot's, before any task).
; Out: A = the task's SE_KernSP, the SP swtch resumes it with; _kCurKDP,
;      _kCurKStkTop and _kCurKStkBase name its slot.  Preserves X; clobbers Y.
;
; The resume SP is read AFTER any restore, through _schedTblPtr -- a cell the
; template gives every page the same value, so it reads the same whichever
; image the page holds by then.
;------------------------------------------------------------------------------
_Slot_Ensure    ENT
                MX      %00
                PHX
                LDA:    TCB_TaskID,X
                AND     #$00FF
                STA    |_ks_pid
                DEC
                TAX                             ; X = pid-1
                SEP     #$20
                MX      %10
                LDA    |_kSlotOf,X
                REP     #$20
                MX      %00
                AND     #$00FF
                CMP     #FGX_KSLOT_NONE
                BNE     @se_tied
                JSR     _Slot_Acquire           ; rebasable: any slot, seeded
                BRA     @se_publish
@se_tied        STA    |_ks_slot
                TAX                             ; X = slot
                SEP     #$20
                MX      %10
                LDA    |_kSlotOwner,X
                REP     #$20
                MX      %00
                AND     #$00FF
                STA    |_ks_vpid
                CMP    |_ks_pid
                BEQ     @se_publish             ; resident: its bytes are there
                LDA    |_ks_vpid
                BEQ     @se_restore             ; the slot is free
                JSR     _Slot_Park              ; the holder goes home first
@se_restore     JSR     _Slot_Restore
@se_publish     LDA    |_ks_slot
                ASL
                TAX
                LDA    |_kSlotDP,X
                STAL   KFGX_CUR_KDP
                LDA    |_kSlotTop,X
                STA    |_kCurKStkTop
                LDA    |_kSlotBase,X
                STA    |_kCurKStkBase
                LDA    |_ks_pid
                JSR     _Slot_SeOff
                LDA    |_ks_seoff
                CLC
                ADC     #SE_KernSP
                TAY
                LDA     [_schedTblPtr],Y        ; the resume SP
                PLX
                RTS

;------------------------------------------------------------------------------
; _Slot_Acquire - find a slot for the rebasable task _ks_pid, and seed it.
;
; A free slot first; then one whose holder is gone -- a zombie waiting to be
; reaped, or a recycled pid -- whose image nobody will ever resume; and only
; then a victim, parked: a holder that is not READY (it is not about to run)
; before one that is, scanning from a rotating cursor so the same sleeper is
; not the one parked every time.  Out: _ks_slot.  Clobbers A/X/Y.
;------------------------------------------------------------------------------
_Slot_Acquire   MX      %00
                LDX     #0
@sa_scan        STX    |_ks_slot
                SEP     #$20
                MX      %10
                LDA    |_kSlotOwner,X
                REP     #$20
                MX      %00
                AND     #$00FF
                BEQ     @sa_take                ; free
                JSR     Task_Lookup             ; C=0: no such task any more
                BCC     @sa_take
                LDA:    TCB_Status,X
                CMP     #TASK_ZOMBIE
                BEQ     @sa_take                ; never resumed: as good as free
                LDX    |_ks_slot
                INX
                CPX     #FGX_KSLOT_COUNT
                BCC     @sa_scan
                ; Every slot is held by a live task: park one.  From the
                ; cursor, the first holder that is not READY; failing that,
                ; the cursor's own.
                LDY     #FGX_KSLOT_COUNT        ; slots left to look at
                LDA    |_kSlotCursor
@sa_vscan       STA    |_ks_slot
                TAX
                SEP     #$20
                MX      %10
                LDA    |_kSlotOwner,X
                REP     #$20
                MX      %00
                AND     #$00FF
                STA    |_ks_vpid
                PHY
                JSR     Task_Lookup             ; live, by the scan above
                PLY
                LDA:    TCB_Status,X
                CMP     #TASK_READY
                BNE     @sa_park                ; asleep or stopped: park it
                LDA    |_ks_slot
                INC
                CMP     #FGX_KSLOT_COUNT
                BCC     @sa_vnext
                LDA     #0
@sa_vnext       DEY
                BNE     @sa_vscan
                LDA    |_kSlotCursor            ; all READY: the cursor's own
                STA    |_ks_slot
                TAX
                SEP     #$20
                MX      %10
                LDA    |_kSlotOwner,X
                REP     #$20
                MX      %00
                AND     #$00FF
                STA    |_ks_vpid
@sa_park        LDA    |_ks_slot                ; the cursor moves past the victim
                INC
                CMP     #FGX_KSLOT_COUNT
                BCC     @sa_cursor
                LDA     #0
@sa_cursor      STA    |_kSlotCursor
                JSR     _Slot_Park              ; _ks_vpid out of _ks_slot
@sa_take        JSR     _Slot_Seed              ; _ks_pid into _ks_slot
                RTS

;------------------------------------------------------------------------------
; _Slot_Seed - give slot _ks_slot to the rebasable task _ks_pid: the page is
; a copy of the template with the task's identity stamped in, the stack's top
; two bytes are the first-run frame Task_PrimeKernStack recorded, and the
; sched entry resumes there.
;------------------------------------------------------------------------------
_Slot_Seed      MX      %00
                LDA    |_ks_slot
                ASL
                TAX
                LDY    |_kSlotDP,X              ; the page
                LDA    |_ks_pid
                JSR     _Slot_SeedDP
                JSR     _Slot_WriteFrame
                LDX    |_ks_slot
                LDA    |_ks_pid
                SEP     #$20
                MX      %10
                STA    |_kSlotOwner,X
                LDX    |_ks_pid
                DEX
                LDA    |_ks_slot
                STA    |_kSlotOf,X
                REP     #$30
                MX      %00
                RTS

;------------------------------------------------------------------------------
; _Slot_WriteFrame - the first-run frame recorded for _ks_pid, written at the
; top of slot _ks_slot's stack: [top-1] = entry lo, [top] = entry hi, and the
; sched entry's SE_KernSP = top-2, SE_KernStkBase = top.  Clobbers A/X/Y.
;
; A TASK WITH NO RECORDED ENTRY GETS NO FRAME.  init is the one: boot launches
; it by RTL, never through swtch's RTS, and binds its slot from boot's own
; top-level flow -- whose JSR return address is the top two bytes of the
; stack boot stands on.  With a single slot that stack IS init's, and writing
; a frame there sends the bind's RTS into the frame instead of back to boot.
; Every task swtch resumes has an entry recorded before it can be picked.
;------------------------------------------------------------------------------
_Slot_WriteFrame MX     %00
                LDA    |_ks_pid
                DEC
                ASL
                TAX
                LDA    |_kPrimeEntry,X
                BEQ     @swf_noframe            ; nothing to resume into
                PHA
                LDA    |_ks_slot
                ASL
                TAX
                LDA    |_kSlotTop,X
                DEC
                TAX                             ; X = top-1
                PLA
                STAL    $000000,X               ; [top-1] = lo, [top] = hi
@swf_noframe    LDA    |_ks_slot
                ASL
                TAX
                LDA    |_kSlotTop,X
                PHA
                LDA    |_ks_pid
                JSR     _Slot_SeOff
                LDA    |_ks_seoff
                CLC
                ADC     #SE_KernStkBase
                TAY
                PLA
                STA     [_schedTblPtr],Y        ; SE_KernStkBase = top
                DEC
                DEC
                PHA
                LDA    |_ks_seoff
                CLC
                ADC     #SE_KernSP
                TAY
                PLA
                STA     [_schedTblPtr],Y        ; SE_KernSP = top-2
                RTS

;------------------------------------------------------------------------------
; _Slot_Park - copy the image of _ks_vpid out of slot _ks_slot into its home,
; and free the slot.  The task is not running.  Clobbers A/X/Y; keeps _ks_pid.
;------------------------------------------------------------------------------
_Slot_Park      MX      %00
                LDA    |_ks_pid
                PHA
                LDA    |_ks_vpid
                STA    |_ks_pid                 ; _Slot_Image names it
                STZ    |_ks_dir                 ; bank 0 -> home
                JSR     _Slot_Image
                LDX    |_ks_slot
                SEP     #$20
                MX      %10
                LDA     #0
                STA    |_kSlotOwner,X
                REP     #$20
                MX      %00
                PLA
                STA    |_ks_pid
                RTS

;------------------------------------------------------------------------------
; _Slot_Restore - bring _ks_pid's image back from its home into slot _ks_slot,
; which is free, and take the slot.  Clobbers A/X/Y.
;------------------------------------------------------------------------------
_Slot_Restore   MX      %00
                LDA     #1
                STA    |_ks_dir                 ; home -> bank 0
                JSR     _Slot_Image
                LDX    |_ks_slot
                LDA    |_ks_pid
                SEP     #$20
                MX      %10
                STA    |_kSlotOwner,X
                REP     #$20
                MX      %00
                RTS

;------------------------------------------------------------------------------
; _Slot_Image - move task _ks_pid's image between slot _ks_slot and its home,
; in the direction _ks_dir: the page whole, and the stack from its saved SP
; to the top -- everything above the SP is live and nothing below it is.  The
; home image mirrors the slot at the same offsets, page at +0 and stack byte
; i at +256+i, so the extent is the same arithmetic in both directions.
;
; A saved SP outside the slot's stack would copy some other region over the
; home image or the slot, silently; it is checked and the machine halted
; with the numbers instead.
;------------------------------------------------------------------------------
_Slot_Image     MX      %00
                SEP     #$20
                MX      %10
                LDA    |_kHomeBank
                STA    |_ks_bank
                REP     #$20
                MX      %00
                ; the page
                LDA    |_ks_slot
                ASL
                TAX
                LDA    |_kSlotDP,X
                STA    |_ks_zero
                LDA    |_ks_pid
                JSR     _Slot_HomeOf            ; A = the pid's home base
                STA    |_ks_home
                LDA     #255
                STA    |_ks_len
                JSR     _Slot_Copy
                ; the stack: [SE_KernSP, top]
                LDA    |_ks_pid
                JSR     _Slot_SeOff
                LDA    |_ks_seoff
                CLC
                ADC     #SE_KernSP
                TAY
                LDA     [_schedTblPtr],Y        ; the saved SP
                STA    |_ks_zero
                LDA    |_ks_slot
                ASL
                TAX
                LDA    |_ks_zero
                CMP    |_kSlotBase,X
                BCC     @si_badsp               ; below the stack
                CMP    |_kSlotTop,X
                BEQ     @si_spok
                BCS     @si_badsp               ; above the top
@si_spok        LDA    |_kSlotTop,X
                SEC
                SBC    |_ks_zero
                STA    |_ks_len                 ; top - SP = bytes - 1
                LDA    |_ks_zero
                SEC
                SBC    |_kSlotBase,X            ; SP - base
                CLC
                ADC     #256
                CLC
                ADC    |_ks_home                ; home + 256 + (SP - base)
                STA    |_ks_home
                JMP     _Slot_Copy
@si_badsp       LDA     #@si_msgSp
                STA     _conStrPtr
                JSR     Kern_LogStrNoEOL
                LDA    |_ks_pid
                JSR     Kern_LogDec16
                LDA     #@si_msgSp2
                STA     _conStrPtr
                JSR     Kern_LogStrNoEOL
                LDA    |_ks_zero
                JSR     Kern_LogHex16
                JSR     Kern_LogEOL
                JMP     _Kern_Halt
@si_msgSp       ASC     'kslot: pid ',00
@si_msgSp2      ASC     ' kernel SP outside its slot: $',00

;------------------------------------------------------------------------------
; _Slot_Copy - one MVN between bank 0 and the home bank.
;
; In:  _ks_zero = bank-0 address, _ks_home = home-bank address, _ks_bank =
;      the home bank, _ks_len = bytes - 1, _ks_dir = 0 (bank 0 -> home) or 1
;      (home -> bank 0).
;      MX %00, DBR = kernel bank.  Preserves X/Y; DBR restored.
;
; Self-patching MVN, mirroring _KZeroRegion in main.s: the home bank is only
; known at run time and MVN takes its banks as immediates.  Merlin32's
; operands are SOURCE,DESTINATION and the opcode encodes destination then
; source, so +1 is the destination bank and +2 the source.  The bank is
; _ks_bank: the kernel-image home for a slot, a swap bank for a user image.
;------------------------------------------------------------------------------
_Slot_Copy      MX      %00
                PHX
                PHY
                SEP     #$20
                MX      %10
                LDA    |_ks_bank
                LDX    |_ks_dir
                BNE     @sc_toZero
                STA     @sc_mvn+1               ; destination = home
                STZ     @sc_mvn+2               ; source = bank 0
                REP     #$30
                MX      %00
                LDX    |_ks_zero
                LDY    |_ks_home
                BRA     @sc_go
@sc_toZero      STA     @sc_mvn+2               ; source = home
                STZ     @sc_mvn+1               ; destination = bank 0
                REP     #$30
                MX      %00
                LDX    |_ks_home
                LDY    |_ks_zero
@sc_go          LDA    |_ks_len
@sc_mvn         MVN     $00,$00                 ; banks patched above
                SEP     #$20
                MX      %10
                LDAL    KFGX_ANCHOR             ; MVN leaves DBR on the destination
                PHA
                PLB
                REP     #$30
                MX      %00
                PLY
                PLX
                RTS

;------------------------------------------------------------------------------
; _Slot_HomeOf - A = pid -> A = its home image's base in the home bank,
; (pid-1) * FGX_KHOME_STRIDE.  The shift is hand-coded, so the ERR ties it to
; the constant.
;------------------------------------------------------------------------------
_Slot_HomeOf    MX      %00
                ERR     FGX_KHOME_STRIDE-2048
                DEC
                XBA                             ; << 8
                ASL
                ASL
                ASL                             ; << 11
                RTS

;------------------------------------------------------------------------------
; _Slot_SeOff - A = pid -> _ks_seoff = its sched-entry offset, (pid-1)*32.
;------------------------------------------------------------------------------
_Slot_SeOff     MX      %00
                DEC
                ASL
                ASL
                ASL
                ASL
                ASL
                STA    |_ks_seoff
                RTS


;------------------------------------------------------------------------------
; Task_AllocUarea - Kmalloc(U_SIZE, M_KERN) for the u-area; store 24-bit ptr in
; SE_UareaPtr; zero it; install the nonzero defaults; and INHERIT THE CURRENT
; TASK'S u-area over the top if there is one.
; Out: C=1 / C=0 + A=ENOMEM.  Preserves X.
;
; ALLOCATION AND INHERITANCE ARE ONE ACT, and that is what removes the need for
; a second pointer rather than finding somewhere to put one.  This is the one
; moment the child is addressable through the allocator's OWN local deref
; (_libcTmp2, already seeded for the zero loop) while the parent is still
; reachable through _u -- so the copy needs no scratch cell, no stack depth and
; no direct page, all three of which are scarce here.  It is also BSD's shape:
; 2.11BSD's newproc mallocs USIZE and copies in one step (kern_fork.c:240)
; rather than allocating and then inheriting.
;
; PID 1 NEEDS NO SPECIAL CASE.  main.s allocates its u-area while _curTask is
; still 0 -- the pid is not set to 1 until main.s:671 -- and _Uarea_Cur already
; answers C=0 for "pid 0 = boot context, no task".  So the boot task simply
; keeps the zeros and defaults installed above, which is exactly what it should
; have, through the same path every other task takes.
;
; A SEPARATE _Uarea_Inherit USED TO DO THIS and is deleted.  It could only see
; the child through a pointer the caller had to supply, which meant either a
; U_SIZE staging buffer in the core bank (storage that scales with a structure
; living on the heap) or borrowing an unrelated shared scratch cell and
; documenting a call-ordering rule to keep it safe.  Neither is necessary once
; the copy happens where the allocation does.
;------------------------------------------------------------------------------
Task_AllocUarea ENT
                MX      %00
                PHP
                REP     #$30
                MX      %00
                PHX                             ; save TCB offset
                LDA     #U_SIZE
                LDX     #M_KERN
                JSR     Kmalloc
                BCS     @tau_ok
                PLX
                LDA     #ENOMEM
                PLP
                CLC
                RTS
@tau_ok         PLX                             ; X = TCB offset
                TXA
                SEC
                SBC     #FGX_TASK_TBL_OFF
                LSR
                STA     _seOff
                CLC
                ADC     #SE_UareaPtr
                TAY                             ; Y = sched_off + SE_UareaPtr
                LDA     _kmallocResult          ; ptr lo word
                STA     [_schedTblPtr],Y
                STA     _libcTmp2               ; seed deref (zero loop)
                INY
                INY
                SEP     #$20
                MX      %10
                LDA     _kmallocResult+2        ; bank byte
                STA     [_schedTblPtr],Y
                STA     _libcTmp2+2
                ; zero the u-area (U_SIZE bytes), M=8
                LDY     #0
                LDA     #0
@tau_zL         STA     [_libcTmp2],Y
                INY
                CPY     #U_SIZE
                BCC     @tau_zL
                ; NONZERO DEFAULTS, INSTALLED HERE RATHER THAN AT BOOT.
                ;
                ; Every u-area starts from this routine, so a field whose
                ; correct initial value is not zero gets it by construction --
                ; including on a path that creates a task and forgets to
                ; inherit.  BSD sets its defaults once, for pid 1 only
                ; (init_main.c), because there every later u-area is a COPY of
                ; a live one; here Task_AllocUarea zeroes first, so the same
                ; guarantee needs the defaults at the allocation.
                ;
                ; The direction matters more than the value: a forgotten
                ; inheritance then yields 022 (the ordinary default) instead of
                ; 0 (mask nothing).  Zero is the permissive answer for a
                ; creation mask, and permissive is the wrong way to fail.
                LDY     #U_Cmask
                LDA     #$12                    ; 022 octal -- Reno's CMASK
                STA     [_libcTmp2],Y
                REP     #$30
                MX      %00
                ; Resource limits: every one RLIM_INFINITY, which is what Reno's
                ; init_main.c does before vminit() narrows the VM ones.  FGX has
                ; no VM, so all of them stay unlimited and the loop is the whole
                ; policy.  16-bit stores, so two per long: $7FFF high, $FFFF low
                ; -- RLIM_INFINITY is 0x7FFFFFFF, deliberately NOT 0xFFFFFFFF,
                ; because rlim_t is SIGNED and comparisons against it must not
                ; see a negative.
                LDY     #U_Rlimit
@tau_rlL        LDA     #$FFFF
                STA     [_libcTmp2],Y           ; low word
                INY
                INY
                LDA     #$7FFF
                STA     [_libcTmp2],Y           ; high word
                INY
                INY
                CPY     #U_Rlimit+{U_RLIM_NLIMITS*U_RLIM_ENTLEN}
                BCC     @tau_rlL

                ; --- INHERIT: copy the CURRENT task's u-area over the top. ---
                ;
                ; BY DEFAULT, WITH THE EXCEPTIONS NAMED -- BSD's polarity.  Its
                ; fork duplicates the whole u-area and then clears the few
                ; fields that must not carry over.  The opposite policy, copying
                ; only an explicit list, fails PERMISSIVE for anything left off
                ; it: zero is root for a uid and masks nothing for a creation
                ; mask.  See the note beside U_INHERIT_LEN in kernel.s.
                ;
                ; _libcTmp2 still points at the child (the zero loop's deref)
                ; and _Uarea_FromSeOff touches only _u and _schedTblPtr, so the
                ; parent lookup cannot disturb it.
                PHX                             ; belt-and-braces: _Uarea_Cur is
                                                ; documented to PRESERVE X (task.s
                                                ; header) and the traced path does,
                                                ; touching only A/Y/_u.  This comment
                                                ; used to claim it clobbers X, which
                                                ; contradicted the contract two call
                                                ; sites now rely on (apple/fgx#109).
                JSR     _Uarea_Cur              ; _u = parent, or C=0 at boot
                PLX
                BCC     @tau_noparent           ; no current task -> keep defaults
                SEP     #$20
                MX      %10                     ; 8-bit A; Y stays 16-bit
                LDY     #0
@tau_inh        LDA     [_u],Y                  ; parent
                STA     [_libcTmp2],Y           ; child
                INY
                CPY     #U_INHERIT_LEN
                BCC     @tau_inh
                ; THE EXCEPTION LIST GOES HERE -- fields that must NOT carry
                ; over are cleared after the copy, as BSD's newproc bzeroes
                ; u_ru/u_cru/u_acflag.
                REP     #$30
                MX      %00
                ; U_RestartFlag (apple/fgx#105).  A restart is a property of ONE
                ; syscall invocation, and the child never made it.  Inherited,
                ; the child's first syscall would be re-entered with the
                ; parent's arguments -- and copy-by-default means this has to be
                ; named here or it happens.
                LDA     #0
                LDY     #U_RestartFlag
                STA     [_libcTmp2],Y           ; child
                ; U_StopSig (apple/fgx#109).  A stop belongs to the task that
                ; was stopped; a fresh child has never been stopped, and
                ; inheriting the parent's would let a later stop that failed to
                ; record report the parent's signal instead of nothing.
                LDA     #0
                LDY     #U_StopSig
                STA     [_libcTmp2],Y           ; child
@tau_noparent   PLP
                SEC
                RTS

;------------------------------------------------------------------------------
; Task_FreeKernStack - release the task's kernel image: its slot, if its bytes
; are still in one (a zombie's are, until it is reaped), and its tie to that
; slot; a parked image is simply abandoned in the home bank.  The sched-entry
; cells are zeroed.  Idempotent.  Preserves X.
;------------------------------------------------------------------------------
Task_FreeKernStack ENT
                MX      %00
                PHP
                REP     #$30
                MX      %00
                PHX
                PHY
                LDA:    TCB_TaskID,X
                AND     #$00FF
                STA    |_ks_pid
                DEC
                TAX                             ; X = pid-1
                STZ    |_ks_slot
                SEP     #$20
                MX      %10
                LDA    |_kSlotOf,X
                CMP     #FGX_KSLOT_NONE
                BEQ     @tfk_untied
                STA    |_ks_slot                ; low byte; the high one is 0
                LDA     #FGX_KSLOT_NONE
                STA    |_kSlotOf,X
                LDX    |_ks_slot
                LDA    |_kSlotOwner,X
                CMP    |_ks_pid
                BNE     @tfk_untied             ; parked: nothing to free
                LDA     #0
                STA    |_kSlotOwner,X
@tfk_untied     REP     #$30
                MX      %00
                LDA     3,S                     ; the caller's X: PHX went first,
                                                ;   so Y is on top at 1,S
                SEC
                SBC     #FGX_TASK_TBL_OFF
                LSR
                TAY                             ; Y = seoff = SE_KernSP
                LDA     #0
                STA     [_schedTblPtr],Y
                INY
                INY
                STA     [_schedTblPtr],Y        ; handle lo
                INY
                INY
                STA     [_schedTblPtr],Y        ; handle hi
                INY
                INY
                STA     [_schedTblPtr],Y        ; SE_KernStkBase
                PLY
                PLX
                PLP
                RTS

;==============================================================================
; U-AREA ACCESS (credentials campaign P1)
;
; The u-area was allocated, zeroed and freed per task, but until now NO field
; was ever dereferenced: _u ($A8) was never written and `[_u],Y` appeared only
; in a comment.  The dpmap slot exists because the Phase-3 design intended
; swtch to keep _u pointing at the running task — that dispatcher refactor was
; deliberately deferred (include/kernel.s: "cheaper than the _u-area dispatcher
; refactor and leaves the hot path untouched").
;
; So _u is loaded ON DEMAND by the helpers below, NOT maintained across context
; switches.  ***Treat _u as valid only immediately after one of these returns
; C=1.***  That keeps the hot path untouched, costs a few instructions on the
; cold identity syscalls, and avoids aliasing a shared scratch pointer (see the
; dpmap.s _shTmp* warning and the dp-scratch-aliasing bug history) — _u is
; touched by nothing else in the tree.
;
; "No u-area" is reported as C=0 rather than faulted: the boot context runs
; with _curTask == 0, and Task_FreeUarea zeroes SE_UareaPtr on teardown.
; Callers treat that as uid 0 / root, which is what a credential-less kernel
; context has always effectively been.
;==============================================================================

;------------------------------------------------------------------------------
; _Uarea_FromSeOff - A = sched-entry byte offset -> _u = that task's u-area.
; Out: C=1 + _u valid; C=0 = no u-area (SE_UareaPtr bank byte is 0).
; Clobbers A, Y.  Preserves X.  MX %00 in/out.
;
; The bank-byte test is the same "bank 0 -> not allocated" idiom Task_FreeUarea
; uses: a live u-area is a Kmalloc(M_KERN) block in the kernel heap banks, so
; its bank is never 0, and the free path zeroes the cell.
;------------------------------------------------------------------------------
_Uarea_FromSeOff MX     %00
                CLC
                ADC     #SE_UareaPtr
                TAY
                LDA     [_schedTblPtr],Y        ; ptr lo word
                STA     _u
                INY
                INY
                SEP     #$20
                MX      %10
                LDA     [_schedTblPtr],Y        ; bank byte (LDA sets Z)
                STA     _u+2
                BEQ     @ufs_none
                REP     #$30
                MX      %00
                SEC
                RTS
@ufs_none       REP     #$30
                MX      %00
                CLC
                RTS

;------------------------------------------------------------------------------
; _Uarea_Cur - point _u at the CURRENT task's u-area.  Out/clobbers as above.
;------------------------------------------------------------------------------
_Uarea_Cur      MX      %00
                LDA     _curTask
                AND     #$00FF
                BEQ     @uc_none                ; pid 0 = boot context, no task
                DEC
                ASL
                ASL
                ASL
                ASL
                ASL                             ; (pid-1)*32 = seoff (SE_SIZE=32)
                BRA     _Uarea_FromSeOff        ; tail call
@uc_none        CLC
                RTS

;------------------------------------------------------------------------------
; _Uarea_FromTCB - X = TCB offset -> _u = that task's u-area.  As above.
;------------------------------------------------------------------------------
_Uarea_FromTCB  MX      %00
                TXA
                SEC
                SBC     #FGX_TASK_TBL_OFF
                LSR                             ; (TCBoff-TBL)>>1 = seoff
                BRA     _Uarea_FromSeOff        ; tail call


;------------------------------------------------------------------------------
; Task_FreeUarea - Kfree the u-area (if any); zero SE_UareaPtr.  Idempotent
; (bank 0 -> not allocated).  Preserves X.  Clobbers _kmallocResult.
;------------------------------------------------------------------------------
Task_FreeUarea  ENT
                MX      %00
                PHP
                REP     #$30
                MX      %00
                TXA
                SEC
                SBC     #FGX_TASK_TBL_OFF
                LSR
                STA     _seOff
                CLC
                ADC     #SE_UareaPtr
                TAY
                LDA     [_schedTblPtr],Y        ; ptr lo word
                STA     _kmallocResult
                INY
                INY
                SEP     #$20
                MX      %10
                LDA     [_schedTblPtr],Y        ; bank byte
                STA     _kmallocResult+2
                AND     #$FF
                BNE     @tfu_free
                REP     #$30                    ; bank 0 -> nothing; restore M=16
                MX      %00
                BRA     @tfu_done
@tfu_free       REP     #$30
                MX      %00
                ; apple/fgx#105: a task can DIE holding a restart mark, and that
                ; is the COMMON case, not an edge one -- ^C a program blocked in
                ; read() and @rd_g_intr marks it, then _Sys_CheckSignal's
                ; SA_TERM arm JMPs to _Exit_Core (signal.s @disp_term) and the
                ; harvest that would have consumed the mark never runs.
                ;
                ; Un-count it HERE, the one chokepoint every u-area passes
                ; through on its way to being freed.  Without this
                ; _Sys_RestartLive never returns to zero, so the syscall exit
                ; path's skip gate is dead for the rest of the boot and every
                ; syscall pays the _Uarea_Cur walk again.  MEASURED: one ^C of a
                ; blocked read left Live=1 with Marks=1, Rewinds=0.
                ;
                ; _Uarea_FromSeOff touches only _u/A/Y, never _kmallocResult, so
                ; the pointer Kfree is about to consume survives this.
                JSR     _Uarea_FromTCB          ; X = TCB off -> _u (C=1 if any)
                BCC     @tfu_noMark
                LDY     #U_RestartFlag
                LDA     [_u],Y
                BEQ     @tfu_noMark
                DEC     _Sys_RestartLive
@tfu_noMark     PHX                             ; save TCB off across Kfree
                JSR     Kfree
                PLX
                LDA     _seOff
                CLC
                ADC     #SE_UareaPtr
                TAY
                LDA     #0
                STA     [_schedTblPtr],Y        ; ptr lo word = 0
                INY
                INY
                SEP     #$20
                MX      %10
                STA     [_schedTblPtr],Y        ; bank byte = 0
                REP     #$30
                MX      %00
@tfu_done       PLP
                RTS

;------------------------------------------------------------------------------
; Task_AllocStack scratch + bank-0 user-stack arena page map.
;------------------------------------------------------------------------------
_tas_npages     DS      2                       ; arena alloc: stack pages (guarded)
_tas_rpages     DS      2                       ; arena alloc: the range's pages:
                                                ;   the stack and its direct page
_tas_firstpage  DS      2                       ; arena alloc: first page of the run
_tas_stkEnd     DS      2                       ; hwm: one past the top of the region
_tas_hwm        DS      2                       ; hwm: scratch, then the answer
_tas_sampled    DS      2                       ; hwm: 1 = the sampled mark, not
                                                ; a scan (Task_StkHwm)
_tas_hwmw       DS      2                       ; hwm: the WORD found at the
                                                ; deepest address -- see the
                                                ; ' w=' field on the stkhwm line
_seOff          DS      2                       ; sched-entry byte offset scratch
                                                ; ((TCBoff-FGX_TASK_TBL_OFF)>>1)
_pksEntry       DS      2                       ; Task_PrimeKernStackAt first-run
                                                ; target (entry-1, RTS convention)
; (The u-area staging buffer that lived here is gone.  It existed because the
; inherit copy ran in a separate routine that could only reach the child through
; a caller-supplied pointer; doing the copy inside Task_AllocUarea, where the
; child is already addressable, removed the need for both the buffer and the
; pointer.  It was U_SIZE of core-bank storage scaling with a structure that
; lives on the heap.)
; Per-page reservation map for the user-stack arena (FGX_STK_ARENA).  One byte
; per page: how many reservations cover it, 0 = free.  Zeroed by Task_Init.
; Task_AllocStack does a first-fit free-run scan, and when that fails may lay
; a range over parked tasks' pages (_Uimg_Overlap); Task_FreeStack counts a
; task's pages back down on exit.
;------------------------------------------------------------------------------
; _Tas_LogNoRoom - report a stack-arena placement failure.
;
; The bare ENOMEM this accompanies is nearly undiagnosable from user space:
; 2.11BSD sh maps ENOMEM to the string "too big", so on 2026-07-26 a 57-page
; tcsh that could not be placed beside a 57-page bsh in the 112-page arena
; presented as seven characters with no numbers, and it cost hours to trace back
; to the arena.  The PAGE COUNT is the load-bearing number, so that is all this
; prints -- the kernel image has ~90 bytes of headroom against the FGX_DATA
; boundary, which a chattier message (largest-free-run etc.) overran.
;   Caller MX %00.  Clobbers A/Y.
;------------------------------------------------------------------------------
_Tas_LogNoRoom  MX      %00
                LDA     #_tasNoRoom
                STA     _conStrPtr
                JSR     Kern_LogStrNoEOL
                LDA     _tas_npages
                AND     #$00FF
                JSR     Kern_LogDec16
                LDA     #_tasNoRoomP
                STA     _conStrPtr
                JSR     Kern_LogStr
                RTS

_tasNoRoom      ASC     'stk ENOMEM ',$00
_tasNoRoomP     ASC     'p',$00

;------------------------------------------------------------------------------
; STACK HIGH-WATER MARK (bank-0 stack campaign, increment 0.1).
;
; Every task's stack reservation is a STATIC worst case computed at link time by
; stack_measure.py, and its cycle term is the constant CYCLE_TURNS = 8 standing
; in for a data-dependent quantity.  Nothing in the system has ever measured
; what a task ACTUALLY uses, so every claim the campaign makes about reservation
; sizes -- before or after -- would otherwise rest on the same simulation that
; produced the number being questioned.  This is the measurement.
;
; Method: fill the region with STK_PAINT at carve time, then at free time scan
; UPWARD from the base for the first word that is no longer the paint value.
; That word is the deepest address the task ever touched, so
; hwm = end - deepest.  Cost is one fill per spawn and one scan per exit --
; both O(reservation), neither on any hot path.  Nothing is sampled, so a
; one-instruction-deep excursion between two timer ticks is still counted.
;
; The region includes the +1 GUARD page (Task_AllocStack's INC), deliberately:
; an hwm larger than the reservation means the guard page was entered, which is
; exactly the silent-neighbour-corruption case the campaign exists to remove.
;
; Two limits, stated rather than papered over:
;   - The line names a pid, not a program.  The TCB is full (64 B, ERR-guarded
;     in kernel.s) so there is nowhere to keep a name.  The RESERVATION is
;     printed alongside and is a good discriminator in practice; the harvest
;     runs one workload at a time (tools/stack_baseline.py).
;   - Snapshot-fork runs the child IN PLACE on the parent's region, so a
;     forked pair reports the max over both.  That is the honest number for
;     "what did this reservation have to hold", which is the question.
;
; Only a guard hit is logged; a task inside its reservation says nothing, so
; this can be always-on without moving a character of any test's screen
; output.  ps(1)'s STK column shows a live task's mark.
;------------------------------------------------------------------------------
STK_PAINT       EQU     $A5A5           ; never-written fill word.  A value in
                                        ; the arena's own address range could
                                        ; collide with a saved _fcc_fb; $A5A5
                                        ; is above the arena's $B6FF top.

;------------------------------------------------------------------------------
; _Tas_PaintStack - fill a freshly carved region with STK_PAINT.
; Input: X = TCB offset, StackBase/StackSize already stored.  Caller MX %00.
; Preserves X.  Clobbers A.
;------------------------------------------------------------------------------
_Tas_PaintStack MX      %00
                PHX                             ; save TCB offset
                LDA:    TCB_StackBase,X
                PHA                             ; base -> becomes the cursor
                CLC
                ADC:    TCB_StackSize,X
                STA     _tas_stkEnd
                PLX                             ; X = cursor (bank-0 offset)
                LDA     #STK_PAINT
@tps_L
_tas_paintStal  STAL    $000000,X               ; region is page-aligned and a
                INX                             ; whole number of pages, so the
                INX                             ; 16-bit stride never straddles
                CPX     _tas_stkEnd             ; the end
                BCC     @tps_L
                PLX                             ; restore TCB offset
                RTS

;------------------------------------------------------------------------------
; THE SAMPLED HIGH-WATER MARK.  Per pid: the deepest user S the dispatcher has
; seen at a syscall entry, the base of the region that mark belongs to, and
; whether the region has ever been SHARED -- another task's reservation was
; laid over it, or it was laid over another's (_Uimg_Overlap), or a parent
; whose snapshot-fork child ran in place on it.
;
; The paint scan below is exact only while a region is private: once two
; tasks have used the same addresses, bank 0 below the incoming task's S holds
; the previous occupant's bytes, and a copy that moves only the live extent
; cannot carry a task's deeper excursions out with it.  A shared region is
; therefore reported from the sample, BSD's statclock shape: the deepest S at
; a kernel entry cannot exceed the truth, and for a program that does its I/O
; from its deepest frames it is within a few bytes of it.  The base rides
; with the mark because exec carves the new image's stack before freeing the
; old one, for the same pid; a tracker that names another base is not this
; region's.
_kStkMinSP      DS      TASK_MAX_SLOTS*2 ; per pid-1: the lowest user S seen
_kStkMinBase    DS      TASK_MAX_SLOTS*2 ; per pid-1: the region it was seen in
_kStkShared     DS      TASK_MAX_SLOTS  ; per pid-1: 1 = report the sample

;------------------------------------------------------------------------------
; _Tas_HwmInit - start the sampled mark for a freshly carved region, private
; until _Tas_MarkShared says otherwise.
; Input: X = TCB offset, StackBase/StackSize already stored.  Caller MX %00.
; Preserves X.  Clobbers A/Y.
;------------------------------------------------------------------------------
_Tas_HwmInit    ENT
                MX      %00
                PHX
                LDA:    TCB_TaskID,X
                AND     #$00FF
                DEC
                TAY                             ; Y = pid-1
                SEP     #$20
                MX      %10
                LDA     #0
                STA    |_kStkShared,Y           ; private, until told otherwise
                REP     #$20
                MX      %00
                TYA
                ASL
                TAY                             ; Y = word index
                LDA:    TCB_StackBase,X
                STA    |_kStkMinBase,Y
                CLC
                ADC:    TCB_StackSize,X
                STA    |_kStkMinSP,Y            ; one past the top: nothing seen
                PLX
                RTS

;------------------------------------------------------------------------------
; _Tas_MarkShared - pid A's region is no longer private: report the sample.
; Caller MX %00.  Preserves X; clobbers A/Y.
;------------------------------------------------------------------------------
_Tas_MarkShared ENT
                MX      %00
                AND     #$00FF
                BEQ     @tms_done               ; pid 0 has no region
                DEC
                TAY
                SEP     #$20
                MX      %10
                LDA     #1
                STA    |_kStkShared,Y
                REP     #$20
                MX      %00
@tms_done       RTS

;------------------------------------------------------------------------------
; Task_StkHwm - measure the high-water mark of a task's stack region.
;
; In:  X = TCB offset, region intact.  Caller MX %00.
; Out: A = _tas_hwm = deepest BYTE COUNT the task has ever touched; _tas_sampled
;      = 1 if that came from the sample rather than a scan.  X preserved.
;
; A SHARED region (see _kStkShared) is reported from the sampled mark, when the
; tracker names this region's base.  A private one is SCANNED: upward from the
; base for the first word that is no longer STK_PAINT; hwm = end - that
; address.  A region OUTSIDE the arena was never painted (init runs on a static
; stack), so the scan would read whatever is there and report a near-full
; reservation -- those return 0 = "not measurable" instead, which is what ps(1)
; shows as `-`.  So does a region the pid's sample tracker no longer names: exec
; carves the new image's stack before it frees the old one, and the new range
; (its zeroed direct page, its paint, its argv) can lie over the old, so the old
; region's bytes describe the new image by then.  Exec measures the old region
; before it carves (process.s), while it is still the one the tracker names.
;
; Split out of _Tas_ReportHwm (which measures once, at free time) so SYS_PROCS
; can measure a LIVE task.  The scan is O(reservation) and the walk is longest
; for the tasks that use their stack LEAST -- ~19k iterations if a full 147-page
; arena is enumerated.  That is a per-`ps` cost, on no hot path.
;------------------------------------------------------------------------------
Task_StkHwm     ENT
                MX      %00
                PHX                             ; save TCB offset
                STZ     _tas_sampled
                LDA:    TCB_StackBase,X
                CMP     #FGX_STK_ARENA
                BCC     @tsh_none               ; below the arena (init / unset)
                CMP     #FGX_STK_ARENA+{FGX_STK_ARENA_PAGES*256}
                BCS     @tsh_none               ; at or above the arena end
                ; the pid's current region?  (_Tas_HwmInit names it at carve)
                LDA:    TCB_TaskID,X
                AND     #$00FF
                DEC
                ASL
                TAY
                LDA    |_kStkMinBase,Y
                CMP:    TCB_StackBase,X
                BEQ     @tsh_mine
@tsh_none       BRL     @tsh_unpainted          ; not measurable
@tsh_mine
                ; shared, and the tracker is this region's?
                LDA:    TCB_TaskID,X
                AND     #$00FF
                DEC
                TAY
                SEP     #$20
                MX      %10
                LDA    |_kStkShared,Y
                REP     #$20
                MX      %00
                AND     #$00FF
                BEQ     @tsh_scan
                TYA
                ASL
                TAY
                LDA    |_kStkMinBase,Y
                CMP:    TCB_StackBase,X
                BNE     @tsh_scan               ; another region's mark
                LDA:    TCB_StackBase,X
                CLC
                ADC:    TCB_StackSize,X
                SEC
                SBC    |_kStkMinSP,Y            ; end - deepest S
                BCS     @tsh_sampled
                LDA     #0                      ; nothing seen yet
@tsh_sampled    STA     _tas_hwm
                LDA     #1
                STA     _tas_sampled
                PLX
                LDA     _tas_hwm
                RTS
@tsh_scan       LDA:    TCB_StackBase,X
                PHA                             ; base -> becomes the cursor
                CLC
                ADC:    TCB_StackSize,X
                STA     _tas_stkEnd
                PLX                             ; X = cursor
@tsh_L          LDAL    $000000,X
                CMP     #STK_PAINT
                BNE     @tsh_found
                INX
                INX
                CPX     _tas_stkEnd
                BCC     @tsh_L
                                                ; untouched: X = end, hwm = 0
                                                ; A = the word that stopped the
                                                ; scan, or STK_PAINT if it ran
                                                ; the whole region out.  That is
                                                ; free evidence and the ONLY
                                                ; thing that tells a full-looking
                                                ; report apart from a broken
                                                ; measurement: `w=A5A5` with
                                                ; used == size is impossible for
                                                ; a task that really went that
                                                ; deep (apple/fgx#49).
@tsh_found      STA     _tas_hwmw
                STX     _tas_hwm                ; deepest address touched
                LDA     _tas_stkEnd
                SEC
                SBC     _tas_hwm
                STA     _tas_hwm                ; bytes used
                PLX                             ; restore TCB offset
                LDA     _tas_hwm
                RTS

@tsh_unpainted  STZ     _tas_hwm
                PLX
                LDA     _tas_hwm
                RTS

;------------------------------------------------------------------------------
; Task_StkArenaUsed - count ALLOCATED pages in the bank-0 stack arena.
; Out: A = pages in use (0..FGX_STK_ARENA_PAGES).  Caller MX %00.  Clobbers X/Y.
;
; Read straight off _stkArenaMap rather than summed from the per-task
; reservations, so the number ps(1) prints is the allocator's own state and not
; a reconstruction that a leak would agree with.
;------------------------------------------------------------------------------
Task_StkArenaUsed ENT
                MX      %00
                LDY     #0                      ; used-page count
                LDX     #0
                SEP     #$20
                MX      %10
@tsau_L         LDA:    _stkArenaMap,X          ; 0 = free
                BEQ     @tsau_next
                INY
@tsau_next      INX
                CPX     #FGX_STK_ARENA_PAGES
                BCC     @tsau_L
                REP     #$30
                MX      %00
                TYA
                RTS

;------------------------------------------------------------------------------
; _Tas_ReportHwm - measure and log the high-water mark of a region about to be
; freed.  Input: X = TCB offset, region still intact.  Caller MX %00.
; Preserves X.  Clobbers A/Y.
;------------------------------------------------------------------------------
_Tas_ReportHwm  ENT
                MX      %00
                JSR     Task_StkHwm             ; -> _tas_hwm (bytes), X preserved

                ; Stage both TCB reads NOW: Kern_LogDec16 clobbers X, and
                ; re-fetching through it would mean juggling the TCB offset
                ; across every call.  _tas_stkEnd/_tas_npages are dead here --
                ; Task_FreeStack recomputes both AFTER this returns.
                LDA:    TCB_TaskID,X
                STA     _tas_stkEnd             ; reused: pid
                LDA:    TCB_StackSize,X
                STA     _tas_npages             ; reused: reservation bytes
                LDA:    TCB_StackBase,X
                STA     _tas_logBase            ; stash it HERE, where X is
                                                ; known good -- the log tail runs
                                                ; with a saved X and an 8-bit
                                                ; mirror byte both on the stack,
                                                ; so pulling X back there reads
                                                ; the wrong bytes (measured: it
                                                ; logged $6A38/$0000/$FF29).
                PHX                             ; hold the TCB offset for exit

                ; Logged only when the deepest address touched is inside the
                ; GUARD page (hwm > reservation - 256).  Then the task was one
                ; page from scribbling on a neighbour's stack, which is this
                ; project's most expensive failure class -- it presents as
                ; SOMEONE ELSE's bug.  The line goes to the console and the
                ; ring, marked, so a gate can assert its absence rather than a
                ; human having to read a table and notice.
                LDA     _tas_npages             ; reservation bytes
                SEC
                SBC     #256                    ; last address outside the guard
                CMP     _tas_hwm
                BCC     @trh_loud               ; (size-256) < hwm -> guard hit
                BRL     @trh_done               ; outside the guard: nothing to say

@trh_loud       LDA     #_tasHwmG
                STA     _conStrPtr
                JSR     Kern_LogStrNoEOL
                LDA     #_tasHwm1
                STA     _conStrPtr
                JSR     Kern_LogStrNoEOL
                LDA     _tas_stkEnd             ; pid
                JSR     Kern_LogDec16
                LDA     #_tasHwm2
                STA     _conStrPtr
                JSR     Kern_LogStrNoEOL
                LDA     _tas_hwm
                JSR     Kern_LogDec16
                LDA     #_tasHwm3
                STA     _conStrPtr
                JSR     Kern_LogStrNoEOL
                LDA     _tas_npages             ; reservation
                JSR     Kern_LogDec16
                ; The stack BASE, so the log names the range: a task is gone
                ; from the task table by the time the harness dumps it, and
                ; which addresses a reservation landed on is what an
                ; address-preserving park rests on.
                LDA     #_tasHwm4
                STA     _conStrPtr
                JSR     Kern_LogStrNoEOL
                LDA     _tas_logBase
                JSR     Kern_LogHex16
                ; A scanned region shows the word that stopped the scan; a
                ; sampled one says so instead, since there is no such word.
                LDA     _tas_sampled
                BNE     @trh_sampled
                LDA     #_tasHwm5
                STA     _conStrPtr
                JSR     Kern_LogStrNoEOL
                LDA     _tas_hwmw
                JSR     Kern_LogHex16
                BRA     @trh_eol
@trh_sampled    LDA     #_tasHwm6
                STA     _conStrPtr
                JSR     Kern_LogStrNoEOL
@trh_eol        JSR     Kern_LogEOL
@trh_done       PLX                             ; restore TCB offset
                RTS

_tasHwmG        ASC     'GUARD ',$00
_tasHwm1        ASC     'stkhwm ',$00
_tasHwm2        ASC     ' ',$00
_tasHwm3        ASC     '/',$00
_tasHwm4        ASC     ' @',$00
_tasHwm5        ASC     ' w=',$00
_tasHwm6        ASC     ' sampled',$00


;==============================================================================
; Task_StkLock / Task_StkUnlock - set/clear SEF_STKLOCK for a task (B3).
;
; In:  X = TCB offset (the task whose STACK is held, NOT the holder -- the two
;      differ for every case the B3.0 survey found: it is always a parent
;      writing a child's stack).
; Out: nothing.  A, X, Y AND P are all preserved -- deliberately, so these drop
;      in around an existing JSR without disturbing it.  Every call site wraps a
;      call whose CARRY is its result (_Loader_StageArgs returns C=0 on failure
;      with errno in A), and _tsl_seoff's SEC/SBC/LSR/CLC/ADC would eat it.
;      Caller MX %00, DBR = kernel bank.
;
; Idempotent on purpose.  A path that locks twice or unlocks an already-clear
; task is not an error worth a second mechanism; a path that FORGETS to unlock
; is, and `_sleep`'s assertion is what catches that.
;==============================================================================
Task_StkLock    ENT
                MX      %00
                PHP
                PHA
                PHY
                JSR     _tsl_seoff
                LDA     [_schedTblPtr],Y
                ORA     #SEF_STKLOCK
                STA     [_schedTblPtr],Y
                PLY
                PLA
                PLP
                RTS

Task_StkUnlock  ENT
                MX      %00
                PHP
                PHA
                PHY
                JSR     _tsl_seoff
                LDA     [_schedTblPtr],Y
                AND     #SEF_STKLOCK_CLR
                STA     [_schedTblPtr],Y
                PLY
                PLA
                PLP
                RTS

;==============================================================================
; Task_BorrowSet / Task_BorrowClr - set/clear SEF_STKBORROW for a task (B3).
;
; "Someone else is executing on this task's bank-0 stack."  Set on the PARENT
; when a fork/vfork child is created, cleared when the child hands the image
; back (execve or _exit).  See SEF_STKBORROW in include/kernel.s for why this
; cannot be SEF_STKLOCK: the parent must SLEEP while pinned.
;
; In:  X = TCB offset of the task whose STACK is borrowed (the PARENT).
; Out: nothing.  A, X, Y and P preserved, same contract as Task_StkLock.
;      Caller MX %00, DBR = kernel bank.
;
; Task_BorrowClr REPORTS A CLEAR OF A FLAG THAT WAS NEVER SET.  That is not
; pedantry: the set site and the two clear sites are in different routines and
; different files, and a borrow window that ends without having begun means they
; have drifted apart -- which, once B3.2 reads this flag, is a live task getting
; swapped out from under a running child.  Checking it here makes every fork in
; the entire suite a test of the pairing, instead of needing a bespoke one.
;==============================================================================
Task_BorrowSet  ENT
                MX      %00
                PHP
                PHA
                PHY
                JSR     _tsl_seoff
                LDA     [_schedTblPtr],Y
                BIT     #SEF_STKBORROW
                BEQ     @tbs_wasClear
                ; Already borrowed.  vfork BLOCKS the parent until hand-back, so
                ; a task can never have two borrowers at once -- this means a
                ; previous window never ended, i.e. a clear site was missed.
                ; Without this the two clears are unverifiable: a leaked flag is
                ; silent until B3.2 reads it, and then it is a shell that can
                ; never be swapped out and a lane that never frees.
                LDA     #_tasBorrow2Msg
                JSR     _Tas_BorrowPanic
                JSR     _tsl_seoff              ; the log clobbers A and Y
                LDA     [_schedTblPtr],Y
@tbs_wasClear   ORA     #SEF_STKBORROW
                STA     [_schedTblPtr],Y
                PLY
                PLA
                PLP
                RTS

Task_BorrowClr  ENT
                MX      %00
                PHP
                PHA
                PHY
                JSR     _tsl_seoff
                LDA     [_schedTblPtr],Y
                BIT     #SEF_STKBORROW
                BNE     @tbc_wasSet
                LDA     #_tasBorrowMsg
                JSR     _Tas_BorrowPanic        ; preserves X; clobbers A and Y
                JSR     _tsl_seoff              ; ...so re-derive the seoff
                LDA     [_schedTblPtr],Y
@tbc_wasSet     AND     #SEF_STKBORROW_CLR
                STA     [_schedTblPtr],Y
                PLY
                PLA
                PLP
                RTS

; Report a hand-back with no matching borrow.  Reports and RETURNS rather than
; halting, for the same reason as _Slp_StkLockPanic: nothing is corrupted until
; B3.2 reads the flag, and halting would hang the harness on a timeout and hide
; every later occurrence.  The gate is the suite's `screen_lacks PANIC`.
; IT HALTS, since 2026-08-07.  B3.2 has landed: the victim scan reads this flag,
; so a broken set/clear pairing is no longer a bookkeeping slip -- it is either a
; shell that can never be swapped out (a leaked set) or a live task swapped from
; under a running child (a leaked clear).  The second is silent corruption.
;
; It reported-and-returned while the flag had no consumer, which was right then
; and stopped being right the moment one existed.
; In: A = message address, X = the parent's TCB offset.  Preserves X (the
; Kern_Log* helpers clobber both index registers, so the pid is read BEFORE any
; logging and X is stacked across all of it).  Clobbers A and Y.
_Tas_BorrowPanic
                MX      %00
                STA     _conStrPtr
                PHX                             ; X must survive the log calls
                LDA:    TCB_TaskID,X
                AND     #$00FF
                PHA                             ; ...and so must the pid
                JSR     Kern_LogStrNoEOL
                PLA
                JSR     Kern_LogDec16
                JSR     Kern_LogEOL
                PLX
                JMP     _Kern_Halt              ; see the header: the flag has a
                                                ; consumer now

_tasBorrowMsg   ASC     'PANIC B3: fork hand-back with no SEF_STKBORROW, parent pid ',$00
_tasBorrow2Msg  ASC     'PANIC B3: SEF_STKBORROW set twice (a clear was missed), parent pid ',$00

; Y = sched-entry offset of SE_Flags for the TCB at X.  The sched entry is
; TCB_SIZE/2 bytes, so the offset is a shift, never a multiply (see SE_SIZE's
; comment in include/kernel.s).
_tsl_seoff      MX      %00
                TXA
                SEC
                SBC     #FGX_TASK_TBL_OFF
                LSR
                CLC
                ADC     #SE_Flags
                TAY
                RTS

;==============================================================================
; THE USER IMAGE: bank 0 as a cache of user stacks (design section 5.2).
;
; A task's reservation is RESIDENT while its bytes are at their own addresses
; and PARKED while they sit in its HOME IMAGE, a run of 2 KB units in one of
; the swap banks below.  The running task is always resident.  Reservations
; may OVERLAP: when the arena has no free run, Task_AllocStack may place a big
; enough request (TASK_STK_OVER_MIN) over tasks that are not running and can be
; parked (_Uimg_Overlap); it parks them then and there, and each comes back to
; the same addresses -- its direct page's floor, its frames' saved bases --
; when the scheduler next picks it (Uimg_Ensure).  Every copy is address-
; preserving: fcc frames hold absolute bank-0 pointers, so nothing may ever
; come back anywhere else.  This is 2.11BSD's u-area swap (vm_swap.c) with the
; correction B3 recorded: the victim is whoever sits on the addresses needed,
; not the fattest sleeper.
;
; WHO MAY BE PARKED (Uimg_Evictable): a task that is not RUNNING, not
; SEF_STKLOCK (the kernel holds a pointer into its stack), not SEF_STKBORROW
; (a fork child executes on its bytes), and -- if it is merely READY -- has
; held its bytes for TASK_STK_HOLD_TICKS.  A fork child is never parked on its
; own account: its bytes are its parent's, which the borrow flag pins.
;
; WHERE IT HAPPENS.  Parking and restoring run in task context only: in swtch
; on the switch stack (Uimg_Ensure), and inside Task_AllocStack in the
; allocating task's syscall (_Uimg_Overlap).  Never from an interrupt, which
; is section 5's warning from 2.11BSD's overlay thunks.  The allocator may park
; because a victim is not running and cannot start to before the allocator's
; own task yields; the heartbeat can wake it, not run it.
;
; HOMES are granted at the OVERLAPPER's spawn -- for itself and for every task
; it lands on -- never at eviction, so running out is a clean spawn-time ENOMEM
; (2.11BSD's out-of-swap panic, vm_swap.c, is the counter-example).  A task
; that was never overlapped has no home and never needs one.  A home mirrors a
; range: address a of the range is at _uiHomeOff + (a - base) in the home
; bank, and Task_FreeStack gives it back when THAT range goes.
;
; STATE, per pid-1 (SE is padded to exactly 32 bytes and cannot grow):
;==============================================================================
UI_CHECK        EQU     0               ; _Uimg_Walk: may every resident go?
UI_PARK         EQU     1               ; _Uimg_Walk: park every resident
UI_RANK         EQU     2               ; _Uimg_Walk: may a new range land here?
UI_COMMIT       EQU     3               ; _Uimg_Walk: homes, marks, parks
UI_DEFER        EQU     4               ; _Uimg_Walk: homes and marks only
UIMG_POOL_BANKS EQU     4               ; swap banks, taken as needed
UIMG_UNIT_PAGES EQU     8               ; a home is a run of 2 KB units...
UIMG_POOL_UNITS EQU     32              ; ...of which a bank holds 32

_uiResident     DS      TASK_MAX_SLOTS  ; 1 = its bytes are at its own addresses
_uiAcqTick      DS      TASK_MAX_SLOTS*2 ; low16 of _kSystemTicks when it last
                                        ;   became resident (the dwell)
_uiHomeBank     DS      TASK_MAX_SLOTS  ; home: swap bank, 0 = no home
_uiHomeOff      DS      TASK_MAX_SLOTS*2 ; home: where the range's base is kept
_uiHomeBase     DS      TASK_MAX_SLOTS*2 ; home: the range it mirrors
_uiHomeUnits    DS      TASK_MAX_SLOTS  ; home: units held
_uiPoolBank     DS      UIMG_POOL_BANKS ; swap banks, 0 = not taken yet
_uiPoolMap      DS      UIMG_POOL_BANKS*UIMG_POOL_UNITS ; per unit: 1 = in use
_kImgCopies     DS      2               ; user-image copies: one per fork
                                        ;   snapshot and one per restore

_ui_pid         DS      2               ; the task being placed or picked
_ui_self        DS      2               ; its TCB, skipped by the walk (0 = none)
_ui_lo          DS      2               ; the range under examination...
_ui_hi          DS      2               ;   ...and one past its end
_ui_mode        DS      2               ; UI_*
_ui_pass        DS      2               ; UI_RANK: 1 sleepers only, 2 READY
                                        ;   too, 3 anybody (parked at its pick)
_ui_slo         DS      2               ; staging base: bytes 0-1...
_ui_sbank       DS      2               ;   ...and byte 2
_ui_hits        DS      2               ; walk: intersecting tasks seen
_ui_tcb         DS      2               ; walk: the current TCB
_ui_vpid        DS      2               ; walk: its pid
_ui_vflags      DS      2               ; walk: its SE_Flags
_ui_lpid        DS      2               ; park/restore/log: the pid
_ui_from        DS      2               ; extent: low end
_ui_xlo         DS      2               ; extent: the task's base...
_ui_xhi         DS      2               ;   ...and one past its top
_ui_hbase       DS      2               ; home alloc: the range base
_ui_hpages      DS      2               ; home alloc: its pages
_ui_hpid        DS      2               ; home alloc: the pid; free: pid-1
_ui_units       DS      2               ; home alloc: units wanted
_ui_k           DS      2               ; home alloc/free: swap bank index
_ui_mapBase     DS      2               ; home alloc/free: that bank's map base
_ui_i           DS      2               ; home alloc/free: map cursor
_ui_cand        DS      2               ; overlap: candidate first page
_ui_step        DS      2               ; overlap: +1 upward, -1 downward
_ui_over        DS      2               ; overlap: 1 = the range was taken over

;------------------------------------------------------------------------------
; Uimg_Init - every task resident with no home, no swap bank taken.  From
; Task_Init, before any task exists.  Preserves X/Y.
;------------------------------------------------------------------------------
Uimg_Init       ENT
                MX      %00
                PHX
                LDX     #0
                SEP     #$20
                MX      %10
                LDA     #0
@uii_pid        STA    |_uiHomeBank,X
                STA    |_uiHomeUnits,X
                STA    |_uiResident,X
                INX
                CPX     #TASK_MAX_SLOTS
                BCC     @uii_pid
                LDX     #0
@uii_bank       STA    |_uiPoolBank,X
                INX
                CPX     #UIMG_POOL_BANKS
                BCC     @uii_bank
                LDX     #0
@uii_map        STA    |_uiPoolMap,X
                INX
                CPX     #UIMG_POOL_BANKS*UIMG_POOL_UNITS
                BCC     @uii_map
                REP     #$30
                MX      %00
                STZ    |_kImgCopies
                LDX     #0
                LDA     #0
@uii_word       STA    |_uiHomeOff,X
                STA    |_uiHomeBase,X
                STA    |_uiAcqTick,X
                INX
                INX
                CPX     #TASK_MAX_SLOTS*2
                BCC     @uii_word
                PLX
                RTS

;------------------------------------------------------------------------------
; Uimg_CanRun - COULD the task at X be made resident?  Pure predicate.
;
; In:  X = TCB offset.  MX %00.   Out: C=1 runnable, C=0 blocked on its range.
;      Preserves X and Y.  Clobbers A.
;
; Split from Uimg_Ensure deliberately: pick_next needs to ASK without copying
; (it is scanning candidates and will reject most of them), and swtch needs to
; ACT on the one it chose.
;------------------------------------------------------------------------------
Uimg_CanRun     ENT
                MX      %00
                PHX
                PHY
                JSR     _Uimg_Held
                BCS     @ucr_yes
                JSR     _Uimg_Range
                LDA     #UI_CHECK
                STA    |_ui_mode
                JSR     _Uimg_Walk              ; C = every resident there may go
                PLY
                PLX
                RTS
@ucr_yes        PLY
                PLX
                SEC
                RTS

;------------------------------------------------------------------------------
; Uimg_Ensure - make the task at X resident, parking whoever holds its
; addresses.  The ONLY place a task is restored.
;
; In:  X = TCB offset of the task about to run.  MX %00, DBR = kernel bank,
;      interrupts off, S on the switch stack.
; Out: C=1 the task may run (already resident, a borrower, or restored).
;      C=0 it cannot have its addresses right now -- the caller must pick
;      somebody else.  Preserves X.  Clobbers A/Y.
;------------------------------------------------------------------------------
Uimg_Ensure     ENT
                MX      %00
                PHX
                PHY
                JSR     _Uimg_Held
                BCS     @uen_done
                JSR     _Uimg_Range
                LDA     #UI_CHECK
                STA    |_ui_mode
                JSR     _Uimg_Walk
                BCS     @uen_take
                ; Refused.  Logged, so "never restored" has a cause on record:
                ; not called, held, or refused need different fixes.
                LDX    |_ui_self
                LDA:    TCB_TaskID,X
                AND     #$00FF
                STA    |_ui_lpid
                PLY
                PLX
                CLC
                RTS
@uen_take       LDA     #UI_PARK
                STA    |_ui_mode
                JSR     _Uimg_Walk              ; every resident there goes home
                LDX    |_ui_self
                LDA:    TCB_TaskID,X
                AND     #$00FF
                JSR     _Uimg_Restore
@uen_done       PLY
                PLX
                SEC
                RTS

;------------------------------------------------------------------------------
; _Uimg_Held - does the task at X hold its bytes?  C=1: resident, or a vfork
; child, whose bytes are its parent's and pinned by SEF_STKBORROW there.  A
; snapshot fork child is an ordinary claimant of its range.
; Preserves X; clobbers A/Y.
;------------------------------------------------------------------------------
_Uimg_Held      MX      %00
                JSR     _tsl_seoff              ; Y = SE_Flags offset for X
                LDA     [_schedTblPtr],Y
                BIT     #SEF_VFORKCHILD
                BNE     @uh_yes
                LDA:    TCB_TaskID,X
                AND     #$00FF
                DEC
                TAY
                SEP     #$20
                MX      %10
                LDA    |_uiResident,Y
                REP     #$20
                MX      %00
                AND     #$00FF
                BNE     @uh_yes
                CLC
                RTS
@uh_yes         SEC
                RTS

;------------------------------------------------------------------------------
; _Uimg_Range - the task at X is the one being placed: _ui_self, and its range
; in _ui_lo/_ui_hi.  Preserves X; clobbers A.
;------------------------------------------------------------------------------
_Uimg_Range     MX      %00
                STX    |_ui_self
                LDA:    TCB_StackBase,X
                CLC
                ADC:    TCB_StackSize,X
                STA    |_ui_hi
                LDA:    TCB_StackBase,X
                SEC
                SBC     #256                    ; the range starts at the page
                STA    |_ui_lo
                RTS

;------------------------------------------------------------------------------
; Uimg_Evictable - may pid A be parked right now?
;
; Out: C=1 yes (or no such task), C=0 pinned.  Clobbers A/X/Y.
;
; The conditions, and why each is here:
;   - not RUNNING       its bytes are live under the CPU.
;   - not SEF_STKLOCK   the kernel holds a pointer into that stack (B3.0).
;   - not SEF_STKBORROW a vfork child is EXECUTING on those bytes (scope 3.3).
;   - the DOC owner     the user sound interrupt handler writes its data
;                       bank at interrupt time (_Sys_SoundClaim), so its
;                       image never leaves (concurrent-fork survey, LOCK).
;   - SEF_SNAPCHILD     a snapshot child is pinned until it RELEASES its
;     without FORKREL   parent (SEF_FORKREL): the parent waits parked until
;                       then, and the shell's fork-then-exec never swaps.
;   - READY: its dwell  TASK_STK_HOLD_TICKS since it became resident.
; A merely-READY task IS parkable after its dwell: address-preserving copies
; make that safe, and 2.11BSD's own fallback tier does the same.  The flags
; are absolute vetoes and are tested before policy.
;------------------------------------------------------------------------------
Uimg_Evictable  ENT
                MX      %00
                JSR     Task_Lookup             ; X = TCB, or C=0
                BCC     @ue_yes                 ; gone: nothing to keep
                LDA:    TCB_Status,X
                CMP     #TASK_RUNNING
                BEQ     @ue_no
                LDA:    TCB_TaskID,X
                AND     #$00FF
                CMP    |_docOwner
                BEQ     @ue_no                  ; the sound handler's bank
                JSR     _tsl_seoff              ; Y = SE_Flags offset for X
                LDA     [_schedTblPtr],Y
                BIT     #SEF_STKLOCK+SEF_STKBORROW
                BNE     @ue_no
                AND     #SEF_SNAPCHILD+SEF_FORKREL
                CMP     #SEF_SNAPCHILD
                BEQ     @ue_no                  ; not yet released
                LDA:    TCB_Status,X
                CMP     #TASK_READY
                BNE     @ue_yes                 ; blocked/stopped: freely
                LDA:    TCB_TaskID,X
                AND     #$00FF
                DEC
                ASL
                TAY
                LDA    |_kSystemTicks           ; low16 is enough; wrap is fine
                SEC                             ; (the difference is what counts)
                SBC    |_uiAcqTick,Y
                CMP     #TASK_STK_HOLD_TICKS
                BCC     @ue_no                  ; still within its dwell
@ue_yes         SEC
                RTS
@ue_no          CLC
                RTS

;------------------------------------------------------------------------------
; _Uimg_Walk - visit every task whose reservation intersects [_ui_lo, _ui_hi),
; other than the TCB at _ui_self, and do _ui_mode's work on each:
;   UI_CHECK   C=0 the moment a RESIDENT one cannot be parked (Uimg_Evictable)
;   UI_PARK    park every resident one
;   UI_RANK    C=0 the moment one cannot be a victim of a NEW range: RUNNING,
;              locked, borrowed, or READY under _ui_strict
;   UI_COMMIT  give each a home (C=0 if the pool is out), mark it shared, and
;              park it if resident
; A vfork child is skipped: its bytes are its parent's, and the parent is in
; the walk, pinned by SEF_STKBORROW.  A snapshot child is walked like any
; claimant, and pinned by SEF_SNAPCHILD until SEF_FORKREL.
; Out: C=1 done, _ui_hits = how many intersect.  Clobbers A/X/Y.
;------------------------------------------------------------------------------
_Uimg_Walk      MX      %00
                STZ    |_ui_hits
                LDX     #FGX_TASK_TBL_OFF
                BRA     @uw_test
@uw_skip        LDX    |_ui_tcb
                TXA
                CLC
                ADC     #TCB_SIZE
                TAX
                CPX     #FGX_TASK_TBL_OFF+{TASK_MAX_SLOTS*TCB_SIZE}
                BCC     @uw_test
                SEC
                RTS
@uw_test        STX    |_ui_tcb
                CPX    |_ui_self
                BEQ     @uw_skip
                LDA:    TCB_Status,X
                BEQ     @uw_skip                ; TASK_UNUSED
                LDA:    TCB_StackBase,X
                BEQ     @uw_skip                ; no reservation
                SEC
                SBC     #256                    ; its range starts at its page
                CMP    |_ui_hi
                BCS     @uw_skip                ; starts at or past the range
                LDA:    TCB_StackBase,X
                CLC
                ADC:    TCB_StackSize,X
                CMP    |_ui_lo
                BCC     @uw_skip                ; ends below it
                BEQ     @uw_skip                ; ends exactly at it
                ; It intersects.
                JSR     _tsl_seoff              ; Y = SE_Flags offset for X
                LDA     [_schedTblPtr],Y
                BIT     #SEF_VFORKCHILD
                BNE     @uw_skip                ; a borrower: see the parent
                STA    |_ui_vflags
                LDA:    TCB_TaskID,X
                AND     #$00FF
                STA    |_ui_vpid
                INC    |_ui_hits
                LDA    |_ui_mode
                CMP     #UI_RANK
                BEQ     @uw_rank
                CMP     #UI_COMMIT
                BEQ     @uw_commit
                CMP     #UI_DEFER
                BEQ     @uw_commit
                ; UI_CHECK / UI_PARK: only a resident holds the range.
                JSR     _Uimg_VRes
                BEQ     @uw_skip
                LDA    |_ui_mode
                CMP     #UI_PARK
                BEQ     @uw_park
                LDA    |_ui_vpid
                JSR     Uimg_Evictable
                BCS     @uw_ok
                JMP     @uw_fail
@uw_ok          JMP     @uw_skip
@uw_park        LDA    |_ui_vpid
                JSR     _Uimg_Park
                JMP     @uw_skip
@uw_rank        LDA    |_ui_pass
                CMP     #3
                BNE     @uw_rankNow
                JMP     @uw_skip                ; pass 3: parked when it can be
@uw_rankNow     LDA:    TCB_Status,X
                CMP     #TASK_RUNNING
                BEQ     @uw_fail
                LDA    |_ui_vflags
                BIT     #SEF_STKLOCK+SEF_STKBORROW
                BNE     @uw_fail
                AND     #SEF_SNAPCHILD+SEF_FORKREL
                CMP     #SEF_SNAPCHILD
                BEQ     @uw_fail
                LDA    |_ui_pass
                CMP     #1
                BEQ     @uw_rankR
                JMP     @uw_skip
@uw_rankR       LDA:    TCB_Status,X
                CMP     #TASK_READY
                BEQ     @uw_fail
                JMP     @uw_skip
@uw_commit      LDA:    TCB_StackBase,X
                SEC
                SBC     #256                    ; the range: page and stack
                STA    |_ui_hbase
                LDA:    TCB_StackSize,X
                XBA
                AND     #$00FF
                INC
                STA    |_ui_hpages
                LDA    |_ui_vpid
                JSR     Uimg_HomeAlloc          ; preserves X
                BCC     @uw_fail
                LDA    |_ui_vpid
                JSR     _Tas_MarkShared         ; preserves X
                LDA    |_ui_mode
                CMP     #UI_DEFER
                BEQ     @uw_commitD             ; parked at its pick, not now
                JSR     _Uimg_VRes
                BNE     @uw_commitP
@uw_commitD     JMP     @uw_skip
@uw_commitP     LDA    |_ui_vpid
                JSR     _Uimg_Park
                JMP     @uw_skip
@uw_fail        CLC
                RTS

; _Uimg_VRes - Z=0 if the walk's current task (_ui_vpid) is resident.
; Clobbers A/Y; keeps X.
_Uimg_VRes      MX      %00
                LDA    |_ui_vpid
                DEC
                TAY
                SEP     #$20
                MX      %10
                LDA    |_uiResident,Y
                REP     #$20
                MX      %00
                AND     #$00FF
                RTS

;------------------------------------------------------------------------------
; _Uimg_Overlap - Task_AllocStack found no free run for _tas_npages pages: find
; a range whose every occupant can be parked, park them, and claim it.
;
; In:  X = TCB of the task being placed; _tas_npages.  MX %00.
; Out: C=1 + _tas_firstpage, _ui_over = 1; C=0 = ENOMEM, nothing changed.
;      Clobbers A/X/Y.
;
; Candidates are tried in the order the free-run scan would have placed the
; range -- big from the top, small from the bottom -- and three times over.
; Pass 1 accepts only sleepers (BLOCKED, STOPPED) as victims and pass 2 READY
; tasks too, which is 2.11BSD's "an interruptible sleeper, else the oldest
; runnable"; both park the victims here and now, and neither takes a RUNNING,
; locked or borrowed task, so the placer's own live range -- on exec, the
; stack it is standing on -- is never taken.  Pass 3 accepts anybody: a
; session shell spawning a session shell has no range to offer but its own,
; which it is standing on, and two of them do not fit the arena side by side.
; The range is then placed but NOT cleared: the new task's image is built in
; its HOME (the paint and the argv staging are pointed there), it starts out
; parked, and the scheduler parks the occupants and brings it in at its
; first pick, once whoever is pinned has let go -- the spawning shell in
; wait(), the fork parent handed its stack back.  That is the lane's spawn
; hand-off, for any range.
;
; ponytail: no slptime scoring among candidates; the first range that
; qualifies in a pass wins.  Score by TCB_LastRun when a workload shows the
; wrong sleeper being parked.
;------------------------------------------------------------------------------
_Uimg_Overlap   MX      %00
                LDA:    TCB_TaskID,X
                AND     #$00FF
                STA    |_ui_pid
                ; The knob.  0 = never; else the GUARDED count must reach MIN+1.
                LDA     #TASK_STK_OVER_MIN
                BEQ     @uo_no
                INC
                CMP    |_tas_npages
                BEQ     @uo_eligible
                BCC     @uo_eligible
@uo_no          CLC
                RTS
@uo_eligible    LDA     #1
                STA    |_ui_pass                ; pass 1: sleepers only
@uo_pass        LDA    |_tas_npages
                CMP     #TASK_STACK_BIG_PAGES
                BCS     @uo_down
                STZ    |_ui_cand                ; small: upward from the bottom
                LDA     #1
                STA    |_ui_step
                BRA     @uo_try
@uo_down        LDA     #FGX_STK_ARENA_PAGES
                SEC
                SBC    |_tas_rpages
                STA    |_ui_cand                ; big: downward from the top
                LDA     #$FFFF
                STA    |_ui_step
@uo_try         LDA    |_ui_cand
                XBA
                CLC
                ADC     #FGX_STK_ARENA
                STA    |_ui_lo
                LDA    |_tas_rpages
                XBA
                CLC
                ADC    |_ui_lo
                STA    |_ui_hi
                STZ    |_ui_self                ; the placer's own range counts:
                                                ;   on exec it is the live one
                LDA     #UI_RANK
                STA    |_ui_mode
                JSR     _Uimg_Walk
                BCS     @uo_found
                LDA    |_ui_cand
                CLC
                ADC    |_ui_step
                STA    |_ui_cand
                LDA    |_ui_step
                BMI     @uo_more
                LDA     #FGX_STK_ARENA_PAGES
                SEC
                SBC    |_tas_rpages
                CMP    |_ui_cand
                BCS     @uo_try                 ; still a place to try
                BRA     @uo_passEnd
@uo_more        LDA    |_ui_cand
                BPL     @uo_try                 ; not yet past page 0
@uo_passEnd     LDA    |_ui_pass
                CMP     #3
                BNE     @uo_passNext
                JMP     @uo_no
@uo_passNext    INC    |_ui_pass                ; 2: READY tasks too; 3: anybody
                JMP     @uo_pass
@uo_found       ; The new task's home first, then everybody else's: a pool
                ; that runs out here has changed nothing.
                LDA    |_ui_lo
                STA    |_ui_hbase
                LDA    |_tas_rpages
                STA    |_ui_hpages
                LDA    |_ui_pid
                JSR     Uimg_HomeAlloc
                BCS     @uo_haveHome
                JMP     @uo_no
@uo_haveHome    LDA     #UI_COMMIT
                LDX    |_ui_pass
                CPX     #3
                BNE     @uo_modeSet
                LDA     #UI_DEFER               ; homes and marks; the parks
                                                ;   are the scheduler's
@uo_modeSet     STA    |_ui_mode
                JSR     _Uimg_Walk
                BCS     @uo_ok
                LDA    |_ui_pid
                JSR     Uimg_HomeFree
                JMP     @uo_no
@uo_ok
                LDA    |_ui_cand
                STA    |_tas_firstpage
                LDA    |_ui_pass
                CMP     #3
                BNE     @uo_now
                LDA     #2                      ; deferred: built in the home
                BRA     @uo_setOver
@uo_now         LDA     #1
@uo_setOver     STA    |_ui_over
                SEC
                RTS

;------------------------------------------------------------------------------
; _Uimg_Park - pid A's live extent goes to its home; it is no longer resident.
; _Uimg_Restore - pid A's live extent comes back; it is resident, and its
; dwell starts.  Clobber A/X/Y.
; A restored member of a snapshot fork's image group takes its banks back
; from its bank home by exchange with the member that held them (Img_Swap,
; process.s); a park leaves the banks where they are.
;------------------------------------------------------------------------------
_Uimg_Park      MX      %00
                STA    |_ui_lpid
                LDA    |_ui_lpid
                JSR     _Uimg_Extent
                STZ    |_ks_dir                 ; bank 0 -> home
                JSR     _Uimg_Move
                LDA    |_ui_lpid
                DEC
                TAY
                SEP     #$20
                MX      %10
                LDA     #0
                STA    |_uiResident,Y
                REP     #$20
                MX      %00
                RTS

_Uimg_Restore   MX      %00
                STA    |_ui_lpid
                LDA    |_ui_lpid
                JSR     _Uimg_Extent
                LDA     #1
                STA    |_ks_dir                 ; home -> bank 0
                JSR     _Uimg_Move
                LDA    |_ui_lpid
                JSR     Img_Swap                ; its banks, if it has a home
                LDA    |_ui_lpid
                DEC
                TAY
                SEP     #$20
                MX      %10
                LDA     #1
                STA    |_uiResident,Y
                REP     #$20
                MX      %00
                TYA
                ASL
                TAY
                LDA    |_kSystemTicks
                STA    |_uiAcqTick,Y            ; the start of its dwell
                RTS

;------------------------------------------------------------------------------
; _Uimg_Extent - the low end of pid A's LIVE extent, into _ui_from; its range
; into _ui_xlo/_ui_xhi.
;
; Everything from the task's user S up to its top is live and nothing below it
; is, so that is all a park or a restore has to move.  Two candidates name
; that S: SE_UserSP, saved by swtch when the task last gave up the CPU, and
; TCB_SavedS, the S its first run starts at -- a task that has never run has
; only the second, and its sched entry may hold anything.  The LOWER of the
; two that fall inside the range is taken; if neither does, the whole stack
; is.  Copying more than the live extent is always safe; copying less never
; is.  Clobbers A/X/Y.
;------------------------------------------------------------------------------
_Uimg_Extent    MX      %00
                PHA                             ; pid
                JSR     Task_Lookup             ; X = TCB, or C=0
                BCS     @ux_have
                PLA
                JMP     _Uimg_NoTask
@ux_have        LDA:    TCB_StackBase,X
                STA    |_ui_xlo
                CLC
                ADC:    TCB_StackSize,X
                STA    |_ui_xhi
                STA    |_ui_from                ; one past the top: nothing yet
                LDA:    TCB_SavedS,X
                JSR     _Uimg_Lower
                PLA
                DEC
                ASL
                ASL
                ASL
                ASL
                ASL                             ; (pid-1)*32 = seoff
                CLC
                ADC     #SE_UserSP
                TAY
                LDA     [_schedTblPtr],Y
                JSR     _Uimg_Lower
                LDA    |_ui_from
                CMP    |_ui_xhi
                BCC     @ux_done
                LDA    |_ui_xlo                 ; neither candidate: the whole stack
                STA    |_ui_from
@ux_done        RTS

; _Uimg_Lower - A = a candidate S: inside the range and below _ui_from, take it.
_Uimg_Lower     MX      %00
                CMP    |_ui_xlo
                BCC     @ul_no
                CMP    |_ui_xhi
                BCS     @ul_no
                CMP    |_ui_from
                BCS     @ul_no
                STA    |_ui_from
@ul_no          RTS

; _Uimg_NoTask - A = a pid with no TCB was to be moved.  Halt with the number:
; the copy would have moved some other region.
_Uimg_NoTask    MX      %00
                STA    |_ui_lpid
                LDA     #@unt_msg
                STA     _conStrPtr
                JSR     Kern_LogStrNoEOL
                LDA    |_ui_lpid
                JSR     Kern_LogDec16
                JSR     Kern_LogEOL
                JMP     _Kern_Halt
@unt_msg        ASC     'uimg: no task for pid ',00

;------------------------------------------------------------------------------
; _Uimg_Move - two MVNs between bank 0 and _ui_lpid's home, in the direction
; _ks_dir: the live extent [_ui_from, _ui_xhi), then the direct page below the
; stack.  The home mirrors the range at a fixed offset, so the extent is the
; same arithmetic in both directions.  A task with no home cannot be here --
; every task another range lands on is given one first -- so that is a halt
; with the pid, not a copy to bank 0.
;------------------------------------------------------------------------------
_Uimg_Move      MX      %00
                LDA    |_ui_lpid
                DEC
                TAY
                SEP     #$20
                MX      %10
                LDA    |_uiHomeBank,Y
                STA    |_ks_bank
                REP     #$20
                MX      %00
                AND     #$00FF
                BEQ     @um_noHome
                TYA
                ASL
                TAY
                LDA    |_ui_from
                STA    |_ks_zero
                SEC
                SBC    |_uiHomeBase,Y           ; from - base
                CLC
                ADC    |_uiHomeOff,Y            ; + where the base is kept
                STA    |_ks_home
                LDA    |_ui_xhi
                DEC
                SEC
                SBC    |_ui_from
                STA    |_ks_len                 ; top - from = bytes - 1
                JSR     _Slot_Copy              ; preserves Y
                ; the direct page: the range's first page, kept at the home's
                LDA    |_ui_xlo
                SEC
                SBC     #256
                STA    |_ks_zero
                LDA    |_uiHomeOff,Y
                STA    |_ks_home
                LDA     #255
                STA    |_ks_len
                JMP     _Slot_Copy
@um_noHome      LDA     #@um_msg
                STA     _conStrPtr
                JSR     Kern_LogStrNoEOL
                LDA    |_ui_lpid
                JSR     Kern_LogDec16
                JSR     Kern_LogEOL
                JMP     _Kern_Halt
@um_msg         ASC     'uimg: no home for pid ',00

;------------------------------------------------------------------------------
; _Uimg_StageAt - point the paint and the loader's argv staging at task
; _ui_pid's HOME, for a range placed while somebody pinned still holds it:
; the image is built in the home and the scheduler brings it in at the
; task's first pick.  _Uimg_StageZero points them back at bank 0, which
; every ordinary carve does, so a patch never outlives the carve it was made
; for.
;
; The stores are `STAL base,X` with X the bank-0 address, so the base is the
; 24-bit difference between where the range's copy lives and the range; the
; bank byte carries the borrow when the copy sits below the range within its
; bank.  Clobbers A/X/Y.
;------------------------------------------------------------------------------
_Uimg_StageAt   MX      %00
                LDA    |_ui_pid
                DEC
                TAY
                SEP     #$20
                MX      %10
                LDA    |_uiHomeBank,Y
                STA    |_ui_sbank
                REP     #$20
                MX      %00
                TYA
                ASL
                TAY
                LDA    |_uiHomeOff,Y
                SEC
                SBC    |_uiHomeBase,Y           ; copy - range, low word
                STA    |_ui_slo
                LDA    |_ui_sbank
                AND     #$00FF
                ADC     #$FFFF                  ; bank - 1 + carry: the borrow
                STA    |_ui_sbank
                BRA     _Uimg_StagePatch
_Uimg_StageZero MX      %00
                STZ    |_ui_slo
                STZ    |_ui_sbank
_Uimg_StagePatch MX     %00
                LDA    |_ui_slo
                STA    |_tas_paintStal+1
                SEP     #$20
                MX      %10
                LDA    |_ui_sbank
                STA    |_tas_paintStal+3
                REP     #$20
                MX      %00
                LDA    |_ui_slo
                LDY    |_ui_sbank
_kfp998         JSL     KFAR_LA_SETSTAGEBASE
                RTS

;------------------------------------------------------------------------------
; Uimg_DPPtr - _libcTmp2 = where the task at X's direct page lives right now:
; bank 0 at TCB_DirectPage while its bytes are at their own addresses (or it
; is a fork child, on its parent's), else the copy in its home.  The kernel
; writes a not-yet-run task's page through this -- the zero at the carve, the
; stack floor, the soft-frame seed -- because a task placed while somebody
; pinned still holds its range is built in its home until its first pick.
; Preserves X/Y; clobbers A.
;------------------------------------------------------------------------------
Uimg_DPPtr      ENT
                MX      %00
                PHY
                LDA:    TCB_DirectPage,X
                STA     _libcTmp2
                SEP     #$20
                MX      %10
                STZ     _libcTmp2+2             ; bank 0
                REP     #$20
                MX      %00
                JSR     _Uimg_Held              ; C=1: at its own addresses
                BCS     @udp_done
                LDA:    TCB_TaskID,X
                AND     #$00FF
                DEC
                TAY
                SEP     #$20
                MX      %10
                LDA    |_uiHomeBank,Y
                STA     _libcTmp2+2             ; the home bank
                REP     #$20
                MX      %00
                TYA
                ASL
                TAY
                LDA:    TCB_DirectPage,X
                SEC
                SBC    |_uiHomeBase,Y           ; the page is the range's base
                CLC
                ADC    |_uiHomeOff,Y
                STA     _libcTmp2
@udp_done       PLY
                RTS

;------------------------------------------------------------------------------
; Uimg_SetResident - pid A's bytes are at their own addresses.  For exec's
; rollback: a carve that was deferred marked the task parked, and the range
; it stands on again was never anything else.  Preserves X/Y; clobbers A.
;------------------------------------------------------------------------------
Uimg_SetResident ENT
                MX      %00
                PHY
                AND     #$00FF
                DEC
                TAY
                SEP     #$20
                MX      %10
                LDA     #1
                STA    |_uiResident,Y
                REP     #$20
                MX      %00
                PLY
                RTS

;------------------------------------------------------------------------------
; Uimg_HomeAlloc - give pid A a home for the range _ui_hbase of _ui_hpages
; pages: a run of ceil(pages/8) units in a swap bank, first fit, taking a
; fresh Bank_Alloc bank when the ones held are full.  A home the pid already
; holds is kept if it is this range's and dropped if it is another's.
;
; Out: C=1 ok, C=0 out of banks or units.  Preserves X/Y.
;------------------------------------------------------------------------------
Uimg_HomeAlloc  ENT
                MX      %00
                PHX
                PHY
                AND     #$00FF
                STA    |_ui_hpid
                DEC
                TAY
                SEP     #$20
                MX      %10
                LDA    |_uiHomeBank,Y
                REP     #$20
                MX      %00
                AND     #$00FF
                BEQ     @uha_new
                TYA
                ASL
                TAY
                LDA    |_uiHomeBase,Y
                CMP    |_ui_hbase
                BNE     @uha_other
                JMP     @uha_ok                 ; this range's already
@uha_other      LDA    |_ui_hpid
                PHA
                JSR     Uimg_HomeFree           ; another range's: drop it
                PLA                             ; HomeFree leaves pid-1 in
                STA    |_ui_hpid                ;   _ui_hpid, its own scratch
@uha_new        LDA    |_ui_hpages
                CLC
                ADC     #UIMG_UNIT_PAGES-1
                LSR
                LSR
                LSR                             ; units = ceil(pages / 8)
                STA    |_ui_units
                STZ    |_ui_k
@uha_bank       LDX    |_ui_k
                SEP     #$20
                MX      %10
                LDA    |_uiPoolBank,X
                REP     #$20
                MX      %00
                AND     #$00FF
                BNE     @uha_scan
                PHX
                JSR     Bank_Alloc              ; C=1 + A = bank
                PLX
                BCC     @uha_fail
                SEP     #$20
                MX      %10
                STA    |_uiPoolBank,X
                REP     #$20
                MX      %00
@uha_scan       TXA
                ASL
                ASL
                ASL
                ASL
                ASL                             ; k * UIMG_POOL_UNITS
                STA    |_ui_mapBase
                STA    |_ui_i
                LDY     #0                      ; the free run so far
@uha_s          LDX    |_ui_i
                SEP     #$20
                MX      %10
                LDA    |_uiPoolMap,X
                REP     #$20
                MX      %00
                AND     #$00FF
                BNE     @uha_reset
                INY
                CPY    |_ui_units
                BEQ     @uha_got
                BRA     @uha_next
@uha_reset      LDY     #0
@uha_next       INC    |_ui_i
                LDA    |_ui_i
                SEC
                SBC    |_ui_mapBase
                CMP     #UIMG_POOL_UNITS
                BCC     @uha_s
                INC    |_ui_k                   ; this bank is full: the next
                LDA    |_ui_k
                CMP     #UIMG_POOL_BANKS
                BCC     @uha_bank
@uha_fail       PLY
                PLX
                CLC
                RTS
@uha_got        ; The run ends at _ui_i.  Mark it, and record the home.
                LDA    |_ui_i
                SEC
                SBC    |_ui_units
                INC
                STA    |_ui_i                   ; its first unit (map index)
                TAX
                LDY    |_ui_units
                SEP     #$20
                MX      %10
                LDA     #1
@uha_mark       STA    |_uiPoolMap,X
                INX
                DEY
                BNE     @uha_mark
                REP     #$30
                MX      %00
                LDX    |_ui_k
                LDA    |_ui_hpid
                DEC
                TAY
                SEP     #$20
                MX      %10
                LDA    |_uiPoolBank,X
                STA    |_uiHomeBank,Y
                LDA    |_ui_units
                STA    |_uiHomeUnits,Y
                REP     #$20
                MX      %00
                TYA
                ASL
                TAY
                LDA    |_ui_hbase
                STA    |_uiHomeBase,Y
                LDA    |_ui_i
                SEC
                SBC    |_ui_mapBase             ; the unit within its bank
                ERR     UIMG_UNIT_PAGES-8       ; the shift below is 2 KB
                XBA
                ASL
                ASL
                ASL                             ; * 2048
                STA    |_uiHomeOff,Y
@uha_ok         PLY
                PLX
                SEC
                RTS

;------------------------------------------------------------------------------
; Uimg_HomeFree - give back pid A's home, if it has one.  The swap banks
; themselves are kept once taken.  Preserves X/Y.
; ponytail: banks are never returned to Bank_Alloc; return an all-free one
; when a workload shows the pool sitting on banks it no longer uses.
;------------------------------------------------------------------------------
Uimg_HomeFree   ENT
                MX      %00
                PHX
                PHY
                AND     #$00FF
                DEC
                STA    |_ui_hpid                ; pid-1 here
                TAY
                SEP     #$20
                MX      %10
                LDA    |_uiHomeBank,Y
                REP     #$20
                MX      %00
                AND     #$00FF
                BNE     @uhf_have
                JMP     @uhf_done               ; no home
@uhf_have       STA    |_ui_k                   ; the bank number, for the scan
                LDX     #0
@uhf_k          SEP     #$20
                MX      %10
                LDA    |_uiPoolBank,X
                REP     #$20
                MX      %00
                AND     #$00FF
                CMP    |_ui_k
                BEQ     @uhf_found
                INX
                CPX     #UIMG_POOL_BANKS
                BCC     @uhf_k
                BRA     @uhf_forget             ; not a pool bank: nothing to clear
@uhf_found      TXA
                ASL
                ASL
                ASL
                ASL
                ASL                             ; k * UIMG_POOL_UNITS
                STA    |_ui_mapBase
                LDA    |_ui_hpid
                ASL
                TAY
                LDA    |_uiHomeOff,Y
                XBA
                LSR
                LSR
                LSR                             ; / 2048 = the first unit
                AND     #$001F
                CLC
                ADC    |_ui_mapBase
                STA    |_ui_i
                LDY    |_ui_hpid
                LDA    |_uiHomeUnits,Y          ; 16-bit read; the high byte
                AND     #$00FF                  ;   is the next pid's, masked
                TAY                             ; Y = units
                LDX    |_ui_i
                SEP     #$20
                MX      %10
                LDA     #0
@uhf_clr        STA    |_uiPoolMap,X
                INX
                DEY
                BNE     @uhf_clr
                REP     #$20
                MX      %00
@uhf_forget     LDY    |_ui_hpid
                SEP     #$20
                MX      %10
                LDA     #0
                STA    |_uiHomeBank,Y
                STA    |_uiHomeUnits,Y
                REP     #$20
                MX      %00
                TYA
                ASL
                TAY
                LDA     #0
                STA    |_uiHomeOff,Y
                STA    |_uiHomeBase,Y
@uhf_done       PLY
                PLX
                RTS

_tas_logBase    DS      2                       ; stack base for the stkhwm line

_stkArenaMap    DS      FGX_STK_ARENA_PAGES

;==============================================================================
; END task.s
;==============================================================================
