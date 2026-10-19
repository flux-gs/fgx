;==============================================================================
; vfs.s - the assembly root of vfs.mod: the BSD VFS, compiled from C, in a
; loadable FGXM module of its own.
;
; THE SECOND C MODULE AND THE FIRST REAL ONE.  hellokc.mod proved the container
; -- own bank, shared fcc runtime, kernel services through SYS_KCALL, function
; pointer tables with no relocation pass.  This is the same container carrying
; ~32 KB of subsystem instead of a probe, which is the only thing that was ever
; in question.
;
; WHY THE VFS AND WHY NOW.  src/kernel/far/far.s calls itself "module SHAPED"
; and says promoting a subsystem out of it "is a link change, not a rewrite".
; Its two stated blockers -- may call Kmalloc, may call _sleep, "both forbidden
; to modules" -- were retired by KSVC_KMALLOC/KSVC_KFREE and
; KSVC_SLEEP/KSVC_WAKEUP.  The VFS has NO runtime customers yet: only the boot
; probes call it.  That is what makes this cheap, and it is the reason to do it
; before UFS 1.6b (namei) gives it one.
;
; THE C IS UNCHANGED AND IS NOT COPIED.  These are the SAME generated files the
; far bank PUTs, from the same `kernelc` ninja edges -- fcc is invoked with
; identical flags for both (`-fno-safepoints --pile --kernel-bank`).  Only
; kc_sys.s differs, and only in how it reaches the kernel: the far bank JSLs
; _FarSh_* shims at addresses scraped from the kernel's build listing, which a
; module cannot do because it does not know the kernel's bank at build time.
; This one goes through the bank-0 gateway, whose addresses are fixed by
; construction.  That substitution is the whole of "a link change".
;
; IT IS NOT GATED ON KCPROBE.  far.s wraps its kernel C in `DO KCPROBE=1`
; because that code shares the kernel's own ceiling and a debug build must be
; able to give it back.  A module costs the kernel nothing when it is not in
; /etc/modload.conf, so the gate has nothing left to buy.  vfs_probe stays
; behind VFSPROBE: that one WRITES to a disk on the boot path, which is a
; narrower question than "is kernel C compiled in".
;
; MODBANK-C-OK: every global, literal and runtime scratch this module's C
; touches is read DBR-relatively, which is correct here and only here: the C is
; only ever entered through MOD_KC_ENTER, which puts DBR on this module's own
; bank for the whole time it runs.  The waiver is at MODULE level because both
; the accesses and the declarations live in fcc OUTPUT, and annotating
; generated files is the workaround this tree forbids.
;==============================================================================

                MX      %11
                PUT     modplace.s
                ORG     MODP_ORG

                PUT     ../../../include/config.s       ; CFG_* build gates
                PUT     ../../../include/macros.s       ; FGX2_MODE/EXPORT/RELOC
                PUT     ../../../include/kernel.s       ; FGX_DP_KERNELC
                PUT     ../../../include/dpmap.s        ; DUM $00: the block
                                                        ;   layer's DP cells,
                                                        ;   which kc_blkio
                                                        ;   writes.  Emits no
                                                        ;   bytes -- see the
                                                        ;   note in kernelc.s
                                                        ;   about what a byte
                                                        ;   before the ORG does.
                PUT     ../../../include/modules.s      ; SYS_KCALL, KSVC_*
                PUT     ../../../include/errno.s        ; ENODEV, for kc_chardev.s
                PUT     ../../../include/chardev.s      ; CHARDEV_MAX, for the
                                                        ;   index|flag encoding
                PUT     ../../../include/kernelc.s      ; MOD_KC_ENTER/LEAVE
                PUT     ../../../include/fs.s           ; DEV_* record layout +
                                                        ;   FS_MAX_DEVICES, for
                                                        ;   the probe's device
                                                        ;   scan.  DUM blocks and
                                                        ;   EQUs -- the ERR after
                                                        ;   the header catches it
                                                        ;   if that stops being
                                                        ;   true.
                PUT     ../../../include/vfs_equ.s      ; GENERATED from the C
                                                        ;   headers: VFS_NBUF,
                                                        ;   VFS_BLKSIZE and
                                                        ;   VFS_POOL_BYTES, so
                                                        ;   the arena sizes have
                                                        ;   no second copy

;------------------------------------------------------------------------------
; FGXM header v2 (40 bytes).
;------------------------------------------------------------------------------
vfs_bss         EQU     0

