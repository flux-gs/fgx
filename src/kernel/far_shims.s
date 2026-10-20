;==============================================================================
;
; FGX - Flux GS uniX
;
; File:     far_shims.s
; Purpose:  RTL entry points into the core kernel, for far-bank callers
; Created:  2026-08-01
;
; EVERY CORE ROUTINE THE FAR BANK NEEDS IS RTS-TERMINATED.  A cross-bank JSL
; pushes three bytes (PBR + PC) and an RTS pulls two, so calling them directly
; from the far bank would return into garbage and leave a byte on the stack.
;
; This is not a new problem and it already has an answer in this tree: the MOD_JT
; slot targets (_Sys_KernLogImpl, _Sys_PathResolveImpl, ...) exist for exactly
; the same reason -- FGXM modules are cross-bank callers too.  These shims are
; that pattern, minus the bank-0 gateway: the far bank reaches them by scraped
; address (tools/gen_kernel_exports.py, 'far' manifest) rather than by slot,
; because the 32-slot MOD_JT is full and only covers some of what is needed.
;
; EACH SHIM ALSO SETS DBR TO THE CORE BANK, and that is not optional.  The far
; bank calls in with DBR = far bank, but these callees address their own statics
; DBR-relative: Kmalloc walked the arena tables in the FAR bank and returned into
; a crash the first time this was tried without it.  PHK here yields the core
; bank because the shim is core code.
;
; A, X and Y pass straight through (PHB/PHK/PLB touch none of them).  The
; trailing PLB clobbers N and Z but NOT carry, so carry-as-error-return -- which
; is what all of these use -- is unaffected.
;
; Why not wire these into MOD_JT instead: the table is at capacity (slot 31 is
; SYS_NETKC_SLEEP), Kmalloc is DELIBERATELY unwired there because modules must
; not allocate kernel heap, and the far bank is not a module -- it is kernel
; code, and may allocate.
;
; DBR IS NOT ENOUGH FOR A SHIM THAT TAKES A POINTER.  Setting DBR to the core
; bank fixes the callee's statics but simultaneously makes any pointer argument
; unreadable, because a bare 16-bit pointer argument is resolved against that
; same DBR.  One DBR cannot be two banks.  _FarSh_Fs_Open below shows the
; resolution: move the data across the boundary, then call.
;
; ADDING ONE: add the shim here, add its label to the 'far' manifest in
; tools/gen_kernel_exports.py, and call it from the far bank with a _cfpNNN
; marker so Far_BankInit patches the bank byte.
;==============================================================================

                MX      %00

; _FarSh_Fs_Open is the one shim that also has to move DATA, not just control.
;
; Fs_Open takes X = a bare 16-bit path offset and every layer under it reaches
; the string DBR-relative: Path_Resolve and
; -- past the FOP dispatch -- _Sys_PathResolveImpl and prodos.mod, which re-enter
; with DBR already forced to the kernel bank.  So the path must physically be in
; the core bank; carrying its bank alongside the pointer would only survive as
; far as the module boundary, where the offset is handed on bare.
;
; Copy it here, at the one place the banks actually change.  Reading with
; [_fsPathPtr],Y takes the bank from the pointer (still the FAR bank at this
; point), writing with |_fsFarPathBuf,Y takes it from DBR (the CORE bank, set
; below), so the copy straddles the boundary in a single loop.  Fs_Open then
; sees an ordinary kernel-bank path and needs no knowledge of the far bank at
; all.  Truncation is refused rather than silently accepted -- a path cut short
; would open the WRONG FILE, which is worse than failing the open.
_FarSh_Fs_Open  MX      %00
                STX     _fsPathPtr      ; path offset ...
                PHB                     ; (1) saved for the exit PLB
                PHB                     ; (2) consumed by the capture below
                SEP     #$20
                MX      %10
                PLA
                STA     _fsPathPtr+2    ; ... and its bank: the FAR bank
                REP     #$30
                MX      %00
                PHK
                PLB                     ; DBR = CORE bank (dest of the copy)

                SEP     #$20
                MX      %10
                LDY     #0
@fso_copy       LDA     [_fsPathPtr],Y  ; src bank from _fsPathPtr+2 (far)
                STA    |_fsFarPathBuf,Y ; dst bank from DBR (core)
                BEQ     @fso_copied     ; copied the NUL: done
                INY
                CPY     #FS_FARPATH_MAX
                BCC     @fso_copy
                ; No NUL within the buffer -- refuse rather than open a
                ; truncated path.
                REP     #$30
                MX      %00
                LDA     #ENAMETOOLONG
                PLB
                CLC
                RTL
@fso_copied     REP     #$30
                MX      %00
                LDX     #_fsFarPathBuf
                JSR     Fs_Open
                PLB
                RTL

_FarSh_Fs_Read  PHB
                PHK
                PLB                     ; DBR = CORE bank
                JSR     Fs_Read
                PLB
                RTL

; _FarSh_ModFindVtable - UFS 1.7d, the inward seam.
;
; Mod_FindVtable is CORE and the seam that needs it is FAR, which is the whole
; reason this file exists.  It passes everything in registers -- A = VT_* going
; in, C=1 + A = voffset + X.lo = bank coming back -- so it needs the plain
; shape rather than Fs_Open's data-moving one: no pointer argument means no
; second bank to resolve against.
;
; PLB SETS N AND Z from the byte it pulls and leaves CARRY alone, which is the
; only flag this call answers with.  A and X cross it untouched.
; _FarSh_CurPid - the running pid, for the far bank's kc_curpid.
;
; _curTask is a DIRECT PAGE cell and the CALLER has already put D on the
; kernel's page (far/kc_sys.s does the _FarSh_KernDP dance first), so this only
; has to fix DBR and read it.  That split is deliberate: one shim that switched
; both would have to know which page the caller wanted back.
_FarSh_CurPid   PHB
                PHK
                PLB                     ; DBR = CORE bank
                LDA     _curTask
                PLB
                RTL

_FarSh_ModFindVtable PHB
                PHK
                PLB                     ; DBR = CORE bank
                JSR     Mod_FindVtable
                PLB
                RTL

