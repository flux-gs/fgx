;==============================================================================
; vfs_seam.s - THE INWARD SEAM's far-bank half: resolve VT_VFSCORE, then run
; the check.  UFS 1.7d.
;
; src/kernel/main.s said for months that this seam "returns when 1.6b's namei
; gives the VFS a syscall-path customer, shaped by that customer", and
; src/modules/vfs/vfs.s said the other half: VT_VFSCORE "points SIDEWAYS rather
; than up -- the kernel calls into the VFS at zero points today".  Both stop
; being true here.  The customer is the DESCRIPTOR LAYER: open(2) needs falloc,
; every fd-taking syscall needs getf, close(2) needs fdrelease and closef.
;
;------------------------------------------------------------------------------
; WHY THE FAR BANK, MEASURED RATHER THAN PREFERRED.  This was built in the CORE
; bank first and killed the boot with no output at all.  Three reasons it
; belongs here, in the order they matter:
;
;   1. THE IMPORT SHIMS MUST BE ENTERED FROM C.  Every shim in vfs_import.s
;      says so in its own comment -- "entered from C, which left DBR on our
;      bank" -- and the callee is fcc-compiled C that needs the register file
;      on FGX_DP_KERNELC.  The far bank RUNS kernel C: fcc_rt.s, fcc_dp.s,
;      fcc_ktrap.s and fcc_runtime_data.s are all PUT here.  Calling module C
;      from far-bank C is C to C, with the direct page already established.
;      From core assembly it is not, and hand-bracketing D around the call to
;      fake it re-implements what the C entry already does.
;
;   2. ROOM, AND ONLY AS A TIEBREAK.  Core had 1,272 bytes free when this was
;      written; the far bank had 44,658.  That is not the reason -- see 1 --
;      but it is why nothing here has to be rationed.
;
;   3. THE SLOT WAS ALREADY RESERVED.  far.s's slots 28-30 are stubbed and
;      their comment reads "They were bufinit, vfs_probe and vfs_init ... the
;      core has nothing to call".  Those WERE the kernel-to-VFS slots, kept
;      because the table's shape is ABI.  This is that call coming back.
;
; _kVfsBank / _kVfsImp are DECLARED BY THE GENERATOR in vfs_import.s, with the
; shims that read them, for the same reason the module tables are: the cells
; and their readers are one thing.  This file only FILLS them.
;==============================================================================

                MX      %00

