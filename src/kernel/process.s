;==============================================================================
; process.s - Process syscalls (slice 2): posix_spawn / wait / _exit.
;
; v1 process model:
;   - posix_spawn(path):
;       allocate child TCB + bank + per-PID DP/stack page, load the binary,
;       build the child's first-run resume frame on its user stack, switch
;       _curTask to the child, and update _Sys_UserSP so the dispatcher's
;       exit path PLB+RTLs into the child instead of back to the parent.
;       The parent's resume SP is saved in its TCB; the parent is parked
;       in TASK_BLOCKED.
;
;   - _exit(status):
;       mark child ZOMBIE, save the exit status, free the child's bank,
;       wake the parent (state RUNNABLE), point _curTask + _Sys_UserSP at
;       the parent's saved frame, set A=child_pid + C=1, RTS.  The
;       dispatcher's exit path then resumes the parent at the instruction
;       past its posix_spawn JSL.
;
;   - wait(status_ptr):
;       scan the task table for a ZOMBIE child of _curTask.  In v1 the
;       child has already exited by the time wait runs (linear scheduling),
;       so this is just "reap the zombie": return its pid, optionally write
;       the BSD-encoded status into the caller's buffer, free the TCB slot.
;       ECHILD if no children.
;==============================================================================

;------------------------------------------------------------------------------
; _Sys_PosixSpawn (#43) - spawn a child task and yield to it.
;
; Slice-3 argv/envp ABI (BSD-shaped):
;   Caller passes a NULL-terminated array of (16-bit caller-bank-offset)
;   pointers to NUL-terminated strings, for argv (in X) and envp (in Y).
;   Either pointer may be 0 to mean "empty array".  By convention argv[0]
;   is the program name (`__progname`).
;
;   _Loader_StageArgs lays a BSD-canonical frame onto the child's stack
;   page (strings region + argv/envp ptr tables + argc word + dispatcher
;   resume frame).  After the dispatcher's PLB+RTL, the child's S sits
;   one byte below argc, reachable via `LDA LSARGV_ARGC,S` etc. — see
;   include/loader.s.
;
;   See docs/superpowers/plans/2026-04-26-fgx-slice2-closeout-slice3-kickoff.md
;   §B.1 for the rationale.
;
; Args:    A = path-offset within caller's user bank (NUL-terminated).
;          X = argv_ptr  (NULL-term ptr table in caller bank; 0 = empty).
;          Y = envp_ptr  (NULL-term ptr table in caller bank; 0 = empty).
; Return:  Doesn't return *to this syscall site* until the child has _exit'd.
;          On the eventual return: C=1 + A = child_pid (which is now zombie
;            unless the parent's wait() has already reaped it).
;          On error before the child runs: C=0 + A = errno
;            (EAGAIN, ENOMEM, ENOENT, ENOEXEC, EIO, E2BIG, EINVAL).
;------------------------------------------------------------------------------
_Sys_PosixSpawn ENT
                MX      %00
                ; Save argv/envp pointers — CopyPathToBuf clobbers Y, and we
                ; need both later for _Loader_StageArgs.
                STX     _ps_argBlk
                STY     _ps_argBlkBank
                STZ     _ps_fdActionsPtr        ; plain SPAWN: no actions
                BRA     _ps_common

;------------------------------------------------------------------------------
; _Sys_PosixSpawnX (#44) - posix_spawn with file_actions.
;
; Args:    A = path-offset in caller bank (NUL-term).
;          X = argv ptr in caller bank (NULL-term, may be 0).
;          Y = file_actions ptr in caller bank (op=0-term; 0 = no actions,
;              equivalent to SYS_POSIX_SPAWN).
; envp:    empty for this entry — pass via SYS_POSIX_SPAWN if you need envp.
;
; Returns same shape as SYS_POSIX_SPAWN.  Action failures (open ENOENT,
; bad fd index, etc.) free the partially-built child and propagate errno.
;------------------------------------------------------------------------------
_Sys_PosixSpawnX ENT
                MX      %00
                STX     _ps_argBlk
                STY     _ps_fdActionsPtr
                STZ     _ps_argBlkBank          ; SPAWNX's block is always a C
                                                ; stack local, so bank 0
                ; Fall through.
_ps_common
                ; Stage path into _Sys_PathBuf (DBR=kernel-bank already; the
                ; dispatcher does PHB+PHK+PLB before any handler runs).
                JSR     _Sys_CopyPathToBuf
                BCC     @psp_plok
                LDA     #ENAMETOOLONG           ; apple/fgx#436
                CLC
                RTS
@psp_plok
                ; Allocate child TCB.  Returns C=1 + X = TCB byte offset
                ; with TaskID + Status already populated by Task_Alloc.
                JSR     Task_Alloc
                BCS     @psp_haveTCB
                JSR     _Kern_LogForkFail   ; the path that mattered
                CLC                                 ; A already = EAGAIN
                RTS
@psp_haveTCB     STX     _ps_childTCB
                ; Read pid back out of the TCB so we can use it as a save
                ; key without recomputing.
                LDA:     TCB_TaskID,X
                AND     #$00FF
                STA     _ps_childPid
                ; Stash parent in child TCB.
                LDA     _curTask
                STA:     TCB_ParentID,X

                ; Allocate child's user bank.  Use a JMP trampoline because
                ; the failure label is too far for an 8-bit branch.
                JSR     Bank_Alloc
                BCS     @psp_haveBank
                JMP     @psp_noBank
@psp_haveBank   LDX     _ps_childTCB
                SEP     #$20
                MX      %10
                STA:     TCB_CodeBank,X
                STA:     TCB_DataBank,X
                STA:     TCB_BankList+0,X        ; Phase 2 slice 2.1: child's
                                                ; segment-0 bank.  Future
                                                ; multi-segment loads fill
                                                ; +1..+7 in addition.  _Sys_Exit
                                                ; walks this list at task end.
                STA     _ps_childBank
                REP     #$20
                MX      %00

                ; (The child's direct page comes with its stack, below: the
                ; first page of the reservation Task_AllocStack carves.)
                ; Allocate child's fd table (Slice-3 B.2).  On ENOMEM, free
                ; everything we've claimed so far and propagate.  Task_Free
                ; handles fd-table cleanup; this slot's fd-table is
                ; still unallocated so Task_FreeFdTable inside will no-op.
                LDX     _ps_childTCB
                JSR     Task_AllocFdTable
                BCS     @psp_haveChildFd
                STA     _ps_savedErr
                ; Uniform child teardown: _Task_FreeBanks frees BankList[0]
                ; (= _ps_childBank, stored at spawn top) and any copied extras.
                LDX     _ps_childTCB
                JSR     _Task_FreeBanks
                JSR     Task_Free
                LDA     _ps_savedErr
                CLC
                RTS

@psp_haveChildFd ; Child inherits the parent's cwd (per-task file state, parallel
                ; to the fd-table copy below).  Parent cwd = current [_fsCwdPtr];
                ; child pid = TCB_TaskID[_ps_childTCB].  Done before the fd copy so
                ; it can't disturb _libcTmp2/_kmallocResult used there.
                LDX     _ps_childTCB
                LDA:    TCB_TaskID,X
                AND     #$00FF
                JSR     Task_InheritCwd
                ; Set the child's process name = basename(spawn path) for ps.
                ; _Sys_PathBuf still holds the staged path (Load_Binary is later).
                LDX     #_Sys_PathBuf
                LDA     _ps_childPid
                AND     #$00FF
                JSR     Task_SetName
                ; Copy parent's fd table into child's (extracted to
                ; _Task_CopyParentFds for the fork train — vfork builds the
                ; same inherited fd table).  _libcTmp2 = child's fd-table
                ; long-ptr, left by Task_AllocFdTable.
                LDA     _ps_childPid            ; A = child pid, for the
                                                ;   file table's copy
                JSR     _Task_CopyParentFds

@psp_haveDP     ; Stack base is now MM-allocated post-Load_Binary so we can
                ; honor the FGX1 header's stack_pages_hint byte.  Load the
                ; binary first (it populates _ldHeader), then alloc the
                ; stack from the hint.
                LDA     _ps_childBank
                LDX     #_Sys_PathBuf
_kfp933         JSL     KFAR_LOAD_BINARY
                BCS     @psp_loaded
                ; Loader failed; free bank + TCB and return errno.
                STA     _ps_savedErr
                ; T5-B (+ pre-existing leak fix): free EVERYTHING the child
                ; holds via _Task_FreeBanks — BankList[0] (= _ps_childBank,
                ; stored at spawn top), any FGX2 extras already copied in,
                ; and the refcounted shared-libc mapping — instead of the
                ; childBank-only Bank_Free that leaked multi-seg extras on
                ; post-load aborts.
                LDX     _ps_childTCB                ; FreeBanks + Task_Free want X = TCB offset
                JSR     _Task_FreeBanks
                JSR     Task_Free
                LDA     _ps_savedErr
                CLC
                RTS

@psp_loaded     ; The image's banks into the TCB, so _Sys_Exit's
                ; _Task_FreeBanks walk frees what the child owns, and the text
                ; it runs (see _Ld_Bind).
                LDX     _ps_childTCB
                JSR     _Ld_BindText

                ; Allocate the user stack from the FGX1 stack_pages_hint
                ; byte.  0 -> 1 page (default).  Task_AllocStack clamps to
                ; [1, 32] and stores Base/Size/Handle in the TCB.
                ;
                ; #45: the linker sizes the hint for the C frame + DEFAULT_PAD
                ; only — it never sees the argv/envp frame the loader lays on
                ; TOP of the child's stack.  Add ceil(T/256) pages for that
                ; frame here so a big command line can't push saved_S below the
                ; guard floor.  Normalize the hint 0->1 BEFORE adding (else a
                ; 0 hint + extra would skip the default C page).  If the sum
                ; exceeds the [1,32] clamp the frame still won't fit -> the
                ; loader's pre-write floor gate returns a clean E2BIG.
                LDX     _ps_argBlk
                LDY     _ps_argBlkBank
_kfp942         JSL     KFAR_LOADER_ARGPAGES        ; A = ceil(T/256)
                PHA                                  ; save extra pages
                SEP     #$20
                MX      %10
_kfp943         LDAL    KFAR_LD_HEADER+FGX1_OFF_STACK    ; hint byte
                REP     #$20
                MX      %00
                AND     #$00FF
                BNE     @psp_haveHint
                LDA     #1                           ; 0 hint -> 1 default C page
@psp_haveHint   CLC
                ADC     1,S                          ; + extra pages (pushed)
                PLY                                  ; discard pushed word
                LDX     _ps_childTCB
                JSR     Task_AllocStack
                BCS     @psp_stackOK
                STA     _ps_savedErr
                ; Uniform child teardown: _Task_FreeBanks frees TCB_BankList
                ; (the image's own banks, the spawn-top bank among them) and
                ; its text reference.
                LDX     _ps_childTCB
                JSR     _Task_FreeBanks
                JSR     Task_Free
                LDA     _ps_savedErr
                CLC
                RTS
@psp_stackOK
                ; P3-3 3.2b: seed the child's hardware-stack floor for the fcc
                ; prologue overflow guard.  floor = TCB_StackBase (lowest addr of
                ; the region; stack grows down toward it) + FCC_STK_FLOOR_MARGIN
                ; (the non-C headroom the linker also reserves via DEFAULT_PAD).
                ; The child's DP is bank 0 at TCB_DirectPage; write the 16-bit
                ; floor at +FCC_STKFLOOR_DP.  Non-fcc / unseeded binaries keep a
                ; zero floor (the carve zeroes the page), so their guard —
                ; if any — never false-traps against 0.  Shared with the execve
                ; path -- see the helper.
                LDX     _ps_childTCB
                JSR     _Ev_SeedStkFloor

                ; Bank-0 campaign 1.3: give this binary's soft-frame stack its
                ; own bank.  Shared with the execve path -- see the helper.
                PHX
                JSR     _Loader_SeedSoftBank
                PLX

                ; Phase 3a: allocate the child's kernel context (per-task kernel
                ; stack + u-area) into the scheduler-state table.  Alloc'd here
                ; but not yet USED — the dispatcher still runs on the shared
                ; kernel stack + global carryover until Phase 3b.  Task_Free
                ; (rollback below / task end) frees them.
                LDX     _ps_childTCB
                JSR     Task_AllocKernStack
                BCS     @psp_kstkOK
                STA     _ps_savedErr
                ; Uniform child teardown: _Task_FreeBanks frees TCB_BankList
                ; (the image's own banks, the spawn-top bank among them) and
                ; its text reference.
                LDX     _ps_childTCB
                JSR     _Task_FreeBanks
                JSR     Task_Free
                LDA     _ps_savedErr
                CLC
                RTS
@psp_kstkOK     LDX     _ps_childTCB
                JSR     Task_AllocUarea
                BCC     @psp_uareaFail          ; A = errno, consumed below
                ; Credentials campaign P1: Task_AllocUarea ZEROES the u-area,
                ; so without this the child comes up root no matter who forked
                ; it.  _curTask is still the parent here.  Best-effort (C=1
                ; always); preserves X.
                BRA     @psp_uareaOK
@psp_uareaFail  STA     _ps_savedErr
                ; Uniform child teardown: _Task_FreeBanks frees TCB_BankList
                ; (the image's own banks, the spawn-top bank among them) and
                ; its text reference.
                LDX     _ps_childTCB
                JSR     _Task_FreeBanks
                JSR     Task_Free
                LDA     _ps_savedErr
                CLC
                RTS
@psp_uareaOK
                ; --- BSD INHERITANCE: controlling terminal + process group ---
                ; 2.11BSD has no spawn; ours IS a fused fork+exec, so it owes
                ; what fork+exec gives.  There, ttyopen (tty.c:655) records the
                ; ctty in the u-area and sets p_pgrp, fork copies the u-area and
                ; proc entry wholesale, and kern_exec.c never clears either --
                ; so both survive fork AND exec.  The fork path below already
                ; mirrors that (the SE_PGroup copy and the SEF_CTTY block);
                ; spawn never did, and Task_Alloc zeroes both.
                ;
                ; TWO CONSEQUENCES, both apple/fgx#51, and the second is why it
                ; hid for so long:
                ;   - pgrp 0 means _Kill_GroupFanout never matches the child
                ;     against TTY_FgPgrp, so ^C cannot reach ANYTHING started
                ;     through system() (= spawnv) -- man(1)'s pager, for one.
                ;   - ctty "none" is mapped to VC 0 by _Vc_CttyIsActive, so on
                ;     the console (_kVcActive = 0) it matches BY ACCIDENT and
                ;     everything works; on any virtual console it does not, and
                ;     SYS_GETKEY sleeps on WCHAN_KBD forever.  The bug is
                ;     invisible exactly where it is usually tested.
                ;
                ; MUST PRECEDE ApplyFdActions.  A file action that opens a tty
                ; calls _Se_SetCtty through _kCttyTarget and is MEANT to
                ; override what we inherit here -- that is init spawning getty
                ; onto a line it just opened.  Inherit first, let the explicit
                ; open win, exactly as BSD orders fork then ttyopen.
                ;
                ; _curTask is still the PARENT here -- the same fact
                ; Task_AllocUarea relies on to inherit the u-area.
                PHX                                 ; child TCB offset
                LDA     _curTask
                AND     #$00FF
                BEQ     @psp_inhDone                ; boot: no parent to copy
                DEC
                ASL
                ASL
                ASL
                ASL
                ASL                                 ; (pid-1) * SE_SIZE (32)
                STA     _ps_seParent
                LDA     _ps_childPid
                AND     #$00FF
                BEQ     @psp_inhDone
                DEC
                ASL
                ASL
                ASL
                ASL
                ASL
                STA     _ps_seChild
                ; THE PROCESS GROUP, inherited exactly as fork inherits p_pgrp
                ; (apple/fgx#60).  This was tried once before and reverted,
                ; because FGX had no way for a session creator to arrive at its
                ; tty open with pgrp 0 -- spawn zeroing the group WAS the
                ; mechanism, by accident, and inheriting it removed the only
                ; one there was.  BSD's rule is not two facts but three: fork
                ; inherits p_pgrp; a session creator DETACHES to pgrp 0 first
                ; (TIOCNOTTY, tty_tty.c:57-62 -- telnetd.c:266-271 is the
                ; canonical sequence); and ttyopen then claims.  FGX now has
                ; the middle one, as TIOCNOTTY and as FA_OP_DETACH for spawn's
                ; fused fork+exec, so this can land.
                ;
                ; Init keeps pgrp 0 -- it is created at boot, where the block
                ; above bails at @psp_inhDone with no parent to copy from, so
                ; init-spawned gettys still inherit 0 and claim their lines
                ; with no detach needed, exactly as BSD's dfork() does.
                ; MEASURED, not assumed: apple/fgx#70's mutation run had a
                ; pgrp-0 child's kill(0, SIGTERM) reach init and halt the
                ; machine.
                ;
                ; What this buys: a spawned child is now in its parent's group,
                ; so _Kill_GroupFanout matches it against TTY_FgPgrp and ^C can
                ; reach anything started through spawnv -- time(1), init, login,
                ; ptyshell.  While they sat in pgrp 0 they were unreachable by
                ; the tty signals and by killpg.
                LDA     _ps_seParent
                CLC
                ADC     #SE_PGroup
                TAY
                LDA     [_schedTblPtr],Y
                STA     _ps_seCtty                  ; (scratch reuse: the ctty
                                                    ;  copy below reloads it)
                LDA     _ps_seChild
                CLC
                ADC     #SE_PGroup
                TAY
                LDA     _ps_seCtty
                STA     [_schedTblPtr],Y
                ; controlling terminal: the SEF_CTTY field ONLY, so the child's
                ; other flag bits survive (SEF_CTTY_CLEAR exists for this).
                LDA     _ps_seParent
                CLC
                ADC     #SE_Flags
                TAY
                LDA     [_schedTblPtr],Y
                AND     #SEF_CTTY_MASK
                STA     _ps_seCtty
                LDA     _ps_seChild
                CLC
                ADC     #SE_Flags
                TAY
                LDA     [_schedTblPtr],Y
                AND     #SEF_CTTY_CLEAR
                ORA     _ps_seCtty
                STA     [_schedTblPtr],Y
@psp_inhDone    PLX

                ; Apply file_actions to the child's fd table (slice-4
                ; redirection).  Runs AFTER Load_Binary so the singleton FS
                ; write-path state (_fwDataBlk, _fwDataBlkIdx, _fsCurOwnerFcb)
                ; is left in the redirect-target file's "fresh seedling"
                ; state when the child first writes — matching Fs_Write's
                ; same-block fast path.  If we ran ApplyFdActions first,
                ; Load_Binary's Fs_Open of the binary would clobber the
                ; singleton with sapling-state sentinels and the child's
                ; first Fs_Write would hit the slow path's SEED case
                ; (which the legacy code rejects with ENOSYS).
                ;
                ; When _ps_fdActionsPtr is 0 this is a no-op + C=1.
                JSR     _Sys_ApplyFdActions
                BCS     @psp_actsOK
                STA     _ps_savedErr
                ; Uniform child teardown: _Task_FreeBanks frees TCB_BankList
                ; (the image's own banks, the spawn-top bank among them) and
                ; its text reference.
                LDX     _ps_childTCB
                JSR     _Task_FreeBanks
                JSR     Task_Free
                LDA     _ps_savedErr
                CLC
                RTS
@psp_actsOK
                ; Stash entry into the child's TCB.EntryPoint (low 16 bits).
                LDX     _ps_childTCB
_kfp944         LDAL    KFAR_LD_ENTRY
                STA:     TCB_EntryPoint,X

                ;--- Lay BSD-shaped argv/envp onto child's stack + emit the
                ;    dispatcher resume frame (slice-3 B.1).  Returns
                ;    saved_S in A.
                LDX     _ps_childTCB
                JSR     Task_StkLock            ; B3: the parent is about to write
                                                ; the CHILD's stack (survey case 1)
                LDX     _ps_argBlk
                LDY     _ps_argBlkBank
_kfp945         JSL     KFAR_LOADER_STAGEARGS
                LDX     _ps_childTCB
                JSR     Task_StkUnlock
                BCS     @psp_argsOK
                ; Failed (E2BIG / EINVAL).  Free bank + TCB and pass errno.
                STA     _ps_savedErr
                ; T5-B (+ pre-existing leak fix): free EVERYTHING the child
                ; holds via _Task_FreeBanks — TCB_BankList (the spawn-top bank
                ; and any FGX2 extras copied in by _Ld_Bind), its text,
                ; and the refcounted shared-libc mapping — instead of the
                ; childBank-only Bank_Free that leaked multi-seg extras on
                ; post-load aborts.
                LDX     _ps_childTCB                ; FreeBanks + Task_Free want X = TCB offset
                JSR     _Task_FreeBanks
                JSR     Task_Free
                LDA     _ps_savedErr
                CLC
                RTS
@psp_argsOK     ; A = saved_S.  Stash in the child's TCB — its primed first-run
                ; user frame, which _Task_FirstRun TCS+RTLs into on first run.
                LDX     _ps_childTCB
                STA:     TCB_SavedS,X

                ;--- Prime the child's kernel stack so the first swtch to it
                ;    lands at _Task_FirstRun (which RTLs into the child's entry).
                JSR     Task_PrimeKernStack         ; X = child TCB (preserved)

                ;--- ASYNC (Phase 3.2): mark the child READY and return to the
                ;    parent immediately — the parent keeps running.  The child
                ;    does not run until the parent next blocks or yields (e.g.
                ;    the parent's waitpid → _sleep → swtch picks the child).
                ;    No parent block, no swtch here — so _ps_childPid is intact
                ;    for the return value.
                LDX     _ps_childTCB
                LDA     #TASK_READY
                STA:     TCB_Status,X
                LDA     _ps_childPid
                AND     #$00FF
                SEC
                RTS                                 ; C=1, A = child_pid

@psp_noBank      ; Bank_Alloc failed; A = ENOMEM.  Free child TCB.
                STA     _ps_savedErr
                LDX     _ps_childTCB                ; Task_Free wants X = TCB offset
                JSR     Task_Free
                LDA     _ps_savedErr
                CLC
                RTS
@psp_internalErr ; Lookup failures — should not happen mid-spawn.  Return ESRCH.
                LDA     #ESRCH
                CLC
                RTS

;------------------------------------------------------------------------------
; _Task_CopyParentFds - copy the parent's (_curTask's) fd table into the
; child's and bump the shared FCB refcounts.  Extracted verbatim from the
; spawn path for the fork train — vfork builds the same inherited table.
;
; In:  A = the CHILD's pid (UFS 1.7d I2b -- the file table is indexed by pid,
;      where the kernel fd table is reached through a pointer the caller
;      already holds).
;      _libcTmp2 = child's 24-bit fd-table ptr (left by Task_AllocFdTable).
;      Caller MX %00, DBR = kernel bank.
; Out: child fd table = refcounted copies of the parent's.  If the parent
;      lookup fails (shouldn't happen) the child table is left empty --
;      same fail-soft as the original spawn block.  Clobbers A, X, Y,
;      _kmallocResult.
;------------------------------------------------------------------------------
_Task_CopyParentFds
                MX      %00
                PHA                             ; the child pid, needed after
                                                ;   the lookup and the copy
                LDA     _curTask
                JSR     Task_Lookup
                BCC     @tcf_done               ; parent missing — leave child
                                                ; fd table empty (still has
                                                ; valid stdin/out/err = 0,0,0;
                                                ; user gets ENOSPC on use).
                                                ; Shouldn't happen in practice.
                LDA:    TCB_FdTablePtr,X
                STA     _kmallocResult
                SEP     #$20
                MX      %10
                LDA:    TCB_FdTablePtr+2,X
                STA     _kmallocResult+2
                LDY     #0
@tcf_fdcL       LDA     [_kmallocResult],Y      ; parent[Y]
                STA     [_libcTmp2],Y           ; child[Y]
                INY
                CPY     #FS_MAX_FDS*3
                BCC     @tcf_fdcL
                REP     #$20
                MX      %00
                ; The child now holds inherited COPIES of the parent's fd-table
                ; slots — new references to the same shared FCBs.  Bump each
                ; FCB's refcount so the child's exit-time close
                ; drops a reference instead of freeing an FCB the parent still
                ; holds (the boot-time double-free).  _libcTmp2 = child table.
                JSR     _Fcb_InheritRefs

                ; AND THE FILE TABLE INHERITS TOO -- UFS 1.7d I2b.  The loop
                ; above copied the kernel fd table; the far bank's file table
                ; is indexed by pid and knows nothing of it, so without this
                ; the child's ofile[] is EMPTY and falloc hands its first
                ; open(2) fd 0 -- over the stdin it just inherited.  That is
                ; not an error anywhere: `ls /' simply printed nothing.
                ;
                ; fdcopy bumps f_count per descriptor, which is Reno's fork
                ; loop (kern_fork.c:264, "Increase reference counts on shared
                ; objects"), and closef only closes the last reference, so the
                ; child's exit balances it.
                ;
                ; fdcopy(frompid, topid): fcc reads arguments right to left, so
                ; topid goes down first and frompid ends nearest the return.
                REP     #$30
                MX      %00
                LDA     1,S                     ; the child pid, as pushed
                AND     #$00FF
                PHA                             ; topid
                LDA     _curTask
                AND     #$00FF
                PHA                             ; frompid
_kfp913         JSL     KFAR_VFS_DESCCOPY       ; bank byte patched by Far_Init
                TSC
                CLC
                ADC     #4                      ; drop the two arguments
                TCS
@tcf_done       MX      %00
                PLA                             ; the child pid, balanced on
                                                ;   both paths
                RTS

;------------------------------------------------------------------------------
; _Ld_BindText / _Ld_Bind - a loaded image's banks into the TCB at X.
;
; KFAR_LD_EXTRABANKS[k] is segment k's bank when the process owns it -- the
; data segment's is the bank the caller allocated -- and 0 for a shared
; text's; it becomes TCB_BankList[k], the list exit frees.  KFAR_LD_USERBANK
; is segment 0's bank, which holds the entry: TCB_CodeBank.  _Ld_BindText also
; makes the text the load took the one this pid runs (KTTY_TEXT_SET); exec
; leaves that to its commit, where the old text goes.
; MX %00 in and out.  Preserves X.
;------------------------------------------------------------------------------
_Ld_BindText    MX      %00
                LDA:    TCB_TaskID,X
                PHX
                PHA
                SEP     #$20
                MX      %10
_kfp1005        LDAL    KFAR_LD_TEXT
                REP     #$20
                MX      %00
                AND     #$00FF
                TAX
                PLA
_ktp119         JSL     KTTY_TEXT_SET
                PLX
_Ld_Bind        MX      %00
                SEP     #$20
                MX      %10
_kfp1006        LDAL    KFAR_LD_USERBANK
                STA:    TCB_CodeBank,X
_kfp1007        LDAL    KFAR_LD_EXTRABANKS+0
                STA:    TCB_BankList+0,X
_kfp1008        LDAL    KFAR_LD_EXTRABANKS+1
                STA:    TCB_BankList+1,X
_kfp1009        LDAL    KFAR_LD_EXTRABANKS+2
                STA:    TCB_BankList+2,X
_kfp1010        LDAL    KFAR_LD_EXTRABANKS+3
                STA:    TCB_BankList+3,X
_kfp1011        LDAL    KFAR_LD_EXTRABANKS+4
                STA:    TCB_BankList+4,X
_kfp1012        LDAL    KFAR_LD_EXTRABANKS+5
                STA:    TCB_BankList+5,X
_kfp1013        LDAL    KFAR_LD_EXTRABANKS+6
                STA:    TCB_BankList+6,X
_kfp1014        LDAL    KFAR_LD_EXTRABANKS+7
                STA:    TCB_BankList+7,X
                REP     #$20
                MX      %00
                RTS

;------------------------------------------------------------------------------
; _Sys_Vfork (#46) - BSD vfork(2), fork train Stage V.
;
; The child BORROWS the parent's entire memory image: banks, data seg, DP
; page, user stack.  Nothing is copied, and the child's TCB owns nothing —
; BankList all-zero, DP/stack/kern-stack/u-area handles are its own or zero —
; so the existing teardown paths (child _exit -> _Task_FreeBanks, reap ->
; Task_Free) naturally no-op on the shared image.  The text it runs and the
; libraries it uses are counted: the child takes a reference on each (below,
; and ld.mod's fork hook), which its exec or exit drops.
;
; The parent blocks (TASK_BLOCKED on WCHAN_VFORK) until the child execve()s
; (Stage V2 hand-back) or _exit()s (_Exit_Core clears the child's
; SEF_VFORKCHILD, then wakes WCHAN_VFORK).  Wake predicate, rechecked under
; SEI per the _sleep contract: child gone, zombie, or no longer flagged.
;
; USER-STACK BYTE HAZARD: the dispatcher's 4-byte exit frame [DBR,PCL,PCH,PB]
; at $00:userSP+1..+4 is consumed FIRST by the child's first-run exit and
; then REUSED by the child's own pushes.  The parent's eventual dispatcher
; exit needs those bytes intact, so they ride the parent's KERNEL stack
; across the sleep (a task's kernel stack survives swtch) and are rewritten
; before the parent returns.  The libc vfork stub protects its own
; caller-RTL bytes the same way (toolchain lib/libc.s).
;
; Child resume: kernel stack primed at _Task_VforkFirstRun (syscall.s), which
; replays the dispatcher exit with A=0 + C=1 from the child's SE carryover
; (= copies of the parent's live _Sys_UserSP/UserDP/CallerBank).
;
; Child signal state: dispositions (SIG_IGN mask) are inherited; pending
; signals are cleared.  Registered C-handler far-ptrs are per-pid and NOT
; copied in v1 — a vfork child execve()s immediately (exec resets handlers
; anyway); revisit for snapshot-fork subshells at Stage F.
;
; Returns: child A=0; parent (on wake) A=child pid; C=0 + A=errno (EAGAIN /
; ENOMEM) with the child slot rolled back on failure.
;------------------------------------------------------------------------------
_Sys_Vfork      ENT
                MX      %00
                LDA     #0                          ; mode 0 = vfork
                STA     _vf_mode
                BRA     _vf_common

;------------------------------------------------------------------------------
; _Sys_Fork (#2) - snapshot fork, fork train Stage F.  Same shared-image
; child as vfork PLUS _Fork_Snapshot: the parent's mutable banks/stack/DP
; are saved to spares, the child runs IN PLACE (same pointers, same
; banks), and the hand-back RESTORES the parent from the snapshot at the
; child's execve/_exit -- "deferred-parent" fork.  The child carries the
; parent's SE_SoftBank so heap pointers resolve; _Fork_Restore scrubs it
; before the exit-time sbrk free can touch the parent's bank.
;------------------------------------------------------------------------------
_Sys_Fork       ENT
                MX      %00
                LDA     #1                          ; mode 1 = snapshot fork
                STA     _vf_mode
                ; fall through
_vf_common
                ; 1. Child TCB slot.
                JSR     Task_Alloc
                BCS     @vf_haveTCB
                JSR     _Kern_LogForkFail   ; the path that mattered
                CLC                                 ; A = EAGAIN
                RTS
@vf_haveTCB     STX     _vf_childTCB
                LDA:    TCB_TaskID,X
                AND     #$00FF
                STA     _vf_childPid
                LDA     _curTask
                STA:    TCB_ParentID,X
                ; Scrub the aliased/stale fields a recycled slot may carry
                ; BEFORE any rollback can run: DataBank+Reserved1 pair, exit
                ; code, wait bookkeeping, pending-signal words.  (Task_Alloc
                ; zeroes only BankList; Task_Free zeroes only SE_Flags + the
                ; per-resource handles.)
                LDA     #0
                STA:    TCB_DataBank,X              ; + TCB_Reserved1 (adjacent, 0)
                STA:    TCB_ExitCode,X
                STA:    TCB_WaitingOn,X             ; = TCB_SavedPC alias
                STA:    TCB_WaitType,X              ; = TCB_SavedPB alias
                STA:    TCB_MsgQHead,X              ; = TCB_PendingSig lo
                STA:    TCB_MsgQTail,X              ; = TCB_PendingSig hi
                STA:    TCB_MsgQCount,X             ; = TCB_SigIgnore (unused; see #54)

                ; 2. Kernel context: per-task kernel stack + u-area.
                JSR     Task_AllocKernStack
                BCS     @vf_kstkOK
                BRL     @vf_rollback
@vf_kstkOK      LDX     _vf_childTCB
                JSR     Task_AllocUarea
                BCS     @vf_credsOK
                BRL     @vf_rollback
@vf_credsOK     ; Task_AllocUarea has copied the parent's u-area whole --
                ; credentials, u_cmask, rlimits, login -- as 2.11BSD's newproc
                ; copies USIZE (include/kernel.s, U_INHERIT_LEN).  It happens
                ; HERE, at fork, not at the SE_SnapPtr restore: the CHILD
                ; performs that restore (at execve/_exit), so a copy there
                ; would capture what the parent held AFTER the fork.
@vf_uareaOK
                ; 3. Own fd table + inherited refcounted copies.
                LDX     _vf_childTCB
                JSR     Task_AllocFdTable
                BCS     @vf_fdOK
                BRL     @vf_rollback
@vf_fdOK        LDA     _vf_childPid                ; A = child pid, for the
                                                    ;   file table's copy
                JSR     _Task_CopyParentFds         ; _libcTmp2 = child fd tbl

                ; 4. cwd inherit (same as spawn), and the parent's name, which
                ; the child keeps until its execve names it (Task_InheritName).
                LDA     _vf_childPid
                JSR     Task_InheritCwd
                LDA     _vf_childPid
                JSR     Task_InheritName

                ; 5. Share the parent's memory image: copy the TCB memory and
                ; scheduling fields verbatim, one bounce per field (abs,X is
                ; the file idiom; both offsets live in singletons consumed
                ; before the parent blocks).
                LDA     _curTask
                JSR     Task_Lookup                 ; X = parent TCB offset
                BCS     @vf_parOK
                LDA     #ESRCH                      ; can't happen mid-syscall
                BRL     @vf_rollback
@vf_parOK       STX     _vf_parentTCB
                LDA:    TCB_Priority,X              ; + BasePriority (byte pair)
                LDX     _vf_childTCB
                STA:    TCB_Priority,X
                LDX     _vf_parentTCB
                LDA:    TCB_Flags,X
                LDX     _vf_childTCB
                STA:    TCB_Flags,X
                LDX     _vf_parentTCB
                LDA:    TCB_StackBank,X
                LDX     _vf_childTCB
                STA:    TCB_StackBank,X
                LDX     _vf_parentTCB
                LDA:    TCB_StackPtr,X
                LDX     _vf_childTCB
                STA:    TCB_StackPtr,X
                LDX     _vf_parentTCB
                LDA:    TCB_StackBase,X
                LDX     _vf_childTCB
                STA:    TCB_StackBase,X
                LDX     _vf_parentTCB
                LDA:    TCB_StackSize,X
                LDX     _vf_childTCB
                STA:    TCB_StackSize,X
                LDX     _vf_parentTCB
                LDA:    TCB_DirectPage,X
                LDX     _vf_childTCB
                STA:    TCB_DirectPage,X
                LDX     _vf_parentTCB
                LDA:    TCB_DataBank,X              ; + TCB_Reserved1 (byte pair)
                LDX     _vf_childTCB
                STA:    TCB_DataBank,X
                LDX     _vf_parentTCB
                LDA:    TCB_CodeBank,X
                LDX     _vf_childTCB
                STA:    TCB_CodeBank,X
                LDX     _vf_parentTCB
                LDA:    TCB_EntryPoint,X
                LDX     _vf_childTCB
                STA:    TCB_EntryPoint,X
                LDX     _vf_parentTCB
                LDA:    TCB_SavedS,X
                LDX     _vf_childTCB
                STA:    TCB_SavedS,X
                ; --- SIGNAL STATE INHERITANCE (apple/fgx#27 + #54) ---
                ; What stood here was `LDA TCB_SigIgnore / STA TCB_SigIgnore`
                ; with the comment "dispositions inherit".  BOTH HALVES WERE
                ; FALSE.  TCB_SigIgnore occurred exactly twice in the tree --
                ; its EQU in include/kernel.s and that copy -- and the delivery
                ; path reads only the SIGHND_IGN table through _sigHndPtr.  The
                ; copy was dead code, so fork inherited NOTHING: Task_Alloc
                ; zeroes the child's handler tables, its 32-bit mask and its
                ; ignore mask, and nothing put them back.
                ;
                ; BSD inherits all three, in one act: fork copies the proc entry
                ; and u-area wholesale, so p_sigmask, p_sigignore, p_sigcatch and
                ; u_signal[] all come across.  Splitting them would leave a
                ; child whose mask and dispositions disagree.
                ;
                ; It bit hardest for fork WITHOUT exec.  Fork-then-exec re-syncs
                ; by accident (exec resets caught handlers anyway, and the fresh
                ; image zeroes libc's shadow), but a SUBSHELL kept libc's shadow
                ; mask -- it lives in the data bank, which snapshot-fork copies
                ; verbatim -- while its KERNEL mask was 0.  tcsh's pfork holds
                ; sigblock(sigmask(SIGCHLD)) across fork + palloc precisely so
                ; pchild cannot run before the pid is recorded; in the child that
                ; hold was fictitious.
                ;
                ; EVERY COPY BELOW IS REAL, FOR A VFORK TOO.  This said the
                ; opposite until apple/fgx#253 -- "a vfork child borrows its
                ; parent's pid, so source and destination coincide and every
                ; copy below is a no-op" -- and it was false in both halves:
                ; `_vf_common' opens by calling `Task_Alloc' (step 1 above),
                ; which hands back a FRESH slot and writes `TCB_TaskID' =
                ; slot + 1 (task.s:130), and `_vf_childPid' is read straight
                ; back out of that new TCB.  Parent and child are two rows, and
                ; fork inheritance IS these copies.  Upstream agrees:
                ; `rpp->p_pid = mpid', kern_fork.c:171.
                ;
                ; SAID AT LENGTH BECAUSE THE WRONG VERSION COST A CYCLE.  It
                ; reads as an invitation to delete the loop, and it makes
                ; `_Sig_ResetOnExec' -- which keys off `_curTask', the CHILD,
                ; during the child's own execve -- look as though it clears the
                ; PARENT'S dispositions.  A fix for that non-problem was
                ; written, built and measured before the premise was checked;
                ; the real defect was in libc, where `_sig_c_tab' sits in the
                ; data bank a vfork child SHARES.  Left unconditional rather
                ; than branched, which is still right: a wrong guard here would
                ; be silent.
                LDX     _vf_parentTCB
                LDA:    TCB_TaskID,X
                AND     #$00FF
                DEC
                ASL                                 ; (ppid-1)*2, handler stride
                STA     _vf_sigPar
                LDA     _vf_childPid
                AND     #$00FF
                DEC
                ASL
                STA     _vf_sigChd
                ; The per-task signal ENTRY point: one word each (apple/fgx#58,
                ; which replaced five per-signal handler tables with this plus
                ; the CATCH mask below).
                LDA     _vf_sigPar
                CLC
                ADC     #SIGHND_ENTRY_OFF
                TAY
                LDA     [_sigHndPtr],Y
                PHA
                LDA     _vf_sigChd
                CLC
                ADC     #SIGHND_ENTRY_OFF
                TAY
                PLA
                STA     [_sigHndPtr],Y
                ; The THREE 32-bit masks (BSD mask, SIG_IGN, then CATCH) at
                ; (pid-1)*4.  fork inherits all three: BSD's fork copies the
                ; whole proc struct, so p_sigmask, p_sigignore AND p_sigcatch
                ; all survive it -- a forked child keeps its parent's handlers
                ; until it execs, which is what _Sig_ResetOnExec then undoes.
                ; The three are contiguous at a 64 B stride precisely so this
                ; stays ONE loop; see include/memmap.s.
                ASL     _vf_sigPar                  ; *2 -> *4
                ASL     _vf_sigChd
                LDA     #SIGHND_MASK_OFF
                STA     _vf_sigBase
                LDX     #3
@vf_sigML       LDA     _vf_sigBase
                CLC
                ADC     _vf_sigPar
                TAY
                LDA     [_sigHndPtr],Y
                PHA                                 ; lo
                INY
                INY
                LDA     [_sigHndPtr],Y
                PHA                                 ; hi
                LDA     _vf_sigBase
                CLC
                ADC     _vf_sigChd
                TAY
                INY
                INY
                PLA
                STA     [_sigHndPtr],Y              ; hi
                DEY
                DEY
                PLA
                STA     [_sigHndPtr],Y              ; lo
                LDA     _vf_sigBase
                CLC
                ADC     #{SIGHND_IGN_OFF-SIGHND_MASK_OFF}
                STA     _vf_sigBase
                DEX
                BNE     @vf_sigML

                ; 6. Child sched-entry: user-resume carryover = the parent's
                ; LIVE dispatcher globals (we are inside the parent's syscall,
                ; so these are exactly the parent's user frame); pgroup
                ; inherits; flags = SEF_VFORKCHILD alone (slot's SE_Flags was
                ; zeroed by Task_Free); WaitChan + SnapPtr/SbrkBank scrubbed.
                LDA     _vf_childTCB
                SEC
                SBC     #FGX_TASK_TBL_OFF
                LSR
                STA     _vf_childSe
                CLC
                ADC     #SE_UserSP
                TAY
                LDA     _Sys_UserSP
                STA     [_schedTblPtr],Y
                LDA     _vf_childSe
                CLC
                ADC     #SE_UserDP
                TAY
                LDA     _Sys_UserDP
                STA     [_schedTblPtr],Y
                LDA     _vf_childSe
                CLC
                ADC     #SE_CallerBank
                TAY
                LDA     _Sys_CallerBank
                STA     [_schedTblPtr],Y
                LDA     _vf_childSe
                CLC
                ADC     #SE_WaitChan
                TAY
                LDA     #0
                STA     [_schedTblPtr],Y
                LDA     _vf_childSe
                CLC
                ADC     #SE_SnapPtr
                TAY
                LDA     #0
                STA     [_schedTblPtr],Y            ; SnapPtr lo16
                INY
                INY
                LDA     #0
                STA     [_schedTblPtr],Y            ; SnapPtr hi8 + SbrkBank
                ; pgroup: parent SE -> child SE
                LDA     _vf_parentTCB
                SEC
                SBC     #FGX_TASK_TBL_OFF
                LSR
                CLC
                ADC     #SE_PGroup
                TAY
                LDA     [_schedTblPtr],Y
                PHA
                LDA     _vf_childSe
                CLC
                ADC     #SE_PGroup
                TAY
                PLA
                STA     [_schedTblPtr],Y
                ; flags: exactly SEF_VFORKCHILD (mode 0) or SEF_SNAPCHILD
                ; (mode 1); a snapchild ALSO inherits the parent's sbrk
                ; bank byte so heap far-pointers keep resolving in place.
                ; ... PLUS THE PARENT'S CONTROLLING TERMINAL.  In BSD the ctty is
                ; a property of the SESSION, not the process: fork inherits it
                ; and exec preserves it.  This used to store the SEF_*CHILD flag
                ; ALONE, so every command a shell ran came up with ctty "none" --
                ; which the keyboard gate reads as "belongs to VC 0".  A job on
                ; VC2 therefore never saw its own ^C: the keystroke stayed in the
                ; shared ring and was collected by the CONSOLE's shell at the next
                ; switch, and a ^C typed at the console reached the VC2 job
                ; instead.  It showed with ntpplay running on VC2 --
                ; a good witness precisely because it polls SYS_POLLKEY for $03
                ; itself rather than relying on signal delivery, so it isolates
                ; the eligibility gate from the signal path.
                LDA     _vf_parentTCB
                SEC
                SBC     #FGX_TASK_TBL_OFF
                LSR
                CLC
                ADC     #SE_Flags
                TAY
                LDA     [_schedTblPtr],Y
                AND     #SEF_CTTY_MASK          ; parent's ctty, stored as index+1
                PHA
                LDA     _vf_mode
                BNE     @vf_snapFlag
                PLA
                ORA     #SEF_VFORKCHILD
                BRA     @vf_setFlag
@vf_snapFlag    PLA
                ORA     #SEF_SNAPCHILD
@vf_setFlag     PHA
                LDA     _vf_childSe
                CLC
                ADC     #SE_Flags
                TAY
                PLA
                STA     [_schedTblPtr],Y
                LDA     _vf_mode
                BEQ     @vf_flagsDone
                ; snapchild: SE_SoftBank(child) = SE_SoftBank(parent)
                LDA     _vf_parentTCB
                SEC
                SBC     #FGX_TASK_TBL_OFF
                LSR
                CLC
                ADC     #SE_SoftBank
                TAY
                SEP     #$20
                MX      %10
                LDA     [_schedTblPtr],Y
                PHA                                 ; (8-bit push)
                REP     #$20
                MX      %00
                LDA     _vf_childSe
                CLC
                ADC     #SE_SoftBank
                TAY
                SEP     #$20
                MX      %10
                PLA                                 ; (8-bit pull)
                STA     [_schedTblPtr],Y
                REP     #$20
                MX      %00
@vf_flagsDone


                ; 8. Prime the child's kernel stack: first swtch lands at
                ; _Task_VforkFirstRun, which exits the dispatcher with A=0
                ; (a snapchild resumes the same way -- same carryover).
                LDX     _vf_childTCB
                LDA     #_Task_VforkFirstRun-1
                JSR     Task_PrimeKernStackAt

                ; 8.5 (mode 1): snapshot the parent's mutable image.  On
                ; failure the snapshot self-unwinds its partial claims,
                ; and we join the common rollback (the child owns nothing).
                LDA     _vf_mode
                BEQ     @vf_noSnap
                ; The parent's image-cache home first (step 9 parks its stack
                ; and direct page there), so a pool out of units fails the
                ; fork before anything is copied.  A home it already holds for
                ; this range is kept.
                LDX     _vf_parentTCB
                LDA:    TCB_StackBase,X
                SEC
                SBC     #256                    ; the range: page and stack
                STA    |_ui_hbase
                LDA:    TCB_StackSize,X
                XBA
                AND     #$00FF
                INC
                STA    |_ui_hpages
                LDA:    TCB_TaskID,X
                JSR     Uimg_HomeAlloc          ; preserves X
                BCS     @vf_haveHome
                LDA     #ENOMEM
                BRA     @vf_snapFail
@vf_haveHome    JSR     _Fork_Snapshot          ; the parent's bank home
                BCC     @vf_snapFail
                ; The child's image-cache home too, for the same range
                ; (_ui_hbase/_ui_hpages are still set), here in this syscall so
                ; that its release allocates nothing (Img_Release).  It needs
                ; no bank home: it holds the live banks, and takes the
                ; parent's home over at the first swap (Img_Swap).
                LDX     _vf_childTCB
                LDA:    TCB_TaskID,X
                JSR     Uimg_HomeAlloc
                BCS     @vf_noSnap
                LDA     _curTask
                JSR     _Img_FreeHome
                LDA     #ENOMEM
@vf_snapFail    BRL     @vf_rollback
@vf_noSnap
                ; The child runs the parent's text, and counts it: 2.11BSD
                ; newproc (sys/kern_fork.c), "rip->p_textp->x_count++;".  Here,
                ; past every roll-back, so a failed fork never took one.
                LDX     _vf_childTCB
                LDA:    TCB_TaskID,X
                PHA
                LDX     _vf_parentTCB
                LDA:    TCB_TaskID,X
                PLX
_ktp120         JSL     KTTY_TEXT_FORK
                ; 9. Child runnable.
                ;
                ; B3: flag the PARENT unswappable HERE, and not earlier.  The
                ; child now runs on the parent's bank-0 stack (this routine
                ; copied StackBank/Ptr/Base/Size across above) while the parent
                ; blocks interruptibly on WCHAN_VFORK -- which would otherwise
                ; make it an eligible swap victim with a live task executing on
                ; its bytes.  Not SEF_STKLOCK: that one asserts the holder does
                ; NOT sleep, and sleeping is exactly what the parent does here.
                ;
                ; SET AFTER THE LAST THING THAT CAN FAIL.  It used to be set
                ; ~60 lines earlier, before _Fork_Snapshot -- whose failure arm
                ; BRLs to @vf_rollback and never cleared it, so every failed fork
                ; leaked the flag.  bigforkx fails the snapshot five times on
                ; purpose and tripped the pairing check every run; it went
                ; unnoticed only because the check reported instead of halting
                ; and the message scrolled away before `screen_lacks PANIC`
                ; looked at the final screen.  Setting it at the commit point
                ; needs no rollback arm at all, which is why this is the fix
                ; rather than adding a clear to that one path.
                ;
                ; Nothing can swap in the window this gives up: the child is not
                ; READY until the instruction below, so it cannot run, and the
                ; parent has not slept yet.
                ;
                ; A SNAPSHOT fork borrows nothing: the parent's stack and direct
                ; page go to its home, the child holds the range as an ordinary
                ; resident, and the parent comes back through Uimg_Ensure when
                ; it is next picked.  Its live S is _Sys_UserSP, which swtch
                ; would store at the sleep below; the park needs it now.
                LDA     _vf_mode
                BNE     @vf_park
                LDX     _vf_parentTCB
                JSR     Task_BorrowSet          ; cleared at both hand-back sites
                BRA     @vf_ready
@vf_park        LDA     _vf_parentTCB
                SEC
                SBC     #FGX_TASK_TBL_OFF
                LSR
                CLC
                ADC     #SE_UserSP
                TAY
                LDA     _Sys_UserSP
                STA     [_schedTblPtr],Y
                LDX     _vf_parentTCB
                LDA:    TCB_TaskID,X
                AND     #$00FF
                JSR     _Uimg_Park
                STZ    |_ks_dir                 ; ...and its banks, to the
                LDA     _curTask                ;   home _Fork_Snapshot made
                JSR     _Img_BankMove
                LDA     _vf_childPid
                AND     #$00FF
                DEC
                TAY
                SEP     #$20
                MX      %10
                LDA     #1
                STA    |_uiResident,Y           ; the child holds the range
                REP     #$20
                MX      %00
                TYA
                ASL
                TAY
                LDA    |_kSystemTicks
                STA    |_uiAcqTick,Y
@vf_ready       ANOP
                ; ld.mod: the child uses what its parent uses (shared libc
                ; SP4).  Past every failure path, so nothing to undo.
                LDA     _vf_childPid
_ktp108         JSL     KTTY_LD_FORK
                LDX     _vf_childTCB
                LDA     #TASK_READY
                STA:    TCB_Status,X

                ; 10. Parent: stash the dispatcher exit frame + child pid on
                ; our KERNEL stack (survives swtch; singletons don't survive
                ; the block), then sleep until the child hands the image back.
                LDX     _Sys_UserSP
                LDAL    $000001,X                   ; frame bytes SP+1..SP+2
                PHA
                LDAL    $000003,X                   ; frame bytes SP+3..SP+4
                PHA
                LDA     _vf_childPid
                PHA
@vf_waitLoop    SEI                                 ; recheck under spl (the
                                                    ; _sleep lost-wakeup rule)
                LDA     1,S                         ; child pid
                JSR     Task_Lookup
                BCC     @vf_done                    ; slot gone — child reaped
                LDA:    TCB_Status,X
                CMP     #TASK_ZOMBIE
                BEQ     @vf_done                    ; child _exit'd
                ; still alive: flagged = still borrowing our image?
                TXA
                SEC
                SBC     #FGX_TASK_TBL_OFF
                LSR
                CLC
                ADC     #SE_Flags
                TAY
                LDA     [_schedTblPtr],Y
                BIT     #SEF_VFORKCHILD+SEF_SNAPCHILD
                BEQ     @vf_done                    ; hand-back done (execve)
                BIT     #SEF_FORKREL
                BNE     @vf_done                    ; released: both run
                ; UNINTERRUPTIBLE, as upstream's is: 2.11BSD newproc waits
                ; `while (rpp->p_flag & SVFORK) sleep((caddr_t)rpp,PSWP+1);'
                ; (sys/kern_fork.c:297-298), below PZERO.  _sleep would
                ; return at once with a signal pending and this loop would
                ; spin without ever letting the child run.
                LDA     #WCHAN_VFORK
                JSR     _sleepUn                    ; blocks; CLIs on wake
                BRA     @vf_waitLoop
@vf_done        CLI
                PLA                                 ; child pid
                TAY                                 ; park in Y (no JSRs below)
                ; restore the dispatcher exit frame the child consumed
                LDX     _Sys_UserSP                 ; parent's own again (swtch
                                                    ; restored our carryover)
                PLA
                STAL    $000003,X                   ; frame bytes SP+3..SP+4
                PLA
                STAL    $000001,X                   ; frame bytes SP+1..SP+2
                TYA
                AND     #$00FF
                SEC
                RTS

@vf_rollback    JSR     _Kern_LogForkFail
                ; A = errno.  Child owns only its kernel context + fd table;
                ; Task_Free handles all of those (each FreeX no-ops on a zero
                ; handle).  No banks were claimed, so _Task_FreeBanks isn't
                ; needed.
                STA     _ps_savedErr
                LDX     _vf_childTCB
                JSR     Task_Free
                LDA     _ps_savedErr
                CLC
                RTS

;------------------------------------------------------------------------------
; _Fork_CopyBank - copy [_fs_start, _fs_end] of one bank into another, and
; when _fs_end is below $FFFF, [_ib_lim, $FFFF] as well: the region above the
; heap and the heap descriptor.
;
; MVN's bank bytes are assembly-time immediates, so runtime banks go
; through this self-modified 4-byte stub (the kernel runs from RAM; same
; class as the w5100 patch sites).  MVN is interruptible/resumable, and
; the kernel is cooperative in-syscall, so nothing else runs mid-copy.
;
; _fs_start is the pair's recorded floor: 0 for a bank whose whole content is
; live, and the parent's _fcc_sfp for the soft-frame bank, which is live only
; from the soft stack's current top upward (apple/fgx#372 item 1).
;
; _fs_end is $FFFF for every pair but the data bank's, whose end is its break
; less one: nothing lives in [HEAP_BRK, HEAP_LIM) (sbrk zero-fills a grown
; span, and every sh stak and blok writer grows the break before it writes),
; so the copy is the heap's extent plus everything from the heap limit up --
; the data and the stack segment of 2.11BSD's fork, at the two ends of the
; space (usr/sys/sys/kern_fork.c:271-273).
;
; In:  A.lo = source bank, Y.lo = destination bank, _fs_start = first offset,
;      _fs_end = last offset, _ib_lim = the source's heap limit.  MX %00.
; Out: copied.  Clobbers A/X/Y; DBR preserved (PHB/PLB -- MVN leaves DBR = the
;      destination bank).
;------------------------------------------------------------------------------
_Fork_CopyBank  ENT
                MX      %00
                SEP     #$20
                MX      %10
                STA     _fcb_mvn+2                  ; MVN src bank operand
                TYA
                STA     _fcb_mvn+1                  ; MVN dst bank operand
                REP     #$20
                MX      %00
                LDX     _fs_start                   ; src = dst offset
                LDA     _fs_end
                SEC
                SBC     _fs_start                   ; count-1 = end - start
                JSR     @fcb_move
                LDA     _fs_end
                CMP     #$FFFF
                BEQ     @fcb_done
                LDX    |_ib_lim                     ; the region above the heap
                LDA     #$FFFF                      ;   and the descriptor
                SEC
                SBC    |_ib_lim                     ; count-1 = $FFFF - limit
                JSR     @fcb_move
@fcb_done       RTS
                ; The MVN runs from a JSR, NOT a JSL: the kernel is relocated
                ; at boot, so a JSL to an in-kernel label would target the
                ; assembly-time bank.  The self-mod stores above are abs writes
                ; under DBR = the LIVE kernel bank, so they patch the relocated
                ; copy we are executing from.
@fcb_move       TXY
                PHB
_fcb_mvn        MVN     $00,$00                     ; operands self-modified
                PLB
                RTS

;------------------------------------------------------------------------------
; _Fork_CopyRange - move a byte range between two banks known at the call.
;
; The stack and DP copies were hand-rolled BYTE loops that toggled MX around
; every byte, about 37 cycles each against MVN's 7 (apple/fgx#372).  Both banks
; are known where they run, so the block move the 65816 has applies.
;
; Self-modified for the same reason _Fork_CopyBank is: MVN's bank operands are
; assembly-time immediates, the kernel is relocated at boot, and the abs stores
; below run under DBR = the LIVE kernel bank, so they patch the copy being
; executed rather than the assembly-time one.
;
; In:  _fcr_src = source bank:offset, _fcr_dst = destination bank:offset,
;      _fcr_len = byte count.  A count of zero moves nothing.  MX %00.
; Out: bytes moved.  Clobbers A/X/Y.  DBR preserved -- MVN leaves it holding
;      the destination bank, so the PLB is not optional.
;------------------------------------------------------------------------------
_Fork_CopyRange MX      %00
                LDA     _fcr_len
                BEQ     @fcr_done
                DEC                                 ; MVN counts len-1
                PHB
                PHA
                SEP     #$20
                MX      %10
                LDA     _fcr_src+2
                STA     _fcr_mvn+2                  ; MVN src bank operand
                LDA     _fcr_dst+2
                STA     _fcr_mvn+1                  ; MVN dst bank operand
                REP     #$20
                MX      %00
                LDX     _fcr_src
                LDY     _fcr_dst
                PLA                                 ; len-1 back into A
_fcr_mvn        MVN     $00,$00                     ; operands self-modified
                PLB
@fcr_done       RTS

;------------------------------------------------------------------------------
; _Fork_Snapshot - save the parent's mutable image for a snapshot fork.
;
; Mutable set (census, Stage 0): the DATA bank (== the whole bank for a
; single-bank FGX1 image -- copying its code bytes too is harmless), the
; soft-frame bank if granted (campaign 1.3; the slot was the private sbrk
; bank), EVERY BANK of every dedicated big-malloc block
; the parent owns (#11, 2026-08-02).  The user stack and the DP page are the
; image cache's: _vf_common parks the parent's in its home.  Code banks stay shared read-only (fcc code is
; pure; the DBR rule keeps mutable data in the data seg).
;
; The big blocks joined the set because they are user memory living OUTSIDE the
; data bank: malloc routes >= $F000 to _Kmalloc_Big, and a bank fork does not
; copy is a bank the child writes THROUGH to the parent -- issue #4's leak, one
; allocator over.  There is no MMU, so there is no copy-on-write to hide behind;
; only a task that actually holds a big block pays the copy.
;
; Descriptor (Kmalloc'd, M_KERN):
;   +0  parent pid (2)          +2  pair count (2)
;   +4  pairs[FORK_MAX_PAIRS] of {orig bank, spare bank, 2 unused}
;       (data, soft-frame, then one pair per BANK of each owned big block)
;
; FORK_MAX_PAIRS is a fixed ceiling so the descriptor stays fixed-header: a task
; holding more big banks than fit cannot fork, and gets EAGAIN.  That is the
; same fail-closed answer as running out of spare banks, and it is deliberate --
; a variable-length header in the least forgiving code in the tree buys nothing
; here, since spare banks run out long before eight pairs do.
;
; DP-pointer discipline: the descriptor pointer's TRUTH lives in the
; absolute _fs_desc static; it is (re)loaded into the _kmallocResult DP
; long-ptr via _Fork_LdDesc after every allocator call (Kmalloc /
; Bank_Alloc / Bank_Free clobber the caller-saved DP scratch).  The byte
; walker rides _libcTmp2; no JSR happens inside any copy loop, so both
; stay stable where it matters.
;
; In:  _vf_parentTCB/_vf_childTCB/_vf_childSe already set (the _Sys_Vfork
;      common body).  MX %00.
; Out: C=1, child SE_SnapPtr -> descriptor; C=0 + A=errno with every
;      partial claim unwound (descriptor freed, spares freed).
;------------------------------------------------------------------------------
FORK_MAX_PAIRS  EQU     8                           ; {orig,spare} slots
FSD_PAIR_STRIDE EQU     4                           ; orig(1) spare(1) unused(2)
FSD_PID         EQU     0
FSD_NPAIR       EQU     2
FSD_PAIRS       EQU     4
; BRACES, NOT PRECEDENCE.  Merlin32 evaluates strictly left to right, so the
; old `FSD_PAIRS+FORK_MAX_PAIRS*2' was {4+8}*2 = 24 and not the 20 its comment
; claimed.  Harmless -- everything downstream derives from this EQU -- but it
; had four bytes of the descriptor unaccounted for and a comment that disagreed
; with the assembler.
FSD_HDR         EQU     FSD_PAIRS+{FORK_MAX_PAIRS*FSD_PAIR_STRIDE}  ; 36

_Fork_LdDesc                                        ; _fs_desc -> _kmallocResult
                MX      %00
                LDA     _fs_desc
                STA     _kmallocResult
                SEP     #$20
                MX      %10
                LDA     _fs_desc+2
                STA     _kmallocResult+2
                REP     #$20
                MX      %00
                RTS

;------------------------------------------------------------------------------
; _Fork_AddPair - claim a spare bank for the live bank in _fs_orig, record the
; {orig, spare} pair, and PUBLISH the new pair count.  Nothing is copied here:
; the park at the fork's commit point moves the banks (_Img_BankMove).
;
; Publishing the count as each pair completes is what makes the unwind trivial
; and, more to the point, correct: the descriptor always describes exactly the
; spares that have actually been claimed, so the unwind can neither free a bank
; that was never taken nor miss one that was.
;
; In:  _fs_orig = live bank, _fs_nPair = pairs recorded so far.  MX %00.
; Out: C=1 + _fs_nPair bumped; C=0 + A = errno, nothing claimed.
;------------------------------------------------------------------------------
_Fork_AddPair   MX      %00
                LDA     _fs_nPair
                CMP     #FORK_MAX_PAIRS
                BCC     @fa_room
                LDA     #EAGAIN                     ; descriptor full: fail closed
                CLC
                RTS
@fa_room        JSR     Bank_Alloc
                BCS     @fa_have
                LDA     #ENOMEM
                CLC
                RTS
@fa_have        STA     _fs_spare
                JSR     _Fork_LdDesc                ; Bank_Alloc clobbered it
                LDA     _fs_nPair
                ASL
                ASL                                 ; pair stride 4
                CLC
                ADC     #FSD_PAIRS
                TAY
                SEP     #$20
                MX      %10
                LDA     _fs_orig
                STA     [_kmallocResult],Y          ; pair.orig
                LDA     _fs_spare
                INY
                STA     [_kmallocResult],Y          ; pair.spare
                REP     #$20
                MX      %00
                INC     _fs_nPair
                LDA     _fs_nPair
                LDY     #FSD_NPAIR
                STA     [_kmallocResult],Y          ; publish the count
                SEC
                RTS

_Fork_Snapshot  ENT
                MX      %00
                ; A home the parent still holds from an earlier fork is stale:
                ; the parent is running, so its banks are the live ones.
                LDA     _curTask
                JSR     _Img_FreeHome
                ; Descriptor allocation: the header only.  The parent's stack
                ; and direct page are not in it: they go to its image-cache
                ; home (_vf_common step 9) and come back through Uimg_Ensure.
                LDA     #FSD_HDR
                LDX     #M_KERN
                JSR     Kmalloc
                BCS     @fs_haveDesc
                LDA     #ENOMEM
                CLC
                RTS
@fs_haveDesc    ; truth copy of the block ptr (Kmalloc left it in
                ; _kmallocResult, which later allocator calls clobber).
                LDA     _kmallocResult
                STA     _fs_desc
                SEP     #$20
                MX      %10
                LDA     _kmallocResult+2
                STA     _fs_desc+2
                REP     #$20
                MX      %00
                ; Header: parent pid, zeroed pairs.
                LDA     _curTask
                AND     #$00FF
                LDY     #FSD_PID
                STA     [_kmallocResult],Y
                STZ     _fs_nPair
                LDA     #0
                LDY     #FSD_NPAIR
                STA     [_kmallocResult],Y          ; pair count = 0
                LDX     #FORK_MAX_PAIRS
                LDY     #FSD_PAIRS
@fs_zpL         STA     [_kmallocResult],Y          ; Kmalloc does not clear, and
                INY                                 ;   the count is authoritative,
                INY                                 ;   but a zeroed table makes a
                DEX                                 ;   dump readable
                BNE     @fs_zpL
                LDX     _vf_parentTCB
                ; --- Pair 0: the data bank (always). ---
                LDA:    TCB_DataBank,X
                AND     #$00FF
                STA     _fs_orig
                JSR     _Fork_AddPair
                BCS     @fs_sbrk
                BRL     @fs_unwindPairs
@fs_sbrk        ; --- Pair 1: the SOFT-FRAME bank (if granted).  The child
                ; overwrites the parent's live activation records in place, so
                ; the parent's frames need a home like its data (campaign 1.3). ---
                LDA     _vf_parentTCB
                SEC
                SBC     #FGX_TASK_TBL_OFF
                LSR
                CLC
                ADC     #SE_SoftBank
                TAY
                SEP     #$20
                MX      %10
                LDA     [_schedTblPtr],Y
                REP     #$20
                MX      %00
                AND     #$00FF
                BEQ     @fs_big                     ; no soft-frame bank
                STA     _fs_orig
                JSR     _Fork_AddPair
                BCS     @fs_big
                BRL     @fs_unwindPairs
@fs_big         ; --- One pair per BANK of every dedicated big block the parent
                ; owns (#11).  _BlkRow_FindOwned walks the kind-4 block-table
                ; rows stamped with our pid; the cursor rides a static because
                ; Bank_Alloc and the bank copy clobber the allocator scratch it
                ; returns in.
                STZ     _fs_bigRow
@fs_bigL        LDX     _fs_bigRow
                LDA     _curTask                    ; fork runs in the parent
                AND     #$00FF
                JSR     _BlkRow_FindOwned
                BCC     @fs_stack                   ; no more owned blocks
                STA     _fs_orig                    ; base bank
                STX     _fs_bigCnt                  ; bank count
                STY     _fs_bigRow                  ; resume point for the walk
@fs_bankL       LDA     _fs_bigCnt
                BEQ     @fs_bigL                    ; block done -> next row
                JSR     _Fork_AddPair
                BCS     @fs_bankNext
                BRL     @fs_unwindPairs
@fs_bankNext    DEC     _fs_bigCnt
                INC     _fs_orig                    ; next bank of this block
                BRA     @fs_bankL
@fs_stack
                ; The child is about to run in place on the parent's region, so
                ; the parent's high-water mark is the sampled one from here on:
                ; the paint below its S will be the child's residue.
                LDA     _curTask                ; fork runs in the parent
                AND     #$00FF
                JSR     _Tas_MarkShared
                ; --- Publish: the PARENT's SE_SnapPtr = its bank home. ---
                LDA     _vf_parentTCB
                SEC
                SBC     #FGX_TASK_TBL_OFF
                LSR
                CLC
                ADC     #SE_SnapPtr
                TAY
                LDA     _fs_desc
                STA     [_schedTblPtr],Y            ; lo16
                INY
                INY
                SEP     #$20
                MX      %10
                LDA     _fs_desc+2
                STA     [_schedTblPtr],Y            ; bank byte (SnapPtr+2)
                REP     #$20
                MX      %00
                SEC
                RTS
@fs_unwindPairs ; A = errno.  Free EVERY spare claimed so far, then the
                ; descriptor.  THIS IS THE FAIL-CLOSED PATH: a fork that cannot
                ; copy one of the parent's mutable banks must fail, never fall
                ; through to sharing it.  The descriptor's pair count is the
                ; truth -- _Fork_AddPair publishes it only once the spare is
                ; claimed AND recorded -- so this can neither free a bank that
                ; was never taken nor miss one that was.
                STA     _ps_savedErr
@fs_uwL         LDA     _fs_nPair
                BEQ     @fs_unwindDesc2
                DEC     _fs_nPair
                JSR     _Fork_LdDesc                ; Bank_Free clobbers it
                LDA     _fs_nPair
                ASL
                ASL                                 ; pair stride 4
                CLC
                ADC     #FSD_PAIRS+1                ; ...+1 = pair.spare
                TAY
                LDA     [_kmallocResult],Y          ; spare in the low byte
                AND     #$00FF
                JSR     Bank_Free
                BRA     @fs_uwL
@fs_unwindDesc2 LDA     _ps_savedErr
@fs_unwindDesc  STA     _ps_savedErr
                JSR     _Fork_LdDesc                ; Kfree consumes _kmallocResult
                JSR     Kfree
                LDA     _ps_savedErr
                CLC
                RTS

;------------------------------------------------------------------------------
; THE BANK HOME.  A snapshot fork's members share one set of addresses: the
; stack range and direct page (the image cache's, task.s) and the mutable
; banks -- the data bank, the soft-frame bank, the parent's big blocks.  One
; member HOLDS the live banks; each of the others keeps its bytes of them in a
; BANK HOME, a descriptor on its SE_SnapPtr with one spare per live bank.  So
; a group of N members has N-1 homes, and the holder is the one member with
; SE_SnapPtr = 0.
;
; Fork makes the one new home, in the parent's syscall (_Fork_Snapshot), and
; the parent parks its banks into it; the child holds the live ones.  When a
; member with a home is picked, its home and the live banks EXCHANGE, and the
; home passes to the member whose bytes it now holds (Img_Swap, from
; _Uimg_Restore): nothing is allocated or freed in swtch, and the pool of
; spare banks a fork needs is what a deferred-parent fork always needed.  A
; holder that leaves (exec, exit) hands the live banks to a member with a
; home, whose home then goes (_Img_Leave).
;
; 2.11BSD's no-core fork path is the model: "swap out the current process to
; generate the copy" (sys/kern_fork.c, newproc), and both images run, each
; swapped in as it is scheduled.
;------------------------------------------------------------------------------

;------------------------------------------------------------------------------
; _Img_LdHdr - copy pid A's bank-home header into _ib_hdr, its pointer into
; _ib_desc.  A block move, not the _kmallocResult DP cell, because the swap
; runs in swtch, between two tasks' syscalls.
; Out: C=1 copied; C=0 the pid has no home.  Clobbers A/X/Y.
;------------------------------------------------------------------------------
_Img_LdHdr      MX      %00
                JSR     _Img_SnapOff
                LDA     [_schedTblPtr],Y
                STA    |_ib_desc
                INY
                INY
                LDA     [_schedTblPtr],Y
                AND     #$00FF                  ; the bank; SE_SoftBank follows
                STA    |_ib_desc+2
                ORA    |_ib_desc
                BNE     @ilh_have
                CLC
                RTS
@ilh_have       LDA    |_ib_desc
                STA     _fcr_src
                LDA     #_ib_hdr
                STA     _fcr_dst
                SEP     #$20
                MX      %10
                LDA    |_ib_desc+2
                STA     _fcr_src+2
                PHK
                PLA
                STA     _fcr_dst+2              ; the kernel bank
                REP     #$20
                MX      %00
                LDA     #FSD_HDR
                STA     _fcr_len
                JSR     _Fork_CopyRange
                SEC
                RTS

; _Img_SnapOff - Y = the SE_SnapPtr offset of pid A.  Clobbers A.
_Img_SnapOff    MX      %00
                AND     #$00FF
                DEC
                ASL
                ASL
                ASL
                ASL
                ASL                             ; (pid-1)*32 = seoff
                CLC
                ADC     #SE_SnapPtr
                TAY
                RTS

;------------------------------------------------------------------------------
; _Img_Sfp - A = pid A's soft-stack top, read from the direct page kept in its
; image-cache home: a member whose banks move is never resident at the time.
; 0 (the whole bank) when it has no home.  Clobbers A/X/Y.
;------------------------------------------------------------------------------
_Img_Sfp        MX      %00
                AND     #$00FF
                DEC
                TAY
                SEP     #$20
                MX      %10
                LDA    |_uiHomeBank,Y
                STA     _fcr_src+2
                PHK
                PLA
                STA     _fcr_dst+2
                REP     #$20
                MX      %00
                LDA     _fcr_src+2
                AND     #$00FF
                BEQ     @isf_none
                TYA
                ASL
                TAY
                LDA    |_uiHomeOff,Y            ; the DP page: the home's start
                CLC
                ADC     #FCC_SFP_DP
                STA     _fcr_src
                LDA     #_ib_w
                STA     _fcr_dst
                LDA     #2
                STA     _fcr_len
                JSR     _Fork_CopyRange
                LDA    |_ib_w
                RTS
@isf_none       LDA     #0
                RTS

;------------------------------------------------------------------------------
; _Img_Brk - A = the data bank A.lo's break less one, or $FFFF when the cell
; holds no break.  Clobbers A.
;------------------------------------------------------------------------------
_Img_Brk        MX      %00
                PHB
                SEP     #$20
                MX      %10
                PHA
                PLB                             ; DBR = that bank
                REP     #$20
                MX      %00
                LDA    |HEAP_BRK
                PLB
                DEC
                CMP     #HEAP_LIM                   ; a break is at most HEAP_LIM
                BCC     @ibk_ok
                LDA     #$FFFF
@ibk_ok         RTS

;------------------------------------------------------------------------------
; _Img_Lim - A = the data bank A.lo's heap limit cell (HEAP_LIM): the first
; byte of the region above the heap that a copy of the bank carries.  A cell
; above its seed reads as the seed, so a copy never skips the descriptor.
; Clobbers A.
;------------------------------------------------------------------------------
_Img_Lim        MX      %00
                PHB
                SEP     #$20
                MX      %10
                PHA
                PLB                             ; DBR = that bank
                REP     #$20
                MX      %00
                LDA    |HEAP_LIM
                PLB
                CMP     #HEAP_LIM+1
                BCC     @ilm_ok
                LDA     #HEAP_LIM
@ilm_ok         RTS

;------------------------------------------------------------------------------
; _Img_Extent - _fs_start/_fs_end for pair _ib_i of the header in _ib_hdr,
; pid _ib_pid's: the data bank to the break (_ib_brk, set by the caller) plus
; everything from its heap limit up (_ib_lim, set by the caller; the copy
; routines add it), the soft-frame bank from _ib_sfp, a big block whole.
; Nothing lives between the break and the cells: sbrk zero-fills a grown span
; and every sh stak and blok writer grows the break first.  Clobbers A/Y.
;------------------------------------------------------------------------------
_Img_Extent     MX      %00
                STZ     _fs_start
                LDA     #$FFFF
                STA     _fs_end
                LDA    |_ib_i
                BNE     @iex_soft
                LDA    |_ib_brk
                STA     _fs_end
                RTS
@iex_soft       LDA    |_ib_pid
                DEC
                ASL
                ASL
                ASL
                ASL
                ASL
                CLC
                ADC     #SE_SoftBank
                TAY
                LDA     [_schedTblPtr],Y
                EOR    |_ib_pair
                AND     #$00FF
                BNE     @iex_done               ; a big-block bank: whole
                LDA    |_ib_sfp
                STA     _fs_start
@iex_done       RTS

;------------------------------------------------------------------------------
; _Img_BankMove - pid A's banks to its home (_ks_dir = 0) or back (1), by
; block move.  For the fork's park of the parent and a leaver's hand-over.
; No-op for a pid with no home.  Clobbers A/X/Y.
;------------------------------------------------------------------------------
_Img_BankMove   MX      %00
                STA    |_ib_pid
                JSR     _Img_LdHdr
                BCS     @ibm_have
                RTS
@ibm_have       INC    |_kImgCopies
                LDA    |_ib_pid
                JSR     _Img_Sfp
                STA    |_ib_sfp
                STZ    |_ib_i
@ibm_l          LDA    |_ib_i
                CMP    |_ib_hdr+FSD_NPAIR
                BCC     @ibm_pair
                RTS
@ibm_pair       ASL
                ASL                             ; pair stride 4
                TAX
                LDA    |_ib_hdr+FSD_PAIRS,X     ; lo = orig, hi = spare
                STA    |_ib_pair
                LDX    |_ks_dir
                BEQ     @ibm_src
                XBA                             ; restore: the spare is the source
@ibm_src        PHA
                JSR     _Img_Lim                ; the source's limit and break
                STA    |_ib_lim                 ; (both used for pair 0 only)
                PLA
                JSR     _Img_Brk
                STA    |_ib_brk
                JSR     _Img_Extent
                LDA    |_ib_pair
                LDX    |_ks_dir
                BEQ     @ibm_park
                XBA                             ; restore: spare -> orig
@ibm_park       PHA
                AND     #$00FF                  ; A.lo = source
                STA    |_ib_w
                PLA
                XBA
                AND     #$00FF
                TAY                             ; Y = destination
                LDA    |_ib_w
                JSR     _Fork_CopyBank
                INC    |_ib_i
                BRA     @ibm_l

;------------------------------------------------------------------------------
; Img_Swap - pid A is being restored: if it has a bank home, its home and the
; live banks exchange, and the home passes to the group's holder, whose bytes
; it now holds.  From _Uimg_Restore, in swtch: allocates nothing.  The extent
; exchanged covers both members' live bytes -- the higher break, the lower
; soft-stack top.  Halts if the group has no holder, which would mean two
; members' bytes in one place.  Clobbers A/X/Y.
;------------------------------------------------------------------------------
Img_Swap        ENT
                MX      %00
                STA    |_ib_pid
                JSR     _Img_LdHdr
                BCS     @isw_have
                RTS
@isw_have       LDA    |_ib_pid
                JSR     Task_Lookup
                BCS     @isw_tcb
@isw_fail       JMP     _Img_NoHolder
@isw_tcb        STX    |_il_tcb
                LDA:    TCB_DataBank,X
                AND     #$00FF
                STA    |_il_bank
                JSR     _Img_Holder             ; A = its pid
                BCC     @isw_fail
                STA    |_il_pid
                INC    |_kImgCopies
                JSR     _Img_Sfp                ; the holder's soft-stack top
                STA    |_ib_sfp
                LDA    |_ib_pid
                JSR     _Img_Sfp                ; ...and the incoming one's
                CMP    |_ib_sfp
                BCS     @isw_sfpLo
                STA    |_ib_sfp                 ; the lower of the two
@isw_sfpLo      STZ    |_ib_i
@isw_l          LDA    |_ib_i
                CMP    |_ib_hdr+FSD_NPAIR
                BCS     @isw_pass
                ASL
                ASL
                TAX
                LDA    |_ib_hdr+FSD_PAIRS,X
                STA    |_ib_pair
                JSR     _Img_Brk                ; the live break (orig)
                STA    |_ib_brk
                LDA    |_ib_pair
                XBA
                JSR     _Img_Brk                ; the home's (spare)
                CMP    |_ib_brk
                BCC     @isw_brkLo
                STA    |_ib_brk                 ; the higher of the two
@isw_brkLo      LDA    |_ib_pair
                JSR     _Img_Lim                ; the live limit (orig)
                STA    |_ib_lim
                LDA    |_ib_pair
                XBA
                JSR     _Img_Lim                ; the home's (spare)
                CMP    |_ib_lim
                BCS     @isw_limHi
                STA    |_ib_lim                 ; the lower of the two
@isw_limHi      JSR     _Img_Extent
                LDA    |_ib_pair
                XBA
                AND     #$00FF
                TAY
                LDA    |_ib_pair
                AND     #$00FF
                JSR     _Img_Xchg
                INC    |_ib_i
                BRA     @isw_l
@isw_pass       ; The home now holds the holder's bytes: it is the holder's.
                LDA    |_il_pid
                JSR     _Img_SnapOff
                LDA    |_ib_desc
                STA     [_schedTblPtr],Y
                INY
                INY
                SEP     #$20
                MX      %10
                LDA    |_ib_desc+2
                STA     [_schedTblPtr],Y
                REP     #$20
                MX      %00
                LDA    |_ib_pid
                JMP     _Img_SnapClr

; _Img_NoHolder - a member with a home was restored and no member holds the
; live banks: two members' bytes would share them.  Halt with the pid.
_Img_NoHolder   MX      %00
                LDA     #@inh_msg
                STA     _conStrPtr
                JSR     Kern_LogStrNoEOL
                LDA    |_ib_pid
                JSR     Kern_LogDec16
                JSR     Kern_LogEOL
                JMP     _Kern_Halt
@inh_msg        ASC     'img: no holder for pid ',00

; _Img_SnapClr - pid A's SE_SnapPtr = 0, three bytes; SE_SoftBank follows.
_Img_SnapClr    MX      %00
                JSR     _Img_SnapOff
                LDA     #0
                STA     [_schedTblPtr],Y
                INY
                INY
                SEP     #$20
                MX      %10
                STA     [_schedTblPtr],Y
                REP     #$20
                MX      %00
                RTS

;------------------------------------------------------------------------------
; _Img_Holder - the pid of the member of data bank _il_bank, other than the
; TCB at _il_tcb, that has no home (holds the live banks).
; Out: C=1 A = pid; C=0 none.  Clobbers A/X/Y.
; _Img_Homed - the same walk for the first member that HAS a home.
;------------------------------------------------------------------------------
_Img_Holder     MX      %00
                STZ    |_ib_want
                BRA     _Img_Find
_Img_Homed      MX      %00
                LDA     #1
                STA    |_ib_want
_Img_Find       MX      %00
                LDX     #FGX_TASK_TBL_OFF
@ifd_l          CPX    |_il_tcb
                BEQ     @ifd_next
                LDA:    TCB_Status,X
                BEQ     @ifd_next               ; TASK_UNUSED
                CMP     #TASK_ZOMBIE
                BEQ     @ifd_next
                LDA:    TCB_DataBank,X
                AND     #$00FF
                CMP    |_il_bank
                BNE     @ifd_next
                LDA:    TCB_TaskID,X
                PHX
                JSR     _Img_SnapOff
                PLX
                LDA     [_schedTblPtr],Y
                INY
                ORA     [_schedTblPtr],Y        ; lo16 | (hi8 + bank)
                BEQ     @ifd_none
                LDA     #1
                BRA     @ifd_test
@ifd_none       LDA     #0
@ifd_test       CMP    |_ib_want
                BNE     @ifd_next
                LDA:    TCB_TaskID,X
                AND     #$00FF
                SEC
                RTS
@ifd_next       TXA
                CLC
                ADC     #TCB_SIZE
                TAX
                CPX     #FGX_TASK_TBL_OFF+{TASK_MAX_SLOTS*TCB_SIZE}
                BCC     @ifd_l
                CLC
                RTS

;------------------------------------------------------------------------------
; _Img_Xchg - exchange [_fs_start, _fs_end] of banks A.lo and Y.lo, a word at
; a time, and when _fs_end is below $FFFF [_ib_lim, $FFFF] too: the region
; above the heap and the descriptor.  Each range is widened to even bounds.
; An exchange is its own inverse, so a word both ranges cover would be
; swapped back: the second range starts no lower than the first one's
; widened end, which an odd heap limit or one below the break would
; otherwise overlap.  About 20 cycles a byte against 14 for the two block moves a copy
; through a third bank would take, and it needs no third bank.  The bank bytes
; of the four long-indexed operands are patched in place, as _Fork_CopyBank's
; MVN operands are.  Clobbers A/X/Y; DBR = the kernel bank.
;------------------------------------------------------------------------------
_Img_Xchg       MX      %00
                SEP     #$20
                MX      %10
                STA     _ixA1+3
                STA     _ixA2+3
                TYA
                STA     _ixB1+3
                STA     _ixB2+3
                REP     #$20
                MX      %00
_ixRange        LDA     _fs_end
                INC
                INC
                AND     #$FFFE
                STA    |_ix_stop                ; one past the end, even
                LDA     _fs_start
                AND     #$FFFE
                TAX
_ixA1           LDAL    $000000,X
                TAY
_ixB1           LDAL    $000000,X
_ixA2           STAL    $000000,X
                TYA
_ixB2           STAL    $000000,X
                INX
                INX
                CPX    |_ix_stop
                BNE     _ixA1
                LDA     _fs_end
                CMP     #$FFFF
                BEQ     @ix_done
                LDA     #$FFFF                  ; the heap cells, then stop
                STA     _fs_end
                LDA    |_ib_lim                 ; the region above the heap, from
                CMP    |_ix_stop                ;   no lower than the first range's
                BCS     @ix_limHi               ;   widened end
                LDA    |_ix_stop
@ix_limHi       STA     _fs_start
                BRA     _ixRange
@ix_done        RTS

;------------------------------------------------------------------------------
; _Img_FreeHome - pid A's bank home, if it has one: its spares, its descriptor,
; its SE_SnapPtr.  Syscall context.  Clobbers A/X/Y, and _libcTmp2 via Kfree.
;------------------------------------------------------------------------------
_Img_FreeHome   MX      %00
                AND     #$00FF
                STA    |_ib_pid
                JSR     _Img_LdHdr
                BCS     @ifh_have
                RTS
@ifh_have       STZ    |_ib_i
@ifh_l          LDA    |_ib_i
                CMP    |_ib_hdr+FSD_NPAIR
                BCS     @ifh_desc
                ASL
                ASL
                TAX
                LDA    |_ib_hdr+FSD_PAIRS+1,X
                AND     #$00FF
                JSR     Bank_Free
                INC    |_ib_i
                BRA     @ifh_l
@ifh_desc       LDA    |_ib_desc
                STA     _kmallocResult
                SEP     #$20
                MX      %10
                LDA    |_ib_desc+2
                STA     _kmallocResult+2
                REP     #$20
                MX      %00
                JSR     Kfree
                LDA    |_ib_pid
                JMP     _Img_SnapClr

;------------------------------------------------------------------------------
; _Img_Leave - the task at X leaves the image group of data bank A (its exec
; commit, or its exit).  A leaver with a home just frees it: its bytes are
; dead.  A leaver that HELD the live banks hands them to a member with a home:
; that member's bytes come back into them now -- the leaver is done with them
; -- and its home goes.  Syscall context.  Clobbers A/X/Y.
;------------------------------------------------------------------------------
_Img_Leave      MX      %00
                AND     #$00FF
                STA    |_il_bank
                STX    |_il_tcb
                LDA:    TCB_TaskID,X
                JSR     _Img_SnapOff
                LDA     [_schedTblPtr],Y
                INY
                ORA     [_schedTblPtr],Y
                BEQ     @il_holder
                LDX    |_il_tcb
                LDA:    TCB_TaskID,X
                JMP     _Img_FreeHome
@il_holder      JSR     _Img_Homed              ; A = a member with a home
                BCC     @il_done
                STA    |_il_pid
                LDA     #1
                STA    |_ks_dir
                LDA    |_il_pid
                JSR     _Img_BankMove
                LDA    |_il_pid
                JSR     _Img_FreeHome
@il_done        RTS

;------------------------------------------------------------------------------
; Img_Release - the running task, if it is a snapshot fork child not yet
; released, lets its parent run: SEF_FORKREL, and a wake on WCHAN_VFORK.
; Nothing is allocated: the parent's home was made at fork and the child's
; bytes take it over at the swap (Img_Swap).  Called from an interruptible
; _sleep only.  Not from the quantum yield: the quantum is one free-running
; countdown, so almost every child would reach a yield before its exec, and
; each released child costs two image copies more on the shell's
; fork-then-exec path.  A child that computes without sleeping keeps its
; parent waiting, as every fork child did before.  Preserves A/X/Y.
;------------------------------------------------------------------------------
Img_Release     ENT
                MX      %00
                PHA
                PHX
                PHY
                LDA     _curTask
                JSR     Task_Lookup
                BCC     @ir_out
                JSR     _tsl_seoff              ; Y = SE_Flags offset
                LDA     [_schedTblPtr],Y
                AND     #SEF_SNAPCHILD+SEF_FORKREL
                CMP     #SEF_SNAPCHILD
                BNE     @ir_out
                LDA     [_schedTblPtr],Y
                ORA     #SEF_FORKREL
                STA     [_schedTblPtr],Y
                LDA     #WCHAN_VFORK
                JSR     _wakeup
@ir_out         PLY
                PLX
                PLA
                RTS

;------------------------------------------------------------------------------
; Img_DataBank - A = the bank holding the data-bank bytes of the task at X:
; its bank home's spare for the data bank if it has a home, else its live data
; bank.  For a reader of another task's heap cells (SYS_PROCS).  Preserves X;
; clobbers A/Y and _fcr_*.
;------------------------------------------------------------------------------
Img_DataBank    ENT
                MX      %00
                PHX
                LDA:    TCB_TaskID,X
                JSR     _Img_LdHdr
                PLX
                BCC     @idb_live
                LDA    |_ib_hdr+FSD_PAIRS+1     ; pair 0's spare
                AND     #$00FF
                RTS
@idb_live       LDA:    TCB_DataBank,X
                AND     #$00FF
                RTS

;------------------------------------------------------------------------------
; Img_HandOff - the task at X is leaving the image group of data bank A (its
; exit, or its exec commit with _ho_exec = 1, the outgoing image then being
; the one saved in _ev_old*).  If it OWNS the group's memory -- the owner is
; the member that is not a snapshot child -- and a member remains, the first
; member found becomes the owner: the bank list, the stack reservation, the
; soft-frame bank and the big-block rows pass to it, and it stops being a
; snapshot child, so its own exec or exit frees them.  The leaver is left
; holding nothing its frees could reach.  Without this the owner's exit frees
; memory the rest of the group is running in.  Syscall context.
; Clobbers A/X/Y.
;------------------------------------------------------------------------------
Img_HandOff     ENT
                MX      %00
                AND     #$00FF
                STA    |_il_bank
                STX    |_il_tcb
                JSR     _tsl_seoff
                LDA     [_schedTblPtr],Y
                BIT     #SEF_SNAPCHILD+SEF_VFORKCHILD
                BEQ     @iho_owner
                RTS                             ; a fork child owns nothing
@iho_owner      JSR     _Img_Homed              ; the heir: any member
                BCS     @iho_heir
                JSR     _Img_Holder
                BCS     @iho_heir
                RTS                             ; nobody left: nothing to hand
@iho_heir       STA    |_ho_heirPid
                JSR     Task_Lookup
                STX    |_ho_heir
                LDX    |_il_tcb
                LDA     _ho_exec
                BNE     @iho_fromExec
                LDA:    TCB_StackBase,X         ; exit: the TCB is the image
                STA    |_ho_base
                LDA:    TCB_BankList+0,X
                STA    |_ho_bl+0
                LDA:    TCB_BankList+2,X
                STA    |_ho_bl+2
                LDA:    TCB_BankList+4,X
                STA    |_ho_bl+4
                LDA:    TCB_BankList+6,X
                STA    |_ho_bl+6
                STZ:    TCB_BankList+0,X
                STZ:    TCB_BankList+2,X
                STZ:    TCB_BankList+4,X
                STZ:    TCB_BankList+6,X
                STZ:    TCB_StackBase,X
                STZ:    TCB_StackSize,X
                BRA     @iho_give
@iho_fromExec   LDA     _ev_oldStkBase          ; exec: the saved image
                STA    |_ho_base
                LDA     _ev_oldBankList+0
                STA    |_ho_bl+0
                LDA     _ev_oldBankList+2
                STA    |_ho_bl+2
                LDA     _ev_oldBankList+4
                STA    |_ho_bl+4
                LDA     _ev_oldBankList+6
                STA    |_ho_bl+6
                STZ     _ev_oldBankList+0
                STZ     _ev_oldBankList+2
                STZ     _ev_oldBankList+4
                STZ     _ev_oldBankList+6
                STZ     _ev_oldStkBase
                STZ     _ev_oldStkSize
@iho_give       LDX    |_ho_heir
                LDA    |_ho_bl+0
                STA:    TCB_BankList+0,X
                LDA    |_ho_bl+2
                STA:    TCB_BankList+2,X
                LDA    |_ho_bl+4
                STA:    TCB_BankList+4,X
                LDA    |_ho_bl+6
                STA:    TCB_BankList+6,X
                JSR     _tsl_seoff              ; the heir owns now
                LDA     [_schedTblPtr],Y
                AND     #$FF6F                  ; not SNAPCHILD, not FORKREL
                STA     [_schedTblPtr],Y
                ; The soft-frame bank: the heir carries the same byte from the
                ; fork; the leaver's goes, so its free finds nothing.
                LDX    |_il_tcb
                TXA
                SEC
                SBC     #FGX_TASK_TBL_OFF
                LSR
                CLC
                ADC     #SE_SoftBank
                TAY
                SEP     #$20
                MX      %10
                LDA     #0
                STA     [_schedTblPtr],Y
                REP     #$20
                MX      %00
                ; The big-block rows: re-keyed, so _BlkRow_FreeByOwner on the
                ; leaver finds none.
                LDA:    TCB_TaskID,X
                AND     #$00FF
                STA    |_ho_old
                LDX     #0
@iho_rowL       LDA    |_ho_old
                JSR     _BlkRow_FindOwned       ; X = cursor
                BCC     @iho_rowsDone
                STY    |_ho_next
                TYA
                DEC
                ASL
                ASL
                ASL                             ; row byte-offset = idx * 8
                CLC
                ADC     #3                      ; +3 owner
                TAY
                SEP     #$20
                MX      %10
                LDA    |_ho_heirPid
                STA     [_kHeapCur],Y
                REP     #$20
                MX      %00
                LDX    |_ho_next
                BRA     @iho_rowL
@iho_rowsDone   ; The leaver's image-cache home for the range it gave away.
                LDX    |_il_tcb
                LDA:    TCB_TaskID,X
                AND     #$00FF
                DEC
                ASL
                TAY
                LDA    |_ho_base
                SEC
                SBC     #256
                CMP    |_uiHomeBase,Y
                BNE     @iho_done
                LDA:    TCB_TaskID,X
                JSR     Uimg_HomeFree
@iho_done       RTS

;------------------------------------------------------------------------------
;------------------------------------------------------------------------------
; _Loader_SeedSoftBank - grant the freshly-loaded image a DEDICATED bank for its
; soft-frame stack and seed _fcc_sfp = bank:$FFFE in the child's direct page.
;
; FGX2 header byte 15 asks for it, and fgx_ld DERIVES that byte from the presence
; of a `_SOFTSIZE EQU` in the binary's own assembly -- so the request cannot
; disagree with the codegen that needs it, and every pre-campaign binary reads 0
; because the byte was `reserved`.
;
; WHY A WHOLE BANK.  The soft stack shared the task's DATA bank until 2026-08-02
; and did not fit -- not for want of room but for want of privacy: bsh's stak
; arena claims ~50 KB of that bank during parse and left the soft stack seven
; sourced commands.  Capping the break to make room made sbrk FAIL, and 2.11BSD's
; setbrk never checks its return, so the cap corrupted the shell rather than
; bounding it.  apple/fgx#12.
;
; SHARED BY SPAWN AND EXECVE.  Both load a fresh image into a fresh DP, and the
; execve path was written as "spawn's block, verbatim" -- a third verbatim copy
; is how the stack-floor seed would have drifted next.  In execve this MUST be
; called after the old bank is freed, or the free reclaims the bank just granted.
;
; In:  _ps_childTCB = the child's TCB offset; _ldHeader = the new image's header.
; Out: nothing.  A grant failure is deliberately NOT fatal -- the pointer keeps a
;      ZERO bank and the prologue guard traps the first soft frame, which is a
;      clean named death, where failing the load would report ENOMEM for a
;      condition the caller cannot act on.
; Clobbers A/X/Y, _libcTmp2.  Caller MX %00.
;------------------------------------------------------------------------------
; _Kern_LogForkFail - name a refused fork.  A = errno, preserved.
;
; 2.11BSD sh retries a failed fork FOREVER and silently:
;     WHILE (parent=fork()) == -1 DO sigchk(); alarm(10); pause() OD   (xec.c:243)
; libc's alarm/pause exist for that loop.  So a permanently-failing fork is an
; alive machine producing no output and tripping no guard -- and none of the four
; detectors this campaign added watches fork at all.
;
; EVERY failure path must come here, which is the whole point of it being a
; routine.  The first version of this instrument lived inline at @vf_rollback and
; missed the one path that mattered: _vf_common's Task_Alloc failure returns
; CLC/RTS directly, because there is no child TCB to roll back yet -- and a full
; task table is exactly what a fork storm exhausts.  An instrument on the wrong
; path reads identically to a machine that never failed.
;
; Not mirrored to the console: the retry loop would flood it.  The line still
; reaches syslogd through /dev/klog, as 2.11BSD's tablefull("proc") reaches it
; through log(LOG_ERR, ...) (tablefull, vendor/2.11BSD/usr/sys/sys/subr_prf.c,
; called from kern_fork.c).
;------------------------------------------------------------------------------
_Kern_LogForkFail ENT
                MX      %00
                PHA
                PHX
                PHY
                PHA                                 ; errno, for the hex print
                SEP     #$20
                MX      %10
                LDA    |_kernLogMirror
                PHA
                STZ    |_kernLogMirror
                REP     #$20
                MX      %00
                LDA     #_K_ForkFailMsg
                STA     _conStrPtr
                JSR     Kern_LogStrNoEOL
                LDA     3,S                         ; the errno pushed above
                JSR     Kern_LogHex16
                JSR     Kern_LogEOL
                SEP     #$20
                MX      %10
                PLA
                STA    |_kernLogMirror
                REP     #$20
                MX      %00
                PLA                                 ; drop the errno copy
                PLY
                PLX
                PLA
                RTS

;------------------------------------------------------------------------------
; _Loader_FreeSoftBank - release the soft-frame bank the OUTGOING image held.
;
; Paired with _Loader_SeedSoftBank across every exec arm: a fresh image gets a
; fresh bank, and the old one must go back to the pool first or an exec loop
; leaks a bank per generation until Bank_Alloc starts failing.
;
; In:  _ps_childTCB = the TCB offset of the task being re-imaged.
; Out: SE_SoftBank scrubbed to 0.
; Preserves A/X/Y.  Caller MX %00.
;------------------------------------------------------------------------------
_Loader_FreeSoftBank ENT
                MX      %00
                PHA
                PHX
                PHY
                LDA     _ps_childTCB
                SEC
                SBC     #FGX_TASK_TBL_OFF
                LSR
                CLC
                ADC     #SE_SoftBank
                TAY
                SEP     #$20
                MX      %10
                LDA     [_schedTblPtr],Y
                BEQ     @lfb_none
                PHA
                LDA     #0
                STA     [_schedTblPtr],Y            ; scrub BEFORE the free, so a
                PLA                                 ; failure cannot double-free
                REP     #$20
                MX      %00
                AND     #$00FF
                JSR     Bank_Free
                BRA     @lfb_done
@lfb_none       REP     #$20
                MX      %00
@lfb_done       PLY
                PLX
                PLA
                RTS

;------------------------------------------------------------------------------
_Loader_SeedSoftBank ENT
                MX      %00
                PHA                                 ; caller-transparent: this
                PHX                                 ; sits between unrelated
                PHY                                 ; steps in two long routines
                SEP     #$20
                MX      %10
_kfp946         LDAL    KFAR_LD_HEADER+FGX2_OFF_SOFTBANK
                REP     #$20
                MX      %00
                AND     #$00FF
                BNE     @lsb_want
                BRA     @lsb_done
@lsb_want       JSR     Bank_Alloc                  ; C=1 + A = bank
                BCS     @lsb_got
                BRA     @lsb_done                   ; ENOMEM: leave the bank 0
@lsb_got        PHA                                 ; keep the bank number
                LDA     _ps_childTCB                ; SE slot = (TCB-base)>>1
                SEC
                SBC     #FGX_TASK_TBL_OFF
                LSR
                CLC
                ADC     #SE_SoftBank
                TAY
                PLA
                PHA
                SEP     #$20
                MX      %10
                STA     [_schedTblPtr],Y            ; remember it: freed at exit
                REP     #$20
                MX      %00
                LDX     _ps_childTCB
                JSR     Uimg_DPPtr                  ; _libcTmp2 -> the child's
                                                    ;   page, wherever it lives
                LDA     #$FFFE                      ; the soft stack grows DOWN
                LDY     #FCC_SFP_DP
                STA     [_libcTmp2],Y
                PLA
                SEP     #$20
                MX      %10
                LDY     #FCC_SFP_DP+2
                STA     [_libcTmp2],Y               ; child DP $BF = the bank
                REP     #$20
                MX      %00
@lsb_done       PLY
                PLX
                PLA
                RTS

;------------------------------------------------------------------------------
; _Ev_SeedStkFloor - seed a task's hardware-stack floor for fcc's prologue
; overflow guard.  floor = TCB_StackBase (the LOWEST address of the region;
; the stack grows down toward it) + FCC_STK_FLOOR_MARGIN (the non-C headroom
; the linker also reserves via DEFAULT_PAD), written 16-bit into the task's
; bank-0 DP page at +FCC_STKFLOOR_DP.
;
; A binary with no seeded floor keeps a zero one (the carve zeroes the page),
; so its guard -- if it has one -- never false-traps against 0.
;
; Factored out at #14 because exec then needed it TWICE (once per arm of the
; own-vs-borrow split), which would have made three verbatim copies counting
; posix_spawn's.  Same reasoning as _Loader_SeedSoftBank right above, whose
; header says the same thing: three copies is how the paths drift.
;
; In:  X = TCB offset.  Caller MX %00.  Preserves A/X/Y; clobbers _libcTmp2.
;------------------------------------------------------------------------------
; _Ev_CredOnExec - adopt a set-id image's credentials at the exec commit.
;
; 4.3BSD-Reno kern/kern_exec.c:645-656, the block after the image is in place:
;
;       if ((p->p_flag&STRC)==0) {
;               if (uid != cred->cr_uid || gid != cred->cr_gid)
;                       u.u_cred = cred = crcopy(cred);
;               cred->cr_uid = uid;
;               cred->cr_gid = gid;
;               p->p_uid = uid;
;       } else
;               psignal(p, SIGTRAP);
;       p->p_svuid = p->p_uid;
;       p->p_svgid = cred->cr_gid;
;
; and 2.11BSD usr/sys/sys/kern_exec.c:604-613 is the same in its own idiom.
;
; THE EFFECTIVE IDS MOVE AND THE REAL ONES DO NOT, which is the whole of what
; makes su(1) work: `su' keeps running as the person who typed it -- getuid()
; still answers 100, so it still demands a password -- while being able to
; become root.  U_Ruid and U_Rgid are untouched here for that reason.
;
; THE SAVED SET IS REWRITTEN ON EVERY EXEC, set-id or not.  Upstream's two
; lines are outside the `if', and that is not an accident: the saved id is
; what a process may return to, so an image that did NOT gain privilege must
; not inherit a saved id from the one before it.  _Cred_Set (syscall.s) is the
; reader -- a non-root caller may set an id only to its real or its saved-set
; one -- so a stale saved id is a way back to a privilege this image never had.
;
; THE TRACED ARM IS ABSENT because there is no ptrace; upstream refuses the
; privilege and signals SIGTRAP instead, and this is the line that gets it.
;
; _curTask IS THE RIGHT TASK, including for a vfork child, which borrows its
; parent's pid -- _Sig_ResetOnExec beside the caller is indexed the same way
; and for the same reason.
;------------------------------------------------------------------------------
_Ev_CredOnExec  MX      %00
                PHP
                REP     #$30
                MX      %00
                JSR     _Uarea_Cur
                BCC     @coe_done               ; no u-area: kernel context
_kfp996         LDAL    KFAR_LD_SETUID
                CMP     #$FFFF
                BEQ     @coe_gid
                LDY     #U_Uid
                STA     [_u],Y
@coe_gid
_kfp997         LDAL    KFAR_LD_SETGID
                CMP     #$FFFF
                BEQ     @coe_saved
                LDY     #U_Gid
                STA     [_u],Y
@coe_saved      LDY     #U_Uid
                LDA     [_u],Y
                LDY     #U_Svuid
                STA     [_u],Y
                LDY     #U_Gid
                LDA     [_u],Y
                LDY     #U_Svgid
                STA     [_u],Y
@coe_done       PLP
                RTS

;------------------------------------------------------------------------------
_Ev_SeedStkFloor ENT
                MX      %00
                PHA
                PHX
                PHY
                JSR     Uimg_DPPtr                  ; _libcTmp2 -> the task's
                                                    ;   page, wherever it lives
                LDA:    TCB_StackBase,X
                CLC
                ADC     #FCC_STK_FLOOR_MARGIN
                LDY     #FCC_STKFLOOR_DP
                STA     [_libcTmp2],Y
                PLY
                PLX
                PLA
                RTS

; _Sys_Brk (#17) - fork train Stage S: the BSD break(2) surface over the
; task's own DATA bank.  BSD allocators (sh stak.c, csh/tcsh alloc11.c)
; are sbrk-based, and the data bank is what snapshot-fork can isolate,
; unlike the SHARED kernel-arena SYS_MALLOC heap, which fork deliberately
; does not cover.
;
; THE HEAP IS THE TAIL OF THE DATA BANK, not a bank of its own.  `end`
; (the data+bss tail) is the initial break and the heap grows the span
; [end, $FFFE); the 16-bit break cursor lives at data-bank $FFFE and the
; loader seeds it at spawn.  See the fuller note at the head of the
; handler body below, which is the authority on why.  Snapshot-fork's
; pair-0 copies the whole 64 KB data bank, so the heap travels with the
; image and needs no separate machinery.
;
; SE_SoftBank names the SOFT-FRAME bank (campaign 1.3), not a heap bank:
; every "sbrk bank" reading below is a slot whose contents are frames.
; Grown spans are ZERO-FILLED: classic BSD sbrk gives zero pages and the
; 2.11BSD allocators may rely on it.  One-bank ceiling: ENOMEM past
; $FFFF, fails closed (tcsh fit its whole data+stack in 64KB on the
; PDP-11).
;
; THE ARGUMENT IS AN ABSOLUTE BREAK, NOT AN INCREMENT, because that is the
; only form BSD's syscall has ever taken.  2.11BSD's sbrk(2) reads its
; argument as `struct a { char *nsiz; }' (usr/sys/sys/kern_mman.c:20-26) and
; 4.3BSD-Reno's obreak the same way (kern/kern_mman.c:316-321); the ADDITION
; lives in libc, which caches the break and hands the kernel the sum
; (`add curbrk,r0', pdp/sys/sbrk.s; `addl d0,sp@(4)', hp300/sys/sbrk.s).  A
; kernel that adds has to choose a signedness for the increment, and that
; choice caps a single grow at half the bank for no reason the machine
; requires -- see the note on the floor below for what upstream does instead.
;
; In:  A = the new break offset, Y.lo = the sbrk bank.
; Out: C=1 + A = OLD break offset + Y = the sbrk bank (libc composes the
;      far pointer from Y:A, malloc-style);
;      C=0 + A = ENOMEM below HEAP_BASE or past HEAP_LIM, EINVAL for a
;      bank that is not this task's (no BSD counterpart: upstream has no
;      banks, and it is a bad argument rather than a memory shortage).
; No blocking anywhere in this handler; the _sb_* statics are plain
; syscall-lifetime singletons.
;------------------------------------------------------------------------------
_Sys_Brk        ENT
                MX      %00
                STA     _sb_arg
                STY     _sb_bankArg
                ; BSD contiguous data+bss+heap (2026-07-23): the sbrk heap lives
                ; in the task's DATA bank, NOT a separate bank.  sh/tcsh's PDP-11
                ; blok.c arena round-trips every pointer through Rcheat/BLK
                ; (16-bit, re-composed against the data bank), so `end` (the
                ; data+bss tail) IS the initial program break and the heap grows
                ; from there -- exactly BSD.  We therefore read TCB_DataBank
                ; directly.  The slot once called SE_SbrkBank went unused
                ; from that point and now carries the SOFT-FRAME bank instead
                ; (campaign 1.3) -- so every "sbrk bank" below names a slot whose
                ; contents are frames, not heap, and the free/snapshot machinery
                ; those comments describe protects frames now.  Snapshot-fork's
                ; pair-0
                ; already copies the whole 64KB data bank (heap included).  The
                ; 16-bit break cursor lives at data-bank $FFFE (the last 2
                ; bytes); the loader seeds it to `end` at spawn; the heap grows
                ; the span [end, $FFFE).
                LDA     _curTask
                AND     #$00FF
                JSR     Task_Lookup                 ; C=1 + X = TCB offset
                SEP     #$20
                MX      %10
                LDA:    TCB_DataBank,X              ; the task's data bank (byte)
                STA     _libcTmp2+2                 ; cursor long-ptr bank
                REP     #$20
                MX      %00
                AND     #$00FF
                STA     _sb_bank                    ; 16-bit clean copy of the bank
                ; THE CEILING IS THE BANK'S OWN HEAP_LIM CELL, as 2.11BSD's is
                ; the next segment up: estabur refuses data that would run into
                ; the stack's pages, `if (ctos(ts) > 8 || ctos(nd)+ctos(ns) > 8)'
                ; (usr/sys/sys/kern_mman.c:98).  The loader seeds the cell to
                ; $FFF8, so an unreserved bank's heap runs to the descriptor; a
                ; lower cell reserves the region above it.  The soft-frame stack
                ; has a bank of its own (SE_SoftBank), so nothing else shares
                ; the data bank with the heap.
                STZ     _libcTmp2                   ; base = (data bank : $0000) -- heap
                                                    ; addressing; the break cursor is
                                                    ; reached at +$FFFE (last 2 bytes)
                LDY     #HEAP_LIM                   ; ceiling: the break may reach
                LDA     [_libcTmp2],Y               ;   the heap limit cell, not
                CMP     #HEAP_LIM+1                 ;   past it; a cell above its
                BCC     @sb_limOk                   ;   seed reads as the seed
                LDA     #HEAP_LIM
@sb_limOk       INC
                STA     _sb_sfp
                LDY     #$FFFE
                LDA     [_libcTmp2],Y               ; A = old break (loader-seeded to `end`)
                STA     _sb_old
                ; Y.lo must name THIS task's bank.  Upstream has no
                ; counterpart -- a PDP-11 break is one number -- but on the
                ; 65816 the bank is half the address and a caller that gets it
                ; wrong is naming another task's memory.
                LDA     _sb_bankArg
                AND     #$00FF
                STA     _sb_new                     ; borrow as scratch
                SEP     #$20
                MX      %10
                LDA     _sb_bank
                CMP     _sb_new
                REP     #$20
                MX      %00
                BEQ     @sb_bankOk
                BRL     @sb_einval                  ; out of BNE range: the
                                                    ; checks below grew
@sb_bankOk      ; THE FLOOR IS HEAP_BASE, WHICH IS `end', AND UPSTREAM'S IS THE
                ; SAME PLACE.  2.11BSD computes the new data size relative to
                ; the segment base and clamps it there -- `n = btoc((int)nsiz)
                ; ... if (n < 0) n = 0' (kern_mman.c:26-33) -- and Reno does
                ; the identical thing against dptov(p,0) (kern_mman.c:329-331),
                ; so neither can be driven below the base however the argument
                ; was computed.  libc keeps the same bound as `minbrk: _end'
                ; and brk(2) clamps to it before the call (pdp/sys/brk.s,
                ; hp300/sys/brk.s).
                ;
                ; This REFUSES where upstream clamps, and the difference is
                ; diagnosis rather than policy: libc's brk already guarantees
                ; the argument is at or above minbrk, so the clamp is
                ; unreachable through the documented path.  It fires only for a
                ; break computed wrong, which upstream treats as a caller
                ; defect -- 2.11BSD update #58 is that bug ("a negative
                ; increment to sbrk() was being calculated when the text size
                ; was greater than 32kb.  This released part of the program's
                ; .bss segment back to the system"), and the fix was to make
                ; the caller's arithmetic unsigned, not to change sbrk.  A
                ; clamp turns that into a silently emptied heap; ENOMEM turns
                ; it into a return value the caller already tests.
                LDA     _sb_arg
                STA     _sb_new
                LDY     #HEAP_BASE
                CMP     [_libcTmp2],Y
                BCC     @sb_enomem                  ; below `end'
                CMP     _sb_sfp
                BCS     @sb_enomem                  ; at or past the cursor cell
                ; RLIMIT_DATA, WHICH IS THE BREAK PATH'S CHECK IN BOTH TREES.
                ; Reno refuses `if (ctob(ds + d) > u.u_rlimit[RLIMIT_DATA]
                ; .rlim_cur)' (kern/kern_mman.c:342-343) and 2.11BSD acquired
                ; the same test in update #439.  `ds + d' is the data segment's
                ; new size, and on FGX the break offset IS that size: the data
                ; segment starts at offset 0 of the bank and the heap is its
                ; tail, so _sb_new compares directly.
                ;
                ; The limit is a SIGNED 32-bit byte count defaulting to
                ; RLIM_INFINITY ($7FFFFFFF) at Task_AllocUarea, so a high word
                ; that is not zero already exceeds anything a 16-bit break can
                ; reach and costs one branch.  An unset limit therefore costs
                ; the u-area lookup and nothing else.
                ;
                ; A refusal here joins the ceiling's on the ring line below:
                ; the heap IS full as far as this process is permitted, and the
                ; address it prints is the break that was refused either way.
                JSR     _Uarea_Cur
                BCC     @sb_rlimOk                  ; boot context: no u-area
                LDY     #U_Rlimit+{U_RLIMIT_DATA*U_RLIM_ENTLEN}+2
                LDA     [_u],Y                      ; rlim_cur high word
                BNE     @sb_rlimOk                  ; >= 65536: unreachable
                LDY     #U_Rlimit+{U_RLIMIT_DATA*U_RLIM_ENTLEN}
                LDA     [_u],Y                      ; rlim_cur low word
                CMP     _sb_new
                BCC     @sb_enomem                  ; limit < the new data size
@sb_rlimOk      LDA     _sb_new
                CMP     _sb_old
                BCC     @sb_store                   ; shrink: no zeroing
                BRA     @sb_zeroSpan
@sb_enomem
                LDA     #ENOMEM
                CLC
                RTS
@sb_zeroSpan    ; Clear the grown span [old, new), as 2.11BSD's sbrk does:
                ;
                ;     d = n - u.u_dsize;
                ;     if (d > 0)
                ;             clear(u.u_procp->p_daddr + u.u_dsize, d);
                ;
                ; (vendor/2.11BSD/usr/sys/sys/kern_mman.c:36-38).  That is safe
                ; only while nothing live sits above the break.  Upstream's sh
                ; keeps that true through the MEMF write fault (sh/fault.c:29);
                ; FGX has no write fault, so every sh stak and blok writer grows
                ; the break before it writes (vendor sh stak.c stakneed, word.c,
                ; blok.c).
                ;
                ; One zero byte, then a block move of the span onto itself one
                ; byte up: MVN copies ascending, so the zero propagates at 7
                ; cycles a byte.
                LDA     _sb_new
                SEC
                SBC     _sb_old
                BEQ     @sb_store                   ; nothing grown
                DEC
                STA     _fcr_len                    ; the rest after byte one
                LDY     _sb_old
                SEP     #$20
                MX      %10
                LDA     #0
                STA     [_libcTmp2],Y               ; byte one
                LDA     _sb_bank
                STA     _fcr_src+2
                STA     _fcr_dst+2
                REP     #$20
                MX      %00
                TYA
                STA     _fcr_src
                INC
                STA     _fcr_dst
                JSR     _Fork_CopyRange             ; len 0 moves nothing
@sb_store       LDY     #HEAP_BRK
                LDA     _sb_new
                STA     [_libcTmp2],Y               ; cursor @ dataBank:$FFFE = new break
                ; HIGH-WATER MARK (apple/fgx#42).  The break alone answers "how
                ; much is in use NOW", which is the wrong question for a process
                ; that peaks during startup and frees: tcsh's login path reads as
                ; idle afterwards.  Same current-vs-peak trap the bank-0 stack
                ; campaign hit, solved the same way -- record the maximum, never
                ; lower it.  Costs one compare per GROW; a shrink is skipped.
                LDY     #HEAP_HWM
                LDA     [_libcTmp2],Y
                CMP     _sb_new
                BCS     @sb_hwmDone                 ; hwm >= new: nothing to do
                LDA     _sb_new
                STA     [_libcTmp2],Y
@sb_hwmDone     LDA     _sb_bank
                AND     #$00FF
                TAY                                 ; Y-return = the bank
                LDA     _sb_old                     ; A-return = OLD break
                SEC
                RTS
@sb_einval      LDA     #EINVAL
                CLC
                RTS

;------------------------------------------------------------------------------
; _Sys_ExecveVfork - THE execve implementation (#14: there is no longer a
; second one).  Load the new program into FRESH banks, rebind the TCB to the
; new image, hand any borrowed parent image back (clear SEF_VFORKCHILD, wake
; WCHAN_VFORK), and enter the new image via
; _Task_FirstRun.
;
; TWO CALLERS, ONE PATH.  The difference is OWNERSHIP of the outgoing image,
; not the mechanism:
;
;   fork child (SEF_VFORKCHILD/SEF_SNAPCHILD) -- BORROWS the parent's banks,
;     DP page and user stack.  Reads them, never frees or writes them.
;
;   plain exec (`exec cmd`; flags clear) -- OWNS them.  So on the commit, and
;     only there, the outgoing banks and user stack are freed and the DP page
;     is re-zeroed.  Everything before the commit stays non-destructive so a
;     failed exec can hand the caller back intact.
;
; That last clause is the whole BSD contract and it is load-bearing.  execve(2)
; keeps the same pid/ppid/pgrp (this is the same task throughout -- no internal
; fork), open fds survive (the fd table is untouched), caught signals revert to
; SIG_DFL at the commit, and a FAILURE returns C=0 + errno with the caller
; still running.  On any failure the TCB is restored field-for-field.
;
; #14 history: this used to be the vfork-only arm, and non-fork callers went to
; a "replace in your own bank" arm in syscall.s that called Load_Binary with
; A=0 ("honor the header's bank").  That is an FGX1-era concept -- _LoadFGX2,
; which FGX3 shares, REQUIRES a caller-supplied override bank and returns
; EINVAL without one.  Every binary this OS builds is FGX2/FGX3, so that arm
; was reached and could not load ANYTHING: `exec cmd` was broken disk-wide.
; (The issue said EBADF; that was a misreported errno -- _LoadFGX2 stashed its
; errno in _shTmp0 and then called Fs_Close, which uses _shTmp0 as scratch.)
;
; Claim order mirrors spawn (bank -> pre-load TCB bind -> DP -> load ->
; stack -> stage-args -> commit).  Load_Binary's FS reads may block, but
; every _ev_* save static is written before the first block and only
; consumed on this task's own failure paths, and the pre-load TCB binds are
; restored on failure -- same singleton discipline spawn itself uses.
;
; In:  A = path offset (caller = the borrowed parent bank);
;      _ps_argBlk/_ps_argBlkBank staged by _Sys_Execve.  MX %00, DBR=kernel.
; Out: success: never returns (JMP _Task_FirstRun into the new image).
;      failure: C=0 + A=errno, child still in the borrowed image.
;------------------------------------------------------------------------------
_Sys_ExecveVfork ENT
                MX      %00
                JSR     _Sys_CopyPathToBuf      ; A = path -> _Sys_PathBuf
                BCC     @evf_plok
                LDA     #ENAMETOOLONG           ; apple/fgx#436
                CLC
                RTS
@evf_plok       LDA     _curTask
                JSR     Task_Lookup
                BCS     @evf_haveTCB
                LDA     #ESRCH
                CLC
                RTS
@evf_haveTCB    STX     _ps_childTCB            ; loader + StageArgs key on this
                ; Do we OWN the outgoing image or are we borrowing it?  Read the
                ; fork-child bits ONCE, here, because the commit CLEARS them
                ; before the last place that needs to know.  seoff=(TCB-TBL)>>1.
                LDA     _ps_childTCB
                SEC
                SBC     #FGX_TASK_TBL_OFF
                LSR
                CLC
                ADC     #SE_Flags
                TAY
                LDA     [_schedTblPtr],Y
                AND     #SEF_VFORKCHILD+SEF_SNAPCHILD
                STA     _ev_isChild             ; 0 = plain exec = we own it
                ; Save every field the exec path overwrites.
                LDA:    TCB_DirectPage,X
                STA     _ev_oldDP
                LDA:    TCB_StackBank,X
                STA     _ev_oldStkBank
                LDA:    TCB_StackPtr,X
                STA     _ev_oldStkPtr
                LDA:    TCB_StackBase,X
                STA     _ev_oldStkBase
                LDA:    TCB_StackSize,X
                STA     _ev_oldStkSize
                LDA:    TCB_CodeBank,X
                STA     _ev_oldCode
                LDA:    TCB_DataBank,X          ; + TCB_Reserved1 (byte pair)
                STA     _ev_oldData
                LDA:    TCB_EntryPoint,X
                STA     _ev_oldEntry
                LDA:    TCB_SavedS,X
                STA     _ev_oldSavedS
                ; The whole owned-bank set, not just Code/Data: TCB_DataBank can
                ; be one of the EXTRAS (StageArgs persists the real data bank),
                ; so BankList is the only authoritative list.  A fork child's is
                ; all zeros (it owns nothing), which is why the rollback below
                ; can restore this unconditionally.  Four word reads; +6 covers
                ; bytes 6-7 and stops at the end of the 8-byte array.
                LDA:    TCB_BankList+0,X
                STA     _ev_oldBankList+0
                LDA:    TCB_BankList+2,X
                STA     _ev_oldBankList+2
                LDA:    TCB_BankList+4,X
                STA     _ev_oldBankList+4
                LDA:    TCB_BankList+6,X
                STA     _ev_oldBankList+6

                ; 1. Fresh first bank + spawn-style pre-load TCB bind (the
                ; loader's reloc path and StageArgs read CodeBank/BankList).
                JSR     Bank_Alloc
                BCS     @evf_haveBank
                CLC                             ; A = ENOMEM, nothing claimed
                RTS
@evf_haveBank   LDX     _ps_childTCB
                SEP     #$20
                MX      %10
                STA:    TCB_CodeBank,X
                STA:    TCB_DataBank,X
                STA:    TCB_BankList+0,X
                STA     _ps_childBank
                REP     #$20
                MX      %00

                ; 2. (The new image's direct page comes with its stack at step
                ; 5, the first page of the reservation, zeroed there.  The
                ; page this task runs on now -- the borrowed one, or a plain
                ; exec's own -- stays the live one until the commit, so a
                ; failed exec hands the caller back with its DP scratch intact:
                ; fcc keeps its frame pointer, soft-frame pointer and stack
                ; floor there.)
                ; 3. Load the new image (FS reads; may block).
                LDA     _ps_childBank
                AND     #$00FF
                LDX     #_Sys_PathBuf
_kfp947         JSL     KFAR_LOAD_BINARY
                BCS     @evf_loaded
                STA     _ps_savedErr
                BRL     @evf_rollDP
@evf_loaded
                ; 4. The image's banks -> the TCB (spawn's _Ld_Bind, so the
                ; failure sweeps and the exit walk see them uniformly).  The
                ; text it runs is recorded at the commit, when the old one goes.
                LDX     _ps_childTCB
                JSR     _Ld_Bind
                SEP     #$20
                MX      %10
_kfp1015        LDAL    KFAR_LD_TEXT
                STA     _ev_newText             ; the commit's, or the roll-down's
                REP     #$20
                MX      %00

                ; 5. New user stack from the header hint + argv frame pages
                ; (spawn's #45 block, verbatim).  An owned outgoing stack is
                ; measured FIRST: the new range may be carved over it, and once
                ; it is the old region's bytes are the new image's
                ; (Task_StkHwm).
                LDA     _ev_isChild
                BNE     @evf_noOldHwm           ; borrowed: not ours to report
                LDX     _ps_childTCB
                JSR     _Tas_ReportHwm          ; preserves X; clobbers A/Y
@evf_noOldHwm   LDX     _ps_argBlk
                LDY     _ps_argBlkBank
_kfp955         JSL     KFAR_LOADER_ARGPAGES        ; A = ceil(T/256)
                PHA
                SEP     #$20
                MX      %10
_kfp956         LDAL    KFAR_LD_HEADER+FGX1_OFF_STACK
                REP     #$20
                MX      %00
                AND     #$00FF
                BNE     @evf_haveHint
                LDA     #1
@evf_haveHint   CLC
                ADC     1,S
                PLY                                 ; discard pushed word
                LDX     _ps_childTCB
                JSR     Task_AllocStack
                BCS     @evf_stackOK
                STA     _ps_savedErr
                BRL     @evf_rollBanks
@evf_stackOK
                ; P3-3 3.2b: seed the stack floor into the NEW range's direct
                ; page.  The page came with the range, so a plain exec's live
                ; page is untouched, and a failed exec hands the caller back
                ; guarding the region it runs on.
                LDX     _ps_childTCB
                JSR     _Ev_SeedStkFloor

                ; 6. Entry point + staged argv/envp frame (persists the real
                ; data bank into TCB_DataBank inside StageArgs).
                LDX     _ps_childTCB
_kfp957         LDAL    KFAR_LD_ENTRY
                STA:    TCB_EntryPoint,X
                LDX     _ps_childTCB
                JSR     Task_StkLock            ; B3: the parent is about to write
                                                ; the CHILD's stack (survey case 1)
                LDX     _ps_argBlk
                LDY     _ps_argBlkBank
_kfp958         JSL     KFAR_LOADER_STAGEARGS
                LDX     _ps_childTCB
                JSR     Task_StkUnlock
                BCS     @evf_argsOK
                STA     _ps_savedErr
                ; free the new stack too, then the shared roll-down
                LDX     _ps_childTCB
                JSR     Task_FreeStack
                BRL     @evf_rollBanks
@evf_argsOK     LDX     _ps_childTCB
                STA:    TCB_SavedS,X

                ; 7. COMMIT -- no failure paths beyond this point.
                ; POSIX exec: caught signals revert to SIG_DFL (SIG_IGN stays).
                ; A vfork child borrows the parent's PID, and the handler tables
                ; are indexed by it, so WITHOUT this the exec'd image inherits
                ; the SHELL's handlers -- which is what made ^C kill no tcsh
                ; foreground job.  Placed after the commit so a FAILED exec
                ; leaves dispositions untouched.
                JSR     _Sig_ResetOnExec
                ; POSIX exec: a set-id image runs as the file's owner, and the
                ; SAVED set follows the effective ids either way.  Beside
                ; _Sig_ResetOnExec because it is the same kind of thing and
                ; wants the same placement -- past the last failure path, so a
                ; failed exec leaves the caller as privileged as it was.
                JSR     _Ev_CredOnExec
                ; POSIX exec: close-on-exec descriptors are closed (Reno
                ; kern_exec.c:282), past the last failure path with the two
                ; above.  The loader may have blocked, and _fd_table_ptr is
                ; only set at syscall entry, so it is re-derived first -- the
                ; hazard _Sys_CloseAllFds records.
                JSR     _Fd_TableOfCur
                JSR     _Fd_CloseOnExec
                ; ld.mod: the old image's library uses go (shared libc SP4);
                ; the new image's binder acquires its own.
                LDA     _curTask
_ktp109         JSL     KTTY_LD_EXEC
                ; Process name = the exec'd path (was empty for the vfork
                ; window).
                LDX     #_Sys_PathBuf
                LDA     _curTask
                AND     #$00FF
                JSR     Task_SetName
                ; A snapshot child leaves its image group here.  The soft-frame
                ; bank it carries is its parent's, so it is zeroed before the
                ; free below; its bank home goes, and the last member left gets
                ; its banks back (_Img_Leave).  The new image is already in
                ; fresh banks, so the old live ones are free to be restored.
                LDA     _ps_childTCB
                SEC
                SBC     #FGX_TASK_TBL_OFF
                LSR
                CLC
                ADC     #SE_Flags
                TAY
                LDA     [_schedTblPtr],Y
                BIT     #SEF_SNAPCHILD
                BEQ     @evf_noRestore
                TYA
                CLC
                ADC     #SE_SoftBank-SE_Flags
                TAY
                SEP     #$20
                MX      %10
                LDA     #0
                STA     [_schedTblPtr],Y
                REP     #$20
                MX      %00
                LDX     _ps_childTCB
                LDA     _ev_oldData
                JSR     _Img_Leave
                ; ...and the image-cache home fork gave it for its parent's
                ; range, unless the carve just re-homed it for the new one.
                LDX     _ps_childTCB
                LDA:    TCB_TaskID,X
                AND     #$00FF
                DEC
                ASL
                TAY
                LDA     _ev_oldStkBase
                SEC
                SBC     #256
                CMP    |_uiHomeBase,Y
                BNE     @evf_softFree
                LDA:    TCB_TaskID,X
                JSR     Uimg_HomeFree
                BRA     @evf_softFree
@evf_noRestore
                ; An owner exec'ing out of its image group hands the memory on
                ; before the reclaim below could free it, and leaves the group.
                ; A vfork child is in no group: its parent is suspended.
                LDA     _ev_isChild
                BNE     @evf_softFree
                LDA     #1
                STA     _ho_exec
                LDX     _ps_childTCB
                LDA     _ev_oldData
                JSR     Img_HandOff
                LDX     _ps_childTCB
                LDA     _ev_oldData
                JSR     _Img_Leave
@evf_softFree   ; Fresh image = fresh soft-frame bank: free the one the task
                ; held pre-exec.  (The comment here used to say "fresh break";
                ; the slot stopped meaning the sbrk heap when the heap moved to
                ; the contiguous BSD `end` layout, and now means frames.)
                ; Was an inline copy of _Loader_FreeSoftBank; #14 deleted the
                ; only OTHER caller of that helper, which would have left it
                ; dead beside its own duplicate.  One implementation instead.
                JSR     _Loader_FreeSoftBank
                ; ---- #14: a PLAIN exec owns the outgoing image.  Reclaim it.
                ; Skipped entirely for a fork child, which borrows.
                ;
                ; This is the only destructive block in the routine and it sits
                ; past the last failure path on purpose.  Every free must
                ; precede the JMP _Task_FirstRun that ends the routine.  The
                ; new range's direct page was zeroed at its carve, before
                ; _Loader_SeedSoftBank below writes FCC_SFP_DP into it -- which
                ; is what kills the stale-_fcc_sfp bug the old in-place arm
                ; had, where crt0's "already seeded" test saw a mid-recursion
                ; pointer left by the DEAD image and carried on with it.
                ; The old image's text loses this pid's reference (xfree) and
                ; the new one is recorded -- a fork child's too: it counted
                ; its parent's at the fork.
                LDX     _ps_childTCB
                LDA:    TCB_TaskID,X
                LDX     _ev_newText
_ktp122         JSL     KTTY_TEXT_SET
                LDA     _ev_isChild
                BNE     @evf_ownDone
                ; The outgoing image's banks.  Freeing from the SAVED list, not
                ; the TCB: the TCB names the NEW image by now.
                LDX     #0
@evf_ofLoop     SEP     #$20
                MX      %10
                LDA     _ev_oldBankList,X
                BEQ     @evf_ofNext
                REP     #$20
                MX      %00
                AND     #$00FF
                PHX
                JSR     Bank_Free
                PLX
                SEP     #$20
                MX      %10
@evf_ofNext     REP     #$20
                MX      %00
                INX
                CPX     #8
                BCC     @evf_ofLoop
                ; The outgoing user stack.  Task_FreeStack frees whatever the
                ; TCB names, so hand it the OLD base/size and put the new ones
                ; back after -- cheaper than a second by-value entry point, and
                ; it keeps the arena-bounds check and the high-water-mark report
                ; in one audited place.  Safe to run here: we are on the per-pid
                ; KERNEL stack (FGX_STK_KTASKS, a different fixed region from
                ; FGX_STK_ARENA), never the user stack we are freeing.  init's
                ; static $3100 page is below the arena and no-ops out.
                LDX     _ps_childTCB
                LDA:    TCB_StackBase,X
                PHA
                LDA:    TCB_StackSize,X
                PHA
                LDA     _ev_oldStkBase
                STA:    TCB_StackBase,X
                LDA     _ev_oldStkSize
                STA:    TCB_StackSize,X
                JSR     Task_FreeStack
                LDX     _ps_childTCB
                PLA
                STA:    TCB_StackSize,X
                PLA
                STA:    TCB_StackBase,X
@evf_ownDone
                ; Bank-0 campaign 1.3: the fresh image gets a fresh soft-frame
                ; bank.  AFTER the free above, not before -- that free reclaims
                ; whatever SE_SoftBank holds, so granting first would hand the
                ; new bank straight back.  Same helper as spawn: execve's stack
                ; block is already a verbatim copy of spawn's, and a third copy
                ; of this is how the two would drift.
                JSR     _Loader_SeedSoftBank
                ; #11: same for any dedicated big block the child allocated
                ; pre-exec.  Keyed on the CHILD's pid, so a snapchild's inherited
                ; (parent-owned) blocks are left alone.
                LDX     _ps_childTCB
                LDA:    TCB_TaskID,X
                AND     #$00FF
                BEQ     @evf_bigDone
                JSR     _BlkRow_FreeByOwner
@evf_bigDone
                ; Hand-back: clear the fork-child flag (the parent's wake
                ; predicate), then wake WCHAN_VFORK.  seoff=(TCB-TBL)>>1.
                LDA     _ps_childTCB
                SEC
                SBC     #FGX_TASK_TBL_OFF
                LSR
                CLC
                ADC     #SE_Flags
                TAY
                LDA     [_schedTblPtr],Y
                AND     #$FF67                      ; the fork-child bits and FORKREL
                STA     [_schedTblPtr],Y
                ; B3: a vfork child's borrow window ends HERE -- from this point
                ; the task runs on a stack of its own, so clear SEF_STKBORROW on
                ; the parent whose bytes it had been using.
                ;
                ; GATED ON SEF_VFORKCHILD because this block is also reached by
                ; a PLAIN exec, which borrowed nothing, and by a snapshot child,
                ; whose parent is parked in its home rather than borrowed --
                ; Task_BorrowClr reports an unmatched clear.
                LDA     _ev_isChild
                AND     #SEF_VFORKCHILD         ; a snapshot parent is parked,
                BEQ     @evf_noBorrow           ;   not borrowed
                LDX     _ps_childTCB
                LDA:    TCB_ParentID,X
                AND     #$00FF
                BEQ     @evf_noBorrow               ; pid 0: no parent to clear
                JSR     Task_Lookup                 ; A=pid -> X=TCB offset, C=1
                BCC     @evf_noBorrow               ; parent already reaped
                JSR     Task_BorrowClr
@evf_noBorrow
                LDA     #WCHAN_VFORK
                JSR     _wakeup
                ; Enter the new image.  _Task_FirstRun re-derives DP/S from
                ; the TCB (SavedS = the staged frame) and PLB+RTLs into the
                ; entry; the dispatcher frame on the borrowed stack is
                ; abandoned, exactly like the legacy execve arm.  The
                ; sched-entry carryover goes stale-garbage like any fresh
                ; spawn's -- the child's next syscall entry rewrites it.
                ; (Signal HANDLER resets on exec are deferred: a vfork child
                ; registers no handlers pre-exec; revisit at Stage F.)
                ; EXEC DOES NOT GO THROUGH swtch, and a task is restored to
                ; its addresses only by the SCHEDULER, so hand off to it rather
                ; than switching stacks here.
                ;
                ; Switching inline cannot be made correct.  A fork child is
                ; executing on the parent's BORROWED stack, so loading an image
                ; over the range it stands on would overwrite the stack under
                ; the call.  The transition is only safe while this task is OFF
                ; CPU, and only the scheduler can arrange that.  (An earlier cut
                ; acquired here and yielded on refusal; that also parked a live
                ; continuation on the borrowed stack after the parent had already
                ; been woken and unpinned, so the parent's own frames grew down
                ; into it.)
                ;
                ; So: re-prime our kernel stack to resume at _Task_FirstRun,
                ; exactly as a fresh spawn does, mark ourselves READY, and enter
                ; the scheduler abandoning this frame.  The new image's range
                ; is resident from its carve (Task_AllocStack parked whatever
                ; it landed on), pick_next's Uimg_CanRun refuses a task whose
                ; addresses cannot be had, and @sw_pick's Uimg_Ensure restores
                ; -- so restoring keeps exactly ONE writer.
                ;
                ; Priming is safe from here: it writes the TOP of our per-pid
                ; kernel stack page, and we are deeper in it, so our own return
                ; address survives the call.
                LDX     _ps_childTCB
                JSR     Task_PrimeKernStack     ; resume at _Task_FirstRun
                LDX     _ps_childTCB
                LDA     #TASK_READY
                STA:    TCB_Status,X
                SEI
                JMP     swtch_nosave            ; never returns here

                ; ---- failure roll-downs (deepest first) ----
@evf_rollBanks  ; free extras and the text reference the load took
                LDA     _ev_newText             ; the reference the load took
_ktp123         JSL     KTTY_TEXT_UNREF
                ; The image's own banks, segment-indexed; the override is
                ; among them, and @evf_rollBank frees it.
                LDX     #0
@evf_rbLoop     SEP     #$20
                MX      %10
_kfp961         LDAL    KFAR_LD_EXTRABANKS,X
                BEQ     @evf_rbNext
                CMP     _ps_childBank
                BEQ     @evf_rbNext
                REP     #$20
                MX      %00
                AND     #$00FF
                PHX
                JSR     Bank_Free
                PLX
                SEP     #$20
                MX      %10
@evf_rbNext     REP     #$20
                MX      %00
                INX
                CPX     #8
                BCC     @evf_rbLoop
                ; BankList is restored (not zeroed) by @evf_rollBank
                ; below, which every roll-down reaches.
                ; fall through
@evf_rollDP     ; (the new direct page went with the new stack, above)
                ; fall through
@evf_rollBank   LDA     _ps_childBank
                AND     #$00FF
                JSR     Bank_Free
                ; Restore every field we overwrote.  BankList goes back to what
                ; the caller had -- all zeros for a fork child (owns nothing, so
                ; this is the old "zero it" behavior verbatim), but the real
                ; owned set for a plain exec, which would otherwise be handed
                ; back unable to free its own banks at exit.
                LDX     _ps_childTCB
                LDA     _ev_oldBankList+0
                STA:    TCB_BankList+0,X
                LDA     _ev_oldBankList+2
                STA:    TCB_BankList+2,X
                LDA     _ev_oldBankList+4
                STA:    TCB_BankList+4,X
                LDA     _ev_oldBankList+6
                STA:    TCB_BankList+6,X
                LDA     _ev_oldDP
                STA:    TCB_DirectPage,X
                LDA     _ev_oldStkBank
                STA:    TCB_StackBank,X
                LDA     _ev_oldStkPtr
                STA:    TCB_StackPtr,X
                LDA     _ev_oldStkBase
                STA:    TCB_StackBase,X
                LDA     _ev_oldStkSize
                STA:    TCB_StackSize,X
                LDA     _ev_oldCode
                STA:    TCB_CodeBank,X
                LDA     _ev_oldData
                STA:    TCB_DataBank,X              ; + Reserved1 byte pair
                LDA     _ev_oldEntry
                STA:    TCB_EntryPoint,X
                LDA     _ev_oldSavedS
                STA:    TCB_SavedS,X
                ; The range this task stands on again is resident, whatever
                ; the carve being undone said about its own.
                LDA:    TCB_TaskID,X
                AND     #$00FF
                JSR     Uimg_SetResident        ; preserves X
                LDA     _ps_savedErr
                CLC
                RTS

;------------------------------------------------------------------------------
; _Sys_Exit (#1) - terminate the current task; resume the parent.
;
; A = exit status (low byte).  Encodes BSD wait format (status<<8) and
; stores in TCB.ExitCode.  Marks the task ZOMBIE.  Frees the task's bank
; (TCB and DP/stack pages stay until the parent's wait reaps them).
;
; If the task's parent is PID 0 (no parent — only init satisfies this in
; v1), we JML to _Kern_Halt instead of trying to switch back.
;------------------------------------------------------------------------------
_Sys_Exit       ENT
                MX      %00
                AND     #$00FF
                ; A task killed by fcc's prologue stack guard exits with this
                ; distinct status and says NOTHING itself.  Report it here.
                ;
                ; It cannot report itself: the guard is _fcc_stkoflow in
                ; fcc_runtime.s, which is duplicated into EVERY code segment, so
                ; a per-binary message costs tcsh nine copies -- measured, it
                ; pushed tcsh straight past its 7-bank cap.  One copy in the
                ; kernel covers every binary for ~40 bytes.
                ;
                ; Silence is not a cosmetic problem here.  Issue #9 presented as
                ; "a sourced shell script just stops after 17 commands" and took
                ; two sessions and a great many emulator boots to identify as a
                ; stack overflow at all, because a guard-killed process is
                ; indistinguishable from a process that exited on purpose.
                ; dmesg now answers it in one line.
                ; Two statuses land here: 134 (bank-0 hardware stack, from
                ; fcc's prologue guard or the dispatcher floor check) and 135
                ; (the data-bank SOFT frame stack, campaign 1.3).  They were
                ; ONE status until 2026-08-02, which made a soft-frame overflow
                ; read exactly like a hardware one in dmesg -- and bsh dying at
                ; 7 sourced commands could not be attributed to either.
                CMP     #TASK_EXIT_STKOFLOW
                BEQ     @sx_isOflow
                CMP     #TASK_EXIT_SFOFLOW
                BEQ     @sx_isOflow
                CMP     #TASK_EXIT_HEAPFULL
                BEQ     @sx_isOflow
                BRL     @sx_noOflow                 ; BRL: the cursor report below
                                                    ; puts @sx_noOflow out of BNE reach
@sx_isOflow     PHA
                ; 136 is not a stack overflow at all -- it is the heap
                ; running out under a port that cannot be told so.  Same exit
                ; path, different noun, because "stack overflow" for a heap
                ; failure is exactly the misdirection this block exists to stop.
                PLA
                PHA
                CMP     #TASK_EXIT_HEAPFULL
                BNE     @sx_stkNoun
                LDA     #_K_HeapFullMsg
                BRA     @sx_noun
@sx_stkNoun     LDA     #_K_StkOflowMsg
@sx_noun        STA     _conStrPtr
                JSR     Kern_LogStrNoEOL
                PLA
                PHA
                CMP     #TASK_EXIT_HEAPFULL
                BEQ     @sx_oflowPid
                ; Say WHICH guard fired.  Two detectors reach this status: fcc's
                ; prologue guard (the common case) and the dispatcher's user-SP
                ; floor check (0.2), which catches mutual recursion through
                ; small frames that the prologue guard never arms on.  Same exit
                ; status deliberately -- to a program it is one condition -- but
                ; a single word here is the difference between "which detector
                ; do I go read" and guessing.
                PLA                             ; peek the status back
                PHA
                CMP     #TASK_EXIT_SFOFLOW
                BNE     @sx_notSoft
                LDA     #_K_StkOflowSoft
                STA     _conStrPtr
                JSR     Kern_LogStrNoEOL
                ; Say WHERE it ran out.  The soft stack has its own bank now,
                ; so there is no second cursor to blame -- just the depth the
                ; frame pointer reached before it hit FCC_SOFT_BOTTOM.
                LDA     _curTask
                AND     #$00FF
                JSR     Task_Lookup
                BCC     @sx_oflowPid                ; no TCB: say nothing more
                LDA     #_K_StkOflowSfp
                STA     _conStrPtr
                PHX
                JSR     Kern_LogStrNoEOL
                PLX
                LDA:    TCB_DirectPage,X
                CLC
                ADC     #$00BD                      ; _fcc_sfp (fcc_runtime.s DP map)
                TAX
                LDAL    $000000,X                   ; DP lives in bank 0
                JSR     Kern_LogHex16
                BRA     @sx_oflowPid
@sx_notSoft     LDA    |_kStkSysOflow
                BEQ     @sx_oflowPid
                LDA     #0
                STA    |_kStkSysOflow          ; one-shot; the task is dying
                LDA     #_K_StkOflowSys
                STA     _conStrPtr
                JSR     Kern_LogStrNoEOL
@sx_oflowPid    LDA     #_K_StkOflowPid
                STA     _conStrPtr
                JSR     Kern_LogStrNoEOL
                LDA     _curTask
                AND     #$00FF
                JSR     Kern_LogHex8
                JSR     Kern_LogEOL
                PLA
@sx_noOflow     ; Encode status into TCB.ExitCode (status<<8).
                XBA                                 ; A.hi = status, .lo = 0
                AND     #$FF00
                STA     _ex_encStatus

_Exit_Core      ENT
                ; Shared termination tail.  Entry: MX %00, _ex_encStatus already
                ; holds the BSD-encoded wait status, _curTask = the dying task.
                ; Reached two ways: (1) _Sys_Exit (above) with status<<8
                ; (WIFEXITED); (2) _Sys_CheckSignal's SA_TERM default action with
                ; the signum in the low byte (WIFSIGNALED).  Never returns —
                ; zombifies, frees banks, wakes the parent, and swtch's away.
                ;
                ; If the dying task owns the DOC (SYS_SOUND_CLAIM), silence it now.
                ; Only TERMINATION reaches here, so a player's audio stops on kill/
                ; exit but keeps playing when backgrounded or ^Z-stopped (neither
                ; reaches _Exit_Core).  _curTask = the dying pid = _docOwner's value.
                LDA     _docOwner
                BEQ     @psx_noDoc
                CMP     _curTask
                BNE     @psx_noDoc
_kfp013         JSL     KFAR_SOUND_STOPDOC      ; far bank; bank byte patched by Far_Init
                STZ     _docOwner
@psx_noDoc
                ; If the dying task owns the SCREEN (SYS_SCREEN_CTL), restore the
                ; console so a killed gfx tool doesn't leave it suspended.
                LDA     _screenOwner
                BEQ     @psx_noScr
                CMP     _curTask
                BNE     @psx_noScr
                STZ     _screenOwner
                STZ     _gfxScanArmed           ; stop the 3200 scanline engine
                SEP     #$20
                LDA     #0
_kfp350         STAL    KFAR_VT_STATE+VT_RENDER_STATE
                STAL    $E0C023                 ; VGC scanline int off (no storm)
                STAL    $E0C032                 ; clear pending
                REP     #$20
_kfp107         JSL     KFAR_CON_INITSCBS       ; SCBs back to 640 template
_kfp108         JSL     KFAR_CON_INSTALLPALETTES ; restore console palettes
_kfp109         JSL     KFAR_CON_RENDERALL      ; repaint text
@psx_noScr
                ;
                ; Close every fd this task held.  Without this, any FCB the
                ; task opened (e.g.
                ; redirection target in slice-4 sh) would leak its FCB heap
                ; allocation when Task_FreeFdTable kfrees the *table* only.
                JSR     _Sys_CloseAllFds

                ; ...and give the cwd VNODE back, which is the same release one
                ; object along.  4.3BSD-Reno kern_exit.c:139, `VOP_LOCK(u.u_cdir)
                ; / vput(u.u_cdir)', which upstream puts a few lines below the
                ; open files for the same reason it is a few lines below them
                ; here: both are references this process took and nobody else
                ; will drop.  Without it a shell that ran `cd' pins that
                ; directory's inode for the life of the boot.
                LDA     _curTask
                AND     #$00FF
                PHA
_kfp966         JSL     KFAR_VFS_CDIREXIT       ; slot 50; returns void
                PLA                             ; the caller pops its argument
                ; ld.mod: release this process's library uses, and abort a
                ; library load it owns (shared libc SP4) -- beside the other
                ; references it took, before its banks go back.
                LDA     _curTask
_ktp107         JSL     KTTY_LD_EXIT

                ; Look up current task.
                LDA     _curTask
                JSR     Task_Lookup
                BCS     @psx_lookOK1
                JMP     @psx_halt
@psx_lookOK1    ; Save status, mark zombie, free all banks owned by this
                ; task.  Phase 2 slice 2.1: walk TCB_BankList[0..7] and
                ; Bank_Free each non-zero entry.  Single-bank binaries
                ; (today's FGX1) populate only slot 0; multi-bank binaries
                ; (future FGX2) will populate 0..n-1.  Reading TCB_CodeBank
                ; alone misses segments 1+ once FGX2 lands, so do the walk
                ; uniformly now to avoid retrofitting at the format slice.
                LDA     _ex_encStatus
                STA:     TCB_ExitCode,X
                LDA     #TASK_ZOMBIE
                STA:     TCB_Status,X
                STX     _ex_freeBanksTCB            ; preserve TCB offset
                                                    ; across Bank_Free's
                                                    ; X-clobber
                STZ     _ho_exec                    ; an owner leaving its image
                LDA:    TCB_DataBank,X              ;   group hands it on first
                JSR     Img_HandOff
                LDX     _ex_freeBanksTCB
                JSR     _Task_FreeBanks             ; walks TCB_BankList[0..7]
                LDX     _ex_freeBanksTCB

                ; Capture child pid for the parent's syscall return value.
                LDA     _curTask
                STA     _ex_childPid

                ; --- Reparent this task's children to pid 1 (the root, always
                ;     alive until halt).  Without this an orphan keeps ParentID =
                ;     the dead parent's pid; when it later _exits it would
                ;     _wakeup a freed/reused slot.  Reparenting to the live root
                ;     keeps the wakeup valid (and pid 1 can reap the orphan).
                ;     _ex_childPid = the dying pid.  Clobbers X; restored after.
                LDX     #FGX_TASK_TBL_OFF
@psx_rpLoop      LDA:    TCB_TaskID,X
                AND     #$00FF
                BEQ     @psx_rpNext                 ; empty slot
                LDA:    TCB_ParentID,X
                AND     #$00FF
                CMP     _ex_childPid
                BNE     @psx_rpNext                 ; not our child
                LDA     #1                          ; reparent to pid 1
                STA:    TCB_ParentID,X
                ; Mark it SEF_REPARENTED so its eventual exit auto-reaps (pid 1
                ; won't waitpid an inherited orphan).  seoff = (X-FGX_TASK_TBL_OFF)>>1.
                TXA
                SEC
                SBC     #FGX_TASK_TBL_OFF
                LSR
                CLC
                ADC     #SE_Flags
                TAY
                LDA     [_schedTblPtr],Y
                ORA     #SEF_REPARENTED
                STA     [_schedTblPtr],Y
                ; --- RESCUE A STOPPED CHILD (apple/fgx#71) ---
                ;     } else if (q->p_stat == SSTOP) {
                ;         psignal(q, SIGHUP);
                ;         psignal(q, SIGCONT);
                ;     }
                ;                       -- 2.11BSD kern_exit.c:141-143
                ;
                ; A stopped child has nobody left who would resume it: the
                ; shell that ^Z'd it is the process now exiting, and its
                ; process group leader is going with it.  Without this it
                ; stays TASK_STOPPED for the life of the boot, holding a task
                ; slot, a direct page and a bank-0 stack reservation, so a few
                ; of these is a real bite rather than an accounting curiosity.
                ;
                ; ORDER IS BSD'S: HUP first, then CONT.  _Kill_Apply flips
                ; TASK_STOPPED back to READY at SIGCONT POST time, so the
                ; second call is what actually restarts it, and _Sys_CheckSignal
                ; then scans low-to-high and reaches SIGHUP (1) before
                ; SIGCONT (19) -- the child wakes, takes the hangup, and dies.
                ; A child that CATCHES SIGHUP runs its handler instead, which
                ; is what BSD gives it too.
                ;
                ; BSD's sibling arm -- P_TRACED -> SIGKILL -- has no analogue
                ; here; FGX has no ptrace.
                LDA:    TCB_Status,X
                AND     #$00FF
                CMP     #TASK_STOPPED
                BNE     @psx_rpNext
                LDA     #SIGHUP
                JSR     _Kill_PostOne
                LDA     #SIGCONT
                JSR     _Kill_PostOne
@psx_rpNext      TXA
                CLC
                ADC     #TCB_SIZE
                TAX
                CPX     #FGX_TASK_TBL_OFF+{TASK_MAX_SLOTS*TCB_SIZE}
                BCC     @psx_rpLoop
                LDX     _ex_freeBanksTCB            ; restore X = dying TCB offset

                ; Identify parent.  PID 0 = no parent → halt.
                LDA:     TCB_ParentID,X
                AND     #$00FF
                BNE     @psx_haveParent
                JMP     @psx_halt
@psx_haveParent STA     _ex_parentPid

                ; Wake the parent.  _wakeup(&parent_TCB) marks it READY iff it
                ; is _sleep'ing in waitpid on its own TCB channel; if the parent
                ; is already READY (e.g. it yielded) this no-ops and swtch picks
                ; it anyway.  chan = the parent's TCB byte-offset within the kernel bank.
                JSR     Task_Lookup                 ; X = parent TCB offset
                BCS     @psx_lookOK2
                JMP     @psx_halt
@psx_lookOK2    TXA                                 ; A = parent TCB offset = chan
                JSR     _wakeup

                ; Post SIGCHLD to the parent (2026-07-27) -- the async child-
                ; death notification BSD job control needs: tcsh's pjwait polls
                ; `while (PRUNNING) sigpause()` and only its SIGCHLD handler
                ; (pchild) reaps + clears PRUNNING, so without this the shell
                ; hangs after its first foreground external command.  Default
                ; action is SA_IGN, so wait()-based shells (bsh/jsh) see no
                ; behavior change.  _Sys_Kill clobbers A/X/Y + _shTmp1; X is
                ; reloaded from _ex_freeBanksTCB below.
                LDA     _ex_parentPid
                LDX     #SIGCHLD
                JSR     _Sys_Kill

                ; --- fork train V3 + F: a dying vfork/snapshot child hands
                ; the borrowed image back.  A SNAPCHILD first RESTORES the
                ; parent's snapshot (banks/stack/DP back, spares + descriptor
                ; freed, child's borrowed SE_SoftBank scrubbed BEFORE the
                ; sbrk-free block below can touch the parent's heap bank).
                ; Then clear the flag (the parent's wake predicate) and wake
                ; WCHAN_VFORK.  The bank/DP/stack frees above were natural
                ; no-ops (the child owns nothing).
                LDX     _ex_freeBanksTCB            ; dying task's TCB offset
                TXA
                SEC
                SBC     #FGX_TASK_TBL_OFF
                LSR
                CLC
                ADC     #SE_Flags
                TAY
                LDA     [_schedTblPtr],Y
                BIT     #SEF_VFORKCHILD+SEF_SNAPCHILD
                BEQ     @psx_plain
                BIT     #SEF_SNAPCHILD
                BEQ     @psx_noRestore
                ; A snapshot child: the soft-frame bank it carries is its
                ; parent's, zeroed so the free below leaves it, and its
                ; image-cache home goes, its range being its parent's.
                TYA
                CLC
                ADC     #SE_SoftBank-SE_Flags
                TAY
                SEP     #$20
                MX      %10
                LDA     #0
                STA     [_schedTblPtr],Y
                REP     #$20
                MX      %00
                LDX     _ex_freeBanksTCB
                LDA:    TCB_TaskID,X
                JSR     Uimg_HomeFree           ; preserves X
                TXA                             ; recompute the flags index
                SEC
                SBC     #FGX_TASK_TBL_OFF
                LSR
                CLC
                ADC     #SE_Flags
                TAY
                LDA     [_schedTblPtr],Y
@psx_noRestore  PHA
                AND     #$FF67                      ; the fork-child bits and FORKREL
                STA     [_schedTblPtr],Y
                PLA
                AND     #SEF_VFORKCHILD             ; a snapshot parent is parked,
                STA     _ex_wasVfork                ;   not borrowed
                BEQ     @psx_noBorrow
                ; B3: end of the borrow window -- the execve twin above, for the
                ; child that dies instead of exec'ing.  No _ev_isChild gate is
                ; needed here: this arm is already inside `BIT #SEF_VFORKCHILD +
                ; SEF_SNAPCHILD / BEQ @psx_noVfork`, so only a real borrower
                ; reaches it.  _ex_parentPid was captured above, before the
                ; frees.
                LDA     _ex_parentPid
                AND     #$00FF
                BEQ     @psx_noBorrow
                JSR     Task_Lookup                 ; A=pid -> X=TCB offset, C=1
                BCC     @psx_noBorrow               ; parent already reaped
                JSR     Task_BorrowClr
@psx_noBorrow
                LDA     #WCHAN_VFORK
                JSR     _wakeup
                ; Borrowed-image hand-back: DISOWN the parent's stack.
                ;
                ; _vf_common copies the parent's TCB_StackBase/StackSize into
                ; the child at fork (the child RUNS on the parent's stack), and
                ; every failed-exec rollback faithfully restores them.  So a
                ; fork child that dies WITHOUT a successful exec still CLAIMS
                ; the parent's arena stack in its TCB.  Task_FreeStack gates
                ; only on arena BOUNDS, never ownership (task.s), so the reap --
                ; waitpid's Task_Free, or the orphan sweep below -- then clears
                ; the PARENT'S LIVE stack pages in _stkArenaMap.
                ;
                ; Nothing shows up immediately: the bytes are untouched, only
                ; the bitmap is poisoned.  It is consumed by the NEXT
                ; Task_AllocStack, which runs only on a SUCCESSFUL load: its
                ; first-fit scan hands the new child the parent's live pages,
                ; _Loader_StageArgs lays the resume frame there, and the commit's
                ; _Fork_Restore copies the parent's snapshot back over it -- so
                ; _Task_FirstRun RTLs into garbage and the machine executes wild
                ; (uninterruptible: it never reaches a syscall boundary again).
                ; Exactly "cmd not found, then any real command hangs".
                ;
                ; A child that DID exec never reaches here -- the commit cleared
                ; both fork-child bits -- so it still frees its own stack.
                LDX     _ex_freeBanksTCB
                LDA     #0
                STA:    TCB_StackBase,X
                STA:    TCB_StackSize,X
                LDA:    TCB_TaskID,X            ; and it holds no range now
                AND     #$00FF
                DEC
                TAY
                SEP     #$20
                MX      %10
                LDA     #0
                STA    |_uiResident,Y
                REP     #$20
                MX      %00
                LDA     _ex_wasVfork
                BNE     @psx_noVfork            ; a vfork child is in no group
@psx_plain      ; Leave the image group, if this task is in one: its bank home
                ; goes, or the live banks pass to a member with one.
                LDX     _ex_freeBanksTCB
                LDA:    TCB_DataBank,X
                JSR     _Img_Leave
@psx_noVfork
                ; FREE THE USER STACK AT EXIT, not at reap.
                ;
                ; Task_FreeStack has only ever run from Task_Free (task.s), which
                ; runs when waitpid REAPS or the orphan sweep collects.  So a
                ; zombie whose parent never waits pinned its entire stack
                ; reservation indefinitely -- and the reservation is the whole
                ; point: tcsh's is 56 pages of a 147-page arena, so two dead
                ; sessions were enough to deny a third one a contiguous run.
                ; That is what `stk ENOMEM 56p` was, and why it looked like the
                ; arena "cannot fund tcsh" when it plainly can: tcsh runs
                ; on two consoles at once, because live tasks free their pages
                ; when they exit and corpses did not.
                ;
                ; AFTER the disown block above, deliberately: that block zeroes
                ; StackBase/Size for a fork child that died WITHOUT exec, whose
                ; pages belong to the parent -- so this call correctly no-ops
                ; there.  Safe to run here for the same reason the exec path's
                ; mid-syscall free is (see the note at step 7): we are on the
                ; per-pid KERNEL stack, never the user stack being freed.
                ; Task_FreeStack is bounds-gated and idempotent and zeroes
                ; StackBase/Size, so the eventual reap's call no-ops in turn.
                LDX     _ex_freeBanksTCB
                JSR     Task_FreeStack
                ; --- free the dying task's soft-frame bank (the slot that
                ; --- fork train Stage S called the private sbrk
                ; bank (SE_SoftBank; 0 = never granted).  Stage F NOTE: a
                ; SNAPCHILD will carry the PARENT'S bank here for running —
                ; its hand-back must zero the byte before this free runs.
                LDX     _ex_freeBanksTCB
                TXA
                SEC
                SBC     #FGX_TASK_TBL_OFF
                LSR
                CLC
                ADC     #SE_SoftBank
                TAY
                SEP     #$20
                MX      %10
                LDA     [_schedTblPtr],Y
                BEQ     @psx_noSbrk
                PHA                                 ; (8-bit push)
                LDA     #0
                STA     [_schedTblPtr],Y            ; zero before the free
                PLA                                 ; (8-bit pull — widths match)
                REP     #$20
                MX      %00
                AND     #$00FF
                JSR     Bank_Free
                BRA     @psx_sbrkDone
@psx_noSbrk     REP     #$20
                MX      %00
@psx_sbrkDone
                ; --- #11: free the dying task's dedicated big blocks.  They are
                ; per-task memory in banks outside its data bank, so they die
                ; with the task exactly like the soft-frame bank above.  A
                ; SNAPCHILD's rows are keyed on ITS pid, so the parent's blocks
                ; are untouched.
                LDX     _ex_freeBanksTCB
                LDA:    TCB_TaskID,X
                AND     #$00FF
                BEQ     @psx_bigDone            ; pid 0 = kernel, owns nothing
                JSR     _BlkRow_FreeByOwner
@psx_bigDone

                ; --- Reap abandoned orphan zombies (SEF_REPARENTED tasks that
                ;     have exited): pid 1 inherited them but won't waitpid them,
                ;     so nobody frees their slots.  Sweep here at each exit (a
                ;     task context — Task_Free is safe on a task that already
                ;     swtch'd away).  Skip the current dying task (it can't free
                ;     its own kernel stack; the NEXT exit's sweep reaps it).
                LDX     #FGX_TASK_TBL_OFF
@psx_reapLoop   LDA:    TCB_Status,X
                CMP     #TASK_ZOMBIE
                BNE     @psx_reapNext
                ; SEF_REPARENTED set?  seoff = (X - FGX_TASK_TBL_OFF) >> 1
                TXA
                SEC
                SBC     #FGX_TASK_TBL_OFF
                LSR
                CLC
                ADC     #SE_Flags
                TAY
                LDA     [_schedTblPtr],Y
                AND     #SEF_REPARENTED
                BEQ     @psx_reapNext
                ; not the current dying task?  (_ex_childPid = our pid)
                LDA:    TCB_TaskID,X
                AND     #$00FF
                CMP     _ex_childPid
                BEQ     @psx_reapNext
                PHX                                 ; Task_Free clobbers X
                JSR     Task_Free
                PLX
@psx_reapNext   TXA
                CLC
                ADC     #TCB_SIZE
                TAX
                CPX     #FGX_TASK_TBL_OFF+{TASK_MAX_SLOTS*TCB_SIZE}
                BCC     @psx_reapLoop

                ; Switch to the parent via the scheduler.  The child is ZOMBIE
                ; and the parent is now READY, so pick_next selects the parent;
                ; the full swtch restores the parent's saved kernel SP and RTSes
                ; into the parent's posix_spawn (right after its `JSR swtch`),
                ; which returns child_pid to the parent's user code.  swtch does
                ; NOT return here — a ZOMBIE is never reselected.  IRQs masked
                ; across the switch (spl); the resumed parent does its own CLI.
                SEI
                JSR     swtch
                ; Unreachable: swtch never comes back to a zombie.  Halt loudly
                ; if it ever does (would indicate a scheduler invariant break).
                JMP     _Kern_Halt              ; RELOC: PB-rel (live kernel bank), NOT JML (baked $02 stale)

@psx_halt        ; No parent / lookup failure / pid 0 — halt the system.
                JMP     _Kern_Halt              ; RELOC: PB-rel (live kernel bank), NOT JML (baked $02 stale)

;------------------------------------------------------------------------------
; _Sys_CloseAllFds - close every open slot in the current task's fd table.
;
; Called from _Sys_Exit so the FCBs the task held (e.g. redirection
; targets) get released before Task_FreeFdTable frees the table itself.
;
; Caller MX %00.  Clobbers A, X, Y, _shTmp0, _libcTmp2, _fcbPtr.
;------------------------------------------------------------------------------
_Sys_CloseAllFds MX     %00
                JSR     _Fd_TableOfCur
                LDX     #0
@cf_L           CPX     #FS_MAX_FDS
                BCS     @cf_done
                PHX
                TXA
                AND     #$00FF
                JSR     Fs_Close                    ; returns C=0 + A=EBADF
                                                    ; on empty slot; we ignore.
                PLX
                INX
                BRA     @cf_L
@cf_done        RTS

;------------------------------------------------------------------------------
; _Fd_TableOfCur - point _fd_table_ptr at the CURRENT task's own fd table.
; MX %00.  Clobbers A, X.
;------------------------------------------------------------------------------
_Fd_TableOfCur  MX      %00
                ; Block-resume safety: re-point _fd_table_ptr at _curTask's OWN
                ; fd table before closing.  The dispatcher only repoints this
                ; global at syscall ENTRY; a task that blocked mid-syscall (e.g.
                ; spinner's SYS_YIELD) lets another task run and overwrite it.
                ; When that task's deferred SA_TERM exit reaches here, the stale
                ; ptr would Fs_Close ANOTHER live task's fds (observed: killing a
                ; backgrounded job zeroed jsh's stdout -> all shell output EBADF
                ; -> "frozen" console).  Re-derive from _curTask = the dying task.
                LDA     _curTask
                AND     #$00FF
                BEQ     @cf_ptrOK               ; pid 0 / boot: leave ptr as-is
                JSR     Task_Lookup
                BCC     @cf_ptrOK               ; lookup miss: leave ptr as-is
                LDA:    TCB_FdTablePtr,X
                STA     _fd_table_ptr
                SEP     #$20
                MX      %10
                LDA:    TCB_FdTablePtr+2,X
                STA     _fd_table_ptr+2
                REP     #$20
                MX      %00
@cf_ptrOK       RTS

;------------------------------------------------------------------------------
; _Fd_CloseOnExec - close every close-on-exec descriptor of the process whose
; table _fd_table_ptr names (the caller sets _fdOwnerPid for one that is not
; the current task, as posix_spawn does for its child).
; 4.3BSD-Reno kern_exec.c:282: past the commit, each fd whose u_pofile carries
; UF_EXCLOSE is closed and its flag cleared.  The flag bytes are the far
; arena's (_Fd_Pop); Fs_Close does the close, so a socket, pipe or device gets
; the teardown dup2 needs for the same reason (apple/fgx#134).
; MX %00.  Clobbers A, X, Y and whatever Fs_Close clobbers.
;------------------------------------------------------------------------------
_Fd_CloseOnExec MX      %00
                LDX     #0
@fce_L          CPX     #FS_MAX_FDS
                BCS     @fce_done
                PHX
                TXA
                JSR     _Fd_Pop
                BCC     @fce_next
                SEP     #$20
                MX      %10
                LDA     [_fdFilePtr],Y
                AND     #UF_EXCLOSE
                BEQ     @fce_next8
                LDA     #0
                STA     [_fdFilePtr],Y
                REP     #$20
                MX      %00
                LDA     1,S                     ; the fd
                JSR     Fs_Close
                BRA     @fce_next
@fce_next8      REP     #$20
                MX      %00
@fce_next       PLX
                INX
                BRA     @fce_L
@fce_done       RTS

;------------------------------------------------------------------------------
; _Sys_ApplyFdActions - walk file_actions list, apply each to the child's
; fd table.  Called from _Sys_PosixSpawn[X] between inherit-copy and
; Load_Binary.  When _ps_fdActionsPtr is 0 (plain SPAWN), this is a
; no-op + C=1.
;
; Side effects:
;   - Temporarily swaps _fd_table_ptr to the child's table for the
;     duration of the walk; restores parent's on return (so parent's
;     subsequent syscalls still see the right table if spawn aborts).
;   - On OPEN action: copies path from caller bank to _Sys_PathBuf via
;     _Sys_CopyPathToBuf, then Fs_Create/Fs_Open per O_CREAT.  The new
;     fd lands in some free slot K of the child's table; we move it to
;     the action's target slot, freeing whatever was already there.
;
; Caller MX %00.  Returns C=1 ok / C=0 + A = errno (ENOENT, EMFILE,
; ENFILE, EFAULT, EINVAL).
;------------------------------------------------------------------------------
_Sys_ApplyFdActions MX  %00
                ; NO EARLY RETURN FOR AN EMPTY LIST: the child's close-on-exec
                ; descriptors are closed at the END below, after the actions
                ; as POSIX orders them, and that needs the child's table
                ; installed whether or not there are actions.
                ; Slice D: a tty opened by these actions becomes the CHILD's
                ; controlling terminal, not init's.  _curTask is still the
                ; parent here, so _Se_SetCtty needs the target spelled out --
                ; see _kCttyTarget in include/memmap.s.  Cleared on every exit
                ; path below so an ordinary open() still binds to its caller.
                LDX     _ps_childTCB
                LDA:    TCB_TaskID,X
                AND     #$00FF
                STA     _kCttyTarget
                ; AND THE SAME FOR THE DESCRIPTORS -- UFS 1.7d I2c.  The block
                ; below repoints _fd_table_ptr at the CHILD, but the file table
                ; is indexed BY PID and _curTask is still the parent, so every
                ; descriptor service called from in here would touch the
                ; parent's entries.  Exactly the hazard _kCttyTarget above
                ; exists for, one layer down; cleared on the same exit paths.
                STA     _fdOwnerPid
                ; Save parent's _fd_table_ptr (3 bytes).
                LDA     _fd_table_ptr
                STA     _afa_savedFdtab
                SEP     #$20
                MX      %10
                LDA     _fd_table_ptr+2
                STA     _afa_savedFdtab+2
                REP     #$20
                MX      %00
                ; Point _fd_table_ptr at child's TCB_FdTablePtr.
                LDX     _ps_childTCB
                LDA:    TCB_FdTablePtr,X
                STA     _fd_table_ptr
                SEP     #$20
                MX      %10
                LDA:    TCB_FdTablePtr+2,X
                STA     _fd_table_ptr+2
                REP     #$20
                MX      %00
                ; _afa_listPtr lives in kernel-bank statics and survives the
                ; Fs_Open/Fs_Create calls that clobber DP scratch.  Each
                ; iteration copies it into _libcTmp2 (DP) for [dp],Y reads.
                LDA     _ps_fdActionsPtr
                BNE     @afa_list
                JMP     @afa_end                    ; no actions
@afa_list       STA     _afa_listPtr
                SEP     #$20
                MX      %10
                LDA     _Sys_CallerBank
                STA     _afa_listPtr+2
                REP     #$20
                MX      %00

@afa_loop       ; Refresh DP long ptr from the kernel-bank cursor.
                LDA     _afa_listPtr
                STA     _libcTmp2
                SEP     #$20
                MX      %10
                LDA     _afa_listPtr+2
                STA     _libcTmp2+2
                ; Read op byte at [_libcTmp2]+0.
                LDY     #0
                LDA     [_libcTmp2],Y
                STA     _afa_op
                BNE     @afa_dispatch
                REP     #$20
                MX      %00
                JMP     @afa_end                    ; op=0: END

@afa_dispatch   ; fd at +1.
                LDY     #1
                LDA     [_libcTmp2],Y
                STA     _afa_fd
                REP     #$20
                MX      %00
                ; arg1 at +2..+3.
                LDY     #2
                LDA     [_libcTmp2],Y
                STA     _afa_arg1
                LDY     #4
                LDA     [_libcTmp2],Y
                STA     _afa_arg2
                ; Dispatch on op.
                SEP     #$20
                MX      %10
                LDA     _afa_op
                CMP     #FA_OP_OPEN
                BEQ     @afa_doOpen
                CMP     #FA_OP_CLOSE
                BNE     @afa_notClose
                JMP     @afa_doClose            ; (BEQ range blown by the P3.2
@afa_notClose   CMP     #FA_OP_DUP2             ;  O_APPEND FCB copy)
                BNE     @afa_notDup2
                JMP     @afa_doDup2
@afa_notDup2    CMP     #FA_OP_DETACH
                BNE     @afa_notDetach
                JMP     @afa_doDetach
@afa_notDetach
                ; Unknown op.  Enter @afa_errExit in M=16 like the
                ; @afa_open_err path does — the exit's fd-table-pointer
                ; restore is 16-bit code; an M=8 entry half-wrote the
                ; parent's _fd_table_ptr (low byte only).  Found by the
                ; strengthened check_mx live-entry-mode pass (2026-07-17).
                REP     #$20
                MX      %00
                LDA     #EINVAL
                JMP     @afa_errExit

;----- OPEN: arg1 = path-offset, arg2 = flags.
@afa_doOpen     REP     #$20
                MX      %00
                ; First close any fd already at the target slot.
                SEP     #$20
                MX      %10
                LDA     _afa_fd
                JSR     Fs_Close                    ; may EBADF — ignored
                ; Copy path to _Sys_PathBuf.
                REP     #$20
                MX      %00
                LDA     _afa_arg1
                JSR     _Sys_CopyPathToBuf
                BCC     @afa_plok
                LDA     #ENAMETOOLONG           ; apple/fgx#436
                JMP     @afa_errExit
@afa_plok
                ; --- THE ROOT FIRST, WITH THE ACTION'S OWN FLAGS ---
                ;
                ; The same order `_Sys_Open' uses, and BEFORE the O_CREAT
                ; branch for the reason it gives: vn_open honours FCREAT,
                ; FTRUNC and FEXCL itself, so whoever claims the name owns the
                ; whole open.  `Fs_Open' below reaches the root through its OWN
                ; hook, which passes FS_FREAD and nothing else -- it serves
                ; Load_Binary and Mod_LoadConf, which carry no O_ flags -- so a
                ; file action that fell through to it would hand the child a
                ; READ-ONLY descriptor for a line it is about to write to.
                ;
                ; 0666 IS THE MODE BECAUSE THE ACTION ABI CARRIES NONE.  It is
                ; masked here exactly as `_Sys_Open' masks the caller's --
                ; `&~ u_cmask', then `& 07777 &~ S_ISVTX' -- so a file created
                ; by a file action gets the same permissions it would have got
                ; from an open(2) the child made itself.
                ;
                ; ONLY EACCES IS CARRIED, which is `_Sys_Open's rule and the
                ; same reasoning: a refusal is a decision the root has made
                ; about a name it owns, and a miss is a routing answer.
                LDA     #$01B6                  ; 0666
                JSR     _Sys_ApplyCmask         ; &~ u_cmask
                AND     #$0DFF                  ; & 07777, &~ S_ISVTX
                TAY                             ; Y = the masked create mode
                LDA     _afa_arg2
                INC                             ; fmode = flags + 1
                LDX     #_Sys_PathBuf
                JSR     _Fs_RootOpen
                BCS     @afa_open_post
                ; THE ROOT'S ANSWER IS FINAL, whatever it is: O_CREAT is the
                ; create mode this call already passed in Y, and there is
                ; nothing behind root_open to ask.  Zero is root_open's folded
                ; ROUTING answer -- no root mounted -- so it becomes ENXIO
                ; rather than reaching the caller as a success code.
                CMP     #0
                BNE     @afa_open_err
                LDA     #ENXIO
                BRA     @afa_open_err
@afa_open_post  ; A = new fd (low byte) in child's table.
                AND     #$00FF
                STA     _afa_newFd
                ; O_APPEND IS THE ROOT'S, and per WRITE rather than per open:
                ; `vn_write' turns FAPPEND into IO_APPEND on every call
                ; (vfs_vnops.c:480), which is upstream's arrangement.
                ; If newFd != target fd, move slot newFd → slot fd.
                LDA     _afa_newFd
                CMP     _afa_fd
                BEQ     @afa_advance
                JSR     _afa_moveSlot
                BRA     @afa_advance

@afa_open_err   ; A holds errno (low byte).
                AND     #$00FF
                JMP     @afa_errExit

;----- CLOSE: just Fs_Close(target_fd).
@afa_doClose    REP     #$20
                MX      %00
                LDA     _afa_fd
                JSR     Fs_Close
                ; Ignore errno (slate-cleaning: EBADF on empty slot is fine).
                BRA     @afa_advance

;----- DUP2: child slot dst (=_afa_fd) becomes a copy of src (=_afa_arg1),
;     closing dst first if open, and bumping the shared FCB's refcount so a
;     later close of either fd doesn't double-free (FCB refcounting, post
;     boot-double-free fix).  Operates on the child fd table (_fd_table_ptr
;     is repointed to the child during action application).
@afa_doDetach   ; FA_OP_DETACH: TIOCNOTTY on the CHILD, before its opens.
                ; _Se_TtyDetach resolves _kCttyTarget (set at the routine's head to the
                ; child's pid) exactly as _Se_TtyOpen does, so this detaches the
                ; task being spawned rather than the spawner.  No fd, no arg,
                ; and no failure mode -- BSD's TIOCNOTTY cannot fail either.
                REP     #$20
                MX      %00
                JSR     _Se_TtyDetach
                BRA     @afa_advance

@afa_doDup2     REP     #$20
                MX      %00
                ; src == dst -> no-op (POSIX dup2 of equal fds).
                LDA     _afa_arg1
                AND     #$00FF
                STA     _shTmp0
                LDA     _afa_fd
                AND     #$00FF
                CMP     _shTmp0
                BEQ     @afa_advance
                ; resolve src; if not open, skip leniently.
                SEP     #$20
                MX      %10
                LDA     _afa_arg1
                JSR     _Fcb_LookupPtr
                BCS     @afa_dup2_go
                REP     #$20
                MX      %00
                BRA     @afa_advance
@afa_dup2_go    ; close dst (harmless/EBADF if empty), re-resolve src (Fs_Close
                ; clobbers _fcbPtr), then dup src's FCB into dst with a refcount bump.
                REP     #$20
                MX      %00
                ; NAME THE SOURCE DESCRIPTOR FIRST -- apple/fgx#227.  `_Fd_Dup'
                ; states `_fdDupSrc = SOURCE fd' in its contract and says why it
                ; cannot derive one (syscall.s:1809): after a dup several fds
                ; share a single FCB, so `_fcbPtr' does not identify which
                ; descriptor was copied.  Only `_Sys_Dup' and `_Sys_Dup2' were
                ; setting it, so a DUP2 file action mirrored against whatever fd
                ; the last dup(2) ANYWHERE IN THE SYSTEM had used.
                ;
                ; THE FD TABLE WAS WRITTEN EITHER WAY, WHICH IS WHY IT LOOKED
                ; LIKE A TTY BUG.  `fddup' (vfs_file.c:434) answers EBADF when
                ; `fdp[oldfd]' is empty and mirrors nothing, so the child got a
                ; descriptor that the FCB table had and the file table did not
                ; -- and every syscall on it answered EBADF.  MEASURED: a getty
                ; spawned that way reports `getp=-1/e9, wr=-1/e9, rd=-1/e9' and
                ; exits without a greeting, which is exactly the second telnet
                ; session that connects, negotiates and stays silent.
                LDA     _afa_arg1
                AND     #$00FF
                STA     _fdDupSrc
                LDA     _afa_fd
                JSR     Fs_Close
                SEP     #$20
                MX      %10
                LDA     _afa_arg1
                JSR     _Fcb_LookupPtr
                LDA     _afa_fd
                JSR     _Fd_Dup
                REP     #$20
                MX      %00
                BRA     @afa_advance

@afa_advance    REP     #$20
                MX      %00
                CLC
                LDA     _afa_listPtr
                ADC     #FA_SIZE
                STA     _afa_listPtr
                JMP     @afa_loop

@afa_end        JSR     _Fd_CloseOnExec             ; the child's, by
                                                    ;   _fdOwnerPid above
@afa_okExit     STZ     _kCttyTarget                ; back to "the current task"
                STZ     _fdOwnerPid                 ; ...for descriptors too
                ; Restore parent's _fd_table_ptr.
                LDA     _afa_savedFdtab
                STA     _fd_table_ptr
                SEP     #$20
                MX      %10
                LDA     _afa_savedFdtab+2
                STA     _fd_table_ptr+2
                REP     #$20
                MX      %00
                SEC
                RTS

@afa_errExit    STZ     _kCttyTarget                ; back to "the current task"
                STZ     _fdOwnerPid                 ; ...for descriptors too
                ; A holds errno (8-bit).  Restore parent's _fd_table_ptr,
                ; return C=0 + A=errno.
                STA     _afa_savedErr
                LDA     _afa_savedFdtab
                STA     _fd_table_ptr
                SEP     #$20
                MX      %10
                LDA     _afa_savedFdtab+2
                STA     _fd_table_ptr+2
                LDA     _afa_savedErr
                REP     #$20
                MX      %00
                AND     #$00FF
                CLC
                RTS

;------------------------------------------------------------------------------
; _afa_moveSlot - copy fd-table slot _afa_newFd → slot _afa_fd, then
; (OPEN path) zero the source slot.  Used to land Fs_Open's allocated
; fd at the action's target slot.
;
; For DUP2 the caller wants both slots populated; that's the caveat
; documented in @afa_doDup2.  We zero the source slot unconditionally
; here because it's the right behaviour for OPEN, and DUP2 is broken
; without refcounting anyway.
;------------------------------------------------------------------------------
_afa_moveSlot   MX      %00
                ; src slot offset = newFd * 3.
                LDA     _afa_newFd
                AND     #$00FF
                STA     _afa_srcOff
                ASL
                CLC
                ADC     _afa_srcOff
                STA     _afa_srcOff
                ; dst slot offset = fd * 3.
                LDA     _afa_fd
                AND     #$00FF
                STA     _afa_dstOff
                ASL
                CLC
                ADC     _afa_dstOff
                STA     _afa_dstOff
                ; Copy 3 bytes src → dst via _afa_tmp3 scratch.
                SEP     #$20
                MX      %10
                LDY     _afa_srcOff
                LDA     [_fd_table_ptr],Y
                STA     _afa_tmp3
                INY
                LDA     [_fd_table_ptr],Y
                STA     _afa_tmp3+1
                INY
                LDA     [_fd_table_ptr],Y
                STA     _afa_tmp3+2
                ; Zero the source slot now (so dst writes can't loop back
                ; through src in any aliased way; also leaves the table
                ; valid mid-copy if interrupted).
                LDY     _afa_srcOff
                LDA     #0
                STA     [_fd_table_ptr],Y
                INY
                STA     [_fd_table_ptr],Y
                INY
                STA     [_fd_table_ptr],Y
                ; Write to dst.
                LDY     _afa_dstOff
                LDA     _afa_tmp3
                STA     [_fd_table_ptr],Y
                INY
                LDA     _afa_tmp3+1
                STA     [_fd_table_ptr],Y
                INY
                LDA     _afa_tmp3+2
                STA     [_fd_table_ptr],Y
                REP     #$30
                MX      %00

                ; MIRROR THE MOVE -- UFS 1.7d I2c.  A move, not a dup: the
                ; reference changes number rather than multiplying, so f_count
                ; is untouched and the source is cleared -- which is what the
                ; three-byte shuffle above just did to the fd table.
                ;
                ; fdmove(pid, oldfd, newfd), right to left.  The pid is
                ; _Fcb_OwnerPid's, which is the CHILD here; see the routine's head.
                LDA     _afa_fd
                AND     #$00FF
                PHA                             ; newfd -- the destination
                LDA     _afa_newFd
                AND     #$00FF
                PHA                             ; oldfd -- the source
                JSR     _Fcb_OwnerPid
                PHA                             ; pid
_kfp916         JSL     KFAR_VFS_DESCMOVE       ; bank byte patched by Far_Init
                TSC
                CLC
                ADC     #6                      ; drop the three arguments
                TCS
                REP     #$20
                MX      %00
                RTS

;------------------------------------------------------------------------------
; _Sys_Wait (#7) - wait(status_ptr) == waitpid(-1, status_ptr, 0).
;   A = status-ptr offset in caller bank (0 = don't want status).
;------------------------------------------------------------------------------
_Sys_Wait       ENT
                MX      %00
                STA     _wt_statusPtr
                LDA     #$FFFF                      ; target = any child
                STA     _wt_target
                STZ     _wt_opts
                BRA     _waitpid_core

;------------------------------------------------------------------------------
; _Sys_Waitpid (#82) - waitpid(pid, status_ptr, options).
;
; A = pid (-1/$FFFF = any child; >0 = that specific child), X = status-ptr
; offset in caller bank (0 = none), Y = options (WNOHANG | WUNTRACED).
;
; Returns: C=1 + A = pid (a reaped ZOMBIE, or — under WUNTRACED — a STOPPED
;            child) + *status_ptr written; or A = 0 if WNOHANG and a matching
;            child is alive but not waitable; C=0 + A = ECHILD if no match.
;
; Phase 3.2: ASYNC spawn means a child may still be live; if so and not WNOHANG,
; _sleep on our TCB (woken by the child's _exit OR its stop — Phase 5.3) and
; rescan.  Cooperative scheduling means no child changes state during a scan,
; so there is no lost-wakeup window.
;
; LIMITATION: a STOPPED child is reported on EVERY WUNTRACED wait (no
; "already reported" flag yet); the shell waits once per stop, so this is benign.
;------------------------------------------------------------------------------
_Sys_Waitpid    ENT
                MX      %00
                STA     _wt_target                  ; target pid (or $FFFF = any)
                STX     _wt_statusPtr
                STY     _wt_opts
_waitpid_core   LDA     _curTask
                AND     #$00FF
                STA     _wt_myPid
@psw_rescan      STZ     _wt_hasChild
                ; Re-derive our pid each pass: _wt_myPid is a global, and a
                ; NESTED wait (a child of ours that itself waits) clobbers it
                ; while we're _sleep'ing.  _curTask is restored to us by swtch
                ; on wake, so re-read it here.
                LDA     _curTask
                AND     #$00FF
                STA     _wt_myPid
                LDX     #FGX_TASK_TBL_OFF
@psw_L           ; A FREE SLOT BY ITS STATUS, NOT ITS PID: a reaped child's
                ; slot keeps TCB_TaskID and TCB_ParentID, so testing the pid
                ; counted every child already reaped as alive, and a wait with
                ; nothing left slept for ever instead of answering ECHILD
                ; (2.11BSD wait1() scans only live processes; reaping clears
                ; p_pid and p_ppid).  The kill fan-out had the same bug
                ; (apple/fgx#401).
                LDA:     TCB_Status,X
                AND     #$00FF
                BEQ     @psw_next                   ; free slot
                LDA:     TCB_ParentID,X
                AND     #$00FF
                CMP     _wt_myPid
                BNE     @psw_next                   ; not our child
                ; Target filter: a specific pid request skips other children.
                LDA     _wt_target
                CMP     #$FFFF
                BEQ     @psw_match
                LDA:     TCB_TaskID,X
                AND     #$00FF
                CMP     _wt_target
                BNE     @psw_next
@psw_match       ; Matching child.  ZOMBIE (reap) / STOPPED+WUNTRACED (report) /
                ; else alive (note + keep scanning).
                LDA:     TCB_Status,X
                AND     #$00FF
                CMP     #TASK_ZOMBIE
                BNE     @psw_notZombie          ; (long: SEF check pushed it OOR)
                JMP     @psw_foundZombie
@psw_notZombie   LDA     #1
                STA     _wt_hasChild
                LDA:     TCB_Status,X
                AND     #$00FF
                CMP     #TASK_STOPPED
                BNE     @psw_next
                LDA     _wt_opts
                AND     #WUNTRACED
                BEQ     @psw_next
                ; Already reported this stop?  SEF_STOPREPORTED in SE_Flags
                ; (seoff = (TCBoff-$0800)>>1).  If set, treat as alive (don't
                ; re-report) — that's what stops a WNOHANG|WUNTRACED poll loop
                ; from re-reporting the same stop forever.  X preserved.
                TXA
                SEC
                SBC     #FGX_TASK_TBL_OFF
                LSR
                CLC
                ADC     #SE_Flags
                TAY
                LDA     [_schedTblPtr],Y
                AND     #SEF_STOPREPORTED
                BNE     @psw_next                   ; already reported
                JMP     @psw_foundStopped           ; X = stopped child's TCB
@psw_next        TXA
                CLC
                ADC     #TCB_SIZE
                TAX
                ; Merlin32 evaluates expressions strictly left-to-right (no
                ; precedence); multiply first so the bound folds correctly.
                CPX     #TASK_MAX_SLOTS*TCB_SIZE+FGX_TASK_TBL_OFF
                BCC     @psw_L
                ; Scan complete: no zombie / stopped-reportable this pass.
                LDA     _wt_hasChild
                BNE     @psw_haveChild              ; P3-4 I3 grew the fn -> BEQ target OOR;
                BRL     @psw_noChild                ;   invert + long-branch to ECHILD
@psw_haveChild  ; A matching child is alive (or stopped w/o WUNTRACED).
                LDA     _wt_opts
                AND     #WNOHANG
                BEQ     @psw_block
                LDA     #0                          ; WNOHANG: nothing waitable yet
                SEC
                RTS
@psw_block       ; Block until a child changes state.  Preserve cross-block
                ; globals (a nested wait would clobber them) on our kernel stack.
                LDA     _wt_statusPtr
                PHA
                LDA     _wt_target
                PHA
                LDA     _wt_opts
                PHA
                LDA     _curTask
                JSR     Task_Lookup                 ; X = our TCB offset = wait chan
                TXA
                LDX     #PRIO_NORMAL                 ; pri (reserved)
                JSR     _sleep                       ; woken by a child's _exit / stop
                                                     ; C=1 -> a signal will act on
                                                     ; us: do NOT re-wait
                PLA                                  ; (PLA/STA set N+Z only, so
                STA     _wt_opts                     ;  _sleep's carry survives the
                PLA                                  ;  restore below)
                STA     _wt_target
                PLA
                STA     _wt_statusPtr
                BCC     @psw_reloop                  ; ordinary wake -> rescan
                ; Interrupted.  Returning EINTR here is what lets the signal be
                ; DELIVERED at all: delivery happens at syscall EXIT, so a wait
                ; that never returns never runs the handler.  Worse, _sleep also
                ; tests before blocking, so re-waiting with the signal still
                ; pending spins the tight loop @psw_rescan -> _sleep -> (C=1,
                ; never blocks) -> @psw_rescan, which HUNG THE MACHINE: measured
                ; 2026-08-04 as `kill -15 1` wedging the CPU inside
                ; _Sig_PendingActionable with init blocked in wait().  Pre-dates
                ; the SIGTERM/SIGHUP work; that work is only what first sent an
                ; actionable signal to a task parked in wait.  (Shells escaped it
                ; because the Bourne shell SIG_IGNs SIGINT while waiting on a
                ; foreground child, and an ignored signal is not actionable.)
                LDA     #EINTR
                CLC
                RTS
@psw_reloop     BRL     @psw_rescan             ; long: refactor pushed rescan OOR

@psw_foundStopped ; Stopped child under WUNTRACED (X = its TCB offset).  Report
                ; a WIFSTOPPED status (low byte $7F, WSTOPSIG = SIGTSTP) WITHOUT
                ; reaping — the task lives on, to be continued by SIGCONT.
                LDA:     TCB_TaskID,X
                AND     #$00FF
                STA     _wt_childPid
                ; Mark SEF_STOPREPORTED so this stop isn't reported again (a
                ; SIGCONT clears it).  X = child TCB; seoff = (TCBoff-$0800)>>1.
                TXA
                SEC
                SBC     #FGX_TASK_TBL_OFF
                LSR
                CLC
                ADC     #SE_Flags
                TAY
                LDA     [_schedTblPtr],Y
                ORA     #SEF_STOPREPORTED
                STA     [_schedTblPtr],Y
                ; WSTOPSIG is the signal that ACTUALLY stopped the child
                ; (apple/fgx#109).  This was `#{SIGTSTP*256}+$7F` -- a constant,
                ; so ^Z, a background tty read (SIGTTIN) and a background tty
                ; write (SIGTTOU) all reported 18 and a job-control shell could
                ; not tell them apart.  @disp_stop records it in the stopping
                ; task's u-area; X is still that child's TCB offset here, and
                ; _Uarea_FromTCB leaves X alone.
                JSR     _Uarea_FromTCB              ; X = child TCB -> _u
                BCC     @psw_fsDefSig               ; no u-area: fall back
                LDY     #U_StopSig
                LDA     [_u],Y
                AND     #$00FF
                BNE     @psw_fsHaveSig
@psw_fsDefSig   LDA     #SIGTSTP                    ; never recorded (pre-#109
                                                    ;   stop, or no u-area)
@psw_fsHaveSig  XBA                                 ; signal -> high byte
                ORA     #$007F                      ; WIFSTOPPED marker
                STA     _wt_status
                JSR     _waitpid_WriteStatus        ; X preserved (unused after)
                LDY     _wt_status                  ; P3-4 I3: also RETURN status in Y — the
                                                    ;   c_waitpid shim passes statusPtr=0 and
                                                    ;   stores this via the caller's real
                                                    ;   far-ptr (bank-0 local safe); hand-asm
                                                    ;   callers (jsh) keep the TCB_DataBank write
                LDA     _wt_childPid
                SEC
                RTS

@psw_foundZombie ; Found a zombie child (X = its TCB offset).  Stash pid+status.
                LDA:     TCB_TaskID,X
                AND     #$00FF
                STA     _wt_childPid
                LDA:     TCB_ExitCode,X
                STA     _wt_status
                JSR     _waitpid_WriteStatus
                ; Free zombie's TCB slot (bank already freed in _exit).
                LDX     _wt_childTCB
                JSR     Task_Free                   ; X = TCB offset
                LDY     _wt_status                  ; P3-4 I3: RETURN status in Y (see above)
                LDA     _wt_childPid
                SEC
                RTS

@psw_noChild     LDA     #ECHILD
                CLC
                RTS

;------------------------------------------------------------------------------
; _waitpid_WriteStatus - write _wt_status to the caller's *status_ptr (if any),
; using the PARENT's (_curTask) DataBank for the cross-bank store.  The status
; ptr is a caller-DBR offset, and a C process's DBR = its DATA bank (seg1 under
; FGX2; == the code bank under FGX1).  Using CodeBank wrote into seg0 under FGX2
; -> the shell's `wstat` global (seg1) stayed 0 -> $? was always 0.
; Entry: X = the child's TCB offset (saved to _wt_childTCB so the zombie path
;        can reload it for Task_Free), _wt_status = 16-bit status, _wt_statusPtr
;        = caller-bank offset (0 = skip).  MX %00.  Clobbers A/X/Y.
;------------------------------------------------------------------------------
_waitpid_WriteStatus MX %00
                STX     _wt_childTCB                ; preserve child TCB for caller
                LDA     _wt_statusPtr
                BEQ     @ws_done
                LDA     _curTask
                JSR     Task_Lookup                 ; X = parent TCB
                BCC     @ws_done
                SEP     #$20
                MX      %10
                LDA:     TCB_DataBank,X             ; caller's DATA bank (seg1 for
                                                    ; FGX2; == CodeBank for FGX1)
                STA     _libcTmp2+2
                REP     #$20
                MX      %00
                LDA     _wt_statusPtr
                STA     _libcTmp2
                LDA     _wt_status
                STA     [_libcTmp2]                 ; 16-bit store of status
@ws_done        RTS

;------------------------------------------------------------------------------
; _Sys_Setpgid (#80) - setpgid(pid, pgid): place a task in a process group.
;
; A = pid  (0 = the calling task), X = pgid (0 = use the (resolved) pid, i.e.
; "make pid a group leader").  Sets SE_PGroup[pid] = pgid.  The shell uses this
; to put each job's tasks in their own group so signals (^C/^Z, kill -pgid) and
; the tty foreground-group gate target a whole job.
;
; Returns C=1 + A=0 on success; C=0 + A=ESRCH if pid names no live task.
; MX %00.  DP-safe: writes SE_PGroup via _schedTblPtr (kernel DP handler).
;------------------------------------------------------------------------------
; _Spg_Permitted - may _curTask change the process group of the task whose TCB
; offset is in X?  C=1 = yes.  MX %00.  Clobbers A, X, Y.
;
; 2.11BSD's setpgrp() guard, in its own order:
;   root (effective uid 0)      -> always
;   same effective uid          -> yes
;   target is our descendant    -> yes  (BSD's inferior())
;   otherwise                   -> no
;
; A task with no u-area reads as uid 0 (root), which is the state
; Task_AllocUarea leaves and what every pre-credentials task already behaves
; as -- failing OPEN here would make setpgid stop working during boot, before
; init has credentials.
;------------------------------------------------------------------------------
_Spg_Permitted  MX      %00
                PHX                                 ; target TCB offset
                ; caller's effective uid
                JSR     _Uarea_Cur
                BCC     @spm_yes                    ; no u-area -> root
                LDY     #U_Uid
                LDA     [_u],Y
                AND     #$00FF
                STA     _spg_uid
                BEQ     @spm_yes                    ; uid 0: root may always
                ; target's effective uid
                PLX
                PHX
                JSR     _Uarea_FromTCB
                BCC     @spm_yes                    ; no u-area -> root-ish
                LDY     #U_Uid
                LDA     [_u],Y
                AND     #$00FF
                CMP     _spg_uid
                BEQ     @spm_yes                    ; same owner
                ; inferior(): walk the target's parent chain up to us.  Bounded
                ; by the slot count -- a corrupted ParentID cycle must not hang
                ; the kernel, and pid 1's parent is itself.
                PLX
                PHX
                LDA     #TASK_MAX_SLOTS
                STA     _spg_walk
@spm_up         LDA:    TCB_ParentID,X
                AND     #$00FF
                BEQ     @spm_no                     ; no parent -> not ours
                CMP     _curTask                    ; reached us?
                BEQ     @spm_yes
                CMP     #1
                BEQ     @spm_no                     ; hit init, and it is not us
                JSR     Task_Lookup                 ; X = that parent's TCB
                BCC     @spm_no
                DEC     _spg_walk
                BNE     @spm_up
@spm_no         PLX
                CLC
                RTS
@spm_yes        PLX
                SEC
                RTS

;------------------------------------------------------------------------------
; _Se_CurUid - A = _curTask's EFFECTIVE uid, 0 when there is no u-area.
; MX %00.  Clobbers A, X, Y.
;
; apple/fgx#108 T3.  BSD's `u.u_uid', which ttioctl reads four times -- TIOCSTI
; twice and TIOCSPGRP twice -- as another bank can ask for it.
;
; ZERO MEANS ROOT AND THAT IS THE EXISTING CONVENTION, not a new one: a task
; with no u-area reads as uid 0 here exactly as it does inside _Spg_Permitted
; above, which is the state Task_AllocUarea leaves and what every
; pre-credentials task already behaves as.  It lands the permissive way in both
; of ttioctl's tests, which is what upstream does for the superuser.
;------------------------------------------------------------------------------
_Se_CurUid      ENT
                MX      %00
                JSR     _Uarea_Cur
                BCC     @scu_root
                LDY     #U_Uid
                LDA     [_u],Y
                AND     #$00FF
                RTS
@scu_root       LDA     #0
                RTS

;------------------------------------------------------------------------------
; _Se_SpgOk - may _curTask hand a tty to process group `pgrp'?
; In: A = pgrp.  Out: C=1 permitted, C=0 refuse with EPERM.  MX %00.
;
; apple/fgx#108 T3.  THE WHOLE OF upstream's TIOCSPGRP OWNERSHIP TEST, and it
; is one call rather than three because the pieces are already here.  2.11BSD
; tty.c:539-548 spells it:
;
;     p = pfind(pgrp);
;     if (p && p->p_pgrp == pgrp &&
;         p->p_uid != u.u_uid && u.u_uid && !inferior(p))
;             return (EPERM);
;
; `pfind' IS Task_Lookup, and the trailing three conjuncts ARE _Spg_Permitted
; inverted -- that routine's header quotes the identical guard out of 2.11BSD's
; kern_prot.c setpgrp, with the same bounded inferior() walk.  So the tty bank
; needs neither pfind nor inferior ported into it, which is what the closure
; scan's seam list had wrongly implied.
;
; THE TWO EARLY EXITS ARE UPSTREAM'S OWN, not shortcuts.  A pgrp naming no live
; task makes `p' NULL, and a task whose own group has since moved fails
; `p->p_pgrp == pgrp'; upstream permits both, because its conjunction is false.
; Answering "permitted" for a group nobody is in is deliberate upstream and its
; comment says so -- "SHOULD VERIFY THAT PGRP IS IN USE AND IS THIS USER'S".
;------------------------------------------------------------------------------
_Se_SpgOk       ENT
                MX      %00
                AND     #$00FF
                BEQ     @sso_ok                 ; pgrp 0 names no task at all
                PHA                             ; keep pgrp; A is the argument
                JSR     Task_Lookup             ; X = its TCB, C=1 found
                BCC     @sso_okPull             ; pfind() == NULL -> permitted
                LDA     1,S
                JSR     _SE_PGroupOf            ; A = its group; X survives
                CMP     1,S
                BNE     @sso_okPull             ; p->p_pgrp != pgrp
                PLA
                JMP     _Spg_Permitted          ; tail call: C=1 = permitted
@sso_okPull     PLA
@sso_ok         SEC
                RTS

;------------------------------------------------------------------------------
_Sys_Setpgid    ENT
                MX      %00
                AND     #$00FF
                STA     _spg_pid                    ; pid (0 = caller)
                BNE     @spg_havePid
                LDA     _curTask
                AND     #$00FF
                STA     _spg_pid
@spg_havePid    TXA
                AND     #$00FF
                BNE     @spg_havePgid
                LDA     _spg_pid                    ; pgid 0 -> use pid
@spg_havePgid   STA     _spg_pgid
                ; Validate the pid is a live task.
                LDA     _spg_pid
                JSR     Task_Lookup
                BCS     @spg_perm                   ; live -> permission check
                LDA     #ESRCH
                CLC
                RTS
@spg_perm       ; --- PERMISSION (apple/fgx#73) ---
                ;     if (p->p_uid != u.u_uid && u.u_uid && !inferior(p))
                ;         u.u_error = EPERM;
                ;                       -- 2.11BSD kern_prot.c setpgrp()
                ; Three ways to be allowed: you are root, the target is yours,
                ; or the target is your descendant.  FGX had NO check at all --
                ; any process could move any other into any group, including
                ; into the foreground group of a tty it does not own, which
                ; then routes that tty's ^C and ^Z to it.  BSD's own comment on
                ; that line reads "need better control mechanisms for process
                ; groups", so this is a floor rather than a model.
                ;
                ; Task_Lookup above left X = the TARGET's TCB offset; keep it.
                PHX
                JSR     _Spg_Permitted
                PLX
                BCS     @spg_ok
                LDA     #EPERM
                CLC
                RTS
@spg_ok         ; SE_PGroup[pid] = pgid.  seoff = (pid-1) << 5.
                LDA     _spg_pid
                AND     #$00FF
                DEC
                ASL
                ASL
                ASL
                ASL
                ASL
                CLC
                ADC     #SE_PGroup
                TAY
                LDA     _spg_pgid
                STA     [_schedTblPtr],Y
                LDA     #0
                SEC
                RTS

;------------------------------------------------------------------------------
; _Sys_Getpgrp (#81) - getpgrp(pid): return THAT process's group.  A = pid,
; 0 meaning the caller.  C=1 + A = SE_PGroup; C=0 + A = ESRCH if the pid names
; no live task.  MX %00.
;
;     if (uap->pid == 0) uap->pid = u.u_procp->p_pid;
;     p = pfind(uap->pid);
;     if (p == 0) { u.u_error = ESRCH; return; }
;     u.u_r.r_val1 = p->p_pgrp;
;                       -- 2.11BSD kern_prot.c getpgrp()
;
; THE PID ARGUMENT IS REAL IN BSD, and used to be ignored here: this reported
; the CALLER's group whatever was passed, so libc had to reject a non-self pid
; with ESRCH rather than answer wrongly (wait.c).  That made "what group is my
; child in?" unaskable, which is a question apple/fgx#60 turns on.  BSD answers
; it for any live process, so FGX does now too.
;------------------------------------------------------------------------------
_Sys_Getpgrp    ENT
                MX      %00
                AND     #$00FF                      ; A = pid arg
                BNE     @gpg_havePid
                LDA     _curTask                    ; 0 -> the caller
                AND     #$00FF
@gpg_havePid    BNE     @gpg_lookup
                LDA     #0                          ; no task at all (boot)
                SEC
                RTS
@gpg_lookup     PHA                                 ; Task_Lookup clobbers A
                JSR     Task_Lookup                 ; C=1 iff a live task
                PLA
                BCS     @gpg_have
                LDA     #ESRCH
                CLC
                RTS
@gpg_have       JSR     _SE_PGroupOf                ; A = SE_PGroup of that pid
                SEC
                RTS

;==============================================================================
; (slice-3 B.1 retired _Sys_SetArg / _Sys_GetArg — kernel transports argv/envp
; on the child's stack via _Loader_StageArgs.  Slot 44/45 in the syscall
; table now point at _Sys_Stub which returns ENOSYS.)
;==============================================================================

;==============================================================================
; Module locals.
;==============================================================================
_ps_childTCB    DS      2
_vf_childTCB    DS      2                       ; vfork: child TCB offset
_vf_childPid    DS      2                       ; vfork: child pid (pre-block)
_vf_parentTCB   DS      2                       ; vfork: parent TCB offset
_vf_childSe     DS      2                       ; vfork: child sched-entry off
; _Sys_ExecveVfork borrowed-field saves (V2).  Written before the first
; possible block, consumed only on this task's own failure paths.
_ev_oldDP       DS      2                       ; TCB_DirectPage (the caller's,
                                                ; or the parent's for a child)
_ev_oldStkBank  DS      2
_ev_oldStkPtr   DS      2
_ev_oldStkBase  DS      2
_ev_oldStkSize  DS      2
_ev_oldCode     DS      2
_ev_oldData     DS      2                       ; DataBank + Reserved1 byte pair
_ev_oldEntry    DS      2
_ev_oldSavedS   DS      2
_ev_newText     DS      2                       ; the text the new image runs
_ev_oldBankList DS      8                       ; #14: the whole owned-bank set.
                                                ; TCB_DataBank can name an EXTRA
                                                ; (StageArgs persists the real
                                                ; data bank), so Code+Data is not
                                                ; the ownership list -- freeing
                                                ; from those two alone would leak
                                                ; every other bank of a multibank
                                                ; image on each `exec`, and tcsh
                                                ; carries seven.
_ev_isChild     DS      2                       ; #14: SEF_VFORKCHILD/SNAPCHILD
                                                ; sampled at ENTRY -- the commit
                                                ; clears them before the last
                                                ; place that needs to know.
; _Sys_Brk syscall-lifetime scratch (Stage S; no blocking in the handler).
_sb_arg         DS      2                       ; A in: the new break offset
_sb_bankArg     DS      2                       ; Y in: bank to validate
_sb_bank        DS      2                       ; the task's sbrk bank
_sb_old         DS      2                       ; break before the call
_sb_new         DS      2                       ; break after the call
_sb_sfp         DS      2                       ; soft-stack floor = the break's
                                                ; real ceiling ($FFFF if none)
; fork/snapshot engine (Stage F) statics.  _fs_desc is the descriptor
; long-ptr's TRUTH; _Fork_LdDesc reloads it into the _kmallocResult DP
; cell after every allocator call.  All consumed within one syscall.
_vf_mode        DS      2                       ; 0 = vfork, 1 = snapshot fork
_vf_sigPar      DS      2                       ; fork signal inheritance (#27/#54):
_vf_sigChd      DS      2                       ;   parent/child table indices and
_vf_sigBase     DS      2                       ;   the walking table base
_fs_desc        DS      4                       ; descriptor long ptr (3B + pad)
_ib_hdr         DS      FSD_HDR                 ; a bank-home header, copied in
_ib_desc        DS      4                       ;   ...and where it lives
_ib_pid         DS      2                       ; the member being moved/freed
_ib_i           DS      2                       ; pair index
_ib_pair        DS      2                       ; lo = orig, hi = spare
_ib_w           DS      2                       ; a word read from a home
_ib_sfp         DS      2                       ; the soft-stack top in play
_ib_brk         DS      2                       ; the data bank's end in play
_ib_lim         DS      2                       ; the data bank's heap limit in play
_ib_want        DS      2                       ; _Img_Find: 0 holder, 1 homed
_ix_stop        DS      2                       ; _Img_Xchg: one past the end
_ho_exec        DS      2                       ; Img_HandOff: 1 = from exec
_ex_wasVfork    DS      2                       ; exit: the dying task was a
                                                ;   vfork child (in no group)
_ho_heir        DS      2                       ;   the heir's TCB
_ho_heirPid     DS      2                       ;   ...and pid
_ho_old         DS      2                       ;   the leaver's pid
_ho_next        DS      2                       ;   row cursor
_ho_base        DS      2                       ;   the stack base given away
_ho_bl          DS      8                       ;   the bank list given away
_il_bank        DS      2                       ; _Img_Leave: the group's data bank
_il_tcb         DS      2                       ;   the leaver
_il_n           DS      2                       ;   members left
_il_last        DS      2                       ;   ...the last one seen (TCB)
_il_pid         DS      2                       ;   ...and its pid
_fs_orig        DS      2                       ; copy-pair scratch: live bank
_fs_spare       DS      2                       ; copy-pair scratch: spare bank
_fs_nPair       DS      2                       ; pairs recorded so far (also the
                                                ;   unwind's count -- the two must
                                                ;   never disagree, so _Fork_AddPair
                                                ;   is the only writer)
_fs_bigRow      DS      2                       ; block-table walk cursor (#11):
                                                ;   a static because Bank_Alloc and
                                                ;   the bank copy clobber the
                                                ;   allocator scratch it rides in
_fs_bigCnt      DS      2                       ; banks left in the current block
_fs_end         DS      2                       ; the pair's last offset ($FFFF
                                                ;   but for the data bank's)
_fs_start       DS      2                       ; the pair's live floor: 0 for a
                                                ;   whole bank, the parent's _fcc_sfp
                                                ;   for the soft-frame one
_fcr_src        DS      4                       ; _Fork_CopyRange source bank:offset
_fcr_dst        DS      4                       ;   ... destination, and the byte
_fcr_len        DS      2                       ;   count.  3-byte pointers, padded
                                                ;   to 4 so a 16-bit store to the
                                                ;   offset cannot reach the bank.
_ps_childPid    DS      2
_ps_seParent    DS      2               ; spawn ctty/pgrp inheritance: parent SE
_ps_seChild     DS      2               ;   base, child SE base, and one staged
_ps_seCtty      DS      2               ;   field in transit (apple/fgx#51)
_ps_childBank   DS      2
_ps_savedErr    DS      2
_ps_argBlk      DS      2               ; caller's arg-block offset ...
_ps_argBlkBank  DS      2               ;   ... and its bank (low byte)
_K_StkOflowMsg  ASC     'stack overflow',00
_K_HeapFullMsg  ASC     'heap exhausted',00
_K_ForkFailMsg  ASC     'fork refused: errno ',00
_K_StkOflowSys  ASC     ' (syscall floor)',00
_K_StkOflowSoft ASC     ' (soft frame)',00
_K_StkOflowSfp  ASC     ' sfp=$',00
_K_StkOflowPid  ASC     ': killed pid $',00
_ps_fdActionsPtr DS     2

_afa_savedFdtab DS      4               ; 3-byte parent fdtab ptr + 1 pad
_afa_savedErr   DS      2
_afa_listPtr    DS      4               ; 3-byte caller-bank long ptr + 1 pad
_afa_op         DS      2
_afa_fd         DS      2
_afa_arg1       DS      2
_afa_arg2       DS      2
_afa_newFd      DS      2
_afa_srcOff     DS      2
_afa_dstOff     DS      2
_afa_tmp3       DS      4               ; 3-byte slot scratch + 1 pad

_ex_encStatus   DS      2
_ex_childPid    DS      2
_ex_parentPid   DS      2
_ex_freeBanksTCB DS     2               ; saved X across _Task_FreeBanks

_wt_statusPtr   DS      2
_wt_myPid       DS      2

_wt_childPid    DS      2
_wt_status      DS      2
_wt_childTCB    DS      2
_wt_hasChild    DS      2               ; wait(): nonzero if a live child exists
_wt_target      DS      2               ; waitpid: target pid ($FFFF = any child)
_wt_opts        DS      2               ; waitpid: WNOHANG | WUNTRACED

_spg_pid        DS      2               ; setpgid: resolved target pid
_spg_uid        DS      2                       ; #73: caller's effective uid
_spg_walk       DS      2                       ; #73: inferior() walk bound
_spg_pgid       DS      2               ; setpgid: resolved process-group id