_FarSh_Fs_Close PHB
                PHK
                PLB                     ; DBR = CORE bank
                JSR     Fs_Close
                PLB
                RTL

; _FarSh_LogStr is THE EXCEPTION: it must NOT set DBR.  Kern_LogStr reads the
; string with `LDA (_conStrPtr),Y`, which takes its bank from the CALLER's DBR,
; and far-bank callers pass far-bank strings.  Forcing the core bank here made it
; print whatever sat at the same offset in the core bank.  It is safe to leave
; DBR alone because _kernLogPutByte sets its own via PHK/PLB.
_FarSh_LogStr   JSR     Kern_LogStr
                RTL

_FarSh_Kmalloc  PHB
                PHK
                PLB                     ; DBR = CORE bank
                JSR     Kmalloc
                PLB
                RTL

_FarSh_Sleep    PHB
                PHK
                PLB                     ; DBR = CORE bank
                JSR     _sleep
                PLB
                RTL

; _FarSh_SleepUn / _FarSh_Wakeup - the pair kernel C waits on.
;
; Separate from _FarSh_Sleep because the UNINTERRUPTIBLE sleep is the one a
; buffer wait needs: the waiter re-tests and has no error path, so the
; interruptible sleep's "C=1, did not sleep" answer would spin.  See _sleepUn
; in sched.s.
;
; _wakeup takes no shim of its own anywhere else because nothing outside the
; core bank has ever needed to wake anything.  A cache shared between tasks is
; the first thing that does: brelse hands the buffer on.
_FarSh_SleepUn  PHB
                PHK
                PLB                     ; DBR = CORE bank
                JSR     _sleepUn
                PLB
                RTL

_FarSh_Wakeup   PHB
                PHK
                PLB                     ; DBR = CORE bank
                JSR     _wakeup
                PLB
                RTL