;------------------------------------------------------------------------------
; _Vfs_SeamEntry - far slot 28.  Resolve, then check, then say so.  Entered by
; JSL from the core bank (main.s), returns by RTL.
;
; A MISS IS NOT FATAL.  A kernel whose /etc/modload.conf has no vfs.mod still
; boots; _kVfsBank stays zero, the GUARD below skips the C -- a shim reading a
; zero table would pile-call bank 0 offset $FFFF (vfs_import.s's own warning)
; -- and the check logs the failure line instead.  Same contract
; _Net_LoadOpsPtr has for a machine with no net.mod.
;
; THE C CALL IS A PILE CALL, NOT A JSL -- and that distinction was the whole
; 1.7d boot wedge.  `JSL vfs_seam_check` assembles its bank byte from this
; file's ORG, $08, and nothing patches it: the far bank's runtime home is the
; kernel bank + 1, unknowable at assembly AND at load -- the same fact that
; makes fcc keep PHK for every C-to-C call it emits in this bank
; (apple/fgx#173).  The baked JSL sent the boot into the bank-$08 heap arena
; and the machine BRK-stormed with no output at all.  MEASURED: the listing
; read `22 A7 12 08`, and the boot-stack post-mortem held that JSL's own
; frame, intact, directly above the wreck.  PHK sources the LIVE bank, so the
; pile form cannot go stale.  It is also why this code is the ENTRY's tail
; rather than a JSR'd helper: a routine containing the pile RTL may not be a
; JSR target (check_far_rtl_calls.py), and the entry already ends in RTL.
;
; D IS BRACKETED around the C because the callee is fcc-compiled: its register
; file is $98-$FF ON WHATEVER PAGE D NAMES, and arriving with boot's kernel D
; would put its _fcc_fpr writes on the KERNEL page -- $9E there is _curTask,
; the parked TCB offset main.s reads back right after this seam returns.  Same
; contract as KC_ENTER / MOD_KC_ENTER.  NOT wrapped around _Vfs_ResolveOps,
; which needs the KERNEL page: Mod_FindVtable walks [_modRegPtr], a kernel DP
; cell.
;
; THE C RETURNS A VALUE AND THIS DOES THE TALKING, because the console is CORE
; and reaching it is a far-to-core shim (_FarSh_LogStr).  Keeping that out of
; the C leaves vfs_seam.c with one job and one answer, checkable by reading it.
;
; LOGGED EITHER WAY, on purpose: a boot that says nothing about the seam is
; indistinguishable from a boot whose check never ran, and "nothing checks it"
; is the exact failure this whole seam exists to stop being true.
;------------------------------------------------------------------------------
_Vfs_SeamEntry  ENT
                MX      %00
                PHB
                PHK
                PLB                     ; DBR = the FAR bank: our cells are here
                JSR     _Vfs_ResolveOps
                LDA     _kVfsBank       ; the miss guard -- see the header
                BEQ     _VfsSeamMiss
                PHD                     ; boot's kernel D, saved
                LDA     #FGX_DP_KERNELC
                TCD                     ; D = fcc's register file page
                PHK
                PEA     _VfsSeamRet-1
                PHK
                PEA     vfs_seam_check-1
                RTL                     ; pile call; the C returns via RTL here
_VfsSeamRet     PLD                     ; kernel D back; A, the verdict, survives
                CMP     #$0000
                BNE     _VfsSeamOK
_VfsSeamMiss    LDA     #_msg_vfs_seam_bad
                BRA     _VfsSeamSay
                ; A WORKING SEAM SAYS NOTHING.  `vfs: seam ok' was on the boot
                ; console for every user of every machine to report that a
                ; cross-bank call returned -- which every filesystem operation
                ; after it demonstrates.  The FAILURE still speaks, and loudly.
_VfsSeamOK      PLB
                RTL
_VfsSeamSay     ; Kern_LogStr's argument is _conStrPtr, a KERNEL direct-page
                ; word -- not a register (log.s:8, and the trap note at
                ; main.s' @lfb_emit).  D is the kernel page here -- boot's own
                ; on the miss path, restored by the PLD above otherwise -- so
                ; the store lands on the real cell; the string bytes are read
                ; with the CALLER's DBR, which is still THIS bank -- the
                ; reason _FarSh_LogStr does not switch DBR (far_shims.s:132).
                STA     _conStrPtr
_cfp401         JSL     _FarSh_LogStr           ; bank byte patched by Far_BankInit
                PLB
                RTL

_msg_vfs_seam_bad ASC   'vfs: SEAM BAD',00

;------------------------------------------------------------------------------
; _Vfs_ResolveOps - find VT_VFSCORE and copy its table into _kVfsImp.
;
; In:   MX %00, DBR = far bank.   Out: table copied, or _kVfsBank left zero.
;
; Mod_FindVtable IS CORE, so it goes through _FarSh_ModFindVtable -- the one
; far-to-core shim this seam needs, added for it in src/kernel/far_shims.s.
; The `_cfp` marker is what Far_BankInit patches the bank byte of; every
; far-to-core JSL in this bank carries one.
;
; ONE ENTRY AT A TIME, carrying it in A across the bank switch, because PHK/PLB
; touches no register.  The module copies used to push the WHOLE table and pop
; it back -- two bytes of stack per export -- and nothing re-derived that as the
; table grew; see apple/fgx#195 for how little boot stack there is to spend.
;------------------------------------------------------------------------------
_Vfs_ResolveUfs MX      %00
                ; The same walk as _Vfs_ResolveOps below, over ufs.mod's table
                ; instead -- UFS 1.7d I3.  Two tables rather than one generic
                ; walk because the destination array and its count differ, and
                ; a shared routine taking three arguments to save eleven lines
                ; would be the harder thing to read.
                ;
                ; A MISS IS NOT FATAL, exactly as it is not for VT_VFSCORE:
                ; _kUfsBank stays zero, the shim refuses, and the machine boots
                ; without a /dev rather than dying for the want of one.
                LDA     #VT_UFSCORE
_cfp402         JSL     _FarSh_ModFindVtable    ; bank byte patched by Far_BankInit
                BCS     @ur_have
                RTS                             ; C=0; _kUfsBank stays zero
@ur_have        TAY
                TXA
                AND     #$00FF
                STA     _kUfsBank
                TYX
                LDY     #0
@ur_L           SEP     #$20
                MX      %10
                LDA     _kUfsBank
                PHA
                PLB                             ; DBR = ufs.mod
                REP     #$20
                MX      %00
                LDA    |$0000,X
                PHK
                PLB                             ; DBR ours again -- A survives
                STA     _kUfsImp,Y
                INX
                INX
                INY
                INY
                CPY     #UFSCORE_COUNT*2
                BNE     @ur_L
                RTS

_Vfs_ResolveOps MX      %00
                LDA     #VT_VFSCORE
_cfp400         JSL     _FarSh_ModFindVtable    ; bank byte patched by Far_BankInit
                BCS     @vr_have
                RTS                             ; C=0; _kVfsBank stays zero
@vr_have        ; A = the table's bank-relative address, X.lo = its bank.
                TAY                             ; park the table address
                TXA
                AND     #$00FF
                STA     _kVfsBank
                TYX                             ; X = table address in vfs.mod

                LDY     #0                      ; destination index
@vr_L           SEP     #$20
                MX      %10
                LDA     _kVfsBank               ; readable only while DBR is ours
                PHA
                PLB                             ; DBR = vfs.mod
                REP     #$20
                MX      %00
                ; `|` IS LOAD-BEARING.  Without it Merlin sees a $0000 operand,
                ; shortens the address mode and emits the DIRECT PAGE form, so
                ; the loop would read fcc's register file instead of the table
                ; -- legal, silent, and plausible 16-bit values.
                LDA    |$0000,X                 ; the entry, from vfs.mod
                PHK
                PLB                             ; DBR ours again -- A survives
                STA     _kVfsImp,Y
                INX
                INX
                INY
                INY
                CPY     #VFSCORE_COUNT*2
                BNE     @vr_L
                RTS

;------------------------------------------------------------------------------
; _Vfs_DescAlloc / _Vfs_DescFree - far slots 29 and 30: the DESCRIPTOR SERVICE
; the core bank's FS layer calls.  UFS 1.7d I2b.
;
; Slots 29 and 30 were `vfs_probe' and `vfs_init' until the VFS became a module
; and the core had nothing to call.  Like slot 28 before them, these are that
; call coming back rather than a reuse of spare space -- the table's shape is
; ABI and the numbers were held open for exactly this.
;
; THE ARGUMENTS ARRIVE ON THE STACK, fcc's convention, pushed by the CORE, and
; THEY HAVE TO BE COPIED.  They cannot be passed where they lie: PHB and PHD
; put three bytes between the caller's arguments and the frame the C reads, so
; every `LDA n,S' in kdesc_alloc would land three bytes low -- assembling,
; running, and reading whatever is adjacent.  `fdp' is a POINTER the C writes
; THROUGH, so the shift is not a wrong answer but a wild 24-bit store, and it
; killed the boot before init with no output at all.
;
; The copy is the generated shims' idiom (tools/gen_mod_imports.py, and
; far/vfs_import.s): read the DEEPEST argument word first and push it, then
; read the SAME `n,S' again -- each push moves S down two, so a constant offset
; walks up the source by one word per iteration and reproduces the layout in
; order.  The caller cleans, so the copy is dropped on the way out.
;
; _Vfs_SeamEntry and _Vfs_FileInit above are immune and are not evidence: the
; first takes no arguments, and the second builds its own AFTER the bracket.
; This is the first entry to carry the core's arguments across it.
;
; The C is reached with the pile-call idiom rather than a JSL, because a JSL
; here bakes the assembly ORG bank and the far bank runs relocated -- the whole
; of apple/fgx#173, and what cost the seam a session.
;
; D IS BRACKETED because the C needs fcc's register file on FGX_DP_KERNELC.
; Without it the C's `_fcc_fpr` writes land on the kernel page, where $9E is
; _curTask -- read back moments later, which is a corruption that arrives
; nowhere near its cause.
;------------------------------------------------------------------------------
_Vfs_DescAlloc  ENT
                MX      %00
                PHB
                PHD
                PHK
                PLB                     ; DBR = far bank
                LDA     #FGX_DP_KERNELC
                TCD

                ; kdesc_alloc(pid, fcb, fd) -- 8 argument bytes (an int, a
                ; 4-byte pointer, an int).  At entry the JSL return sits at
                ; 1,S..3,S and the arguments at 4,S..11,S; PHB and PHD moved
                ; both down three, so the deepest argument word is at 13,S and
                ; stays there as the copy walks.
                LDA     13,S
                PHA
                LDA     13,S
                PHA
                LDA     13,S
                PHA
                LDA     13,S
                PHA

                PHK
                PEA     _VfsDescAllocRet-1
                PHK
                PEA     kdesc_alloc-1
                RTL                     ; pile call into the C
_VfsDescAllocRet TAY                    ; park the errno; the drop needs A
                TSC
                CLC
                ADC     #8              ; drop the copy -- the caller cleans
                TCS
                TYA
                PLD
                PLB
                RTL

_Vfs_DescFree   ENT
                MX      %00
                PHB
                PHD
                PHK
                PLB
                LDA     #FGX_DP_KERNELC
                TCD

                ; kdesc_free(pid, fd) -- 4 argument bytes, so the deepest word
                ; is at 9,S once PHB and PHD have shifted the frame by three.
                LDA     9,S
                PHA
                LDA     9,S
                PHA

                PHK
                PEA     _VfsDescFreeRet-1
                PHK
                PEA     kdesc_free-1
                RTL
_VfsDescFreeRet TAY                     ; park the errno; the drop needs A
                TSC
                CLC
                ADC     #4              ; drop the copy -- the caller cleans
                TCS
                TYA
                PLD
                PLB
                RTL


;------------------------------------------------------------------------------
; _Vfs_DescCopy / _Vfs_DescFreeAll - far slots 32 and 33: the file table's half
; of the PROCESS LIFECYCLE.  UFS 1.7d I2b.
;
; The core bank already inherits and releases the KERNEL fd table at two
; points -- _Task_CopyParentFds on the spawn/vfork path, and Task_FreeFdTable
; at teardown.  These are the file table making the same two moves from the
; same two call sites, and they exist because the tables must agree on which
; descriptor numbers a process holds.  When they did not: a child's ofile[] was
; empty, so falloc handed its first open(2) fd 0 -- over the stdin it had just
; inherited -- and `ls /' printed nothing.
;
; Same argument-copy obligation as slots 29/30 above; see the note there.
;------------------------------------------------------------------------------
_Vfs_DescCopy   ENT
                MX      %00
                PHB
                PHD
                PHK
                PLB                     ; DBR = far bank
                LDA     #FGX_DP_KERNELC
                TCD

                ; fdcopy(frompid, topid) -- 4 argument bytes, so the deepest
                ; word is at 9,S once PHB and PHD have shifted the frame.
                LDA     9,S
                PHA
                LDA     9,S
                PHA

                PHK
                PEA     _VfsDescCopyRet-1
                PHK
                PEA     fdcopy-1
                RTL                     ; pile call into the C
_VfsDescCopyRet TAY                     ; park the errno; the drop needs A
                TSC
                CLC
                ADC     #4              ; drop the copy -- the caller cleans
                TCS
                TYA
                PLD
                PLB
                RTL

_Vfs_DescFreeAll ENT
                MX      %00
                PHB
                PHD
                PHK
                PLB
                LDA     #FGX_DP_KERNELC
                TCD

                ; fdfreeall(pid) -- 2 argument bytes, at 7,S after the shift.
                LDA     7,S
                PHA

                PHK
                PEA     _VfsDescFreeAllRet-1
                PHK
                PEA     fdfreeall-1
                RTL
_VfsDescFreeAllRet TAY                  ; park the errno; the drop needs A
                TSC
                CLC
                ADC     #2              ; drop the copy -- the caller cleans
                TCS
                TYA
                PLD
                PLB
                RTL


;------------------------------------------------------------------------------
; far slot 44 -- THE ROOT MOUNT, UFS 2.4b.  Same shape as slot 36 above and
; for the same reasons: resolve ufs.mod's table first, because without it
; there is no filesystem to mount the boot volume WITH, and report that
; distinctly from "the volume is not one of ours".
;
; Takes no arguments, so the PHB/PHD bracket needs no argument copy.
;------------------------------------------------------------------------------
_Vfs_RootMount  ENT
                MX      %00
                PHB
                PHD
                PHK
                PLB                     ; DBR = far bank
                JSR     _Vfs_ResolveUfs
                LDA     _kUfsBank
                AND     #$00FF
                BEQ     @rm_none        ; no ufs.mod: nothing to mount with
                LDA     #FGX_DP_KERNELC
                TCD
                PHK
                PEA     _VfsRootMountRet-1
                PHK
                PEA     root_mount-1
                RTL                     ; pile call into the C
_VfsRootMountRet PLD
                PLB
                RTL
@rm_none        LDA     #$FFFD          ; -3: no ufs.mod.  DISTINCT from the
                                        ;   C's -1 ("not a 2.11BSD volume")
                                        ;   and -2 ("mounted, no root"), so a
                                        ;   reader tracing the boot log knows
                                        ;   which of the three happened.
                PLD
                PLB
                RTL

_Vfs_DescDup    ENT
                MX      %00
                PHB
                PHD
                PHK
                PLB                     ; DBR = far bank
                LDA     #FGX_DP_KERNELC
                TCD

                ; fddup(pid, oldfd, newfd) -- 6 argument bytes, so the deepest
                ; word is at 11,S once PHB and PHD have shifted the frame.
                LDA     11,S
                PHA
                LDA     11,S
                PHA
                LDA     11,S
                PHA

                PHK
                PEA     _VfsDescDupRet-1
                PHK
                PEA     fddup-1
                RTL
_VfsDescDupRet  TAY                     ; park the errno; the drop needs A
                TSC
                CLC
                ADC     #6              ; drop the copy -- the caller cleans
                TCS
                TYA
                PLD
                PLB
                RTL

;------------------------------------------------------------------------------
; _Vfs_Flock - slot 77: vn_flock(fp, how) -> errno.  flock(2) on a descriptor
; the core has already found to be a vnode's; vn_flock is kern_flock.c, in
; ufs.mod, and the call goes straight to its import shim, which wants the
; frame a C caller would leave: DBR on this bank and D on fcc's page.  6
; argument bytes -- the fcc pointer's two words and `how' -- so the deepest
; word is at 11,S once PHB and PHD have shifted the frame.  vn_lock may sleep.
;------------------------------------------------------------------------------
_Vfs_Flock      ENT
                MX      %00
                PHB
                PHD
                PHK
                PLB                     ; DBR = far bank
                LDA     #FGX_DP_KERNELC
                TCD
                LDA     11,S
                PHA
                LDA     11,S
                PHA
                LDA     11,S
                PHA
                PHK
                PEA     _VfsFlockRet-1
                PHK
                PEA     vn_flock-1              ; the ufs_import.s shim
                RTL
_VfsFlockRet    TAY                     ; park the errno; the drop needs A
                TSC
                CLC
                ADC     #6              ; drop the copy -- the caller cleans
                TCS
                TYA
                PLD
                PLB
                RTL

;------------------------------------------------------------------------------
; _Vfs_Fsetattr - slot 78: vn_fsetattr(fp, mode, uid, gid) -> errno.
; fchmod(2) and fchown(2) on a descriptor the core has already found to be a
; vnode's; vn_fsetattr is kern_fsetattr.c, in ufs.mod, reached through its
; import shim as vn_flock is.  10 argument bytes -- the fcc pointer's two
; words, mode, uid, gid -- so the deepest word is at 15,S once PHB and PHD
; have shifted the frame.
;------------------------------------------------------------------------------
_Vfs_Fsetattr   ENT
                MX      %00
                PHB
                PHD
                PHK
                PLB                     ; DBR = far bank
                LDA     #FGX_DP_KERNELC
                TCD
                LDA     15,S
                PHA
                LDA     15,S
                PHA
                LDA     15,S
                PHA
                LDA     15,S
                PHA
                LDA     15,S
                PHA
                PHK
                PEA     _VfsFsetattrRet-1
                PHK
                PEA     vn_fsetattr-1           ; the ufs_import.s shim
                RTL
_VfsFsetattrRet TAY                     ; park the errno; the drop needs A
                TSC
                CLC
                ADC     #10             ; drop the copy -- the caller cleans
                TCS
                TYA
                PLD
                PLB
                RTL

_Vfs_DescMove   ENT
                MX      %00
                PHB
                PHD
                PHK
                PLB
                LDA     #FGX_DP_KERNELC
                TCD

                ; fdmove(pid, oldfd, newfd) -- 6 argument bytes, as above.
                LDA     11,S
                PHA
                LDA     11,S
                PHA
                LDA     11,S
                PHA

                PHK
                PEA     _VfsDescMoveRet-1
                PHK
                PEA     fdmove-1
                RTL
_VfsDescMoveRet TAY
                TSC
                CLC
                ADC     #6
                TCS
                TYA
                PLD
                PLB
                RTL

_Vfs_RootOpen   ENT
                ; far slot 45 -- UFS 2.4.  root_open(pid, fd, name, fmode,
                ; cmode): finish an open of an ABSOLUTE path against the
                ; mounted root, on a descriptor _Fcb_Alloc already made.
                ;
                ; TWELVE ARGUMENT BYTES, SO 17,S -- and it was slot 37's twin
                ; at ten and 15,S until the create mode was carried.  THE COPY
                ; COUNT IS THE WHOLE CONTRACT AND NOTHING DIAGNOSES IT: with
                ; five copies where six are due, root_open's frame is built
                ; from the word under the last one and the deepest argument is
                ; read from whatever was below the block.  MEASURED, and it is
                ; not a crash: every open still worked and every created file
                ; got a mode that varied per call -- 0400, 0400, 0 for three
                ; identical creates -- because the slot held stack residue.  It
                ; cost a bisect (literal in the C, then literal in the core
                ; push) to find, and apple/fgx#326's rename shim was the same
                ; shape: a short count is silent on both sides.
                ;
                ; The offset does NOT change per copy: each PHA moves the frame
                ; down exactly one word, so the same 17,S walks the source
                ; block deepest-first, which is the order the callee wants.
                ;
                ; NO _Vfs_ResolveUfs HERE, unlike slot 44 one along.  That one
                ; needs ufs.mod's own entry point to mount with; this one calls
                ; vfs_openat, which is IN THIS BANK, and reaches the filesystem
                ; through the vnode the mount already produced.  A root that
                ; never mounted is answered by root_open's own root_status
                ; test, not by a bank check here.
                MX      %00
                PHB
                PHD
                PHK
                PLB                     ; DBR = far bank
                LDA     #FGX_DP_KERNELC
                TCD

                LDA     17,S
                PHA
                LDA     17,S
                PHA
                LDA     17,S
                PHA
                LDA     17,S
                PHA
                LDA     17,S
                PHA
                LDA     17,S
                PHA

                PHK
                PEA     _VfsRootOpenRet-1
                PHK
                PEA     root_open-1
                RTL                     ; pile call into the C
_VfsRootOpenRet TAY                     ; park the errno; the drop needs A
                TSC
                CLC
                ADC     #12             ; drop the copy -- the caller cleans
                TCS
                TYA
                PLD
                PLB
                RTL

_Vfs_RootStat   ENT
                ; far slot 46 -- the path-syscall conversion.  root_stat(name,
                ; sb): resolve an ABSOLUTE path against the mounted root and
                ; fill the core's stat buffer from the vnode's attributes.
                ;
                ; TEN ARGUMENT BYTES -- a pid and two fcc pointers -- so 15,S
                ; once PHB and PHD have moved the frame down three.  Both
                ; pointers name CORE-bank memory (the path in the kernel bank,
                ; `_fsStatBuf' beside it), and the core-side stub supplies the
                ; bank in each; nothing here may use a `^' literal, which would
                ; assemble this bank's.
                ;
                ; A pid, AND THE NOTE HERE USED TO SAY THERE WAS NO USE FOR ONE:
                ; "a stat opens nothing and touches no file table, so there is
                ; no process for it to be about."  True of the FILE TABLE and
                ; false of the WALK.  A relative name is about a process -- it
                ; starts at that process's directory -- and with no pid to ask,
                ; this resolved `.' against the root and answered confidently
                ; about the wrong directory (apple/fgx#295).
                MX      %00
                PHB
                PHD
                PHK
                PLB                     ; DBR = far bank
                LDA     #FGX_DP_KERNELC
                TCD

                LDA     15,S
                PHA
                LDA     15,S
                PHA
                LDA     15,S
                PHA
                LDA     15,S
                PHA
                LDA     15,S
                PHA

                PHK
                PEA     _VfsRootStatRet-1
                PHK
                PEA     root_stat-1
                RTL                     ; pile call into the C
_VfsRootStatRet TAY                     ; park the errno; the drop needs A
                TSC
                CLC
                ADC     #10             ; drop the copy -- the caller cleans
                TCS
                TYA
                PLD
                PLB
                RTL

_Vfs_RootLstat  ENT
                ; far slot 56 -- lstat(2).  root_lstat(pid, name, sb): the
                ; SAME ten argument bytes and the same buffer as slot 46; the
                ; only difference is on the far side, where namei is asked
                ; without FOLLOW so a final symlink is described rather than
                ; resolved.  Cloned from _Vfs_RootStat deliberately: the two
                ; frames must stay identical, and a shared bracket with a flag
                ; would need an eleventh argument byte to carry it.
                ;
                ; TEN ARGUMENT BYTES -- a pid and two fcc pointers -- so 15,S
                ; once PHB and PHD have moved the frame down three.  Both
                ; pointers name CORE-bank memory (the path in the kernel bank,
                ; `_fsStatBuf' beside it), and the core-side stub supplies the
                ; bank in each; nothing here may use a `^' literal, which would
                ; assemble this bank's.
                ;
                ; A pid, AND THE NOTE HERE USED TO SAY THERE WAS NO USE FOR ONE:
                ; "a stat opens nothing and touches no file table, so there is
                ; no process for it to be about."  True of the FILE TABLE and
                ; false of the WALK.  A relative name is about a process -- it
                ; starts at that process's directory -- and with no pid to ask,
                ; this resolved `.' against the root and answered confidently
                ; about the wrong directory (apple/fgx#295).
                MX      %00
                PHB
                PHD
                PHK
                PLB                     ; DBR = far bank
                LDA     #FGX_DP_KERNELC
                TCD

                LDA     15,S
                PHA
                LDA     15,S
                PHA
                LDA     15,S
                PHA
                LDA     15,S
                PHA
                LDA     15,S
                PHA

                PHK
                PEA     _VfsRootLstatRet-1
                PHK
                PEA     root_lstat-1
                RTL                     ; pile call into the C
_VfsRootLstatRet TAY                     ; park the errno; the drop needs A
                TSC
                CLC
                ADC     #10             ; drop the copy -- the caller cleans
                TCS
                TYA
                PLD
                PLB
                RTL

_Vfs_RootReadlink ENT
                ; far slot 57 -- readlink(2).  root_readlink(pid, name, buf,
                ; count) -> the byte count placed, or -errno.
                ;
                ; TWELVE ARGUMENT BYTES, not ten: a pid, two fcc pointers and a
                ; count.  So the first copy is at 17,S once PHB and PHD have
                ; moved the frame down three -- 4 + 2N - 2 for N = 6 words,
                ; plus those three -- and the drop is 12.  Both pointers name
                ; CORE-bank memory and the core-side stub supplies each bank;
                ; nothing here may use a `^' literal, which would assemble this
                ; bank's.
                ;
                ; A COUNT COMES BACK, WHERE EVERY OTHER ENTRY HERE RETURNS AN
                ; ERRNO.  That is upstream's convention and not a local choice:
                ; Reno's readlink returns `uap->count - auio.uio_resid'.  The
                ; bracket is indifferent -- it parks A in Y across the stack
                ; drop either way -- but the CORE side must read it as signed.
                MX      %00
                PHB
                PHD
                PHK
                PLB                     ; DBR = far bank
                LDA     #FGX_DP_KERNELC
                TCD

                LDA     17,S
                PHA
                LDA     17,S
                PHA
                LDA     17,S
                PHA
                LDA     17,S
                PHA
                LDA     17,S
                PHA
                LDA     17,S
                PHA

                PHK
                PEA     _VfsRootReadlinkRet-1
                PHK
                PEA     root_readlink-1
                RTL                     ; pile call into the C
_VfsRootReadlinkRet TAY                 ; park the result; the drop needs A
                TSC
                CLC
                ADC     #12             ; drop the copy -- the caller cleans
                TCS
                TYA
                PLD
                PLB
                RTL

_Vfs_RootChdir  ENT
                ; far slot 48 -- the cwd port.  root_chdir(pid, name) -> 0 or
                ; errno.  SIX ARGUMENT BYTES, an int and one fcc pointer, so
                ; the deepest word is at 11,S once PHB and PHD have moved the
                ; frame down three.
                ;
                ; `name' IS THE CALLER'S, IN THE KERNEL BANK, and the core-side
                ; stub supplies the bank; nothing here may use a `^' literal.
                ; It may be RELATIVE -- vfs_chdir walks it from the process's
                ; current cwd vnode, which is what makes `cd ..' mean anything.
                MX      %00
                PHB
                PHD
                PHK
                PLB                     ; DBR = far bank
                LDA     #FGX_DP_KERNELC
                TCD

                LDA     11,S
                PHA
                LDA     11,S
                PHA
                LDA     11,S
                PHA

                PHK
                PEA     _VfsRootChdirRet-1
                PHK
                PEA     root_chdir-1
                RTL                     ; pile call into the C
_VfsRootChdirRet TAY                    ; park the errno; the drop needs A
                TSC
                CLC
                ADC     #6              ; drop the copy -- the caller cleans
                TCS
                TYA
                PLD
                PLB
                RTL

_Vfs_RootUnlink ENT
                ; far slot 52 -- root_unlink(pid, path) -> 0 or errno.  SIX
                ; ARGUMENT BYTES, an int and one fcc pointer, so the frame is
                ; _Vfs_RootChdir's exactly and the deepest word sits at 11,S
                ; once PHB and PHD have moved it down three.
                ;
                ; `path' IS THE CALLER'S, IN THE KERNEL BANK, supplied by the
                ; core-side stub; nothing here may use a `^' literal.  It may
                ; be RELATIVE -- root_unlink walks it from the process's cwd,
                ; which is what makes `rm foo' work.
                MX      %00
                PHB
                PHD
                PHK
                PLB                     ; DBR = far bank
                LDA     #FGX_DP_KERNELC
                TCD

                LDA     11,S
                PHA
                LDA     11,S
                PHA
                LDA     11,S
                PHA

                PHK
                PEA     _VfsRootUnlinkRet-1
                PHK
                PEA     root_unlink-1
                RTL                     ; pile call into the C
_VfsRootUnlinkRet TAY                   ; park the errno; the drop needs A
                TSC
                CLC
                ADC     #6              ; drop the copy -- the caller cleans
                TCS
                TYA
                PLD
                PLB
                RTL

_Vfs_RootSymlink ENT
                ; far slot 59 -- root_symlink(pid, target, linkname, mode) ->
                ; 0 or errno.  TWELVE ARGUMENT BYTES: an int, two far pointers
                ; and the mode, so 17,S and a drop of 12.
                MX      %00
                PHB
                PHD
                PHK
                PLB
                LDA     #FGX_DP_KERNELC
                TCD

                LDA     17,S
                PHA
                LDA     17,S
                PHA
                LDA     17,S
                PHA
                LDA     17,S
                PHA
                LDA     17,S
                PHA
                LDA     17,S
                PHA

                PHK
                PEA     _VfsRootSymlinkRet-1
                PHK
                PEA     root_symlink-1
                RTL
_VfsRootSymlinkRet TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                PLD
                PLB
                RTL

_Vfs_RootStatfs ENT
                ; far slot 60 -- root_statfs(pid, path, sbp) -> 0 or errno.
                ; TEN ARGUMENT BYTES: an int and two far pointers, so 15,S and
                ; a drop of 10.
                ;
                ; `sbp' IS A POINTER INTO THE CALLER'S BANK, not into this one
                ; and not into the core's.  Nothing here dereferences it -- it
                ; is carried through to vfs_statfs1's uio_copy, which is MVN
                ; and reads the destination bank out of the pointer.  See the
                ; slot comment in include/kfar.s for why there is no staging
                ; buffer to copy out of.
                MX      %00
                PHB
                PHD
                PHK
                PLB
                LDA     #FGX_DP_KERNELC
                TCD

                LDA     15,S
                PHA
                LDA     15,S
                PHA
                LDA     15,S
                PHA
                LDA     15,S
                PHA
                LDA     15,S
                PHA

                PHK
                PEA     _VfsRootStatfsRet-1
                PHK
                PEA     root_statfs-1
                RTL
_VfsRootStatfsRet TAY
                TSC
                CLC
                ADC     #10
                TCS
                TYA
                PLD
                PLB
                RTL

_Vfs_Getfsstat  ENT
                ; far slot 61 -- vfs_getfsstat(sbp, bufsize) -> count.  SIX
                ; ARGUMENT BYTES: one far pointer and an int, so THREE words.
                ; The topmost source is 11,S and the drop is 6 -- the run goes
                ; up by two per word from 11 because PHB/PHD put three bytes
                ; under it, which is the arithmetic _Vfs_RootRename's header
                ; sets out.  THE TWO NUMBERS MOVE TOGETHER.
                ;
                ; STRAIGHT TO vfs_syscalls.c, WITH NO root_ BRACKET.  Every
                ; other slot on this seam calls a root_* function that gates on
                ; root_status; this one does not, because vfs_getfsstat's own
                ; first test is `rootfs == 0' and that is the same question
                ; asked of the structure that actually answers it.  A bracket
                ; would be a second authority for one fact (apple/fgx#114).
                MX      %00
                PHB
                PHD
                PHK
                PLB
                LDA     #FGX_DP_KERNELC
                TCD

                LDA     11,S
                PHA
                LDA     11,S
                PHA
                LDA     11,S
                PHA

                PHK
                PEA     _VfsGetfsstatRet-1
                PHK
                PEA     vfs_getfsstat-1
                RTL
_VfsGetfsstatRet TAY
                TSC
                CLC
                ADC     #6
                TCS
                TYA
                PLD
                PLB
                RTL

_Vfs_Sync       ENT
                ; far slot 36 -- vfs_sync().  apple/fgx#332.
                ;
                ; NO ARGUMENTS, so no argument copy and nothing to drop -- the
                ; PHB/PHD bracket is the whole of it.  _Vfs_SeamEntry has the
                ; same shape and its note is the one that says why an entry
                ; WITH arguments cannot be written this way.
                MX      %00
                PHB
                PHD
                PHK
                PLB                     ; DBR = far bank
                LDA     #FGX_DP_KERNELC
                TCD

                PHK
                PEA     _VfsSyncRet-1
                PHK
                PEA     vfs_sync-1
                RTL                     ; pile call into the C
_VfsSyncRet     PLD
                PLB
                RTL

_Vfs_SyncClean  ENT
                ; far slot 37 -- vfs_syncclean().  apple/fgx#403.
                ;
                ; _Vfs_Sync's twin and the same shape for the same reason: no
                ; arguments, so the PHB/PHD bracket is the whole of it.  What
                ; differs is on the C side -- this one leaves every writable
                ; mount that was clean at mount MARKED clean, which is what
                ; separates a reboot from a crash.
                MX      %00
                PHB
                PHD
                PHK
                PLB                     ; DBR = far bank
                LDA     #FGX_DP_KERNELC
                TCD

                PHK
                PEA     _VfsSyncCleanRet-1
                PHK
                PEA     vfs_syncclean-1
                RTL                     ; pile call into the C
_VfsSyncCleanRet PLD
                PLB
                RTL

_Vfs_Mount      ENT
                ; far slot 64 -- vfs_mountat(pid, dvp, type, dir, flags,
                ; data) -> 0 or errno.  UFS 2.6, mount(2).
                ;
                ; EIGHTEEN ARGUMENT BYTES -- pid 2, dvp 4, type 2, dir 4,
                ; flags 2, data 4 -- so NINE words from 23,S, the offset being
                ; argbytes + 5.  The count and the closing drop move together
                ; and a short one is silent; slot 45 cost a bisect to learn it.
                ;
                ; STRAIGHT TO vfs_syscalls.c WITH NO root_ BRACKET, which is
                ; slot 61's shape: there is nothing for root_status to decide
                ; here.  A mount does not act on the mounted root, and
                ; vfs_mountat's own first test is the one that matters.
                MX      %00
                PHB
                PHD
                PHK
                PLB                     ; DBR = far bank
                LDA     #FGX_DP_KERNELC
                TCD

                LDA     23,S
                PHA
                LDA     23,S
                PHA
                LDA     23,S
                PHA
                LDA     23,S
                PHA
                LDA     23,S
                PHA
                LDA     23,S
                PHA
                LDA     23,S
                PHA
                LDA     23,S
                PHA
                LDA     23,S
                PHA

                PHK
                PEA     _VfsMountRet-1
                PHK
                PEA     vfs_mountat-1
                RTL                     ; pile call into the C
_VfsMountRet    TAY                     ; park the errno; the drop needs A
                TSC
                CLC
                ADC     #18             ; drop the copy -- the caller cleans
                TCS
                TYA
                PLD
                PLB
                RTL

_Vfs_UnmountDev ENT
                ; far slot 65 -- vfs_unmountdev(pid, spec, flags) -> 0 or
                ; errno.  UFS 2.6, umount(2), which names the DEVICE.
                ;
                ; EIGHT ARGUMENT BYTES -- a pid, an fcc pointer and an int --
                ; so FOUR words from 13,S.
                MX      %00
                PHB
                PHD
                PHK
                PLB                     ; DBR = far bank
                LDA     #FGX_DP_KERNELC
                TCD

                LDA     13,S
                PHA
                LDA     13,S
                PHA
                LDA     13,S
                PHA
                LDA     13,S
                PHA

                PHK
                PEA     _VfsUnmountDevRet-1
                PHK
                PEA     vfs_unmountdev-1
                RTL                     ; pile call into the C
_VfsUnmountDevRet TAY                   ; park the errno; the drop needs A
                TSC
                CLC
                ADC     #8              ; drop the copy -- the caller cleans
                TCS
                TYA
                PLD
                PLB
                RTL

_Vfs_Access     ENT
                ; far slot 69 -- root_access(pid, path, fmode) -> 0 or errno.
                ; UFS 2.6, access(2).
                ;
                ; EIGHT ARGUMENT BYTES -- an int, an fcc pointer, an int.  At
                ; entry the JSL return sits at 1,S..3,S and the arguments at
                ; 4,S..11,S; PHB and PHD moved both down three, so the deepest
                ; argument word is at 13,S and stays there as the copy walks --
                ; each PHA moves SP by the two bytes just read.
                ;
                ; THE OFFSET SCALES WITH THE COPY and 9,S is the TWO-word value:
                ; this was written as 9,S first and `pid' arrived as the middle
                ; of the path pointer, so ndslot() answered null and every
                ; access(2) returned EINVAL while open(2) -- a different slot,
                ; correctly written -- kept working.  The permtest manifest is
                ; what said so, in one line.
                MX      %00
                PHB
                PHD
                PHK
                PLB                     ; DBR = far bank
                LDA     #FGX_DP_KERNELC
                TCD

                LDA     13,S
                PHA
                LDA     13,S
                PHA
                LDA     13,S
                PHA
                LDA     13,S
                PHA

                PHK
                PEA     _VfsAccessRet-1
                PHK
                PEA     root_access-1
                RTL                     ; pile call into the C
_VfsAccessRet   TAY                     ; park the errno; the drop needs A
                TSC
                CLC
                ADC     #8              ; drop the copy -- the caller cleans
                TCS
                TYA
                PLD
                PLB
                RTL

_Vfs_Fchdir     ENT
                ; far slot 68 -- root_fchdir(pid, fd) -> 0 or errno.  UFS 2.7,
                ; fchdir(2).
                ;
                ; FOUR ARGUMENT BYTES -- two ints -- so TWO words from 9,S, and
                ; the drop is 4.
                MX      %00
                PHB
                PHD
                PHK
                PLB                     ; DBR = far bank
                LDA     #FGX_DP_KERNELC
                TCD

                LDA     9,S
                PHA
                LDA     9,S
                PHA

                PHK
                PEA     _VfsFchdirRet-1
                PHK
                PEA     root_fchdir-1
                RTL                     ; pile call into the C
_VfsFchdirRet   TAY                     ; park the errno; the drop needs A
                TSC
                CLC
                ADC     #4              ; drop the copy -- the caller cleans
                TCS
                TYA
                PLD
                PLB
                RTL

_Vfs_Fsync      ENT
                ; far slot 70 -- root_fsync(pid, fd) -> 0 or errno.
                ; apple/fgx#355, fsync(2).
                ;
                ; FOUR ARGUMENT BYTES -- two ints -- so TWO words from 9,S, and
                ; the drop is 4.  `_Vfs_Fchdir' above is the same shape.
                MX      %00
                PHB
                PHD
                PHK
                PLB                     ; DBR = far bank
                LDA     #FGX_DP_KERNELC
                TCD

                LDA     9,S
                PHA
                LDA     9,S
                PHA

                PHK
                PEA     _VfsFsyncRet-1
                PHK
                PEA     root_fsync-1
                RTL                     ; pile call into the C
_VfsFsyncRet    TAY                     ; park the errno; the drop needs A
                TSC
                CLC
                ADC     #4              ; drop the copy -- the caller cleans
                TCS
                TYA
                PLD
                PLB
                RTL


_Vfs_RootFstat  ENT
                ; far slot 71 -- root_fstat(pid, fd, sb) -> 0 or errno.
                ; fstat(2), apple/fgx#365.
                ;
                ; EIGHT ARGUMENT BYTES -- two ints and one fcc pointer -- so
                ; FOUR words from 13,S once PHB and PHD have moved the frame
                ; down three.  `_Vfs_RootStat' is the same shape with one more
                ; pointer (ten bytes, 15,S); `_Vfs_Fsync' is the same two ints
                ; without the buffer (four bytes, 9,S).
                ;
                ; `sb' NAMES CORE-BANK MEMORY -- `_fsStatBuf', the same buffer
                ; slot 46 fills -- and the core-side stub supplies its bank.
                ; Nothing here may use a `^' literal, which would assemble THIS
                ; bank's.
                MX      %00
                PHB
                PHD
                PHK
                PLB                     ; DBR = far bank
                LDA     #FGX_DP_KERNELC
                TCD

                LDA     13,S
                PHA
                LDA     13,S
                PHA
                LDA     13,S
                PHA
                LDA     13,S
                PHA

                PHK
                PEA     _VfsRootFstatRet-1
                PHK
                PEA     root_fstat-1
                RTL                     ; pile call into the C
_VfsRootFstatRet TAY                    ; park the errno; the drop needs A
                TSC
                CLC
                ADC     #8              ; drop the copy -- the caller cleans
                TCS
                TYA
                PLD
                PLB
                RTL

_Vfs_UnpName    ENT
                ; far slot 74 -- unp_nameop(pid, op, path, slotp) -> 0 or errno.
                ; An AF_UNIX socket's name, bound and looked up: 4.3BSD-Reno
                ; kern/uipc_usrreq.c's unp_bind and unp_connect.
                ;
                ; TWELVE ARGUMENT BYTES -- two ints and two fcc pointers -- so SIX
                ; words from 17,S once PHB and PHD have moved the frame down three.
                ; `_Vfs_RootStat' is the same shape with two pointers too.
                ;
                ; BOTH POINTERS NAME THE CORE BANK, not this one: `path' is
                ; _Sys_PathBuf, which the KSVC arm filled with _Sys_CopyPathToBuf,
                ; and `slotp' is _unpSlot.  The core-side arm supplies their bank,
                ; and nothing here may use a `^' literal -- that would assemble
                ; THIS bank's.
                MX      %00
                PHB
                PHD
                PHK
                PLB                     ; DBR = far bank
                LDA     #FGX_DP_KERNELC
                TCD

                LDA     17,S
                PHA
                LDA     17,S
                PHA
                LDA     17,S
                PHA
                LDA     17,S
                PHA
                LDA     17,S
                PHA
                LDA     17,S
                PHA

                PHK
                PEA     _VfsUnpNameRet-1
                PHK
                PEA     unp_nameop-1
                RTL                     ; pile call into the C
_VfsUnpNameRet  TAY                     ; park the errno; the drop needs A
                TSC
                CLC
                ADC     #12             ; drop the copy -- the caller cleans
                TCS
                TYA
                PLD
                PLB
                RTL

_Vfs_Sysctl     ENT
                ; far slot 72 -- root_sysctl(pid, uid, blk) -> 0 or errno.
                ; sysctl(2), apple/fgx#410.
                ;
                ; EIGHT ARGUMENT BYTES -- two ints and one fcc pointer -- so
                ; FOUR words from 13,S once PHB and PHD have moved the frame
                ; down three.  `_Vfs_RootFstat' below is the same shape.
                ;
                ; `blk' NAMES THE CALLER'S BANK, not this one and not the
                ; core's: it is the argument block libc marshalled in the
                ; program's own data bank, and the core-side stub supplies
                ; `_Sys_CallerBank' for it.  Nothing here may use a `^'
                ; literal, which would assemble THIS bank's.
                MX      %00
                PHB
                PHD
                PHK
                PLB                     ; DBR = far bank
                LDA     #FGX_DP_KERNELC
                TCD

                LDA     13,S
                PHA
                LDA     13,S
                PHA
                LDA     13,S
                PHA
                LDA     13,S
                PHA

                PHK
                PEA     _VfsSysctlRet-1
                PHK
                PEA     root_sysctl-1
                RTL                     ; pile call into the C
_VfsSysctlRet   TAY                     ; park the errno; the drop needs A
                TSC
                CLC
                ADC     #8              ; drop the copy -- the caller cleans
                TCS
                TYA
                PLD
                PLB
                RTL

_Vfs_Utimes     ENT
                ; far slot 67 -- root_utimes(pid, path, atime, mtime) -> 0 or
                ; errno.  UFS 2.7, utimes(2).  apple/fgx#343.
                ;
                ; FOURTEEN ARGUMENT BYTES -- a pid, an fcc pointer at four and
                ; two time_t at four -- so SEVEN words from 19,S, and the drop
                ; is 14.
                MX      %00
                PHB
                PHD
                PHK
                PLB                     ; DBR = far bank
                LDA     #FGX_DP_KERNELC
                TCD

                LDA     19,S
                PHA
                LDA     19,S
                PHA
                LDA     19,S
                PHA
                LDA     19,S
                PHA
                LDA     19,S
                PHA
                LDA     19,S
                PHA
                LDA     19,S
                PHA

                PHK
                PEA     _VfsUtimesRet-1
                PHK
                PEA     root_utimes-1
                RTL                     ; pile call into the C
_VfsUtimesRet   TAY                     ; park the errno; the drop needs A
                TSC
                CLC
                ADC     #14             ; drop the copy -- the caller cleans
                TCS
                TYA
                PLD
                PLB
                RTL

_Vfs_Ftruncate  ENT
                ; far slot 66 -- root_ftruncate(pid, fd, length) -> 0 or
                ; errno.  UFS 2.7, ftruncate(2).
                ;
                ; EIGHT ARGUMENT BYTES -- a pid, an fd and a 32-bit off_t --
                ; so FOUR words from 13,S, and the drop is 8.  The length is
                ; ONE number in two words rather than a pointer, which changes
                ; nothing here: the copy moves words and the C declares the
                ; type.
                MX      %00
                PHB
                PHD
                PHK
                PLB                     ; DBR = far bank
                LDA     #FGX_DP_KERNELC
                TCD

                LDA     13,S
                PHA
                LDA     13,S
                PHA
                LDA     13,S
                PHA
                LDA     13,S
                PHA

                PHK
                PEA     _VfsFtruncateRet-1
                PHK
                PEA     root_ftruncate-1
                RTL                     ; pile call into the C
_VfsFtruncateRet TAY                    ; park the errno; the drop needs A
                TSC
                CLC
                ADC     #8              ; drop the copy -- the caller cleans
                TCS
                TYA
                PLD
                PLB
                RTL

_Vfs_RootLink   ENT
                ; far slot 63 -- root_link(pid, target, linkname) -> 0 or
                ; errno.  UFS 2.6, link(2).
                ;
                ; TEN ARGUMENT BYTES -- a pid and two fcc pointers -- so FIVE
                ; words from 15,S, and the drop is 10.  Slot 58's shape exactly
                ; (root_rename takes the same three), and for the same reason:
                ; two paths and a process to resolve them against.
                MX      %00
                PHB
                PHD
                PHK
                PLB                     ; DBR = far bank
                LDA     #FGX_DP_KERNELC
                TCD

                LDA     15,S
                PHA
                LDA     15,S
                PHA
                LDA     15,S
                PHA
                LDA     15,S
                PHA
                LDA     15,S
                PHA

                PHK
                PEA     _VfsRootLinkRet-1
                PHK
                PEA     root_link-1
                RTL                     ; pile call into the C
_VfsRootLinkRet TAY                     ; park the errno; the drop needs A
                TSC
                CLC
                ADC     #10             ; drop the copy -- the caller cleans
                TCS
                TYA
                PLD
                PLB
                RTL

_Vfs_RootSetattr ENT
                ; far slot 62 -- root_setattr(pid, path, follow, mode, uid,
                ; gid) -> 0 or errno.  UFS 2.6: chmod(2) and chown(2), one
                ; entry, because Reno's two syscalls differ only in which
                ; vattr field they set and whether they FOLLOW (kern/
                ; vfs_syscalls.c:1136 against :1204).
                ;
                ; FOURTEEN ARGUMENT BYTES -- a pid, an fcc pointer at four and
                ; four ints -- so SEVEN words from 19,S, and the drop is 14.
                ; The offset is N+5 for N argument bytes and it does not change
                ; per copy: each PHA walks the frame down exactly one word, so
                ; the same 19,S reads the next source in turn, deepest first.
                ; THE COUNT AND THE DROP MOVE TOGETHER, and a short one is
                ; SILENT -- slot 45's five-where-six-were-due handed root_open
                ; stack residue as its create mode and cost a bisect.
                MX      %00
                PHB
                PHD
                PHK
                PLB                     ; DBR = far bank
                LDA     #FGX_DP_KERNELC
                TCD

                LDA     19,S
                PHA
                LDA     19,S
                PHA
                LDA     19,S
                PHA
                LDA     19,S
                PHA
                LDA     19,S
                PHA
                LDA     19,S
                PHA
                LDA     19,S
                PHA

                PHK
                PEA     _VfsRootSetattrRet-1
                PHK
                PEA     root_setattr-1
                RTL                     ; pile call into the C
_VfsRootSetattrRet TAY                  ; park the errno; the drop needs A
                TSC
                CLC
                ADC     #14             ; drop the copy -- the caller cleans
                TCS
                TYA
                PLD
                PLB
                RTL

_Vfs_RootRename ENT
                ; far slot 58 -- root_rename(pid, from, to) -> 0 or errno.
                ; TEN ARGUMENT BYTES, the widest entry on this seam: two far
                ; pointers and an int.  Five words to copy, so the topmost
                ; source is 15,S (11 for three words, 13 for four -- the run
                ; goes up by two per word because PHB/PHD put three bytes under
                ; it) and the drop is 10.  THE TWO NUMBERS MOVE TOGETHER: a
                ; copy that reads one word short lands the pid in `to' and the
                ; walk goes off into whatever the stack held.
                MX      %00
                PHB
                PHD
                PHK
                PLB
                LDA     #FGX_DP_KERNELC
                TCD

                LDA     15,S
                PHA
                LDA     15,S
                PHA
                LDA     15,S
                PHA
                LDA     15,S
                PHA
                LDA     15,S
                PHA

                PHK
                PEA     _VfsRootRenameRet-1
                PHK
                PEA     root_rename-1
                RTL
_VfsRootRenameRet TAY
                TSC
                CLC
                ADC     #10
                TCS
                TYA
                PLD
                PLB
                RTL

_Vfs_RootRmdir  ENT
                ; far slot 54 -- root_rmdir(pid, path) -> 0 or errno.  The same
                ; six bytes and the same frame as unlink above; only the C it
                ; calls differs.
                MX      %00
                PHB
                PHD
                PHK
                PLB
                LDA     #FGX_DP_KERNELC
                TCD

                LDA     11,S
                PHA
                LDA     11,S
                PHA
                LDA     11,S
                PHA

                PHK
                PEA     _VfsRootRmdirRet-1
                PHK
                PEA     root_rmdir-1
                RTL
_VfsRootRmdirRet TAY
                TSC
                CLC
                ADC     #6
                TCS
                TYA
                PLD
                PLB
                RTL

_Vfs_RootMkdir  ENT
                ; far slot 53 -- root_mkdir(pid, path, mode) -> 0 or errno.
                ; EIGHT ARGUMENT BYTES, not six: the mode is an int and fcc
                ; pushes right to left, so it went down FIRST and is the
                ; DEEPEST word.  That makes the topmost source 13,S rather
                ; than 11,S, and the drop 8 rather than 6 -- the two numbers
                ; that have to move together and the reason this entry is
                ; written out rather than sharing unlink's.
                MX      %00
                PHB
                PHD
                PHK
                PLB
                LDA     #FGX_DP_KERNELC
                TCD

                LDA     13,S
                PHA
                LDA     13,S
                PHA
                LDA     13,S
                PHA
                LDA     13,S
                PHA

                PHK
                PEA     _VfsRootMkdirRet-1
                PHK
                PEA     root_mkdir-1
                RTL
_VfsRootMkdirRet TAY
                TSC
                CLC
                ADC     #8              ; four words, not three
                TCS
                TYA
                PLD
                PLB
                RTL

_Vfs_Lseek      ENT
                ; far slot 55 -- vfs_lseek(pid, fd, off, whence, resultp) -> 0
                ; or errno.  FOURTEEN ARGUMENT BYTES: two ints, a long, an int
                ; and a pointer, so seven words.  The deepest sits at 19,S once
                ; PHB and PHD have moved the frame down three (4 + 2*7 - 2 + 3).
                ;
                ; IT CALLS vfs_lseek DIRECTLY AND NOT A root_ WRAPPER, unlike
                ; the four hooks above it.  Those route on root_status because
                ; the core hands them a NAME and something has to decide whether
                ; this kernel has a root to resolve it against.  This one is
                ; handed a DESCRIPTOR that the core has already established has
                ; far ops -- which is only true of a descriptor the VFS opened
                ; -- so the routing question is answered before the call.
                ;
                ; `resultp' IS THE CORE BANK'S _flsNew and the core-side stub
                ; supplies the bank; nothing here may use a `^' literal.
                MX      %00
                PHB
                PHD
                PHK
                PLB                     ; DBR = far bank
                LDA     #FGX_DP_KERNELC
                TCD

                LDA     19,S
                PHA
                LDA     19,S
                PHA
                LDA     19,S
                PHA
                LDA     19,S
                PHA
                LDA     19,S
                PHA
                LDA     19,S
                PHA
                LDA     19,S
                PHA

                PHK
                PEA     _VfsLseekRet-1
                PHK
                PEA     vfs_lseek-1
                RTL                     ; pile call into the C
_VfsLseekRet    TAY                     ; park the errno; the drop needs A
                TSC
                CLC
                ADC     #14             ; seven words
                TCS
                TYA
                PLD
                PLB
                RTL

_Vfs_CdirFork   ENT
                ; far slot 49 -- the cwd's fork half.  root_cdirfork(ppid, cpid),
                ; returns void.
                ;
                ; FOUR ARGUMENT BYTES, two ints, so the deepest word is at 9,S
                ; once PHB and PHD have moved the frame down three.  No pointer
                ; and therefore no bank to supply: the whole argument list is
                ; two small integers the core already holds.
                ;
                ; NOTHING COMES BACK.  Reno's line is `VREF(u.u_cdir)' in the
                ; middle of fork and there is no failure it could report -- see
                ; root_cdirfork's header for why the routing gate the sibling
                ; slots carry would be two arms doing the same thing here.
                MX      %00
                PHB
                PHD
                PHK
                PLB                     ; DBR = far bank
                LDA     #FGX_DP_KERNELC
                TCD

                LDA     9,S
                PHA
                LDA     9,S
                PHA

                PHK
                PEA     _VfsCdirForkRet-1
                PHK
                PEA     root_cdirfork-1
                RTL                     ; pile call into the C
_VfsCdirForkRet TSC
                CLC
                ADC     #4              ; drop the copy -- the caller cleans
                TCS
                PLD
                PLB
                RTL

; SYS_MODLOAD's streaming install -- plan B1.  A = subcmd, X/Y per subcmd.
; The caller bank comes from a patched LDAL rather than a register, so both
; index registers are free for arguments.
;
; WHY SO LITTLE CODE: `end' is Mod_RegisterPreLoaded, which the boot loader's
; pre-stage already needed -- it validates the FGXM header at bank:$0000, marks
; the bank used, zeroes BSS, walks VTDR and JSLs mod_init.  So this adds a bank
; and a cursor for `begin', and one MVN per `data'.
;
; Bank 0 is the no-session sentinel: it is the stack bank and never a module's.
_mlsOpen        DS      1               ; a session is open.  THE SENTINEL IS NOT
                                        ;   THE BANK any more: `begin' no longer
                                        ;   allocates one, so there is nothing to
                                        ;   test until the header chunk has said
                                        ;   which ordinal this module joins.
_mlsBank        DS      1               ; bank being filled, 0 until the header
_mlsCur         DS      2               ; write cursor within it
_mlsTot         DS      2               ; bytes accepted so far
_mlsLen         DS      2               ; this chunk's length (Y is needed for MVN)

_Far_ModLoad    ENT
                MX      %00
                PHB
                PHK
                PLB                     ; DBR = far bank, for the statics below
                CMP     #0
                BNE     @fml_t1
                BRL     @fml_begin
@fml_t1         CMP     #1
                BNE     @fml_t2
                BRL     @fml_data
@fml_t2         CMP     #2
                BNE     @fml_t3
                BRL     @fml_end
@fml_t3         CMP     #3
                BNE     @fml_bad
                BRL     @fml_abort
@fml_bad        LDA     #EINVAL
                BRL     @fml_fail

                ; --- begin: claim a bank and rewind the cursor ---
                ; IT NO LONGER ALLOCATES.  A module's bank belongs to its
                ; ORDINAL, and ordinal 0 already holds prodos, net, serial, bpf,
                ; ramdisk, hello and pty at seven different offsets -- so all
                ; but the first module in a chain JOINS a bank rather than
                ; claiming one, and which chain this is cannot be known until
                ; the header arrives.  Claiming one here got a fresh empty bank
                ; that no other module was in, which is exactly the bank an
                ; extent check cannot mean anything about.
@fml_begin      SEP     #$20
                MX      %10
                LDA     _mlsOpen
                BEQ     @fml_bnew
                REP     #$20
                MX      %00
                LDA     #EBUSY          ; one session at a time; subcmd 3 is the
                BRL     @fml_fail       ;   way out of a stuck one
@fml_bnew       MX      %10             ; the BEQ arrives 8-bit; the arm above
                LDA     #1              ;   went 16-bit only to fail
                STA     _mlsOpen
                STZ     _mlsBank
                REP     #$20
                MX      %00
                STZ     _mlsCur
                STZ     _mlsTot
                BRL     @fml_ok

                ; --- data: X = buf offset in the caller bank, Y = length ---
@fml_data       SEP     #$20
                MX      %10
                LDA     _mlsOpen
                BNE     @fml_dsess
                REP     #$20
                MX      %00
                BRL     @fml_nosess
@fml_dsess      REP     #$20
                MX      %00
                TYA                             ; A = length; Y is about to be
                STA     _mlsLen                 ;   the MVN destination
                BNE     @fml_dnz
                BRL     @fml_ok                 ; a zero-length chunk is a no-op
@fml_dnz
                ; THE FIRST CHUNK IS THE HEADER, EXACTLY, and the protocol says
                ; so rather than splitting an arbitrary chunk here.  The kernel
                ; cannot place the text until it has read the placement offset
                ; out of that header, and modload(8) is in a far better position
                ; to read 40 bytes than this is to carve them.
                LDA     _mlsTot
                BNE     @fml_dbody
                LDA     _mlsLen
                CMP     #FGXM_HEADER_SZ
                BEQ     @fml_dhdr
                LDA     #EINVAL
                BRL     @fml_fail

                ; THE HEADER IS NOT MVN'd ANYWHERE.  It used to land at bank:0
                ; so the registrar could read it back, and in a SHARED ordinal
                ; that is prodos's own text -- the image would be validated by
                ; overwriting the module it is being checked against.  The
                ; registrar reads it out of the CALLER's buffer instead, and
                ; nothing is written into any module bank until it has said
                ; where this one goes.
@fml_dhdr       SEP     #$20
                MX      %10
                LDA     #1
_cfp972         STAL    _mlPlaceAny             ; this caller CAN place, so the
_cfp970         LDAL    _Sys_CallerBank         ;   offset-0 refusal is not ours
_cfp974         STAL    _mlHdrBank
                REP     #$20
                MX      %00
                TXA
_cfp975         STAL    _mlHdrOff
                LDA     #$0000                  ; 0 = take the ordinal's bank
_cfp976         JSL     _FarSh_ModHeader        ; C=1 / C=0 + A = errno
                PHP
                SEP     #$20
                MX      %10
                LDA     #0
_cfp973         STAL    _mlPlaceAny             ; stage 2's limit is stage 2's
                REP     #$20
                MX      %00
                PLP
                BCS     @fml_hdrOK
                BRL     @fml_fail
@fml_hdrOK      ; the bank and the text base are the registrar's answers, not
                ; ours: the chain decided one and the header decided the other.
                SEP     #$20
                MX      %10
_cfp977         LDAL    _mlBank
                STA     _mlsBank
                REP     #$20
                MX      %00
_cfp978         LDAL    _mlTextBase
                STA     _mlsCur
                LDA     _mlsLen
                STA     _mlsTot
                BRL     @fml_ok

@fml_dbody      SEP     #$20
                MX      %10
                LDA     _mlsBank
                STA     @fml_mvn+1              ; MVN dest bank
_cfp979         LDAL    _Sys_CallerBank
                STA     @fml_mvn+2              ; MVN source bank
                REP     #$20
                MX      %00
                LDY     _mlsCur
                LDA     _mlsLen
                DEC                             ; MVN moves A+1 bytes
@fml_mvn        MVN     $00,$00                 ; banks patched just above
                PHK
                PLB                             ; MVN left DBR = dest; ours back
                STY     _mlsCur                 ; Y = one past the last byte
                LDA     _mlsTot
                CLC
                ADC     _mlsLen
                STA     _mlsTot
                BRL     @fml_ok

                ; --- end: hand the filled bank to the registrar's tail half ---
@fml_end        SEP     #$20
                MX      %10
                LDA     _mlsOpen
                BNE     @fml_esess
                REP     #$20
                MX      %00
                BRL     @fml_nosess
@fml_esess      MX      %10             ; as @fml_bnew: the BNE arrives 8-bit
                STZ     _mlsOpen                ; the session ends either way
                REP     #$20
                MX      %00
_cfp971         JSL     _FarSh_ModRegister      ; C=1 / C=0 + A = errno
                BCS     @fml_eok
                PHA                             ; keep the errno across the undo
                BRA     @fml_undo
@fml_eok        BRL     @fml_ok

                ; --- abort: subcmd 3, the way out of a half-sent module ---
                ; Without it a stream that died between `begin' and `end' --
                ; a short read, a rejected header, a killed process -- left the
                ; session open and every later `begin' answering EBUSY for the
                ; rest of the boot.
@fml_abort      SEP     #$20
                MX      %10
                LDA     _mlsOpen
                BNE     @fml_asess
                REP     #$20
                MX      %00
                BRL     @fml_nosess
@fml_asess      MX      %10             ; as @fml_bnew: the BNE arrives 8-bit
                STZ     _mlsOpen
                REP     #$20
                MX      %00
                LDA     #EINTR
                PHA

                ; GIVE BACK WHAT THE HEADER HALF TOOK.  It claimed an extent
                ; and may have appended registry rows, and both tables are
                ; append-only, so restoring the counters the header half saved
                ; is a complete undo -- the same argument Mod_Load's @ml_errA
                ; makes.  Reached from `end' too, whose failure has exactly the
                ; same debris.
                ; ONLY IF THE SNAPSHOT IS THIS LOAD'S.  `begin' can be followed
                ; by `abort' with no header chunk between -- modload(8) does
                ; exactly that on a short read -- and the two counters then
                ; still hold the LAST COMPLETED load's pre-snapshot.  Restoring
                ; those unloads a module that is running.
@fml_undo       SEP     #$20
                MX      %10
_cfp988         LDAL    _mlSaveValid
                REP     #$20
                MX      %00
                AND     #$00FF
                BEQ     @fml_undone
_cfp980         LDAL    _mlSaveExtCount
_cfp981         STAL    _modExtCount
_cfp982         LDAL    _mlSaveRegCount
_cfp983         STAL    _modRegCount
                SEP     #$20
                MX      %10
                LDA     #0
_cfp989         STAL    _mlSaveValid
                REP     #$20
                MX      %00

                ; ...AND THE BANK, if this load is the one that allocated it.
                ; A module that JOINED an occupied chain must not hand back a
                ; bank its neighbours are running in, which is what _mlBankFresh
                ; is for.  Today every modload.conf module joins ordinal 0, so
                ; this arm is the one that opens a new chain.
                SEP     #$20
                MX      %10
_cfp984         LDAL    _mlBankFresh
                REP     #$20
                MX      %00
                AND     #$00FF
                BEQ     @fml_undone
_cfp985         LDAL    _mlBankOrd
                TAX
                SEP     #$20
                MX      %10
                LDA     #0
_cfp986         STAL    _modBankTab,X           ; the chain is empty again
_cfp987         STAL    _mlBankFresh
                ; _mlBank, NOT _mlsBank.  The session copies the bank only when
                ; the header SUCCEEDS, so a header that allocated a fresh chain
                ; and was then refused at the extent claim left _mlsBank zero --
                ; and freeing bank 0 is a no-op that loses the real one.
_cfp990         LDAL    _mlBank
                REP     #$20
                MX      %00
                AND     #$00FF
                JSL     _FarSh_Bank_Free
@fml_undone     SEP     #$20
                MX      %10
                STZ     _mlsBank
                REP     #$20
                MX      %00
                PLA                             ; the errno back
                BRL     @fml_fail

@fml_nosess     REP     #$20
                MX      %00
                LDA     #EINVAL                 ; data/end/abort with no begin
@fml_fail       PLB
                CLC
                RTL
@fml_ok         PLB
                SEC
                RTL

_Vfs_CdirExit   ENT
                ; far slot 50 -- the cwd's exit half.  root_cdirexit(pid),
                ; returns void.  TWO ARGUMENT BYTES, so the word is at 7,S.
                MX      %00
                PHB
                PHD
                PHK
                PLB                     ; DBR = far bank
                LDA     #FGX_DP_KERNELC
                TCD

                LDA     7,S
                PHA

                PHK
                PEA     _VfsCdirExitRet-1
                PHK
                PEA     root_cdirexit-1
                RTL                     ; pile call into the C
_VfsCdirExitRet TSC
                CLC
                ADC     #2              ; drop the copy -- the caller cleans
                TCS
                PLD
                PLB
                RTL

_Vfs_RootListdir ENT
                ; far slot 47 -- the directory-read conversion.
                ; root_listdir(name, buf, size) -> bytes written, or -errno.
                ;
                ; TWELVE ARGUMENT BYTES -- a pid, two fcc pointers and a
                ; count -- so the deepest word is at 17,S once PHB and PHD
                ; have moved the frame down three.  The pid arrived with
                ; apple/fgx#295: a listing of a RELATIVE name is about a
                ; process, and with nothing to ask this walked from the
                ; root and listed the wrong directory.
                ;
                ; THE TWO POINTERS NAME DIFFERENT BANKS and both are supplied
                ; by the CORE-side stub: `name' is kernel-bank, `buf' is the
                ; CALLER's, built from the buffer offset and _Sys_CallerBank.
                ; Nothing here may use a `^' literal, which would assemble this
                ; bank's -- and dev_rw's header is where the argument lives for
                ; why a user pointer here is one that must be COMPLETE rather
                ; than translated.  The directory block the walk needs is
                ; vfs.mod's own; see vfs_listdir.
                ;
                ; NO pid, for root_stat's reason: a listdir opens nothing and
                ; touches no file table, so there is no process for it to be
                ; about.
                MX      %00
                PHB
                PHD
                PHK
                PLB                     ; DBR = far bank
                LDA     #FGX_DP_KERNELC
                TCD

                LDA     17,S
                PHA
                LDA     17,S
                PHA
                LDA     17,S
                PHA
                LDA     17,S
                PHA
                LDA     17,S
                PHA
                LDA     17,S
                PHA

                PHK
                PEA     _VfsRootListdirRet-1
                PHK
                PEA     root_listdir-1
                RTL                     ; pile call into the C
_VfsRootListdirRet TAY                  ; park the result; the drop needs A
                TSC
                CLC
                ADC     #12             ; drop the copy -- the caller cleans
                TCS
                TYA
                PLD
                PLB
                RTL

_Vfs_DevRW      ENT
                ; far slot 38 -- UFS 1.7d I3.  dev_rw(pid, fd, uio) ->
                ; count, or -errno.  8 argument bytes, so the deepest word is
                ; at 13,S.
                ;
                ; `uio' IS A COMPLETE 24-BIT POINTER at the task's u.u_ttyuio,
                ; and its iov_bases are complete too.  Nothing here re-banks
                ; them and nothing may: see dev_rw's own header for why a bank
                ; is part of an address on this machine and not a segment to
                ; be translated.
                MX      %00
                PHB
                PHD
                PHK
                PLB                     ; DBR = far bank
                LDA     #FGX_DP_KERNELC
                TCD

                LDA     13,S
                PHA
                LDA     13,S
                PHA
                LDA     13,S
                PHA
                LDA     13,S
                PHA

                PHK
                PEA     _VfsDevRWRet-1
                PHK
                PEA     dev_rw-1
                RTL                     ; pile call into the C
_VfsDevRWRet    TAY                     ; park the result; the drop needs A
                TSC
                CLC
                ADC     #8              ; drop the copy -- the caller cleans
                TCS
                TYA
                PLD
                PLB
                RTL


_Vfs_DevIoctlSel ENT
                ; far slot 43 -- UFS 1.7d I4.  dev_ioctlsel(pid, fd, com, data,
                ; isioctl) -> 0 / a readiness mask, or -errno.  12 argument
                ; bytes, so the deepest word is at 17,S -- copied the way
                ; _Vfs_DevRW copies its frame, and for the same reason: fcc
                ; reads its arguments right to left, so the copy walks a fixed
                ; 17,S as each PHA pushes the stack down under it.
                ;
                ; `data' IS A COMPLETE 24-BIT POINTER at the caller's ioctl
                ; argument, built core-side from _Sys_IoctlArgLo and
                ; _Sys_IoctlArgBank.  NOTHING IN THIS BANK DEREFERENCES IT --
                ; vfs_ioctl passes it to fo_ioctl, vn_ioctl passes it to
                ; VOP_IOCTL, and spec_ioctl does not pass it on at all, because
                ; the driver reads the caller's argument through the syscall
                ; layer's own staging.  It crosses as an opaque address.
                ;
                ; It is MEANINGLESS on the select side and is copied anyway:
                ; branching to push zeros would cost bytes in the CORE bank,
                ; which is the one with nothing left, to save nothing here.
                MX      %00
                PHB
                PHD
                PHK
                PLB                     ; DBR = far bank
                LDA     #FGX_DP_KERNELC
                TCD

                LDA     17,S
                PHA
                LDA     17,S
                PHA
                LDA     17,S
                PHA
                LDA     17,S
                PHA
                LDA     17,S
                PHA
                LDA     17,S
                PHA

                PHK
                PEA     _VfsDevIoctlSelRet-1
                PHK
                PEA     dev_ioctlsel-1
                RTL                     ; pile call into the C
_VfsDevIoctlSelRet TAY                  ; park the result; the drop needs A
                TSC
                CLC
                ADC     #12             ; drop the copy -- the caller cleans
                TCS
                TYA
                PLD
                PLB
                RTL


;------------------------------------------------------------------------------
; _Vfs_FileInit - far slot 31: carve the open-file table.  UFS 1.7d I2b.
;
; IT RUNS BEFORE ANY MODULE LOADS, which is the whole point.  Mod_LoadConf
; opens files through _Fcb_Alloc (modload.s:174 -> Fs_Open -> fs.s:1198) and
; Mod_LoadConf is what LOADS vfs.mod -- so a file table carved by vfs.mod's own
; vfs_init would not exist the first time anything opened a file.  BSD puts
; this in kern_descrip.c for the same reason it is here: descriptors are a
; PROCESS notion, and the filesystem is something a process opens.
;
; A STATIC, NOT A HEAP CARVE.  The VFS pools are Kmalloc'd because the buffer
; arena is 16 KB and cannot be static; this is 2,208 bytes and the far bank has
; forty thousand free, so a static removes an allocation, an error path, and an
; ordering hazard -- it is ready the instant the bank is.  finit zeroes it
; itself (falloc finds a free slot BY the zero), so an uninitialised DS is
; exactly what it wants.
;
; VFS_FILE_BYTES is GENERATED (include/vfs_equ.s, from tools/gen_vfs_equ.py),
; so the size here and finit's arithmetic have one source.
;------------------------------------------------------------------------------
_Vfs_FileInit   ENT
                MX      %00
                PHB
                PHD
                PHK
                PLB                     ; DBR = far bank
                LDA     #FGX_DP_KERNELC
                TCD                     ; D = fcc's register file page

                ; finit(char *arena).  fcc's pointer is 4 bytes -- offset word,
                ; then bank byte, then pad -- and the argument nearest the
                ; return address is the lowest, so the pad and bank go down
                ; first and the offset last.  The bank is PHK's, the LIVE one:
                ; a constant here would bake the assembly ORG bank, which is
                ; the mistake that cost the seam a session.
                ; THE ARENA IS A HEAP BLOCK, taken here on the caller's page:
                ; `Kmalloc' answers on the kernel's real direct page
                ; (`_kmallocResult', dpmap.s), which D still is until the TCD
                ; below.  NFILE file structs and NPROC*FS_MAX_FDS descriptor
                ; words are 5,376 bytes at thirty-two tasks, which no bank
                ; has as a static; the vnode and namei pools are heap arenas
                ; already (vfs.mod, VFS_POOL_BYTES).  The pointer is kept in
                ; this bank for the ofile hand-off below.
                PLD                     ; the caller's page, for Kmalloc
                PHD
                LDA     #VFS_FILE_BYTES
                LDX     #M_KERN
_cfp994         JSL     _FarSh_Kmalloc  ; bank byte patched by Far_BankInit
                BCS     @vfi_haveArena
                BRL     _VfsFileNoArena
@vfi_haveArena  LDA     _kmallocResult
                STA    |_kFileArenaPtr
                LDA     _kmallocResult+1 ; bank in the high byte
                AND     #$FF00
                XBA
                STA    |_kFileArenaPtr+2 ; bank, high byte clear
                LDA     #FGX_DP_KERNELC
                TCD                     ; D = fcc's register file page again

                SEP     #$20
                MX      %10
                LDA     #0
                PHA                     ; pad
                LDA    |_kFileArenaPtr+2
                PHA                     ; bank -- the heap block's
                REP     #$20
                MX      %00
                LDA    |_kFileArenaPtr
                PHA                     ; offset

                PHK
                PEA     _VfsFileInitRet-1
                PHK
                PEA     finit-1
                RTL                     ; pile call into the C
_VfsFileInitRet TSC
                CLC
                ADC     #4              ; drop the pointer argument
                TCS

                ; HAND THE CORE THE DESCRIPTOR ARRAYS' BASE -- UFS 1.7d I2c.
                ;
                ; The core bank has to be able to READ a `struct file': f_ops
                ; is what dispatch will call through, and a far call per
                ; read(2) to fetch it would be a bank round trip on the hottest
                ; path in the system.  So it reads the table directly, with the
                ; offsets include/vfs_equ.s already publishes -- which is what
                ; that file was generated for.
                ;
                ; ONCE, HERE, rather than a slot of its own: this already runs
                ; exactly once, at the only moment the answer becomes true.
                ;
                ; ofile_pool is where finit puts it -- immediately after the
                ; NFILE file structs (`&file_pool[NFILE]').  The arithmetic is
                ; duplicated from the C, so both take NFILE and FILE_SIZE from
                ; the generated equates and gen_vfs_equ.py keeps them equal.
                ;
                ; THE BANK IS THE HEAP BLOCK'S, read back from the pointer the
                ; allocation above stored; nothing here names a bank.
                REP     #$30
                MX      %00
                LDA    |_kFileArenaPtr
                CLC
                ADC     #VFS_OFILE_OFF  ; ofile_pool = arena + NFILE*24
                LDX    |_kFileArenaPtr+2 ; X.lo = the heap block's bank
                PLD
                PLB
                RTL

                ; No heap for the file table: nothing later can open a file,
                ; and a silent zero pointer would be dereferenced by the first
                ; open.  Say so and stop.
_VfsFileNoArena LDA     #_vfsNoArenaMsg
                STA     _conStrPtr
_cfp995         JSL     _FarSh_LogStr   ; bank byte patched by Far_BankInit
_cfp996         JSL     _FarSh_Halt     ; never returns
_vfsNoArenaMsg  ASC     'PANIC: no heap for the file table',00

; The table's pointer: the heap arena holds NFILE `struct file` plus the
; per-process descriptor arrays, which finit carves apart and zeroes;
; falloc/ufalloc find free entries BY that zero.  Offset, then bank.
_kFileArenaPtr  DS      4
