;==============================================================================
;
; FGX - Flux GS uniX
;
; File:     far.s
; Purpose:  Far kernel bank segment root
; Created:  2026-08-01
;
; The SECOND statically linked kernel image.  Subsystems that do not need to sit
; in the core kernel bank live here and are reached by cross-bank JSL through the
; export table at KFAR_EXPORT_BASE.
;
; NOT an FGXM module.  It is loaded by stage 2 before the filesystem exists, and
; it may call Kmalloc and _sleep -- both forbidden to modules.  It is module
; SHAPED (own DBR via PHK/PLB, core statics by scraped offset), so promoting a
; subsystem out of here into a real module later is a link change, not a rewrite.
;
; BANK-AGNOSTIC.  This file ORGs at FGX_KFAR_CODE ($08:0000) for assembly only,
; exactly as a module ORGs at $05.  At runtime the image lives in the kernel
; handle's headroom bank (live kernel bank + 1) and every entry point does
; PHK/PLB so DBR becomes whatever bank it was actually loaded into.
;
; See docs/history/plans/far-kernel-bank.md.
;
;==============================================================================

                MX      %00             ; 16-bit A, X, Y (native mode default)

                PUT     ../../../include/config.s
                PUT     ../../../include/hardware.s
                PUT     ../../../include/kernel.s
                PUT     ../../../include/errno.s
                PUT     ../../../include/macros.s
                PUT     ../../../include/dpmap.s        ; DUM $00 block: DP offsets only,
                                                ;   emits no bytes.  DP is reached
                                                ;   through D, not DBR, so these
                                                ;   resolve identically in either bank.
;--- memmap.s is DUM-only (emits no bytes).  Needed here for the bank-$03
;--- framebuffer addresses (CON_CHARBUF/ATTRBUF/FGBUF/BGBUF) and the other
;--- absolute regions the console reaches by LDAL, which are bank-correct from
;--- either bank.  CAUTION: it also names the CORE kernel's bank-$02 statics --
;--- those must be reached with a _cfp-marked LDAL, never `LDA |sym`, or they
;--- resolve against the FAR bank at the same offset.
                PUT     ../../../include/memmap.s
                PUT     ../../../include/console.s
                PUT     ../../../include/kfar.s
                PUT     ../../../include/loader.s       ; FGX1_/FGX2_ header shapes
                PUT     ../../../include/fgxm.s         ; FGXM_HEADER_SZ, FGXM_OFF_*
                PUT     ../../../include/fs.s           ; SEEK_*, FS_* -- loader.s seeks

;--- The kernel-C seam: fcc's direct-page slot map, and the asm->C boundary
;--- macros.  Both are EQU/MAC only and emit nothing here.  fcc_dp.s is
;--- GENERATED from the compiler's own copy (tools/gen_fcc_dp.py) so the two
;--- cannot drift; a DP slot that moved on one side only would miscompile into
;--- its neighbour with no diagnostic.
                PUT     fcc_dp.s
                PUT     ../../../include/kernelc.s
                ; VT_* tags and the VFSCORE_* ordinals -- UFS 1.7d's inward
                ; seam resolves VT_VFSCORE and indexes its table from here.
                ; EQUs only; emits no bytes.
                PUT     ../../../include/modules.s
                ; GENERATED from the C headers: VFS_FILE_BYTES sizes the
                ; open-file table's static below, so the far bank has no second
                ; copy of the arithmetic finit relies on.
                PUT     ../../../include/vfs_equ.s

                ORG     FGX_KFAR_CODE