; `_FarSh_TtyGetByte', `_FarSh_TtyPollByte' and `_FarSh_TtyFlushPend' STOOD
; HERE and went at T6 increment 4b, with `kc_getbyte'/`kc_pollbyte'/
; `kc_ttflushpend' -- their only callers -- and with the pump those served.
; src/kernel/tty/kc_sys.s carries the reasoning, where the C-side entries were.

; _FarSh_BlkIo - one 512-byte transfer for kernel C's bio_strategy.
;
; In:  A = the caller's buffer BANK, X = nonzero to read / zero to write.
;      _blkNum, _blkNumHi, _blkBuf and _fsCurDevIdx already set by kc_blkio,
;      which can reach them because they are direct page.
; Out: C=1 ok; C=0 and A = errno.
;
; The bank store is why this shim exists at all rather than kc_blkio simply
; JSLing Blk_Read: _blkBufBank is a core-bank static, not a DP cell, so it
; needs DBR here.  It is written INSIDE the DBR window and read by the Blk_*
; entry latch immediately after, which zeroes it again -- so it is never left
; set for the next caller, exactly as _blkNumHi is not.
_FarSh_BlkIo    PHB
                PHK
                PLB                     ; DBR = CORE bank
                STA    |_blkBufBank     ; one-shot; the Blk_* latch consumes it
                ; A pool source is never what kernel C means.  _blkSrcPool says
                ; "the bytes are in a cache pool entry, not in the caller's
                ; buffer", and Blk_Write consults it BEFORE the caller's buffer
                ; bank -- so a stale one, left by a write that took an error
                ; exit without consuming it, sends this transfer to the pool's
                ; bank and silently moves the wrong 512 bytes.  This seam always
                ; supplies a real buffer, so it states that rather than
                ; inheriting whoever ran last.
                PHA
                SEP     #$20                    ; _blkSrcPool is ONE byte; a
                LDA     #0                      ;   16-bit store here reaches
                STA    |_blkSrcPool             ;   into _ulSapRec next door
                REP     #$20
                PLA
                CPX     #0
                BEQ     @fsbi_write
                JSR     Blk_Read
                PLB
                RTL
@fsbi_write     JSR     Blk_Write
                PLB
                RTL

; _FarSh_KernDP - the kernel's REAL direct page, for the way back out of C.
;
; There is no constant for it.  FGX_Entry picks FGX_DP_KKERN under the
; relocating build and FGX_DP_KERNEL ($0000) only on the legacy $02 one, and
; caches the choice in _kFgxDPKernel.  kc_sys.s assumed $0000, which put the
; block layer's parameters -- dev_table_ptr among them -- on page zero: the
; device-state pointer came back null and the SmartPort read went to unit 255,
; on a device that had enumerated perfectly.
;
; It lives on this side because _kFgxDPKernel is a core-bank global and the far
; bank cannot reach it without a bank byte of its own.
_FarSh_KernDP   PHB
                PHK
                PLB                     ; DBR = CORE bank
                LDAL   KFGX_CUR_KDP    ; the running task's slot page, or
                                        ;   boot's template page (task.s)
                PLB                     ; sets N/Z only; A survives
                RTL

; _FarSh_BlkReads - the kernel's count of device reads, low word.
;
; Existing observability rather than new: block.s already bumps
; _kBlkReadCount on every Blk_Read, for spotting read amplification.  The VFS
; probe reads it to prove a cache HIT never reached the device -- a claim the
; cache's own flags cannot settle, since they are what is under test.  The low
; word is enough: the probe compares two samples taken microseconds apart.
_FarSh_BlkReads PHB
                PHK
                PLB                     ; DBR = CORE bank
                LDA     _kBlkReadCount  ; low word (caller is MX %00)
                PLB                     ; sets N/Z only; A survives
                RTL

; _FarSh_VcKbdOK - "may the CURRENT task dequeue a keystroke right now?"
; C=1 yes, C=0 no.  Con_PollKey's virtual-console gate (apple/fgx#41).
;
; This is a SHIM rather than a cached eligibility word on purpose.  The answer
; depends on _curTask's controlling tty AND _kVcActive, so a cache would have to
; be invalidated at three sites (swtch, the VC switch drain, _Se_SetCtty) and a
; missed invalidation fails CLOSED -- a keyboard that goes dead with no
; diagnostic, the single worst failure this subsystem can have.  The call is not
; on a hot path: Con_GetKey sleeps between polls rather than spinning.
;
; PLB sets N/Z only, so the verdict in CARRY survives the bank restore.
_FarSh_VcKbdOK  PHB
                PHK
                PLB                     ; DBR = CORE bank
                JSR     _Vc_CttyIsActive
                PLB
                RTL

; _FarSh_CdLookup - the chardev registry, looked up by a name in the FAR bank.
; UFS 1.7d I3.
;
; The far bank has no SYS_KCALL, so where a module says KSVC_CDLOOKUP this
; says the same thing by the other route -- exactly the split _FarSh_CurPid
; describes one shim up.  The BODY is shared: both roads end in
; _Chardev_LookupBank, which is why that routine left the KSVC dispatcher.
;
; D IS THE CALLER'S JOB, and it must be the KERNEL's page: _cdKcNamePtr is a
; direct-page cell (include/dpmap.s $C3-$C5).  far/kc_sys.s does the
; _FarSh_KernDP dance before calling, the same as kc_sleep and kc_blkio.
;
; In:  A = name offset, Y.lo = the name's bank.  D = the kernel's page.
; Out: C=1 + A.lo = idx, or C=0 + A = ENOENT.  PLB sets N/Z only, so the
;      verdict in CARRY survives the bank restore.
_FarSh_CdLookup PHB
                PHK
                PLB                     ; DBR = CORE bank
                JSR     _Chardev_LookupBank
                PLB
                RTL

; The four routines loader.s reaches for once it runs from the far bank, plus a
; second door onto Fs_Open.  Far-bank phase 3.
;
; ALL FIVE PRESERVE THE CARRY ACROSS THE EXIT PLB, which is the whole verdict in
; four of them: PLB sets N and Z from the byte it pulls and leaves C alone.
;
;------------------------------------------------------------------------------
; _FarSh_Fs_OpenCore - Fs_Open for a path that is ALREADY in the core bank.
;
; NOT a duplicate of _FarSh_Fs_Open, and the difference is the one thing that
; matters here: that shim exists because a far-bank caller's string is in the
; FAR bank, so it captures its caller's DBR and copies the path across the
; boundary before Fs_Open -- which reaches strings DBR-relative all the way down
; -- can see it.  Load_Binary's path is not the far bank's.  It arrives from
; main.s and process.s as a core-bank offset and is still a core-bank offset when
; it gets here, so a copy keyed on the caller's bank would read the far bank at
; the core bank's offset and open whatever happened to be there.
;
; Two shims because there are two contracts, not two implementations.
;
; In:  X = path offset, in the CORE bank.
; Out: Fs_Open's own -- C=1 + A = fd, or C=0 + A = errno.
_FarSh_Fs_OpenCore PHB
                PHK
                PLB                     ; DBR = CORE bank
                JSR     Fs_Open
                PLB
                RTL

;------------------------------------------------------------------------------
; _FarSh_Fs_ReadN - In: A = fd (low byte), X = count, and _frnDstBank/_frnDstOff
; already written (they are core-bank absolutes, so a far-bank caller sets them
; through its own _cfp-marked STALs before calling).
; Out: C=1 + Y = bytes copied, or C=0 + A = errno.
;
; Y IS THE ANSWER, so the exit must not touch it; PLB does not.  Fs_ReadN leaves
; DBR at the kernel bank itself (it does _DBRK after its MVN), which is why the
; PLB below is restoring the FAR bank rather than tidying up after PHK.
_FarSh_Fs_ReadN PHB
                PHK
                PLB                     ; DBR = CORE bank
                JSR     Fs_ReadN
                PLB
                RTL

;------------------------------------------------------------------------------
; _FarSh_Fs_Lseek - In: A = fd (low byte), X = offset bits 0..15,
; Y = offset bits 16..31, and _fsLsWhence already written (core-bank
; absolute, same as above).
; Out: C=1 + A = newpos.lo16, Y = newpos.hi16, or C=0 + A = errno.
;
; Y carries half the result home here too.
_FarSh_Fs_Lseek PHB
                PHK
                PLB                     ; DBR = CORE bank
                JSR     Fs_Lseek
                PLB
                RTL

;------------------------------------------------------------------------------
; _FarSh_Bank_Alloc - Out: C=1 + A = bank, or C=0 + A = ENOMEM.  Preserves X/Y,
; as Bank_Alloc does.
_FarSh_Bank_Alloc PHB
                PHK
                PLB                     ; DBR = CORE bank
                JSR     Bank_Alloc
                PLB
                RTL

;------------------------------------------------------------------------------
; _FarSh_ModRegister - In: A.lo = bank already filled with a module image.
; Out: C=1, or C=0 + A = errno.  Mod_RegisterPreLoaded validates the FGXM
; header at bank:$0000, marks the bank used, zeroes BSS, walks VTDR and JSLs
; mod_init -- the whole of SYS_MODLOAD's `end', already written for the boot
; loader's pre-stage (modload.s).
_FarSh_ModRegister PHB
                PHK
                PLB                     ; DBR = CORE bank
                JSR     Mod_RegisterStreamed
                PLB
                RTL