vfs_hdr         ASC     'FGXM'                          ; +0  magic
                DFB     <MODP_ORG                       ; +4  load lo
                DFB     >MODP_ORG                       ; +5  load mid
                DFB     ^MODP_ORG                       ; +6  load hi -- the
                                                        ;     bank ORDINAL, $06
                DFB     $02                             ; +7  header format v2
                ; Entry, BANK-relative.  The subtrahend is the ordinal's base,
                ; not MODP_ORG: those two coincide only while this module sits
                ; at offset 0 in its bank, which it does today because it is
                ; alone there.  The ERR below is what keeps the constant honest
                ; if gen_modplace.py's OWN_BANK ever moves it.
                DA      mod_init-$060000                ; +8  entry, bank-rel
                DA      vfs_end-vfs_text                ; +10 text bytes
                DA      vfs_bss                         ; +12 bss bytes
                DA      vfs_vtdir-vfs_text              ; +14 vtdir offset
vfs_name        ASC     'vfs'                           ; +16 module name
                DS      16-*+vfs_name                   ;     NUL-pad to 16
                DA      $0000                           ; +32 module version
                ; +34 build identity.  $0000 = not build-locked: this module
                ; bakes no kernel addresses -- it reaches the kernel only
                ; through the bank-0 gateway, which is the point.
                DA      $0000
                DS      4                               ; +36 reserved

vfs_text        EQU     *