;==============================================================================
; The export table.  FIRST thing in the bank -- see include/kfar.s for why.
;
; Slots are JMP abs16 and are NEVER patched: the caller's JSL has already set
; PBR to this bank, so a 16-bit JMP lands correctly.
;
; Every unassigned slot jumps to _Far_StubHalt rather than falling through, so
; an accidental call fails loudly instead of executing whatever follows.
;==============================================================================
                DW      KFAR_MAGIC              ; +0  'FK'
                DW      KFAR_ABI_VERSION        ; +2
                DW      0                       ; +4  reserved

                ; --- slot 0: the init entry ---
                JMP     Far_BankInit
                DFB     0

                ; --- slots 1-3: sound ---
                JMP     Sound_Init
                DFB     0
                JMP     Sound_StopDoc
                DFB     0
                JMP     Sound_Beep
                DFB     0

                ; --- slots 4-7: BRAM real-time clock ---
                JMP     _KCaptureBootTime
                DFB     0
                JMP     _Sys_Uptime
                DFB     0
                JMP     _Sys_RtcRead
                DFB     0
                JMP     _Far_StubHalt           ; slot 7: unassigned
                DFB     0

                ; --- slot 8: boot-state reporting ---
                JMP     Far_LogState
                DFB     0

                ; --- slot 9: boot chime (gated internally) ---
                JMP     Far_BootChime
                DFB     0

                ; --- slots 10-23: console driver ---
                JMP     _fw_Con_Init
                DFB     0
                JMP     _fw_Con_Write
                DFB     0
                JMP     _fw_Con_WriteBuf
                DFB     0
                JMP     _fw_Con_PutChar
                DFB     0
                JMP     _fw_Con_CR
                DFB     0
                JMP     _fw_Con_PollKey
                DFB     0
                JMP     _fw_Con_GetKey
                DFB     0
                JMP     _fw_Con_RenderAll
                DFB     0
                JMP     _fw_Con_ShowCursor
                DFB     0
                JMP     _fw_Con_HideCursor
                DFB     0
                JMP     _fw__Con_InitSCBs
                DFB     0
                JMP     _fw__Con_InstallPalettes
                DFB     0
                JMP     _fw_Con_LoadFontFromFile
                DFB     0
                JMP     _fw_Con_RevertToDefault
                DFB     0

                ; --- slot 24: virtual console switch (slice D) ---
                JMP     _fw_Con_SwitchVC
                DFB     0

                ; --- slots 25-26: background-VC write bracket (slice D) ---
                JMP     _fw_Con_EnterVC
                DFB     0
                JMP     _fw_Con_LeaveVC
                DFB     0

                ; --- slot 27: kernel C, only in a KCPROBE debug kernel ---
                ; The SLOT always exists -- slot addresses are EQUs the core
                ; bakes into its JSL operands, so the table's shape must not
                ; depend on a build flag.  Only its target changes: the halt
                ; stub when there is no C to reach, the same contract every
                ; other unassigned slot gets.
                DO      KCPROBE=1
                JMP     kc_probe                ; C, reached direct (no shim)
                FIN
                DO      KCPROBE=0
                JMP     _Far_StubHalt
                FIN
                DFB     0

                ; --- slots 28-30: RETIRED with the VFS, 2026-08-12 ---
                ; They were bufinit, vfs_probe and vfs_init.  The VFS is
                ; vfs.mod now and brings itself up at module load, so the core
                ; has nothing to call: these are not forwarding anywhere, they
                ; are unused.
                ;
                ; STUBBED RATHER THAN REMOVED, and that is the table's standing
                ; rule: slot addresses are EQUs the core bakes into its JSL
                ; operands, so the table's SHAPE is ABI.  Closing a gap would
                ; renumber every slot above it.  A stale caller gets the halt
                ; stub -- a red border -- rather than whatever moved up.
                JMP     _Vfs_SeamEntry          ; slot 28: THE INWARD SEAM
                DFB     0
                JMP     _Vfs_DescAlloc          ; slot 29: descriptor service
                DFB     0
                JMP     _Vfs_DescFree           ; slot 30: descriptor service
                DFB     0

                ; --- slot 31: the open-file table's carve (UFS 1.7d I2b) ---
                ; Called from main.s right after Far_Init, long before any
                ; module loads -- see _Vfs_FileInit for why that ordering is
                ; the requirement rather than a convenience.
                JMP     _Vfs_FileInit           ; slot 31
                DFB     0

                ; --- slots 32/33: the file table's fork and teardown (I2b) ---
                ; The core bank inherits and frees the KERNEL fd table at two
                ; places (_Task_CopyParentFds, Task_FreeFdTable); these are the
                ; file table making the same two moves from the same two
                ; places, so the pair of tables cannot drift apart.
                JMP     _Vfs_DescCopy           ; slot 32
                DFB     0
                JMP     _Vfs_DescFreeAll        ; slot 33
                DFB     0

                ; --- slots 34/35: the mirror's last two writers (I2c) ---
                JMP     _Vfs_DescDup            ; slot 34
                DFB     0
                JMP     _Vfs_DescMove           ; slot 35
                DFB     0

                ; --- slot 36: sync(2)'s mount-list walk (apple/fgx#332) ---
                JMP     _Vfs_Sync               ; slot 36
                DFB     0

                ; --- slot 37: the shutdown sync (apple/fgx#403) ---
                JMP     _Vfs_SyncClean          ; slot 37
                DFB     0

                ; --- slot 38: the /dev syscall hook (UFS 1.7d I3) ---
                ; The first far slots on a hot path.  See include/kfar.s.
                JMP     _Vfs_DevRW              ; slot 38
                DFB     0

                ; --- slots 39-42: the FGX binary loader (phase 3) ---
                ; Each is a PHB/PHK/PLB wrapper around the RTS body, not the
                ; body itself: the *Impl split far.s's own header prescribes,
                ; so a far-bank neighbour can still JSR the routine while the
                ; core reaches it by JSL.  All four take their arguments in
                ; registers, so the bracket needs no argument copy.
                JMP     _Far_LoadBinary         ; slot 39
                DFB     0
                JMP     _Far_LoaderArgsPages    ; slot 40
                DFB     0
                JMP     _Far_LoaderStageArgs    ; slot 41
                DFB     0
                JMP     _Far_LaSetStageBase     ; slot 42
                DFB     0
                JMP     _Vfs_DevIoctlSel        ; slot 43
                DFB     0

                ; --- slot 44: the ROOT mount (UFS 2.4b) ---
                JMP     _Vfs_RootMount          ; slot 44
                DFB     0

                ; --- slot 45: an open against the ROOT (UFS 2.4) ---
                ; THE PAD IS PART OF THE SLOT.  A JMP is three bytes and the
                ; stride is four, so a slot inserted between a JMP and its DFB
                ; shifts every later byte by one and the ERR below cannot see
                ; it -- the total is unchanged.  Keep the pair together.
                JMP     _Vfs_RootOpen           ; slot 45
                DFB     0
                JMP     _Vfs_RootStat           ; slot 46
                DFB     0
                ; --- slot 47: a directory READ against the root ---
                JMP     _Vfs_RootListdir        ; slot 47
                DFB     0
                ; --- slot 48: chdir against the root (the cwd port) ---
                JMP     _Vfs_RootChdir          ; slot 48
                DFB     0
                ; --- slots 49-50: the cwd's fork and exit halves ---
                JMP     _Vfs_CdirFork           ; slot 49
                DFB     0
                JMP     _Vfs_CdirExit           ; slot 50
                DFB     0

                ; --- slot 51: the userland module loader's streaming install ---
                JMP     _Far_ModLoad            ; slot 51
                DFB     0

                ; --- slots 52-54: the root's namespace operations ---
                JMP     _Vfs_RootUnlink         ; slot 52
                DFB     0
                JMP     _Vfs_RootMkdir          ; slot 53
                DFB     0
                JMP     _Vfs_RootRmdir          ; slot 54
                DFB     0

                ; --- slot 55: lseek against a root descriptor ---
                JMP     _Vfs_Lseek              ; slot 55
                DFB     0

                ; --- slot 56: lstat against the root ---
                JMP     _Vfs_RootLstat          ; slot 56
                DFB     0

                ; --- slot 57: readlink against the root ---
                JMP     _Vfs_RootReadlink       ; slot 57
                DFB     0

                ; --- slot 58: rename against the root ---
                JMP     _Vfs_RootRename         ; slot 58
                DFB     0

                ; --- slot 59: symlink against the root ---
                JMP     _Vfs_RootSymlink        ; slot 59
                DFB     0

                ; --- slot 60: statfs against the root ---
                JMP     _Vfs_RootStatfs         ; slot 60
                DFB     0

                ; --- slot 61: getfsstat over the mount list ---
                JMP     _Vfs_Getfsstat          ; slot 61
                DFB     0

                ; --- slot 62: chmod/chown against the root ---
                JMP     _Vfs_RootSetattr        ; slot 62
                DFB     0

                ; --- slot 63: link(2) against the root ---
                JMP     _Vfs_RootLink           ; slot 63
                DFB     0

                ; --- slot 64: mount(2) ---
                JMP     _Vfs_Mount              ; slot 64
                DFB     0

                ; --- slot 65: umount(2), by device ---
                JMP     _Vfs_UnmountDev         ; slot 65
                DFB     0

                ; --- slot 66: ftruncate(2) ---
                JMP     _Vfs_Ftruncate          ; slot 66
                DFB     0

                ; --- slot 67: utimes(2) ---
                JMP     _Vfs_Utimes             ; slot 67
                DFB     0

                ; --- slot 68: fchdir(2) ---
                JMP     _Vfs_Fchdir             ; slot 68
                DFB     0
                JMP     _Vfs_Access             ; slot 69
                DFB     0
                ; --- slot 70: fsync(2) ---
                JMP     _Vfs_Fsync              ; slot 70
                DFB     0
                ; --- slot 71: fstat(2) ---
                JMP     _Vfs_RootFstat          ; slot 71
                DFB     0
                ; --- slot 72: sysctl(2) ---
                JMP     _Vfs_Sysctl             ; slot 72
                DFB     0
                ; --- slot 73: a module registers a console renderer ---
                JMP     _Far_ConSetBackend      ; slot 73
                DFB     0

                ; --- slot 74: an AF_UNIX socket's name ---
                JMP     _Vfs_UnpName            ; slot 74
                DFB     0

                ; --- slot 75: the blocked-signal mask (#102 and #120) ---
                JMP     _Sys_SigProcMaskFar     ; slot 75
                DFB     0

                ; --- slot 76: setitimer(2), ITIMER_REAL (#121) ---
                JMP     _Sys_SetITimerFar       ; slot 76
                DFB     0

                ; --- slot 77: flock(2) ---
                JMP     _Vfs_Flock              ; slot 77
                DFB     0

                ; --- slot 78: fchmod(2), fchown(2) ---
                JMP     _Vfs_Fsetattr           ; slot 78
                DFB     0

                ; --- slots 79-80: a console write's counted scrolls ---
                JMP     _fw_Con_WriteArm        ; slot 79
                DFB     0
                JMP     _fw_Con_WriteDone       ; slot 80
                DFB     0

                ; --- slots 81.. unassigned, stride 4 (3-byte JMP + 1 pad) ---
                LUP     KFAR_SLOT_COUNT-81
                JMP     _Far_StubHalt
                DFB     0
                --^
                ; THE TABLE MUST BE EXACTLY ITS RESERVATION, and this is the only
                ; thing that says so.  A LUP with a negative count emits NOTHING
                ; and merlin does not complain, so when the assigned slots outgrew
                ; KFAR_SLOT_COUNT the stubs above silently stopped existing and a
                ; call past the last assigned slot ran the next routine in the
                ; bank from its first instruction (apple/fgx#210).  Non-zero here
                ; means the assigned slots have overrun the reservation: raise
                ; KFAR_SLOT_COUNT in include/kfar.s.
                ERR     *-{FGX_KFAR_CODE+KFAR_TABLE_SZ}

;------------------------------------------------------------------------------
; THE TABLE MUST BE AT IMAGE OFFSET 0, AND MERLIN CANNOT CHECK THAT.
;
; Merlin32 does not pad between ORGs -- it emits only real bytes -- so a single
; byte emitted by any file PUT before the `ORG FGX_KFAR_CODE` above prepends
; itself to the image and shifts the whole table down by one, while the slot
; EQUs the core kernel bakes into its JSL operands do not move.  Every export
; then lands one byte into the wrong instruction, in a bank the core cannot see
; into.  Measured, not imagined: a routine briefly drafted in
; include/kernelc.s emitted at 08/0006, the same address as export slot 0, and
; the build stayed green.
;
; An `ERR *-{FGX_KFAR_CODE+KFAR_TABLE_SZ}` here CANNOT catch it, and was tried:
; the explicit ORG resets the address counter, so the addresses are all
; correct and only the file offset is wrong.  The invariant is about the
; IMAGE, so the guard has to read the image -- tools/check_kernel_ceiling.py
; asserts that bin/fgxfar.bin opens with KFAR_MAGIC.
;------------------------------------------------------------------------------

;==============================================================================
; _Far_StubHalt - an unassigned export slot was called.
;
; Red border and halt.  Same loud-failure contract the kernel's
; _Phase1_StubHalt gives an unwired MOD_JT slot: a wild cross-bank jump must be
; obvious on the screen, not a silent wrong-execution.
;==============================================================================
;==============================================================================
; _KZeroRegion - zero A bytes starting at X, IN THE FAR BANK.
;
; Deliberately shadows the core kernel's routine of the same name so the shared
; _ZeroBankRegion macro (include/macros.s) resolves here without a far-local
; macro variant.  The two are separate assembly units, so this is a shadow, not
; a redefinition.
;
; It cannot simply call the core one: that version patches its MVN banks from
; KFGX_ANCHOR, the live KERNEL bank, so it zeroes core-bank memory by
; construction.  The console regions it is used on (CON_VT_STATE, CON_EXPAND,
; _conMode, ...) moved here, so the banks must come from PHK instead.
;
; In:  X = start offset, A = byte count.  MX %00.
; Out: flags/regs per the core version; DBR left as the far bank by the MVN.
;==============================================================================
_KZeroRegion    PHP
                REP     #$30
                MX      %00
                PHX                             ; save start (MVN source)
                PHA                             ; save count
                SEP     #$20
                MX      %10
                PHK
                PLA                             ; A.lo = THIS bank (vs KFGX_ANCHOR)
                STA     @fzr_mvn+1              ; patch MVN dest bank byte
                STA     @fzr_mvn+2              ; patch MVN source bank byte
                PHA
                PLB                             ; DBR = far bank (for the STZ)
                STZ:    $0000,X                 ; zero first byte (force-abs)
                REP     #$30
                MX      %00
                PLA                             ; A = count
                DEC
                DEC                             ; MVN moves A+1 = count-1 bytes
                PLX                             ; X = start (MVN source)
                TXY
                INY                             ; Y = start+1 -> propagate the 0
@fzr_mvn        MVN     $00,$00                 ; banks patched above
                PLP
                RTS

_Far_StubHalt   SEP     #$20
                MX      %10
                LDA     #$01
                STAL    $E0C034                 ; border = red
@spin           BRA     @spin

;==============================================================================
; Far_BankInit - patch every far-side cross-bank operand bank byte to the CORE
; bank, then return.
;
; Reached as `JSL <farbank>:KFAR_INIT` (slot 0) from the core kernel's Far_Init.
;
; In:   A = core bank number in the low byte.  MX %00.
; Out:  C=1 on success.  A/X/Y clobbered.  DBR restored to the caller's.
;==============================================================================
Far_BankInit    MX      %00
                PHB
                PHK
                PLB                     ; DBR = far bank, to reach our own tables

                ; --- ZERO THIS BANK'S STATICS, which nothing did before.
                ;
                ; The core kernel sweeps its whole globals region in
                ; `_KMem_ClearGlobals'; this bank only ever zeroed five console
                ; sub-regions from Con_Init, so the rest of the DUM block --
                ; and every loader output -- started as whatever the RAM held.
                ; A DUM emits no image bytes, so unlike fcc's uninitialised C
                ; globals (which reach the image as zeros) there is nothing to
                ; load over them.  MAME zero-fills and hardware does not, which
                ; is why this was invisible: apple/fgx#360.
                ;
                ; `Load_Binary' already STZ'd `_ldExtraBanks' by hand at the top
                ; of every load for exactly this reason; that guard predates the
                ; sweep and is now redundant rather than load-bearing.
                ;
                ; THE BOOT FONT IS NOT IN EITHER RANGE, deliberately.  Stage 2
                ; stages `_conBootFont' into this bank BEFORE the kernel runs, so
                ; zeroing it here would throw away the glyphs the boot screen is
                ; about to draw with.
                ;
                ; HERE IS THE ONLY PLACE IT CAN GO: Far_Init is main.s:300, before
                ; the console, the heap or the filesystem exist, and the canary
                ; seeding below would be wiped by a sweep that ran after it.
                PHA                     ; the core bank; the zeroer clobbers A
                _ZeroBankRegion FGX_KFAR_DATA;KMem_FarDum_end
                _ZeroBankRegion KFAR_LD_ORG;KMem_LdOut_end
                PLA

                ; --- Re-bank every far-side cross-bank operand to the CORE bank.
                ;     _CorePatchTbl (generated: core_patchsites.s) lists each
                ;     operand BANK byte's in-far-bank offset; we overwrite each
                ;     with the core bank passed in A.  Same shape and same walk
                ;     as Con_Init's _ConBankPatchTbl loop (console_init.s:37).
                ;
                ;     The table is EMPTY until the first far->core call site
                ;     exists (phase 3): _CorePatchBytes is then 0, the CPX/BCC
                ;     fails on the first pass and the body never runs.  The call
                ;     path itself is still exercised, which is the part that
                ;     would otherwise fail silently later.
                ;     No 24-bit pointer is needed here, unlike Con_Init's version.
                ;     Con_Init patches the KERNEL bank from the kernel bank and
                ;     still needs [dp] because its scratch is a DP cell; here DBR
                ;     is ALREADY this bank and the sites are IN this bank, so a
                ;     plain `STA abs,Y` reaches them -- absolute indexed uses DBR.
                STA     _fbiCoreBank            ; stash core bank (low byte used)
                LDX     #0
@fbi_patchL     CPX     #_CorePatchBytes
                BCS     @fbi_patchDone
                LDY     _CorePatchTbl,X         ; Y = in-bank offset of a bank byte
                SEP     #$20
                MX      %10
                LDA     _fbiCoreBank            ; the value being written (low byte)
                STA     |$0000,Y                ; DBR = far bank -> patches our own
                REP     #$30
                MX      %00
                INX
                INX
                BRA     @fbi_patchL
@fbi_patchDone

                ; --- Stamp every &function cell's bank byte with THIS bank.
                ;     fcc emits them as KFAR_FN_PTR with the byte zero, because
                ;     the assembler cannot know where the Memory Manager puts
                ;     this image; PHK here can, and every indirect call in the
                ;     bank's C reads the byte.  _modFnPtrTab is generated by
                ;     tools/gen_mod_bankpatch.py --macro KFAR_FN_PTR, and it is
                ;     _Mod_StampFnPtrs's walk for the same reason.  Before any
                ;     C runs, which is before Con_Init.
                SEP     #$20
                MX      %10
                PHK
                PLA
                STA     _fbiCoreBank            ; reused: the value, low byte
                REP     #$30
                MX      %00
                LDX     #0
@fbi_fnptrL     CPX     #_modFnPtrBytes
                BCS     @fbi_fnptrDone
                LDY     _modFnPtrTab,X          ; Y = a cell's bank-byte offset
                SEP     #$20
                MX      %10
                LDA     _fbiCoreBank
                STA     |$0000,Y
                REP     #$30
                MX      %00
                INX
                INX
                BRA     @fbi_fnptrL
@fbi_fnptrDone

                ; --- FPSIM_TRAMP's default: JML _Fpsim_Absent, in this bank,
                ;     until the fpsim module's mod_init replaces it.  The bank
                ;     byte is PHK's, like SYS_TRAMP's (_Sys_InstallVectors).
                SEP     #$20
                MX      %10
                LDA     #$5C                    ; JML
                STAL    FPSIM_TRAMP+0
                LDA     #<_Fpsim_Absent
                STAL    FPSIM_TRAMP+1
                LDA     #>_Fpsim_Absent
                STAL    FPSIM_TRAMP+2
                PHK
                PLA
                STAL    FPSIM_TRAMP+3
                REP     #$30
                MX      %00

                ; --- Seed the canaries for the console regions that moved here.
                ;     _KMem_WriteCanaries in the core kernel can no longer reach
                ;     them, and they must be armed before Con_Init runs.  DBR is
                ;     the far bank throughout this routine, so plain absolute
                ;     stores land correctly.
                SEP     #$20
                MX      %10
                LDA     #$A5
                STA     |KMem_ConVtState_canary
                STA     |KMem_ConExpand_canary
                STA     |KMem_FontHdrBuf_canary
                STA     |KMem_ConAltSave_canary
                STA     |KMem_ConMode_canary
                STA     |KMem_ConVcState_canary
                REP     #$30
                MX      %00

                PLB                     ; restore caller's DBR
                SEC
                RTL

;------------------------------------------------------------------------------
; _Fpsim_Absent - FPSIM_TRAMP's target while no fpsim module is loaded.
;
; Reached by `JSL FPSIM_TRAMP' from a program doing double arithmetic, in the
; program's own context: its DBR, its direct page, its stack.  It does what
; 2.11BSD's trap.c does for a floating point instruction on a machine with no
; FPU and no simulator, `i = SIGILL;', and it does it the way the program
; itself would, kill(getpid(), SIGILL): the signal is delivered on that
; syscall's return, and SIGILL's default action ends the process.  A handler
; that returns comes back here and on to the caller with no result, as on BSD.
;------------------------------------------------------------------------------
_Fpsim_Absent   MX      %00
                JSL     SYS_TRAMP
                DFB     SYS_GETPID              ; A = pid
                LDX     #SIGILL
                JSL     SYS_TRAMP
                DFB     SYS_KILL                ; A = pid, X = sig
                RTL

;--- Far_BankInit scratch.  In the far bank's own statics, reached DBR-relative
;--- while DBR == far bank inside the routine above.
_fbiCoreBank    DS      2               ; core bank number (low byte significant)

;==============================================================================
; Far-bank STATIC region.  A DUM block, so these reserve space without emitting
; bytes into bin/fgxfar.bin -- CON_EXPAND alone is 512 B and CON_VT_STATE 256 B,
; and a plain DS here would put all of it on disk as zeros.
;
; FGX_KFAR_DATA is the far bank's code ceiling (include/kernel.s), the same way
; FGX_DATA is the core kernel's, so check_kernel_ceiling.py keeps measuring
; something real.
;
; Moved out of include/memmap.s with the console driver.  Console code reaches
; them DBR-relative for free (every far entry does PHK/PLB); only CON_VT_STATE
; is read from the CORE kernel, at 14 sites in syscall.s, by patched LDAL.
;==============================================================================
                DUM     FGX_KFAR_DATA
; CON_VT_STATE IS FIRST, and must stay first: the core kernel names it as
; KFAR_VT_STATE (include/kfar.s) at a fixed offset rather than scraping the far
; listing, which would make the build cyclic.  The ERR below is what keeps the
; two definitions honest.
;------------------------------------------------------------------------------
; Console VT parser state.  Owner: console driver.
; Zero-init: Con_Init via _ZeroBankRegion CON_VT_STATE, KMem_ConVtState_end.
;------------------------------------------------------------------------------
CON_VT_STATE            DS  $0100
KMem_ConVtState_end     EQU *
KMem_ConVtState_canary  DS  1
                ERR     CON_VT_STATE-FGX_KFAR_DATA
                ERR     KFAR_VT_STATE-{FGX_KFAR_DATA-{FGX_KFAR_BANK*$10000}}
;------------------------------------------------------------------------------
; Console mode descriptor.  Owner: console driver (console_mode.s).
; Populated at Con_Init by Con_InitMode from a per-mode entry.
; Zero-init: Con_Init via _ZeroBankRegion _conMode, KMem_ConMode_end.
;------------------------------------------------------------------------------
; THE ACTIVE FONT'S POINTERS.  They describe the DEVICE, not the task, and
; were direct-page cells until the kernel direct page became per-task -- at
; which point a runtime font change wrote one task's page and left every other
; task's pointing at the previous block (apple/fgx#103).  Benign only while
; nothing frees a font block, which is a fact about today's console rather than
; a property of the data.
;
; Far-bank statics: the only readers are console code running with DBR = this
; bank, so they cost nothing to read.  The three [ptr],Y dereferences stage
; into _conFontStage first -- see include/dpmap.s.
CON_FONT_DATA_PTR       DS  3               ; heap font data block
                        DS  1               ; pad to word alignment
CON_FONT_LONG_PTR       DS  3               ; active font (default or heap)
                        DS  1               ; pad to word alignment
_conMode                DS  20                  ; CM_SIZE from include/console.s
KMem_ConMode_end        EQU *
KMem_ConMode_canary     DS  1
;------------------------------------------------------------------------------
; Console back-end switch.  Owner: console driver (console_backend.s).
; $8080 while the VC whose state the engine holds renders on a module's
; device -- Con_LoadVCState sets it from _conVcDisplay -- so BIT reads N set
; in either width; zero otherwise, from the region zero at boot.
; _conVcDisplay is one byte per VC, $80 when a module has registered a device
; for it (VC_CARD, by Con_SetBackend) and 0 for the SHR screen.
;------------------------------------------------------------------------------
_conBackendOn           DS  2
_conVcDisplay           DS  NVC


;------------------------------------------------------------------------------
; Console ExpandWord table.  Owner: console driver.
; Zero-init: Con_Init via _ZeroBankRegion CON_EXPAND, KMem_ConExpand_end.
; Populated by _Con_BuildExpand every time fg/bg changes.
;------------------------------------------------------------------------------
CON_EXPAND              DS  $0200
KMem_ConExpand_end      EQU *
KMem_ConExpand_canary   DS  1

;------------------------------------------------------------------------------
; Font-loader header scratch.  Owner: console_font_loader.  Holds the 48-byte
; FGXF header while the loader validates magic/version/cell-size before
; streaming glyph bytes directly into the heap font block.  256 B for future
; headroom; only the first 48 are touched today.
;------------------------------------------------------------------------------
CON_FONT_HDR_BUF        DS  $0100
KMem_FontHdrBuf_end     EQU *
KMem_FontHdrBuf_canary  DS  1

;------------------------------------------------------------------------------
; Console alt-screen scalar state save.  Owner: console driver.
; Zero-init: Con_Init.
;------------------------------------------------------------------------------
CON_ALT_SAVE            DS  $0010
KMem_ConAltSave_end     EQU *
KMem_ConAltSave_canary  DS  1

;------------------------------------------------------------------------------
; Per-VC console state blocks (slice D).  Owner: console driver.
; Zero-init: Con_Init.
;
; One block per virtual console, INCLUDING the active one -- save and load are
; then symmetric and the switch has no special case for "where the live state
; came from".
;
; WHAT THIS IS NOT: the 14 bytes Con_EnterAltScreen saves.  That set works only
; because enter and exit happen at escape-sequence boundaries inside the SAME
; application, which is exactly what two independent login sessions are not.  A
; VC can be switched away from mid-escape-sequence, so the parser state has to
; travel with it.  Three regions, in this order:
;
;   VCS_VT     90 B  CON_VT_STATE[$00..$59]: parser state, intermediates, the
;                    16 CSI params, SGR, DECSC saves, scroll region, DECTCEM,
;                    DECAWM, the rendered-cursor shadow, VT_PENDING_WRAP, the
;                    tab stops -- and, from $4A, the console SCALARS (cursor,
;                    viewport, colour) that used to be direct page $C0..$CF and
;                    a copy region of their own.  $5A is what the layout in
;                    include/console.s actually defines; the region reserves
;                    $0100 for headroom and copying the unused tail would be
;                    waste.
;
;                    THE SCALARS MOVING IN HERE IS WHY THERE ARE NOW TWO COPY
;                    REGIONS AND NOT THREE.  As direct-page cells they were a
;                    second address space the far bank cannot reach DBR-
;                    relative, so they needed a dp,X loop of their own; that
;                    loop is deleted.  VT_ATTR is inside the copied range for
;                    the reason the old note gave: it is the live attribute
;                    byte every erase/fill handler applies, and one of the ones
;                    alt-screen does not round-trip, so leaving it shared has
;                    session B erasing with session A's reverse-video.
;                    _conRenderState did NOT come with them -- it is now
;                    VT_RENDER_STATE at $5A, deliberately past the copied
;                    range, which states structurally what Con_LoadVCState used
;                    to say by overwriting it.  See include/console.s.
;   VCS_ALT    16 B  CON_ALT_SAVE, plus VCS_ALT_FLAG below.  These are a SINGLE
;                    far-bank static today with no "am I in alt-screen" flag
;                    anywhere, so vi on VC1 and vi on VC2 would clobber each
;                    other's Con_ExitAltScreen restore.  The alt BUFFERS need no
;                    handling -- they live at $8000+ in each VC's own bank and
;                    become per-VC for free -- but the saved scalars do not.
;
; The block is deliberately a flat byte image with no internal pointers, so the
; switch is two block copies in each direction and nothing to get stale.
;------------------------------------------------------------------------------
VCS_VT_OFF              EQU 0
VCS_VT_LEN              EQU $5A             ; CON_VT_STATE thru VT_ATTR
                ; THE COPIED RANGE MUST REACH THE SCALARS.  VCS_VT_LEN is hand
                ; written here; VT_ATTR is the last scalar and is laid out in
                ; include/console.s.  Two independently authored constants, so
                ; this is a real relation -- not the self-comparison the old
                ; CON_VC_DPBASE guard turned out to be.  Verified by mutation:
                ; putting VCS_VT_LEN back to $4A fails the build here.
                ;
                ; A BUILD check because no runtime test covers it.  The whole VC
                ; suite passes with the scalars left out of the copy entirely
                ; (measured 2026-08-13, apple/fgx#101): vccursor counts whether a
                ; cursor is DRAWN, which is a different claim from whether one
                ; SURVIVES a switch.  The last defect here was found by a person
                ; noticing a homed cursor did not stick.
                ERR     VT_ATTR/VCS_VT_LEN
VCS_ALT_OFF             EQU VCS_VT_OFF+VCS_VT_LEN
VCS_ALT_LEN             EQU $10             ; CON_ALT_SAVE
VCS_ALT_FLAG            EQU VCS_ALT_OFF+VCS_ALT_LEN     ; 1 = in alt screen
VCS_INIT_FLAG           EQU VCS_ALT_FLAG+2              ; 1 = this block holds a
                                                        ;   real console state
VCS_USED                EQU VCS_INIT_FLAG+2             ; = 110 B actually used
VCS_SIZE                EQU $80             ; PADDED TO A POWER OF TWO on
                                            ;   purpose.  108 would fit, but
                                            ;   idx*108 is a shift-and-add the
                                            ;   reader has to verify, while
                                            ;   idx<<7 is not.  The waste is 20
                                            ;   B per VC, 60 B total, in a bank
                                            ;   with ~49 KB free -- a bad trade
                                            ;   only if the bank were tight,
                                            ;   and it is the CORE bank that is
                                            ;   tight, not this one.
                ERR     {VCS_USED-1}/VCS_SIZE   ; used must stay <= size: the
                                                ;   division is 0 while it does
                                                ;   and nonzero the moment a
                                                ;   field pushes past the pad
NVC                     EQU 4               ; console + ttyv1 + ttyv2 + ttyv3
                                            ;   (VC_CARD).  Keep in step with
                                            ;   NTTY's ttyv range in
                                            ;   include/kernel.s.
CON_VC_STATE            DS  NVC*VCS_SIZE
KMem_ConVcState_end     EQU *
KMem_ConVcState_canary  DS  1

;------------------------------------------------------------------------------
; Scratch for the VC state movers (console_switch.s).  Far-bank statics: those
; routines run with DBR = far bank and reach these absolute.
;
; The DP half of the move needs no pointer static: the console's live scalars
; sit at FIXED bank-0 addresses, so console_switch.s reaches them with
; long-indexed addressing against a compile-time constant.
;------------------------------------------------------------------------------
_conVcBase              DS  2               ; byte offset of the working block
KMem_FarDum_end         EQU *

                DEND

;==============================================================================
; The loader's OUTPUTS, at a fixed offset because the CORE reads them.
;
; loader.s runs here now, but main.s, process.s and task.s still read what it
; produced -- 34 sites, all patched LDAL.  A core LDAL needs an address at
; assemble time and the two banks are separate link units, so the core cannot
; scrape this one: it names the KFAR_LD_* EQUs in include/kfar.s instead, and
; the ERRs below are what stop those from drifting.  Exactly the arrangement
; CON_VT_STATE has, and for exactly the same reason.
;
; A DUM OF ITS OWN, at a CHOSEN address rather than wherever the block above
; happens to end.  Appending to that block would mean every future far-bank
; static silently moved the loader's outputs and forced the EQUs to be re-derived
; each time.  Here the address is a decision: $F800, which leaves the block above
; 1,548 bytes of growth (it ends at $F1F4 today) and the loader 2,048.  The
; overrun guard is below the block.
;==============================================================================
KFAR_LD_ORG     EQU     FGX_KFAR_DATA+$0BC0     ; $08F800

                DUM     KFAR_LD_ORG
_ldEntry        DS      3               ; 24-bit entry address
_ldUserBank     DS      1               ; load bank
_ldExtraBanks   DS      FGX2_MAX_SEGS   ; seg k's bank when the process owns
                                        ;   it (0 = a shared text's)
_ldHeader       DS      FGX1_HEADER_SZ  ; cached header (FGX1/FGX2 share size)
_ldSetUid       DS      2               ; set-id image's uid, or $FFFF
_ldSetGid       DS      2               ; set-id image's gid, or $FFFF
_ldTextIdx      DS      1               ; the text this load took, 0 = none
; Loader-private from here; in this block only because it emits no bytes.
_ldTextNew      DS      1               ; 1 = _ldTextIdx is a claim this load
                                        ;   fills (F7.6), not a hit
_ldTextList     DS      FGX2_MAX_SEGS*3 ; a shared text's banks, first pages
                                        ;   and page counts by segment (FIND's
                                        ;   answer: 16 bytes; FILL's list: 24)
_ldSegPage      DS      FGX2_MAX_SEGS   ; seg k's page in its bank: the high
                                        ;   byte an offset relocation adds
_ldPlace        DS      2               ; a placed segment's address (bank <<
                                        ;   8 | page), from Core_Alloc
_ldPlaceN       DS      2               ; and its page count
_ldTextKey      DS      8               ; st_dev, st_ino, st_ctime of the file
_ldTextKeyOk    DS      2               ; 1 = _ldTextKey is this load's
KMem_LdOut_end  EQU     *
                DEND

; The EQUs the core bakes must name these exact addresses.
                ERR     _ldEntry-{KFAR_LD_ENTRY+{FGX_KFAR_BANK*$10000}}
                ERR     _ldUserBank-{KFAR_LD_USERBANK+{FGX_KFAR_BANK*$10000}}
                ERR     _ldExtraBanks-{KFAR_LD_EXTRABANKS+{FGX_KFAR_BANK*$10000}}
                ERR     _ldHeader-{KFAR_LD_HEADER+{FGX_KFAR_BANK*$10000}}
                ERR     _ldSetUid-{KFAR_LD_SETUID+{FGX_KFAR_BANK*$10000}}
                ERR     _ldSetGid-{KFAR_LD_SETGID+{FGX_KFAR_BANK*$10000}}
                ERR     _ldTextIdx-{KFAR_LD_TEXT+{FGX_KFAR_BANK*$10000}}
; ...and the block above must not have grown into them.
                ERR     KMem_FarDum_end/{KFAR_LD_ORG+1}


;==============================================================================
; THE BOOT PROGRAM'S CONSOLE FONT.  Stage 2 reads /lib/fonts/default.fnt off
; whichever filesystem it booted from and writes the whole FGXF file here,
; before the kernel's first instruction; Con_Init validates the header and
; points the active font at the glyph block.  The console therefore needs NO
; disk read of its own, which is what let the root filesystem move.
;
; The rationale, the reason there is no BSD counterpart to port, and why this
; is not a compiled-in blob are all in include/kfar.s beside KFAR_BOOT_FONT.
;
; A DUM AT A CHOSEN ADDRESS, like the loader outputs above and for the same
; reason: stage 2 and the core kernel both name it at assemble time, so it must
; not move when a static is added to the block below.  $F900 leaves the loader
; outputs 227 bytes of growth and the bank 768 bytes above this.
;
; IT COSTS THE CODE REGION NOTHING.  The far bank's code ceiling is $EC40; this
; is address space above it that nothing has ever used, and a DUM emits no
; bytes, so bin/fgxfar.bin is the same size with it as without.
;==============================================================================
KFAR_FONT_ORG   EQU     FGX_KFAR_DATA+$0CC0     ; $08F900

                DUM     KFAR_FONT_ORG
_conBootFont    DS      KFAR_BOOT_FONT_MAX
KMem_BootFont_end EQU   *
                DEND

; The EQU the core and stage 2 bake must name this exact address.
                ERR     _conBootFont-{KFAR_BOOT_FONT+{FGX_KFAR_BANK*$10000}}
; The loader outputs must not have grown into it...
                ERR     KMem_LdOut_end/{KFAR_FONT_ORG+1}
; ...and it must not run off the top of the bank.  A DUM that wraps would
; silently alias offset $0000 -- the export table.
                ERR     KMem_BootFont_end/{{FGX_KFAR_BANK+1}*$10000}


;--- Generated: far-side cross-bank operand sites (tools/gen_far_bankpatch.py).
;--- MUST come after the export table: anything emitted before it would displace
;--- the table from offset $0000 and every core-side JSL would land wrong.
;--- Empty until phase 3 adds the first far->core call site.
;--- Generated: CORE symbol addresses (tools/gen_kernel_exports.py, 'far'
;--- manifest).  abs24 with bank $02 baked in; Far_BankInit rewrites each site's
;--- bank byte to the live core bank, which is why every use carries a _cfp
;--- marker.  BSD `ld -A /vmunix` style: regenerated every build, so a renamed or
;--- removed core symbol FAILS THE BUILD rather than drifting stale.
                PUT     kernel_exports.s

;--- libc arena type constants (M_FONT etc.).  PUT rather than hand-copied: it
;--- is the single source of truth alloc.s uses, and a copied constant is how
;--- arena IDs drift apart silently.  Costs ~60 B of duplicated name strings in
;--- a bank with 59 KB free.  MUST stay after the export table -- it emits data.
                PUT     ../libc/alloc_state.s

                PUT     core_patchsites.s

;------------------------------------------------------------------------------
; KERNEL C: the fcc runtime, its traps, its scratch, and the compiled TUs.
;
; ALL FOUR EMIT BYTES, so all four MUST stay below the ORG -- see the export
; table's own note above and check_kernel_ceiling.py's KFAR_MAGIC assertion.
;
; fcc_rt.s is GENERATED from toolchain/lib/fcc_runtime.s (tools/gen_fcc_rt.py),
; taking everything from _fcc_mul16 onward -- the region measured to be free of
; syscalls, libc and every other outside call.  The three routines above that
; point exit or yield through SYS_TRAMP, which a kernel cannot do to itself, so
; fcc_ktrap.s supplies kernel versions that stop the machine instead.
;
; fcc_runtime_data.s is PUT verbatim from the toolchain: it is pure storage, and
; reaching it needs only DBR = this bank, which KC_ENTER establishes.
;------------------------------------------------------------------------------
                DO      KCPROBE=1
                PUT     fcc_rt.s
                PUT     fcc_ktrap.s
                PUT     ../../../toolchain/lib/fcc_runtime_data.s
                PUT     kc_probe.s
                ; THE INWARD SEAM -- UFS 1.7d.  Here rather than in the core
                ; bank because the VFSCORE import shims must be entered from C
                ; and the callee wants fcc's direct page, both of which this
                ; bank already establishes.  vfs_seam.s brings up the table and
                ; does the talking; vfs_seam.c is the C that crosses.
                ; NAMES: vfs_seam_entry.s is HAND-WRITTEN and vfs_seam.s is
                ; fcc's output for vfs_seam.c.  They were both called
                ; vfs_seam.s for about a minute, which the compiler would have
                ; resolved by overwriting the assembly.
                PUT     vfs_import.s
                ; ...and ufs.mod's, for the root mount the kernel does itself
                ; (UFS 1.7d I3), which calls ufs_mountfs directly as Reno's
                ; ufs_mountroot does rather than going through vfssw[].
                PUT     ufs_import.s
                PUT     dev_mount.s
                PUT     root_mount.s
                PUT     dev_mount.data.s
                PUT     root_mount.data.s
                PUT     dev_nodes.s
                PUT     dev_nodes.data.s
                ; sysctl(2), apple/fgx#410.  Its one leaf is securelevel, whose
                ; variable is vfs.mod's -- so this reaches it over vfs_import.s
                ; like everything else here does.
                PUT     root_sysctl.s
                PUT     root_sysctl.data.s
                PUT     vfs_seam_entry.s
                ; THE DESCRIPTOR LAYER -- UFS 1.7d I2b, moved out of vfs.mod.
                ; Mod_LoadConf opens files through _Fcb_Alloc and Mod_LoadConf
                ; is what LOADS vfs.mod, so a file table inside vfs.mod is a
                ; boot that cannot start.  BSD puts this in kern_descrip.c,
                ; which is kernel code and not filesystem code.
                ;
                ; AFTER vfs_import.s because vfs_syscalls.c's `vnops` names the
                ; shims declared there.
                PUT     ../../kernel/vfs/vfs_file.s
                PUT     ../../kernel/vfs/vfs_file.data.s
                PUT     ../../kernel/vfs/vfs_syscalls.s
                PUT     ../../kernel/vfs/vfs_syscalls.data.s
                PUT     vfs_seam.s
                PUT     vfs_seam.data.s
                ; ...and its DATA segment.  Empty today -- kc_probe declares no
                ; globals -- but fcc emits one for every TU, and leaving it out
                ; is how the FIRST kernel-C global would silently not exist.
                PUT     kc_probe.data.s
                ; The C-to-kernel direction: what kernel C calls when it has to
                ; block, wake a waiter, or die.  Inside the gate with the rest
                ; of the payload -- nothing but kernel C reaches these.
                ;
                ; ONLY kc_wakeup IS STILL REACHED, by kc_probe.  The other
                ; four served the VFS and are dead here now -- and they are
                ; still assembled, because Merlin emits everything PUT.  About
                ; 100 bytes in a bank with 44 KB free, kept rather than split
                ; so the seam's account stays in one file; the module's own
                ; kc_sys.s is the live copy and cites this one.
                PUT     kc_sys.s
                ; THE VFS LEFT THIS BANK, 2026-08-12 -- vfs_bio, bio_strategy,
                ; dead_vnops, spec_vnops, vfs_cache, vfs_subr and vfs_probe are
                ; src/modules/vfs/vfs.mod now, ~36 KB of it, in a module bank of
                ; its own.  Nothing about the C changed; only kc_sys did, and
                ; only in how it reaches the kernel.  This file said the move
                ; would be "a link change, not a rewrite" and it was.
                FIN

;==============================================================================
; Subsystem PUTs go here as they migrate.  Code grows UP from just above the
; export table, so the binary stays contiguous from FGX_KFAR_CODE and the
; ceiling check measures something real.
;==============================================================================
                PUT     loader.s

;==============================================================================
; The loader's four export wrappers.
;
; A KFAR slot JMPs straight at its target and the core's JSL has already set
; PBR, but NOT DBR -- and loader.s reaches its own statics bank-relative
; throughout, so DBR has to be this bank for the duration.  PHB/PHK/PLB in,
; PLB out; PLB sets N and Z only, so every one of these returns its verdict in
; the carry intact, and A/X/Y pass through untouched.
;
; The bodies keep their RTS.  That is the *Impl split this file's own header
; prescribes after Far_BootChime called an RTL-terminated Sound_Beep with a
; same-bank JSR: two bytes pushed where three were pulled, and a hang somewhere
; else entirely.  tools/check_far_rtl_calls.py fails the build on a recurrence.
;==============================================================================
_Far_LoadBinary MX      %00
                PHB
                PHK
                PLB                     ; DBR = far bank
                JSR     Load_Binary
                PLB
                RTL

_Far_LoaderArgsPages MX %00
                PHB
                PHK
                PLB
                JSR     _Loader_ArgsExtraPages
                PLB
                RTL

_Far_LoaderStageArgs MX %00
                PHB
                PHK
                PLB
                JSR     _Loader_StageArgs
                PLB
                RTL

_Far_LaSetStageBase MX  %00
                PHB
                PHK
                PLB
                JSR     _La_SetStageBase
                PLB
                RTL

;------------------------------------------------------------------------------
; Slot 73: Con_SetBackend (console_backend.s).  A = table offset, Y = table
; bank, both passed through; the console's own DBR convention inside.
;------------------------------------------------------------------------------
_Far_ConSetBackend MX   %00
                PHB
                PHK
                PLB
                JSR     Con_SetBackend
                PLB
                RTL

;==============================================================================
; Far_LogState - report that the far bank is up, FROM the far bank.
;
; The first far->core call in the tree, and it is deliberately a real one rather
; than a probe: the mechanism it exercises (scraped core address + a _cfp marker
; + Far_BankInit patching the bank byte) is what the console needs 14 times over,
; and debugging machinery and payload together is how the sound move went wrong.
;
; The string lives HERE, in the far bank.  That works because Kern_LogStr reads
; it with `LDA (_conStrPtr),Y` -- DP-indirect-indexed, which takes its bank from
; the CALLER's DBR -- and _kernLogPutByte sets its own DBR via PHK/PLB, so the
; ring and mirror are unaffected by ours.  _conStrPtr itself is direct page
; (dpmap.s:259), reached through D, so it is bank-agnostic.
;
; The call goes through _FarSh_LogStr, not Kern_LogStr: every core routine the
; far bank needs is RTS-terminated.  See src/kernel/far_shims.s.
;
; In:  MX %00.  Out: A/X/Y per Kern_LogStr; DBR restored.
;==============================================================================
; NOTHING TO SAY, for the reason Tty_LogState gives: a bank that did not come
; up cannot answer the call, so `far: bank ready' was never evidence of
; anything the rest of boot did not already demonstrate.
Far_LogState    MX      %00
                RTL

;==============================================================================
; Far_BootChime - sound the boot chime.
;
; IT USED TO BE GATED by /etc/conmode's sysbeep setting.  That setting was
; early testing scaffolding for turning the bell on and off; the bell is on, and the file it lived in is gone.
;
; It stays a far-bank routine because Sound_Beep is the sound driver next
; door, so the core kernel would otherwise pay a second cross-bank call.
;
; In: MX %00.  Out: A/X/Y clobbered.  DBR restored.
;==============================================================================
Far_BootChime   MX      %00
                PHB
                PHK
                PLB                     ; DBR = far bank (the impl is ours)
                JSR     _Sound_BeepImpl ; same bank: JSR the RTS-terminated
                                        ;   impl, NOT the RTL export wrapper
                REP     #$30
                MX      %00
                PLB
                RTL

                PUT     sound.s
                PUT     clock.s
                PUT     sigmask.s
                PUT     itimer.s

;--- Console driver (17 files, 9,555 B).  Order preserved from the core
;--- kernel's original PUT sequence: console_bankpatch.s is GENERATED and
;--- must follow the files whose sites it lists.
                PUT     console/console_mode.s
                PUT     console/console_init.s
                PUT     console/console_buffer.s
                PUT     console/console_char.s
                PUT     console/console_render.s
                PUT     console/console_backend.s
                PUT     console/console_scroll.s
                PUT     console/console_color.s
                PUT     console/console_altscreen.s
                PUT     console/console_switch.s        ; slice D: VC state move
                PUT     console/console_kbd.s
                PUT     console/console_vt.s
                PUT     console/console_vthandler.s
                PUT     console/console_vtcolor.s
                PUT     console/console_bankpatch.s
                PUT     console/console_font.s
                PUT     console/console_set.s
                PUT     console/console_font_loader.s

;==============================================================================
; Console export wrappers.
;
; Each sets DBR to this bank for the duration of the call and restores the
; caller's on the way out.  WRAPPERS rather than edits to the 14 routines: they
; live across 17 files with multiple and sometimes shared exits, and rewriting
; every one of those in place is how a mechanical change becomes a bug.
;
; FLAGS: PLB affects N and Z but NOT carry, so carry-as-status returns pass
; through intact -- which is what every one of these routines uses (SEC/CLC, or
; a PLP restoring the caller's own P).  A caller must not rely on N/Z surviving
; a console call.
;
; A, X and Y are untouched by PHB/PHK/PLB, so arguments and return values pass
; straight through.
;==============================================================================
_fw_Con_Init             PHB
                PHK
                PLB
                JSR     Con_Init
                PLB
                RTL
_fw_Con_Write            PHB
                PHK
                PLB
                JSR     Con_Write
                PLB
                RTL
_fw_Con_WriteBuf         PHB
                PHK
                PLB
                JSR     Con_WriteBuf
                PLB
                RTL
_fw_Con_PutChar          PHB
                PHK
                PLB
                JSR     Con_PutChar
                PLB
                RTL
_fw_Con_CR               PHB
                PHK
                PLB
                JSR     Con_CR
                PLB
                RTL
_fw_Con_PollKey          PHB
                PHK
                PLB
                JSR     Con_PollKey
                PLB
                RTL
_fw_Con_GetKey           PHB
                PHK
                PLB
                JSR     Con_GetKey
                PLB
                RTL
_fw_Con_RenderAll        PHB
                PHK
                PLB
                JSR     Con_RenderAll
                PLB
                RTL
_fw_Con_SwitchVC         PHB
                PHK
                PLB
                JSR     Con_SwitchVC
                PLB
                RTL
_fw_Con_EnterVC          PHB
                PHK
                PLB
                JSR     Con_EnterVC
                PLB
                RTL
_fw_Con_LeaveVC          PHB
                PHK
                PLB
                JSR     Con_LeaveVC
                PLB
                RTL
_fw_Con_ShowCursor       PHB
                PHK
                PLB
                JSR     Con_ShowCursor
                PLB
                RTL
_fw_Con_HideCursor       PHB
                PHK
                PLB
                JSR     Con_HideCursor
                PLB
                RTL
_fw_Con_WriteArm         PHB
                PHK
                PLB
                JSR     Con_WriteArm
                PLB
                RTL
_fw_Con_WriteDone        PHB
                PHK
                PLB
                JSR     Con_WriteDone
                PLB
                RTL
_fw__Con_InitSCBs        PHB
                PHK
                PLB
                JSR     _Con_InitSCBs
                PLB
                RTL
_fw__Con_InstallPalettes PHB
                PHK
                PLB
                JSR     _Con_InstallPalettes
                PLB
                RTL
_fw_Con_LoadFontFromFile PHB
                PHK
                PLB
                JSR     Con_LoadFontFromFile
                PLB
                RTL
_fw_Con_RevertToDefault  PHB
                PHK
                PLB
                JSR     Con_RevertToDefault
                PLB
                RTL


;--- Generated: the bank-byte address of every KFAR_FN_PTR cell in this image
;--- (tools/gen_mod_bankpatch.py --macro KFAR_FN_PTR), walked by Far_BankInit.
;--- LAST, because it is the only output whose size depends on the scan:
;--- nothing after it can move a cell it lists.
                PUT     fnptr_patchsites.s