;------------------------------------------------------------------------------
; _FarSh_ModHeader - In: A.lo = 0 (take the ordinal's bank), _mlHdrBank and
; _mlHdrOff pointing at the caller's own copy of the 40-byte header.
; Out: C=1 and _mlBank / _mlTextBase set, or C=0 + A = errno.
;
; SYS_MODLOAD's header chunk.  Everything that decides WHERE a module goes
; happens here, before a byte of it is written anywhere: magic, build identity,
; placement, ordinal, the bank the chain maps to, and the extent claim.
_FarSh_ModHeader PHB
                PHK
                PLB                     ; DBR = CORE bank
                JSR     Mod_RegisterHeader
                PLB
                RTL

;------------------------------------------------------------------------------
; _FarSh_Core_Alloc / _FarSh_Core_Free - pages in the pool's map (bank.s), for
; the loader and the shared-text table.  Contracts as Core_Alloc / Core_Free.
_FarSh_Core_Alloc PHB
                PHK
                PLB                     ; DBR = CORE bank
                JSR     Core_Alloc
                PLB
                RTL
_FarSh_Core_Free PHB
                PHK
                PLB
                JSR     Core_Free
                PLB
                RTL

;------------------------------------------------------------------------------
; _FarSh_Bank_Free - In: A.lo = bank number.  Preserves X/Y, as Bank_Free does.
_FarSh_Bank_Free PHB
                PHK
                PLB                     ; DBR = CORE bank
                JSR     Bank_Free
                PLB
                RTL

;------------------------------------------------------------------------------
; _FarSh_TextFind / _TextClaim / _TextFill / _TextUnref - the loader's doors to
; the shared-text table (src/kernel/tty/text.s).  The far bank cannot name the
; tty bank, so these relay its registers unchanged; each slot sets its own DBR.
;------------------------------------------------------------------------------
_FarSh_TextFind
_ktp116         JSL     KTTY_TEXT_FIND
                RTL
_FarSh_TextClaim
_ktp117         JSL     KTTY_TEXT_CLAIM
                RTL
_FarSh_TextFill
_ktp124         JSL     KTTY_TEXT_FILL
                RTL
_FarSh_TextUnref
_ktp118         JSL     KTTY_TEXT_UNREF
                RTL

;------------------------------------------------------------------------------
; _FarSh_CdTtyIdx - A.lo = chardev idx -> A = the tty index ($FFFF = not a tty).
;
; FGX's cdevsw[].d_ttys, for a bank that is not the core one.  The tty bank
; (apple/fgx#108) resolves a device to its `struct tty *' with this; see
; _Chardev_TtyIdx in src/kernel/chardev.s for what the answer means.
;
; DBR must be the core bank for the duration: _Chardev_TtyIdx reads the
; registry through the DP long pointer _cdTablePtr, and the bounds constant it
; compares against is a core-bank EQU.
;------------------------------------------------------------------------------
_FarSh_CdTtyIdx PHB
                PHK
                PLB                     ; DBR = CORE bank
                JSR     _Chardev_TtyIdx
                PLB                     ; PLB leaves carry alone -- the status
                RTL                     ;   return survives it

;------------------------------------------------------------------------------
; _FarSh_CdIoctl - cdevsw[].d_ioctl for a bank that is not the core one.
;
; In:  MX %00.  Frame (above this shim's own 3-byte return address):
;        4,S dev index   6,S cmd   8,S arg lo16   10,S arg bank
;      D = the kernel's REAL direct page (the caller sets it; _Chardev_Dispatch
;      reads the registry through the DP long pointer _cdTablePtr).
; Out: A = errno, 0 on success.  The C/A convention of the op is folded here so
;      the C side sees one number.
;
; IT SAVES AND RESTORES _Sys_IoctlCmd/_Sys_IoctlArgLo/_Sys_IoctlArgBank, AND
; THAT IS THE WHOLE REASON THIS IS NOT THREE LINES.  The chardev ioctl ABI
; passes cmd and arg through those three KERNEL SINGLETONS -- _Sys_Ioctl stages
; them at syscall.s:3318 and the op reads them back -- so a second caller that
; simply wrote them would corrupt an ioctl already in flight.  That is
; apple/fgx#89 exactly: a per-byte write loop's counters were statics, another
; task's write landed on them mid-sleep, and the blocked writer resumed with a
; foreign count.
;
; It is not live TODAY -- ttyblock's caller ttyinput runs in task context while
; PENDIN defers input to a reader, so nothing here can preempt _Sys_Ioctl
; between its store and the op's read.  It becomes live at T6, which returns
; ttyinput to arrival time.  Saving now costs six bytes of stack and means the
; increment that moves ttyinput does not have to find this first.
;
; The alternative -- widening the chardev ioctl ABI to carry cmd/arg on the
; stack the way COPS_DRead/COPS_DWrite carry their uio -- is the better shape
; and is what chardev.s's own note argues for, but it rewrites the ioctl entry
; of every module (pty, serial, tty_tty, null).  Not this increment's to do.
;------------------------------------------------------------------------------
_FarSh_CdIoctl  PHB
                PHK
                PLB                     ; DBR = CORE bank
                LDA     _Sys_IoctlCmd   ; save the syscall path's staging
                PHA
                LDA     _Sys_IoctlArgLo
                PHA
                LDA     _Sys_IoctlArgBank
                PHA
                ; +7: PHB (1) and three PHA (6).
                LDA     13,S            ; cmd
                STA     _Sys_IoctlCmd
                LDA     15,S            ; arg lo16
                STA     _Sys_IoctlArgLo
                LDA     17,S            ; arg bank
                STA     _Sys_IoctlArgBank
                LDA     11,S            ; A.lo = dev index
                JSR     _Chardev_Ioctl  ; C=1 ok / C=0 + A=errno
                BCC     @cdi_err
                LDA     #0              ; success is errno 0
@cdi_err        TAY                     ; park it; the restores clobber A
                PLA
                STA     _Sys_IoctlArgBank
                PLA
                STA     _Sys_IoctlArgLo
                PLA
                STA     _Sys_IoctlCmd
                PLB
                TYA
                RTL

;------------------------------------------------------------------------------
; _FarSh_SelWakeup - BSD's selwakeup, as FGX spells it.  No arguments.
;
; UPSTREAM WAKES ONE RECORDED SELECTOR; FGX WAKES THE CHANNEL.  BSD's
; selwakeup(p, coll) takes the proc that registered itself in tp->t_rsel and
; wakes it (or, on a collision, everything).  FGX's select(2) records itself on
; nothing: _Sys_Select is a poll-and-yield loop whose block-forever arm sleeps
; on the single WCHAN_SELECT (syscall.s:1349), and the kbd, socket and idle
; sites in sched.s already wake it exactly this way.  So there is one channel
; and no per-tty registration to consult.
;
; THE GUARD IS THE SAME ONE THOSE SITES USE and is not an optimisation: _wakeup
; walks the scheduler table, and this is reached from the discipline's inner
; loops.  sched.s:172 and :194 are the pattern.
;------------------------------------------------------------------------------
_FarSh_SelWakeup PHB
                PHK
                PLB                     ; DBR = CORE bank
                LDA     _nSelSleepers
                BEQ     @fsw_done
                LDA     #WCHAN_SELECT
                JSR     _wakeup
@fsw_done       PLB
                RTL

;------------------------------------------------------------------------------
; _FarSh_Gsignal - BSD's gsignal(pgrp, sig) for a bank that is not the core one.
;
; In:  MX %00.  4,S = pgrp, 6,S = sig (above this shim's 3-byte return address).
;      D = the kernel's REAL direct page; _Kill_GroupFanout is DP-safe only on
;      it, and it reaches the scheduler table through _schedTblPtr.
; Out: nothing.  A/X/Y clobbered, as _Kill_GroupFanout clobbers them.
;
; _Kill_GroupFanout IS the fan-out BSD's gsignal performs -- post the signal to
; every live non-zombie task whose SE_PGroup matches -- and it is already shared
; by _Sys_Kill's group forms and _Tty_DeliverSig.  It takes
; the signal in A, the pgid in X and the broadcast flag in Y, and does its own
; precompute.  REGISTERS AND NOT CELLS, which matters most on THIS path: this
; shim is what `ttyinput' reaches at interrupt time, so a cell written here
; would be the one the fan-out's own SEI bracket cannot protect (apple/fgx#379).
;
; NOT _Tty_DeliverSig, though that is the closer-looking name: that one takes a
; TTY INDEX and reads _ttyTable+TTY_FgPgrp, and _ttyTable is what T3 deletes.
; The tty bank has its own `struct tty' with t_pgrp, so it holds the pgid the
; fan-out wants and needs no table lookup at all.
;------------------------------------------------------------------------------
_FarSh_Gsignal  PHB
                PHK
                PLB                     ; DBR = CORE bank
                LDA     5,S             ; pgrp (+1 for the PHB)
                TAX
                LDY     #0              ; a GROUP signal, never a broadcast: the
                                        ;   flag is a fan-out input like the
                                        ;   pgid and every caller states which
                                        ;   it is
                LDA     7,S             ; sig
                JSR     _Kill_GroupFanout
                PLB
                RTL

;------------------------------------------------------------------------------
; _FarSh_CdWrite - write a RUN of bytes to a chardev, for a bank that is not
; the core one.  apple/fgx#108 T3 stage 3.
;
; In:  MX %00.  Frame (above this shim's own 3-byte return address):
;        4,S dev index   6,S run lo16   8,S run bank   10,S count
;      D = the kernel's REAL direct page.
; Out: nothing.  A short write cannot be reported through this ABI and does not
;      need to be: the only devices a tty line drives are the console and the
;      pty rings, and both consume every byte or sleep.
;
; A RUN AND NOT A BYTE, and that is the whole point of it.  The tty bank's
; output routine drains `t_outq' with `ndqb', which hands back a CONTIGUOUS run
; inside one cblock -- upstream's `dzstart' does exactly this -- so one crossing
; carries up to a cblock's worth of characters instead of one.  A per-byte shim
; would put a JSL, a PHD/TCD pair and a return on every character the machine
; prints.
;
; THE RUN LIVES IN THE TTY BANK, so it is walked with a DP long pointer:
; `_ttyRunPtr' (dpmap.s, $64).  There is no stack-relative indirect LONG
; addressing mode on the 65816, so parking it on the direct page is not a
; convenience -- it is the only way to reach the bytes at all.
;
; _cdArgByte IS THE CHARDEV PUTC ABI, staged per byte exactly as KSVC_CDWRITE's
; arm stages it (jumptable.s), because _Chardev_Write reads the byte from there
; rather than from a register.
;------------------------------------------------------------------------------
_FarSh_CdWrite  PHB
                PHK
                PLB                     ; DBR = CORE bank
                ; NAME THE LINE.  apple/fgx#255.  `_Ttyv_Write' asks
                ; `_Sys_WrCdIdx' which line it is writing to rather than taking
                ; it from the dispatch, so a caller that leaves it alone writes
                ; to whatever line the last write(2) was for.  KSVC_CDWRITE's
                ; arm sets it and states exactly that (jumptable.s); THIS seam
                ; is the other caller and did not -- so the discipline's own
                ; output, which is every echoed keystroke since the receive
                ; interrupt started running ttyinput at arrival time, reached
                ; the drivers unnamed.  It worked only because the line's own
                ; last write(2) happened to name it.
                ;
                ; NO `_Vc_WriteEnter'/`_Vc_WriteLeave' BRACKET, deliberately.  An
                ; earlier cut wrapped the run in that pair to fix the cursor
                ; here, and it reordered output enough to interleave a typed
                ; line's echo with concurrent program output.  That pair swaps
                ; console banks and suppresses rendering for the whole run; the
                ; hide below is not it, and changes no ordering.
                ;
                ; THE ENGINE IS POINTED AT THE LINE'S CONSOLE ONLY IF IT IS NOT
                ; THERE ALREADY, by `_Vc_EchoEnter', and returned to the console
                ; it was found on by `_Vc_EchoLeave' (ttyv.s).  A write(2)'s runs
                ; arrive inside their own bracket and the pair does nothing for
                ; them; the discipline's own output can arrive with the keyboard
                ; on a console the SHR screen is not showing -- the card's,
                ; after Option-4 -- and without the hop its echo lands in, and is
                ; painted on, whichever console the engine was describing.
                LDA     5,S             ; dev index (+1 for the PHB above)
                AND     #$00FF
                STA     _Sys_WrCdIdx
                JSR     _Vc_EchoEnter
                ; TAKE THE CURSOR DOWN FIRST, which is what every other writer
                ; does and what this seam did not.  apple/fgx#287.
                ;
                ; `_Con_WriteCharAtCursor' (console_char.s) retires the cursor
                ; record when a byte lands ON the drawn cell, and
                ; that covers only the case where a byte lands there: BS, CR, LF
                ; and TAB move the caret and write NO cell, so the record stayed
                ; live at the old cell and `Con_ShowCursor' -- idempotent on
                ; VT_CURS_RENDERED -- then refused to draw the cursor where the
                ; caret had gone.
                ;
                ; MEASURED 2026-09-01, `ls foo' typed at a cooked /bin/sh prompt
                ; and erased back to `ls ' with three DELs: the caret was at
                ; column 8 and the one inverse AttrBuf cell was at column 11,
                ; three columns behind, and stayed there for the rest of the
                ; line.  It is a /bin/sh symptom because tcsh takes the line in
                ; raw mode and echoes through write(2), which has hidden the
                ; cursor since apple/fgx#129; the discipline's own echo is the
                ; only output rail that had no hide.
                ;
                ; IT ALSO CLOSES THE WINDOW A SCROLL OPENS.  The LF that ends a
                ; typed line scrolled the console with the cursor still drawn,
                ; and the hide that eventually came had to reach a cell the
                ; scroll had moved -- see Con_HideCursor (console_char.s), which
                ; no longer trusts a remembered viewport row.
_kfp402         JSL     KFAR_CON_HIDECURSOR
                ; +1 for the PHB above.
                ; TYA/CMP AND NOT CPY: the 65816 has stack-relative CMP and
                ; NOT stack-relative CPY, so the count cannot be compared
                ; against Y directly.
                LDY     #0
@cdw_L          TYA
                CMP     11,S            ; count
                BCS     @cdw_done
                ; THE RUN POINTER IS REBUILT EVERY BYTE, and that is not
                ; wasteful -- it is the whole correctness argument.  The obvious
                ; shape is to set _ttyRunPtr once before the loop; it does not
                ; survive, because _Chardev_Write dispatches into a MODULE and
                ; the kernel direct page is not this routine's to hold across
                ; one.  Setting it once made the FIRST byte of every run
                ; correct and the rest garbage, which reads as text with
                ; characters substituted and doubled rather than as an obvious
                ; failure: `ttypeneg' showed "Ihus no jjob control" and passed
                ; the moment the run was cut to one byte.  The stack frame is
                ; the only copy that is safe here, so it is the copy that is
                ; read.
                LDA     7,S             ; run lo16, from the frame
                STA     _ttyRunPtr
                SEP     #$20
                MX      %10
                LDA     9,S             ; run bank (low byte of the word)
                STA     _ttyRunPtr+2
                LDA     [_ttyRunPtr],Y
                REP     #$20
                MX      %00
                AND     #$00FF
                STA     _cdArgByte      ; the chardev putc ABI
                PHY                     ; _Chardev_Write clobbers Y
                LDA     7,S             ; dev index -- 5,S plus 2 for the PHY
                AND     #$00FF
                JSR     _Chardev_Write
                PLY
                INY
                BRA     @cdw_L
@cdw_done       ; AND PUT THE CURSOR BACK, closing the pair the hide above opens.
                ; apple/fgx#255.
                ;
                ; The hide leaves VT_CURS_RENDERED clear for the whole run, so
                ; this always draws, and it draws where the caret ENDED -- which
                ; is the point: the run may have moved the caret with control
                ; characters that wrote no cell at all.
                ;
                ; IT IS NOT ONLY THE ECHO THAT REACHES THIS, and the note that
                ; used to stand here said it was -- "write(2) has its own byte
                ; loop", which stopped being true at T3 stage 3.  A tty write(2)
                ; goes to `ttwrite' now, and `tty_oproc' drains `t_outq' by
                ; calling `kc_cdwrite' ONCE PER CONTIGUOUS RUN (tty_dev.c:640),
                ; so one write(2) can arrive here several times, INSIDE the
                ; hide/show bracket `_Vc_WriteEnter' already opened.
                ;
                ; That is harmless because the pair is closed per run: run N
                ; draws the cursor at the caret and run N+1's hide takes it down
                ; again before a byte lands, so no run leaves a cursor sitting in
                ; the middle of text a later run paints over.  The outer show in
                ; `_Vc_WriteLeave' then finds it already drawn and returns on its
                ; own idempotence test.
_kfp401         JSL     KFAR_CON_SHOWCURSOR
                JSR     _Vc_EchoLeave   ; back to the console the engine was on
                PLB
                RTL

;------------------------------------------------------------------------------
; _FarSh_CdStop - cdevsw[].d_stop for a bank that is not the core one.
;
; In:  MX %00.  4,S = dev index, 6,S = rw (above the 3-byte return address).
;      D = the kernel's REAL direct page.
; Out: nothing.  _Chardev_Stop answers C=1 whether or not the device had a
;      stop, and upstream's callers ignore the return too.
;
; _cdArgFlag IS THE FLAG CHANNEL, which is how every chardev op takes its X
; argument (_Chardev_Dispatch reloads X from it just before the JSL).  It is
; saved and restored for the same reason _FarSh_CdIoctl saves the ioctl
; staging cells: it is a kernel singleton, and d_stop's eventual caller is
; ttyinput, which returns to arrival time at T6.
;
; THE TWO OFFSETS BELOW WERE EACH ONE LOW UNTIL T4 INCREMENT 5, and the fault
; was invisible because nothing reachable had a d_stop.  PHB is one byte and
; the PHA is two, so the arguments move up by THREE -- `_FarSh_CdIoctl' two
; screens up does the same sum correctly for four of them (4 -> 11, 6 -> 13,
; 8 -> 15, 10 -> 17).  Reading 6,S and 8,S instead took the RETURN ADDRESS'S
; BANK BYTE as the device index and `rw << 8' as the flag, so every
; `ttyflush(FWRITE)' and every `ttstop' on every line dispatched d_stop
; against chardev $02 with a flag of 0 or $0200.  The only device with a real
; d_stop was the serial line (serial.s:341), so the wrong dispatch found a
; zero slot and `_Chardev_Stop' returned without a sound.  `ptypkt' is what
; made it visible: a pty slave's d_stop is `ptsstop', and it is the first one
; a tty line was ever supposed to reach.
;------------------------------------------------------------------------------
_FarSh_CdStop   PHB
                PHK
                PLB                     ; DBR = CORE bank
                LDA     _cdArgFlag
                PHA
                LDA     9,S             ; rw (+1 PHB, +2 PHA)
                STA     _cdArgFlag
                LDA     7,S             ; dev index
                JSR     _Chardev_Stop
                PLA
                STA     _cdArgFlag
                PLB
                RTL

;------------------------------------------------------------------------------
; _FarSh_SeTtyOpen - ttyopen's session acquisition, for a bank that is not the
; core one.  apple/fgx#108 T3.
;
; In:  MX %00.  4,S = tty INDEX, 6,S = that line's current t_pgrp (above this
;      shim's 3-byte return address).
;      D = the kernel's REAL direct page: _Se_TtyOpenPg reaches the scheduler
;      table through the DP long pointer _schedTblPtr.
; Out: A = the line's t_pgrp after the open, for the CALLER to store.
;
; THE PGRP TRAVELS BOTH WAYS BECAUSE THE TTY STATE IS THE CALLER'S.  The tty
; bank has its own `struct tty' and its own t_pgrp; the core's _ttyTable copy is
; a different object that this must not touch on its behalf.  What the core
; still answers is the half only it can: WHICH PROCESS this open is for --
; _kCttyTarget when a spawn is applying file actions, _curTask otherwise,
; because init opens the device inside the CHILD.  BSD's ttyopen is implicitly
; u.u_procp and cannot express that, which is why this one call exists at all
; (docs/history/plans/tty-kernel-bank.md section 9).
;------------------------------------------------------------------------------
_FarSh_SeTtyOpen PHB
                PHK
                PLB                     ; DBR = CORE bank
                LDA     5,S             ; tty index (+1 for the PHB)
                TAX
                LDA     7,S             ; the line's current t_pgrp
                JSR     _Se_TtyOpenPg   ; -> A = the pgrp after the open
                PLB
                RTL

;------------------------------------------------------------------------------
; The three PER-PROCESS reads ttwrite's background gate needs, for a bank that
; is not the core one.  apple/fgx#108 T3.
;
; THREE SHIMS RATHER THAN ONE PREDICATE, and that is the design decision
; docs/history/plans/tty-kernel-bank.md section 9 argues from the source.  Both BSD trees put
; the job-control PREDICATE in the tty layer and none of them in the signal
; code; Reno factors it as `isbackground(p, tp)' in sys/tty.h and HANDS it the
; proc rather than letting it reach a global.  So the conjunction is C in
; tty.c, and these carry the fields it cannot see.
;
; Each answers a NEUTRAL value with no current task rather than an error, so
; the gate simply cannot fire during boot: no group, no controlling terminal,
; not a vfork child.
;
; D = the kernel's REAL direct page in all three: every one of them reaches the
; scheduler table or the signal tables through a DP long pointer.
;------------------------------------------------------------------------------
_FarSh_CurPgrp  PHB
                PHK
                PLB                     ; DBR = CORE bank
                JSR     _Se_CurPgrp     ; A = p_pgrp, 0 = no task
                PLB
                RTL

; BSD's `tp == u.u_ttyp' half: A = the caller's controlling-terminal INDEX, or
; $FFFF for none.  The tty bank compares it with the index of the line in hand,
; which is the same test upstream writes as a pointer compare -- FGX stores the
; ctty as an index in SE_Flags rather than as a `struct tty *', so the pointer
; identity BSD relies on does not exist here to compare.
_FarSh_CurCtty  PHB
                PHK
                PLB                     ; DBR = CORE bank
                JSR     _Se_CurCtty     ; A = ctty index, or $FFFF
                PLB
                RTL

; 4,S = signal, 6,S = 0 for p_sigignore or 1 for p_sigmask.  A SELECTOR RATHER
; THAN TWO ENTRY POINTS because the two differ only in a table base, and
; _Sig_CurOpted already takes that base as an argument -- two shims would be
; two export slots and two manifest rows saying the same thing.
_FarSh_SigOpted PHB
                PHK
                PLB                     ; DBR = CORE bank
                LDY     #SIGHND_IGN_OFF
                LDA     7,S             ; which table (+1 for the PHB)
                BEQ     @fso_have
                LDY     #SIGHND_MASK_OFF
@fso_have       LDA     5,S             ; signal
                JSR     _Sig_CurOpted   ; C=1 = opted out
                LDA     #0
                BCC     @fso_no
                LDA     #1
@fso_no         PLB
                RTL

; No frame at all, unlike its neighbour above: _Sig_CurPending takes no
; argument, so there is nothing to reach past the PHB for.  A = the pending
; mask's low word, X = its high word, and PLB touches neither.
_FarSh_CurUid   PHB
                PHK
                PLB                     ; DBR = CORE bank
                JSR     _Se_CurUid      ; A = effective uid, 0 = root
                PLB
                RTL

; 4,S = pgrp, past the PHB.  ONE shim for the whole ownership test: the core
; already owns pfind (Task_Lookup) and inferior (_Spg_Permitted's walk), so
; sending three answers across would be three round trips to reassemble a
; predicate that exists on the far side already.
_FarSh_SpgOk    PHB
                PHK
                PLB                     ; DBR = CORE bank
                LDA     5,S             ; pgrp (+1 for the PHB)
                JSR     _Se_SpgOk       ; C=1 = permitted
                LDA     #0
                BCC     @fsp_no
                LDA     #1
@fsp_no         PLB
                RTL

_FarSh_SigPending PHB
                PHK
                PLB                     ; DBR = CORE bank
                JSR     _Sig_CurPending ; A = bytes 0,1  X = bytes 2,3
                PLB
                RTL

;------------------------------------------------------------------------------
; _FarSh_Ureadc - ureadc(c, uio) for the tty bank, forwarded to vfs.mod.
;
; _FarSh_Uiomove's twin, and the frame is SIX bytes rather than ten: c (2) +
; uio (4).  Counted rather than assumed, for the reason that shim's header
; gives -- the frame reaches vfs.mod through two calls.
;
; In:  the caller pushed six argument bytes and JSLed here, so they begin at
;      9,S: three for this shim's return address, plus the six.
; Out: A = ureadc's errno, and the six argument bytes are DROPPED here.
;      C=0 + A=EIO if the resolve never ran.
;------------------------------------------------------------------------------
_FarSh_Ureadc   PHB
                PHK
                PLB                     ; DBR = CORE bank, for the statics below
                MX      %00
                LDA     _ttyVfsBank
                AND     #$00FF
                BNE     @fur_have
                PLB
                LDA     #EIO
                CLC
                RTL
@fur_have       ; --- re-push the six argument bytes for vfs.mod --------------
                ; At entry: 1..3,S the JSL return, 4..9,S the six argument
                ; bytes, three words at 4, 6 and 8.  The PHB above adds ONE, so
                ; the LAST word starts at 9,S -- and each PHA adds two, which
                ; walks 9,S backwards through the other two.  Last-first is what
                ; re-creates the frame in order.  COUNTED, not assumed: the same
                ; slip in the uiomove twin answered `uiomove: mode'.
                LDA     9,S
                PHA
                LDA     9,S
                PHA
                LDA     9,S
                PHA
                LDX     _ttyVfsUreadc           ; offset within vfs.mod
                SEP     #$20
                MX      %10
                LDA     _ttyVfsBank
                PHA
                PLB                             ; DBR = vfs.mod.  NET ZERO.
                REP     #$30
                MX      %00
                PHK                             ; @fur_ret is in the CORE bank
                PEA     @fur_ret-1
                PHB                             ; target bank
                TXA
                DEC     A
                PHA                             ; target - 1
                RTL                             ; PILECALL
@fur_ret        TAY                             ; park the answer
                TSC
                CLC
                ADC     #6                      ; drop the re-pushed arguments
                TCS
                TYA
                PLB                             ; back to the caller`s bank
                RTL

_FarSh_Halt     JSR     _Halt           ; never returns; the RTL is unreachable
                RTL                     ;   and present only for uniformity

;------------------------------------------------------------------------------
; _Tty_LoadVfsPtr - resolve vfs.mod's uiomove and ureadc for the tty bank.
; Called once
; from main.s AFTER Mod_LoadConf.  apple/fgx#108 T3.
;
; In:  none.  MX %00.  DBR = core bank.
; Out: C=1 resolved, C=0 no VT_VFSCORE module.  A, X, Y, _libcTmp2 clobbered.
;
; The vtable holds 16-BIT bank-relative offsets and the bank comes from the
; registry, exactly as _Pty_LoadOpsPtr reads VT_CHARDEV.
;------------------------------------------------------------------------------
_Tty_LoadVfsPtr ENT
                MX      %00
                STZ     _ttyVfsBank             ; unresolved until proven
                STZ     _ttyVfsUio
                STZ     _ttyVfsUreadc
                LDA     #VT_VFSCORE
                JSR     Mod_FindVtable          ; C=1: A=voffset, X.lo=bank
                BCC     @tlv_none
                STA     _libcTmp2
                SEP     #$20
                MX      %10
                TXA
                STA     _libcTmp2+2             ; module bank
                REP     #$30
                MX      %00
                LDY     #VFSCORE_Uiomove
                LDA     [_libcTmp2],Y
                STA     _ttyVfsUio
                LDY     #VFSCORE_Ureadc
                LDA     [_libcTmp2],Y
                STA     _ttyVfsUreadc
                LDA     _libcTmp2+2
                AND     #$00FF
                STA     _ttyVfsBank             ; nonzero == resolved
                SEC
                RTS
@tlv_none       CLC
                RTS

;------------------------------------------------------------------------------
; _FarSh_Uiomove - uiomove(cp, n, uio) for the tty bank, forwarded to vfs.mod.
;
; THE ONLY SHIM HERE THAT TAKES A STACK FRAME, and the only one whose callee is
; in a MODULE rather than the core.  Both follow from what it is: the tty bank
; is a static bank and uiomove lives in a loadable one, so there is no address
; to bake and the arguments do not fit registers -- cp (4) + n (2) + uio (4).
;
; In:  the caller pushed ten bytes of arguments and JSLed here, so they begin
;      at 13,S: three for THIS shim`s return address, plus the ten.  COUNT THEM
;      rather than assuming: the frame reaches vfs.mod through two calls, and a
;      shim that guessed the depth is what the first cut of _Chardev_Bulk got
;      wrong (chardev.s).
; Out: A = uiomove`s errno, and the ten argument bytes are DROPPED here.
;
; C=0 + A=EIO if the resolve never ran.  vfs is FIRST in modload.conf so this
; cannot happen on a booted machine, but PILECALLing into bank zero is what the
; alternative looks like.
;------------------------------------------------------------------------------
_FarSh_Uiomove  PHB
                PHK
                PLB                     ; DBR = CORE bank, for the statics below
                MX      %00
                LDA     _ttyVfsBank
                AND     #$00FF
                BNE     @fsu_have
                PLB
                LDA     #EIO
                CLC
                RTL
@fsu_have       ; --- re-push the ten argument bytes for vfs.mod -------------
                ; 13,S, AND COUNTING THEM IS NOT OPTIONAL -- the first cut of
                ; this said 14 and the machine answered `uiomove: mode', which
                ; is uiomove reading a uio_rw one byte out of line.
                ;
                ; At entry: 1..3,S the JSL return, 4..13,S the ten argument
                ; bytes, five words starting at 4,6,8,10,12.  The PHB above
                ; adds ONE, so the LAST word starts at 13,S -- and each PHA
                ; below adds two, which walks 13,S backwards through the other
                ; four.  Last-first is what re-creates the frame in order.
                LDA     13,S
                PHA
                LDA     13,S
                PHA
                LDA     13,S
                PHA
                LDA     13,S
                PHA
                LDA     13,S
                PHA
                LDX     _ttyVfsUio              ; offset within vfs.mod
                SEP     #$20
                MX      %10
                LDA     _ttyVfsBank
                PHA
                PLB                             ; DBR = vfs.mod.  NET ZERO.
                REP     #$30
                MX      %00
                PHK                             ; @fsu_ret is in the CORE bank
                PEA     @fsu_ret-1
                PHB                             ; target bank
                TXA
                DEC     A
                PHA                             ; target - 1
                RTL                             ; PILECALL
@fsu_ret        TAY                             ; park the answer
                TSC
                CLC
                ADC     #10                     ; drop the re-pushed arguments
                TCS
                TYA
                PLB                             ; back to the caller`s bank
                RTL