;------------------------------------------------------------------------------
; VTDR: ONE ENTRY, AND IT POINTS SIDEWAYS RATHER THAN UP.
;
; Every other vtable in this system exists so the KERNEL can call into a module
; -- VT_FST, VT_NET, VT_CHARDEV.  This one exists so ANOTHER MODULE can, and it
; is the first of its kind (apple/fgx#169).  ufs.mod holds the UFS filesystem
; and needs this module's buffer cache; the kernel is not involved in the call
; at all, only in handing over the address.
;
; The entry stayed empty for a long time and the note here said a vtable would
; arrive "when 1.6b's namei gives the VFS a syscall-path customer, shaped by
; that customer".  That is still true and still hasn't happened -- the kernel
; calls into the VFS at zero points today.  What arrived instead was a customer
; from the side, and it shaped this table: six entry points, chosen by reading
; ufs.mod's externs rather than by guessing what a VFS ought to export.
;------------------------------------------------------------------------------
vfs_vtdir       ASC     'VTDR'
                DA      VT_VFSCORE
                DA      vfscore_ops-vfs_text    ; text-relative; the loader makes
                                                ;   it bank-relative (modload.s)
                DA      VT_END

;------------------------------------------------------------------------------
; vfscore_ops - the exported entry points, in VFSCORE_* order.
;
; PLAIN 16-BIT ADDRESSES, not net.mod's 3-byte long pointers with a patched
; bank byte.  The bank is not this table's business: Mod_FindVtable hands the
; caller the bank alongside the table's address, so repeating it six times here
; would be a second copy of one fact, and a second copy is a thing that drifts.
;
; A LABEL IS ALREADY THE BANK-RELATIVE ADDRESS, which is the same assumption
; net.mod's table makes and is not an assumption anyone has to remember: this
; file ORGs at MODP_ORG and the loader places the image there, and the
; `ERR vfs_hdr-MODP_ORG` guard at the foot of this file fails the build if that
; ever stops being true.
;
; THESE ARE fcc FUNCTIONS AND ARE ENTERED WITH fcc's CONVENTION -- arguments on
; the stack, RTL-terminated, and DBR ON THIS MODULE'S BANK, which the caller
; must arrange because fcc reads every global and literal DBR-relatively.
; src/modules/ufs/vfs_import.s is the only caller and carries the whole
; argument; the short version is that a module calling this table without
; setting DBR reads vfs.mod's data structures out of its own bank and gets
; plausible garbage, which is apple/fgx#93's shape.
;------------------------------------------------------------------------------
vfscore_ops     DA      bread                   ; VFSCORE_Bread
                DA      bwrite                  ; VFSCORE_Bwrite
                DA      brelse                  ; VFSCORE_Brelse
                DA      getblk                  ; VFSCORE_Getblk
                DA      bdevvp                  ; VFSCORE_Bdevvp
                DA      vrele                   ; VFSCORE_Vrele
                DA      vref                    ; VFSCORE_Vref
                DA      getnewvnode             ; VFSCORE_Getnewvnode
                DA      vget                    ; VFSCORE_Vget
                DA      uiomove                 ; VFSCORE_Uiomove
                DA      biodone                 ; VFSCORE_Biodone
                DA      vinvalbuf               ; VFSCORE_Vinvalbuf -- 1.12b
                DA      vgone                   ; VFSCORE_Vgone -- 1.12b
                DA      namei                   ; VFSCORE_Namei
                DA      ndslot                  ; VFSCORE_Ndslot
                ; The device switch as the filesystem sees it -- UFS 1.13a.
                ; ufsdir.mod builds spec_inodeops out of these and its own
                ; inode operations; include/modules.s carries the argument.
                DA      checkalias              ; VFSCORE_Checkalias
                ; THE TEN SPEC SLOTS ARE DEAD AND STILL NUMBERED (2026-09-05).
                ; spec_vnops.c moved to ufsdir.mod, which held its only caller
                ; -- ufs_vnops.c names all ten in its device-vnode ops vector --
                ; so the ten shims that reached back here are deleted and the
                ; calls are same-bank.  THE SLOTS STAY because a slot number is
                ; ABI: removing them would renumber every VFSCORE_* above them
                ; and silently repoint every other consumer's shims.  Nothing
                ; reads these now; a reader would pile-call offset 0.
                DA      0                   ; VFSCORE_SpecLookup -- DEAD SLOT
                DA      0                   ; VFSCORE_SpecOpen -- DEAD SLOT
                DA      0                   ; VFSCORE_SpecClose -- DEAD SLOT
                DA      0                   ; VFSCORE_SpecRead -- DEAD SLOT
                DA      0                   ; VFSCORE_SpecWrite -- DEAD SLOT
                DA      0                   ; VFSCORE_SpecIoctl -- DEAD SLOT
                DA      0                   ; VFSCORE_SpecSelect -- DEAD SLOT
                DA      0                   ; VFSCORE_SpecBmap -- DEAD SLOT
                DA      0                   ; VFSCORE_SpecStrategy -- DEAD SLOT
                DA      0                   ; VFSCORE_SpecBadop -- DEAD SLOT
                DA      vcount                  ; VFSCORE_Vcount
                ; The file/vnode glue -- UFS 1.7c.
                DA      vn_open                 ; VFSCORE_VnOpen
                DA      vn_read                 ; VFSCORE_VnRead
                DA      vn_write                ; VFSCORE_VnWrite
                DA      vn_close                ; VFSCORE_VnClose
                DA      vn_rdwr                 ; VFSCORE_VnRdwr
                DA      vn_writechk             ; VFSCORE_VnWritechk
                ; vn_ioctl and vn_select complete the vnops targets: the
                ; VECTOR lives in the far bank with its dispatcher, and its
                ; five entries name far-side shims that cross to these.
                DA      vn_ioctl                ; VFSCORE_VnIoctl
                DA      vn_select               ; VFSCORE_VnSelect
                DA      vn_getattr              ; VFSCORE_VnGetattr
                ; UFS 1.7d I3: the far bank mounts /dev and hands the mount
                ; over; the VOP dispatching that finding its root needs can
                ; only be done from a module.
                DA      vfs_devroot             ; VFSCORE_DevRoot
                ; apple/fgx#108 T3: ttread's one-character handoff.  Its second
                ; caller is T4's tty_pty.c, in another module again.
                DA      ureadc                  ; VFSCORE_Ureadc
                DA      vflush                  ; VFSCORE_Vflush
                DA      vfs_dounmount           ; VFSCORE_Dounmount
                ; UFS 2.4b: the far bank mounts the boot volume as root and
                ; hands the mount over, because `rootdir' is this module's
                ; data and VFS_ROOT is a dispatch only a module may make.
                DA      vfs_setroot             ; VFSCORE_SetRoot
                ; The directory-read conversion.  The far bank decides
                ; whether the root is ours; everything after that is here,
                ; because namei and VOP_READDIR both are.
                DA      vfs_listdir             ; VFSCORE_VfsListdir
                ; The cwd, as a vnode.  namei's relative arm has always read
                ; ni_cdir; these are what finally put something in it.
                DA      vfs_cdir                ; VFSCORE_Cdir
                DA      vfs_chdir               ; VFSCORE_Chdir
                DA      vfs_cdirinit            ; VFSCORE_Cdirinit
                ; Letting go of a LOCKED vnode, which the far bank cannot do
                ; for itself: VOP_UNLOCK dispatches through v_op.
                DA      vput                    ; VFSCORE_Vput
                ; The cwd's fork and exit halves.  chdir is one of Reno's four
                ; lines on this vnode; these are the other two.
                DA      vfs_cdirfork            ; VFSCORE_CdirFork
                DA      vfs_cdirexit            ; VFSCORE_CdirExit
                DA      vfs_unlink              ; VFSCORE_Unlink
                DA      vfs_mkdir               ; VFSCORE_Mkdir
                DA      vfs_rmdir               ; VFSCORE_Rmdir
                DA      vfs_setspecops          ; VFSCORE_Setspecops
                DA      bawrite                 ; VFSCORE_Bawrite
                DA      bdwrite                 ; VFSCORE_Bdwrite
                DA      vflushbuf               ; VFSCORE_Vflushbuf
                DA      bio_strategy            ; VFSCORE_BioStrategy
                DA      vfs_rename              ; VFSCORE_Rename
                DA      vfs_symlink             ; VFSCORE_Symlink
                DA      vfs_readlink            ; VFSCORE_Readlink
                DA      vfs_statfs1             ; VFSCORE_Statfs1
                DA      vfs_statfs              ; VFSCORE_Statfs
                DA      vfs_setattr             ; VFSCORE_Setattr
                DA      vfs_link                ; VFSCORE_Link
                DA      vfs_sync1               ; VFSCORE_Sync1
                ; ftruncate(2)'s VOP_SETATTR, UFS 2.7.  The far bank owns the
                ; descriptor and the refusals; the dispatch is ours.
                DA      vn_setsize              ; VFSCORE_VnSetsize
                ; fchdir(2), UFS 2.7: the cwd table is ours.
                DA      vfs_fchdir              ; VFSCORE_Fchdir
                ; access(2), UFS 2.6: the per-bit check, beside vn_writechk.
                DA      vn_access               ; VFSCORE_VnAccess
                ; The name cache's handover, pointing INTO this module from
                ; ufsdir.mod -- which owns the cache since it was wired into
                ; ufs_lookup.  vfs_setspecops two screens up is the same shape
                ; and arrived for the same reason.
                DA      vfs_setcacheops         ; VFSCORE_Setcacheops
                ; securelevel and its one rule (apple/fgx#410).  The variable
                ; is this module's; spec_securechr is what ufsdir.mod's
                ; spec_open asks on every write-open of a character device,
                ; and the other two are sysctl(2)'s, from the far bank.
                DA      spec_securechr          ; VFSCORE_SpecSecurechr
                DA      vfs_getsecurelevel      ; VFSCORE_GetSecurelevel
                DA      vfs_setsecurelevel      ; VFSCORE_SetSecurelevel
                ; The buffer pool's delayed-write flush (apple/fgx#398), for
                ; ufs.mod's ufs_sync.
                DA      bflush                  ; VFSCORE_Bflush
                ; exec(2)'s permission pair (apple/fgx#416), beside vn_access
                ; because it is the same question asked of the same vnode.
                DA      vn_execchk              ; VFSCORE_VnExecchk
                DA      vn_execsugid            ; VFSCORE_VnExecsugid
                ; mount(2)'s type switch: the far bank's vfs_mountat reads a
                ; row through vfs_getvfsops, and each filesystem's mod_init
                ; hands its row to vfs_setvfsops.
                DA      vfs_getvfsops           ; VFSCORE_Getvfsops
                DA      vfs_setvfsops           ; VFSCORE_Setvfsops
                DA      vattr_null              ; VFSCORE_VattrNull
                ; The table and the offsets that index it must agree.  Merlin's
                ; ERR fires on a NON-ZERO expression.
                ;
                ; THE BRACES ARE LOAD-BEARING.  Merlin evaluates strictly left
                ; to right with NO OPERATOR PRECEDENCE, so the obvious
                ; `*-vfscore_ops-VFSCORE_COUNT*2` reads as
                ; ((*-vfscore_ops)-VFSCORE_COUNT)*2 -- which is (12-6)*2 = 12 on
                ; a CORRECT table, and fails the build.  Measured, not guessed:
                ; that was the first version and Merlin said '0xC'.
                ERR     *-vfscore_ops-{VFSCORE_COUNT*2}

;------------------------------------------------------------------------------
; The C-to-kernel seam.  Inside the module with the C it serves -- nothing but
; this module's C reaches these.
;
; BEFORE mod_init, not after: it defines the ENTERK/LEAVEK macros, and Merlin
; needs a MAC defined before the line that uses one.
;------------------------------------------------------------------------------
                PUT     ../common/kc_sys.s

; kc_chardev.s WENT TO ufsdir.mod WITH spec_vnops.c (2026-09-05).  Its own
; comment said it lived here because "only this one's C calls these" -- and
; that C was spec_vnops.c, which is ufsdir's now, so the file followed its
; only caller rather than staying to be reached across a bank.

;--- `bcopy', which is assembly upstream too and is the block move behind
;--- uiomove.  vfs.mod's own for the same reason as kc_chardev.s: kern_subr.c
;--- is in _VFS_C and nothing else calls it.
                PUT     uio_copy.s

;==============================================================================
; mod_init - bring the whole VFS up, here, at module load.
;
; THE KERNEL NO LONGER CALLS INTO THE VFS AT ALL.  main.s used to allocate both
; arenas and hand them down through three far-bank export slots; that seam is
; gone, not relocated.  A module that needs nothing from the kernel except heap
; and a log line can do its own bring-up, and doing it here removes the one
; thing a module genuinely cannot have: a fixed address the kernel can call.
; The inward seam comes back when 1.6b's namei gives the VFS a syscall-path
; customer, and it will be shaped by that customer rather than by history.
;
; DBR IS OURS FOR THE WHOLE OF THIS ROUTINE.  A module runs with DBR = the
; kernel bank, and almost everything below wants this one: the module's own
; log strings are here, and the KSVC dispatcher saves and restores
; DBR itself so the services do not care.  One PHB/PHK/PLB at the top beats
; hellokc's per-call bracket, which existed because that module had exactly one
; pointer to pass.
;
; IT LOGS NOTHING ON SUCCESS.  The kernel's _BufInit could afford a success line
; because it was the only thing announcing the VFS at all; the loader's 'mod: vfs
; loaded' is that now, and it is not a weaker claim -- the loader prints it only
; when this routine returned with carry set, which is after both C calls have run
; to completion in this module's bank.  A second announcement would say nothing
; the first does not.  Both arenas log on FAILURE only, which is the rule the
; pool layer already followed.
;
; NOT because of apple/fgx#94 any more, though that is why the line went in the
; first cut and came out again: one extra line of boot output turned vccursor
; red.  That was a HARNESS defect, fixed 2026-08-12 -- the check dumped 2000
; bytes of a 8000-byte AttrBuf ring and so drifted off the visible window as the
; console scrolled.  Boot output length is not a constraint on this file.
;==============================================================================
mod_init        MX      %00
                PHP
                REP     #$30
                MX      %00

                PHB
                PHK
                PLB                     ; DBR = ours, for everything below

                ; BEFORE ANYTHING ELSE, and before any C: fcc's --module-bank
                ; leaves every &function cell's bank byte zero because the
                ; assembler cannot know this module's bank.  PHK in here can.
                ; One dispatch through an unstamped cell is a JMP to bank 0.
                JSR     _Mod_StampFnPtrs
                JSR     _Vfs_ZeroKcDP
                JSR     _Vfs_BufInit
                JSR     _Vfs_PoolInit
                DO      VFSPROBE=1
                JSR     _Probe_Drive
                FIN
                PLB
                PLP
                SEC                     ; init OK -- see the note in _Vfs_PoolInit
                RTL                     ;   about why a failed pool is not a
                                        ;   failed LOAD

;------------------------------------------------------------------------------
; _Vfs_ZeroKcDP - clear the kernel-C direct page before the first C runs on it.
;
; Two of fcc's slots are READ BEFORE THEY ARE WRITTEN -- _fcc_stkfloor ($B9),
; which a prologue guard compares against, and _fcc_fb ($BB), which a prologue
; SAVES before overwriting -- so the page cannot be left holding whatever the
; loader last staged through it.
;
; The kernel does this too, inside _KcProbe, and the duplication is deliberate:
; that runs only in a KCPROBE build, and this module must come up correctly in
; a kernel that has no C of its own at all.  Doing it twice is idempotent; the
; page is dead between the far bank's probe and here.
;
; Long stores with an explicit bank of zero.  FGX_DP_KERNELC is a bank-0
; address by construction, so this bakes no kernel address -- but it DOES bake
; the bank-0 layout constant, which moves with kernel.nproc.  That is the same
; dependency MOD_KC_ENTER already has through `LDA #FGX_DP_KERNELC`, so it adds
; no new coupling; it is written down here because nothing else says it.
;------------------------------------------------------------------------------
_Vfs_ZeroKcDP   MX      %00
                LDA     #0
                LDX     #$00FE
@zdp_L          STAL    $000000+FGX_DP_KERNELC,X
                DEX
                DEX
                BPL     @zdp_L
                RTS

;------------------------------------------------------------------------------
; Where each arena landed.  Waived at the DECLARATION rather than on fifteen
; access lines, because the reason is one fact about the whole file: every one
; of these is touched only from mod_init's call tree, and mod_init's first act
; is PHK/PLB.
;------------------------------------------------------------------------------
_vfsBufOff      DS      2       ; MODBANK-OK: mod_init only (DBR=ours)
_vfsBufBank     DS      2       ; MODBANK-OK: mod_init only (DBR=ours)
_vfsPoolOff     DS      2       ; MODBANK-OK: mod_init only (DBR=ours)
_vfsPoolBank    DS      2       ; MODBANK-OK: mod_init only (DBR=ours)

;------------------------------------------------------------------------------
; _Vfs_BufInit - allocate the buffer arena and hand it to bufinit.
;
; THE ARENA MUST NOT STRADDLE A BANK BOUNDARY.  bufinit derives each buffer's
; address as base + i*VFS_BLKSIZE with a 16-BIT add and no carry into the bank,
; so a base near the top of a bank would wrap its later buffers back to the
; bottom of the same one.  Kmalloc satisfies this by construction -- it never
; splits an allocation across banks -- and the check says so out loud rather
; than trusting it silently.
;
; NON-FATAL ON FAILURE.  A machine with no buffer cache still boots ProDOS, and
; refusing the module here would take the vnode layer down with it for a
; subsystem nothing has mounted yet.
;------------------------------------------------------------------------------
_Vfs_BufInit    MX      %00
                LDA     #VFS_NBUF*VFS_BLKSIZE
                LDY     #M_KERN
                LDX     #KSVC_KMALLOC   ; -> C=1, A = offset, X = bank
                JSL     SYS_KCALL
                BCC     @bfi_fail
                STA    |_vfsBufOff
                PHX
                PLA
                AND     #$00FF
                STA    |_vfsBufBank
                ; Bank-straddle check: base + size-1 must not carry out of the
                ; 16-bit offset.  A wrap here is silent corruption later --
                ; buffer 15 would alias buffer 0's neighbourhood.
                LDA    |_vfsBufOff
                CLC
                ADC     #VFS_NBUF*VFS_BLKSIZE-1
                BCS     @bfi_fail       ; wrapped: refuse the arena

                ; READ THE BASE BEFORE THE BRACKET.  MOD_KC_ENTER clobbers A
                ; only, so X and Y carry the value across untouched -- the same
                ; discipline the kernel side used for the opposite reason, and
                ; the reason tools/check_kc_dbr.py now watches both macros.
                LDX    |_vfsBufOff
                LDY    |_vfsBufBank

                MOD_KC_ENTER            ; DBR = our bank, D = kernel-C page
                ; The argument is a 4-byte fcc pointer, and it goes on the
                ; stack HIGH PART FIRST so that ascending from the callee's
                ; frame it reads offset, offset, bank, pad -- which is where
                ; fcc looks: the offset word at 4,S and the bank byte at 6,S.
                SEP     #$20
                MX      %10
                LDA     #0
                PHA                     ; pad byte (never read)
                TYA                     ; bank
                PHA
                REP     #$30
                MX      %00
                TXA                     ; offset
                PHA
                ; NOT A JSL: a JSL bakes the ASSEMBLY-time bank, never the load
                ; bank.  PHK supplies the return bank and PEA the return
                ; address minus one, which is exactly the 3 bytes a JSL pushes,
                ; so the callee's arguments sit where fcc expects.  See
                ; hellokc.s for the full account.
                PHK
                PEA     @bfi_ret-1
                JMP     bufinit
@bfi_ret        PLA                     ; caller pops its own argument
                PLA
                MOD_KC_LEAVE
                RTS

                ; ONLY ON FAILURE, which is the rule the pool layer already
                ; followed and now applies to both arenas.  'vfs: buffer cache
                ; ready' used to print here because the kernel's _BufInit was
                ; the ONLY thing that announced the VFS at all.  As a module
                ; the loader's own 'mod: vfs loaded' already says it, and
                ; mod_init returns SEC only after both C calls have run -- so
                ; a success line here would be a SECOND announcement of the
                ; same fact.
@bfi_fail       LDA     #@bfi_bad
                LDX     #KSVC_LOGSTRNE
                JSL     SYS_KCALL
                LDX     #KSVC_LOGEOL
                JSL     SYS_KCALL
                RTS

@bfi_bad        ASC     'vfs: buffer arena UNAVAILABLE',$00

;------------------------------------------------------------------------------
; _Vfs_PoolInit - build the vnode pool, its free list, and the name cache.
;
; The counterpart of _Vfs_BufInit and the same shape.  The pools USED TO BE C
; arrays in the far bank, which took no allocation and no failure path -- and
; 7,604 bytes of the bank the VFS itself had to fit in.  Storage has no reason
; to sit in the bank the code lands in.
;
; VFS_POOL_BYTES is GENERATED (include/vfs_equ.s) from the C headers, and the
; struct sizes it multiplies are pinned by toolchain/tests/M37/vfslayout.c.
; There is no second copy of that number, and a layout change that would resize
; the arena fails the fixture rather than silently under-allocating it.
;
; IT LOGS ONLY ON FAILURE -- see the apple/fgx#94 note on mod_init.
;
; ON FAILURE IT DOES NOT CALL vfs_init AT ALL.  _Vfs_BufInit can afford to
; carry on; here the pool POINTERS would be left null, and initialising through
; them is what would scribble bank zero.  Not calling leaves them null and
; unused, which is inert.  The module still reports a successful LOAD either
; way: a half-brought-up VFS with nothing mounted on it is not a reason to roll
; back a module image the loader has already placed.
;------------------------------------------------------------------------------
_Vfs_PoolInit   MX      %00
                LDA     #VFS_POOL_BYTES
                LDY     #M_KERN
                LDX     #KSVC_KMALLOC
                JSL     SYS_KCALL
                BCC     @vpi_fail
                STA    |_vfsPoolOff
                PHX
                PLA
                AND     #$00FF
                STA    |_vfsPoolBank
                ; Bank-straddle check, for the reason _Vfs_BufInit spells out:
                ; the C derives every pool entry as base + i*sizeof with a
                ; 16-bit add and no carry into the bank.
                LDA    |_vfsPoolOff
                CLC
                ADC     #VFS_POOL_BYTES-1
                BCS     @vpi_fail

                LDX    |_vfsPoolOff
                LDY    |_vfsPoolBank

                MOD_KC_ENTER
                SEP     #$20
                MX      %10
                LDA     #0
                PHA                     ; pad byte
                TYA                     ; bank
                PHA
                REP     #$30
                MX      %00
                TXA                     ; offset
                PHA
                PHK
                PEA     @vpi_ret-1
                JMP     vfs_init
@vpi_ret        PLA
                PLA
                MOD_KC_LEAVE
                RTS

@vpi_fail       LDA     #@vpi_bad
                LDX     #KSVC_LOGSTRNE
                JSL     SYS_KCALL
                LDX     #KSVC_LOGEOL
                JSL     SYS_KCALL
                RTS

@vpi_bad        ASC     'vfs: POOL ALLOC FAILED - vnode layer disabled',$00



;------------------------------------------------------------------------------
; The device scan and probe driver, SHARED with ufs.mod (src/modules/common).
; This module supplies the identity; the driver supplies the ~200 lines of
; device-selection history.  See that file's header.
;------------------------------------------------------------------------------
                DO      VFSPROBE=1
PROBE_ENTRY     EQU     vfs_probe
PROBE_MSGOK     ASC     'vfs: cache wiring ok',$00
PROBE_MSGBAD    ASC     'vfs: CACHE WIRING BROKEN, case ',$00
PROBE_MSGSKIP   ASC     'vfs: no scratch disk, wiring probe skipped',$00
                PUT     ../common/probe_dev.s
                FIN


;------------------------------------------------------------------------------
; The C, and the runtime it cannot run without.
;
; fcc_dp.s, fcc_rt.s and fcc_ktrap.s are BANK-AGNOSTIC and shared verbatim with
; the far bank -- no second copy of signed division.  fcc_runtime_data.s is the
; exception and must be understood: it is DA-declared storage the helpers reach
; DBR-relatively, so it has to live in the bank the C runs with, which under
; MOD_KC_ENTER is THIS module's.
;
; PUT ORDER mirrors far.s and for its reasons: bio_strategy after vfs_bio so
; its calls into biodone resolve backwards, and dead_vnops + spec_vnops before
; vfs_subr, which names both their ops vectors.
;------------------------------------------------------------------------------
; M_* arena accounting types, PUT rather than copied.  net.mod carries its own
; `M_KERN EQU 6` with a "keep in step" comment; far.s PUTs this file instead,
; for the stated reason that a copied constant is how arena IDs drift apart
; silently.  It costs ~60 B of duplicated name strings in a bank with 29 KB
; free.  MUST stay after the header -- it emits data.
                PUT     ../../kernel/libc/alloc_state.s

                PUT     ../../kernel/far/fcc_dp.s       ; fcc register file (EQU only)
                PUT     ../../kernel/far/fcc_rt.s       ; pure-computation half
                PUT     ../../kernel/far/fcc_ktrap.s    ; stack/soft-frame traps
                PUT     ../../../toolchain/lib/fcc_runtime_data.s

                PUT     ../../kernel/vfs/vfs_bio.s
                PUT     ../../kernel/vfs/vfs_bio.data.s
                PUT     ../../kernel/vfs/bio_strategy.s
                PUT     ../../kernel/vfs/bio_strategy.data.s
                PUT     ../../kernel/vfs/dead_vnops.s
                PUT     ../../kernel/vfs/dead_vnops.data.s
                ; THE NAME CACHE IS NOT IN THIS BANK.  It is ufsdir.mod's, with
                ; ufs_lookup.c -- the only thing that calls cache_lookup and
                ; cache_enter, and the reason the cache could be wired at all:
                ; this bank had 94 bytes free.  vfs_subr.c reaches the two rare
                ; entries, cache_purge and cache_purgevfs, through pointers
                ; ufs_dirinit hands over.
                PUT     ../../kernel/vfs/vfs_subr.s
                PUT     ../../kernel/vfs/vfs_subr.data.s
                ; The raw-disk-to-block mapping, GENERATED by tools/ninja/gen.py
                ; from the lists that mknod the nodes onto the root.  Here
                ; because spec_securechr in vfs_subr.c is its only caller.
                PUT     ../../kernel/vfs/dev_chrtoblk.s
                PUT     ../../kernel/vfs/dev_chrtoblk.data.s
                ; The open-file table (UFS 1.2c).  NOT gated: the table is the
                ; deliverable and vfs_init carves it on every boot.
                ; uiomove (UFS 1.7a).  Not gated: it is a deliverable, and
                ; spec_read/spec_write are built on it at 1.7b.
                PUT     ../../kernel/vfs/kern_subr.s
                PUT     ../../kernel/vfs/kern_subr.data.s
                ; THE UFS CODE LEFT AT apple/fgx#169.  ufs_vfsops, ufs_alloc
                ; and ufs_probe are src/modules/ufs now -- this bank could not
                ; hold them and the path-walk probe at the same time.  What is
                ; left behind is the VT_VFSCORE table near the top of this file,
                ; which is how they still reach the buffer cache.
                ; The composition root, AFTER every pool it chains: it is the
                ; only caller of vntblinit and ndinit, and keeping it in a file
                ; of its own is what stops a fixture that wants one pool from
                ; linking all of them.  See vfs_init.c.
                PUT     ../../kernel/vfs/vfs_init.s
                PUT     ../../kernel/vfs/vfs_init.data.s
                ; namei/lookup AFTER vfs_subr: it calls vref and vrele, and
                ; resolving backwards keeps the listing readable.  NOT gated on
                ; VFSPROBE -- the walk is the deliverable; only the probes that
                ; exercise it are conditional.
                PUT     ../../kernel/vfs/vfs_lookup.s
                PUT     ../../kernel/vfs/vfs_lookup.data.s
                ; The file/vnode glue (UFS 1.7c).  AFTER vfs_lookup for the
                ; same readability reason: vn_open's first act is a namei.
                ; Not gated -- it is the deliverable, and it is what 1.7d's
                ; syscall layer will call.
                PUT     ../../kernel/vfs/vfs_vnops.s
                PUT     ../../kernel/vfs/vfs_vnops.data.s
                ; The syscall BODIES (UFS 1.7d).  AFTER vfs_vnops for the same
                ; reason vfs_vnops is after vfs_lookup: this is what calls it,
                ; and it dereferences `vnops` out of the .data.s above.  Not
                ; gated -- the syscall LAYER is still absent (see the file's
                ; head), but these are shipping code, not probe code.
                DO      VFSPROBE=1
                PUT     ../../kernel/vfs/vfs_probe.s
                PUT     ../../kernel/vfs/vfs_probe.data.s
                FIN
                ; The filesystem probe (1.10a superblock + 1.10b allocators).
                ; Its own gate since 1.10b: the allocators cost ~5.9 KB of
                ; SHIPPING code out of this same bank, and vfsprobe=1 had 410
                ; bytes free before this file was assembled.  See
                ; cfg/system.cfg.  It shares vfsprobe's DEVICE SCAN below
                ; rather than duplicating it -- the two gates are alternatives,
                ; so one driver serves whichever is set.
                ; The &function bank-patch table, PUT LAST so that adding it
                ; cannot move the cells it describes -- see
                ; tools/gen_mod_bankpatch.py on why that makes one
                ; regeneration converge.
                PUT     fnptr_patchsites.s

vfs_end         EQU     *

; Placement guards (tools/gen_modplace.py writes MODP_* into modplace.s).
; Merlin's ERR fires on a NON-ZERO expression; strictly left to right.
                ERR     vfs_hdr-MODP_ORG
                ERR     vfs_end-MODP_ORG+vfs_bss/MODP_LIMIT
; ...and one this module needs that the others do not: the header's entry field
; is bank-relative against a LITERAL $060000, so the ordinal must still be $06.
; Divided rather than `^MODP_ORG`: Merlin's bank-byte operator is an OPERAND
; prefix, and inside an expression it is silently ignored -- the first cut of
; this guard read '^{$060000}-$06' as $5FFFA and failed a correct build.
                ERR     MODP_ORG/$10000-$06
