;==============================================================================
; ufs.s - the assembly root of ufs.mod: the 2.11BSD FILESYSTEM, compiled from
; C, in a loadable FGXM module of its own.
;
; WHY IT IS NOT IN vfs.mod, WHICH IS WHERE IT STARTED.  UFS 1.10b's allocators
; cost 5,770 bytes of shipping code and vfs.mod is one 64 KB bank; with them
; linked the shipping side stood at 54,893 of 65,536, and the probe gated
; beside it stopped assembling.  1.10c (bmap) and
; 1.11 (the read path) add to the same bank.  apple/fgx#169 carries the
; per-gate measurements; this module is the answer.
;
; ITS OWN BANK ORDINAL, NOT THE SHARED ONE.  gen_modplace.py's OWN_BANK comment
; made the argument before this module existed: "a module that outgrows its
; bank mid-campaign is a rebuild of every module placed after it.  Decided
; BEFORE it is wired rather than after it overflows."  1.11-1.13 is the read
; path, the write path and directory ops, so the shared bank would be crowded
; out and then overflow anyway.
;
; THE C IS UNCHANGED AND IS NOT COPIED.  ufs_vfsops.c, ufs_alloc.c and
; ufs_probe.c are the same files, from the same `kernelc` ninja edges, moved
; from one module's PUT list to another's.  That is the whole of the port --
; the same claim far.s made about promoting a subsystem out of the far bank,
; now made a second time about promoting one out of a module.
;
; WHAT IS GENUINELY NEW IS THE SEAM.  This is the first module that calls
; ANOTHER MODULE: the UFS code needs vfs.mod's buffer cache, and until now no
; FGXM module has reached sideways.  vfs_import.s is that seam and carries the
; argument; src/modules/vfs/vfs.s's VT_VFSCORE table is the other half.
;
; MODBANK-C-OK: every global, literal and runtime scratch this module's C
; touches is read DBR-relatively, which is correct here for the same reason it
; is in vfs.mod -- the C is only ever entered through MOD_KC_ENTER, or through
; a vfs_import.s shim that establishes the same thing.  The waiver is at MODULE
; level because both the accesses and the declarations live in fcc OUTPUT.
;==============================================================================

                MX      %11
                PUT     modplace.s
                ORG     MODP_ORG

                PUT     ../../../include/config.s       ; CFG_* build gates
                PUT     ../../../include/macros.s       ; FGX2_MODE/EXPORT/RELOC
                PUT     ../../../include/kernel.s       ; FGX_DP_KERNELC
                PUT     ../../../include/dpmap.s        ; DUM $00: the block
                                                        ;   layer's DP cells,
                                                        ;   which kc_blkio writes
                PUT     ../../../include/modules.s      ; SYS_KCALL, KSVC_*,
                                                        ;   VT_VFSCORE, VFSCORE_*
                PUT     ../../../include/kernelc.s      ; MOD_KC_ENTER/LEAVE
                PUT     ../../../include/fs.s           ; DEV_* record layout,
                                                        ;   for the probe driver's
                                                        ;   device scan
                PUT     ../../../include/vfs_equ.s      ; GENERATED from the C
                                                        ;   headers

;------------------------------------------------------------------------------
; FGXM header v2 (40 bytes).
;------------------------------------------------------------------------------
ufs_bss         EQU     0

ufs_hdr         ASC     'FGXM'                          ; +0  magic
                DFB     <MODP_ORG                       ; +4  load lo
                DFB     >MODP_ORG                       ; +5  load mid
                DFB     ^MODP_ORG                       ; +6  load hi -- the
                                                        ;     bank ORDINAL, $07
                DFB     $02                             ; +7  header format v2
                ; Entry, BANK-relative.  The subtrahend is the ordinal's base.
                ; The ERR at the foot of this file keeps it honest if
                ; gen_modplace.py's OWN_BANK ever moves this module.
                DA      mod_init-$070000                ; +8  entry, bank-rel
                DA      ufs_end-ufs_text                ; +10 text bytes
                DA      ufs_bss                         ; +12 bss bytes
                DA      ufs_vtdir-ufs_text              ; +14 vtdir offset
ufs_name        ASC     'ufs'                           ; +16 module name
                DS      16-*+ufs_name                   ;     NUL-pad to 16
                DA      $0000                           ; +32 module version
                ; +34 build identity.  $0000 = not build-locked: this module
                ; bakes no kernel addresses.  It bakes no VFS ones either -- the
                ; six it needs are resolved at load time through a vtable, which
                ; is the entire point of doing it that way.
                DA      $0000
                DS      4                               ; +36 reserved

ufs_text        EQU     *

;------------------------------------------------------------------------------
; VTDR: VT_UFSCORE since UFS 1.12c, and the note that used to be here -- "this
; module EXPORTS nothing yet, it is a consumer of vfs.mod, not a provider" --
; stopped being true from a direction it did not anticipate.  Not the kernel
; and not mount(2): the PROBES.
;
; ufs.mod's shipping code reached 50,992 bytes of a 64 KB bank at 1.12c and two
; of its three probe gates stopped fitting beside it.  Splitting a gate again
; would have bought one increment; the probes moved to their own bank instead
; and reach back through this table.  mount(2) does not use it: ufs_init hands
; this module's vfsops to vfs.mod's vfssw[] instead.
;------------------------------------------------------------------------------
ufs_vtdir       ASC     'VTDR'
                DA      VT_UFSCORE
                DA      ufscore_ops-ufs_text    ; text-relative; the loader makes
                                                ;   it bank-relative (modload.s)
                DA      VT_END

;------------------------------------------------------------------------------
; ufscore_ops - the exported entry points, in UFSCORE_* order.
;
; PLAIN 16-BIT ADDRESSES and fcc's calling convention, both for the reasons
; vfs.mod's vfscore_ops states at length: the bank comes from Mod_FindVtable
; alongside the table, and repeating it here would be a second copy of one
; fact.  The caller must set DBR to THIS module's bank before entering, which
; src/modules/ufsprobe/ufs_import.s does and which apple/fgx#93 is the cost of
; forgetting.
;------------------------------------------------------------------------------
ufscore_ops     DA      iget                    ; UFSCORE_Iget
                DA      iput                    ; UFSCORE_Iput
                DA      ufs_balloc              ; UFSCORE_Balloc
                DA      ufs_bfree               ; UFSCORE_Bfree
                DA      ufs_bmap                ; UFSCORE_Bmap
                DA      ufs_dget32              ; UFSCORE_Dget32
                DA      ufs_ialloc              ; UFSCORE_Ialloc
                DA      ufs_ifind               ; UFSCORE_Ifind
                DA      ufs_ifree               ; UFSCORE_Ifree
                DA      ufs_itrunc              ; UFSCORE_Itrunc
                DA      ufs_mountfs             ; UFSCORE_Mountfs
                DA      ufs_sbdecode            ; UFSCORE_Sbdecode
                DA      ufs_sbencode            ; UFSCORE_Sbencode
                DA      ufs_sbread              ; UFSCORE_Sbread
                DA      ufs_sbupdate            ; UFSCORE_Sbupdate
                DA      ufs_sbvalid             ; UFSCORE_Sbvalid
                DA      kern_time               ; UFSCORE_KernTime
                DA      clrbuf                  ; UFSCORE_Clrbuf
                DA      iupdat                  ; UFSCORE_Iupdat
                DA      ufs_bmapx               ; UFSCORE_Bmapx
                DA      ufs_ifmttovt            ; UFSCORE_Ifmttovt
                DA      ufs_itimes              ; UFSCORE_Itimes
                DA      ufs_setvnodeops         ; UFSCORE_Setvnodeops
                DA      ufs_reclaim             ; UFSCORE_Reclaim
                ; The device number of a special file, and the second ops
                ; table -- UFS 1.13a.  include/modules.s carries the argument.
                DA      ufs_getrdev             ; UFSCORE_Getrdev
                DA      ufs_setrdev             ; UFSCORE_Setrdev
                DA      ufs_setspecops          ; UFSCORE_Setspecops
                ; UFS 1.8b-2: the entry mount(2) calls.
                DA      ufs_mount               ; UFSCORE_Mount
                DA      ufs_fsyncvp             ; UFSCORE_Fsync
                DA      vn_flock                ; UFSCORE_VnFlock
                DA      vn_unlock               ; UFSCORE_VnUnlock
                DA      vn_fsetattr             ; UFSCORE_VnFsetattr
                ; The table and the offsets that index it must agree.  The
                ; braces are load-bearing: Merlin evaluates strictly left to
                ; right with NO OPERATOR PRECEDENCE, which vfs.s records having
                ; measured.
                ERR     *-ufscore_ops-{UFSCORE_COUNT*2}

;------------------------------------------------------------------------------
; The C-to-kernel seam, SHARED with vfs.mod.  BEFORE mod_init: it defines the
; ENTERK/LEAVEK macros, and Merlin needs a MAC defined before its first use.
;------------------------------------------------------------------------------
                PUT     ../common/kc_sys.s

;------------------------------------------------------------------------------
; The module-to-module seam.  Also before mod_init -- it defines the VFSCALL
; macro and the storage _Ufs_ResolveVfs fills.
;------------------------------------------------------------------------------
                PUT     vfs_import.s

;==============================================================================
; mod_init - resolve vfs.mod, then run the probe if it is gated in.
;
; MUCH SMALLER THAN vfs.mod's, and the difference says what this module is.
; vfs.mod's mod_init carves two heap arenas and brings up four pools, because
; it owns storage.  This one owns none: the buffers, vnodes and name cache all
; belong to vfs.mod, and the UFS code reaches them through six function
; pointers.  All that is left is to find them.
;
; DBR IS OURS FOR THE WHOLE ROUTINE.  A module is entered with DBR = the kernel
; bank, and everything below wants this one: _ufsVfsBank, _ufsImp
; and the log strings are all here.

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
                JSR     _Ufs_ResolveVfs
                BCC     @mi_novfs       ; no vfs.mod: run NO C at all

                ; The filesystem's own one-time init -- the inode hash.  It is
                ; ufs_vfsops's vfs_init slot, called directly rather than
                ; through the vector because there is no mount yet to dispatch
                ; from; Reno calls each type's vfs_init at boot for the same
                ; reason.
                MOD_KC_ENTER
                PHK
                PEA     @mi_initret-1
                JMP     ufs_init
                ; THE LABEL GETS ITS OWN LINE.  tools/check_kc_dbr.py matches
                ; MOD_KC_LEAVE only at the start of a line, so
                ; `@mi_initret MOD_KC_LEAVE' leaves the bracket OPEN as far as
                ; the checker is concerned -- and it then reports every
                ; module-local read in the rest of the file as a DBR error,
                ; which is a long way from the cause.
@mi_initret     ANOP
                MOD_KC_LEAVE

@mi_out         PLB
                PLP
                SEC                     ; LOAD succeeded either way -- see below
                RTL

;------------------------------------------------------------------------------
; A MISSING vfs.mod IS A LOAD-ORDER PROBLEM AND IT SAYS SO, LOUDLY.
;
; It reports a successful LOAD, on the same reasoning vfs.mod's failed pool
; does: the image is placed and inert, and rolling it back helps nobody.  What
; it must NOT do is carry on into the C.  Every shim in vfs_import.s reads its
; target out of _ufsImp, which is still zero, so the first bread would pile-call
; bank 0 offset $FFFF and the machine would come apart a long way from the
; cause.
;
; The fix is /etc/modload.conf ordering -- vfs before ufs -- so the message
; names that rather than the symptom.
;------------------------------------------------------------------------------
@mi_novfs       LDA     #@mi_msgNoVfs
                LDX     #KSVC_LOGSTRNE
                JSL     SYS_KCALL
                LDX     #KSVC_LOGEOL
                JSL     SYS_KCALL
                BRA     @mi_out

@mi_msgNoVfs    ASC     'ufs: vfs.mod not loaded - load it first (modload.conf)',$00

;==============================================================================
; _Ufs_ResolveVfs - find vfs.mod's VT_VFSCORE table and copy it in.
;
; ONCE, HERE, AND NEVER AGAIN.  Mod_FindVtable is a linear walk of the module
; registry, and this module's hot path is every block read; resolving per call
; would put that walk under the filesystem.
;
; WHAT COMES BACK is the table's BANK-RELATIVE address and its bank -- the
; loader converts the module's text-relative VTDR offset for exactly this
; (modload.s), so nothing here has to know where vfs.mod was placed or how big
; its header is.  The six entries inside the table are bank-relative already,
; because a label in a module IS its bank-relative address and the placement
; guards at the foot of both files enforce that.
;
; In:  nothing.  MX %00.  DBR = ours.
; Out: C=1 + _ufsVfsBank and _ufsImp populated; C=0 if vfs.mod is not loaded.
;==============================================================================
_Ufs_ResolveVfs MX      %00
                LDA     #VT_VFSCORE
                LDX     #KSVC_FINDVTABLE
                JSL     SYS_KCALL
                BCS     @rv_have
                RTS                             ; C=0 already
@rv_have        ; A = the table's bank-relative address, X.lo = its bank.
                TAY                             ; park the table address
                TXA
                AND     #$00FF
                STA     |_ufsVfsBank    ; MODBANK-OK: DBR = ours (mod_init set it)
                TYX                             ; X = table address

                ; THE TABLE IS IN vfs.mod's BANK AND THE DESTINATION IS IN OURS,
                ; so the copy cannot be one loop.  Read the six entries with DBR
                ; on vfs.mod and STACK them; put our own DBR back; unstack them
                ; into _ufsImp.  Twelve bytes of stack, no direct page, and no
                ; long pointer -- a module has no direct page of its own to put
                ; one in, and LDAL would bake a bank at assembly time, which is
                ; the trap that has cost this tree two sessions.
                ; ONE ENTRY AT A TIME, NOT A STACK ROUND TRIP -- apple/fgx#194.
                ; This loop used to read the WHOLE table with DBR on vfs.mod,
                ; PUSHING every entry, then pop them back into the import table.
                ; Its stack cost was 2 BYTES PER EXPORT, live across the DBR
                ; switch, inside the boot chain src/kernel/main.s:341 measures
                ; at 437 bytes.  That was fine for the six entries the comment
                ; here used to describe, and it had become a CLIFF: measured
                ; 2026-08-21, VFSCORE_COUNT 34 booted and 35 wedged the machine
                ; with no output at all -- no panic, no verdict, nothing.
                ;
                ; A IS THE ONLY THING THAT MUST SURVIVE THE SWITCH BACK, and it
                ; does: PHK/PLB touches no register.  So each entry is read with
                ; DBR on vfs.mod, carried in A, and stored with DBR on ours, and
                ; the stack cost is ONE TRANSIENT BYTE however big the table
                ; grows.  X walks the source, Y the destination.
                ;
                ; THE BANK BYTE IS RE-READ EVERY ITERATION because it lives in
                ; OUR bank and can only be read while DBR is ours -- which is
                ; exactly the top of the loop.  Hoisting it would want a
                ; register none of the three has spare.
                ;
                ; `|` IS STILL LOAD-BEARING on both operands.  Without it Merlin
                ; sees a $0000 operand, shortens the address mode and emits the
                ; DIRECT PAGE form, so the loop would read fcc's register file
                ; instead of the table.  It does not warn: the instruction is
                ; legal and the values that come back are plausible 16-bit
                ; numbers.
                REP     #$30
                MX      %00
                LDY     #0
@rv_L          SEP     #$20
                MX      %10
                LDA     |_ufsVfsBank        ; MODBANK-OK: DBR is ours here
                PHA
                PLB                             ; DBR = vfs.mod
                REP     #$20
                MX      %00
                LDA     |$0000,X                ; the entry, from vfs.mod
                PHK
                PLB                             ; DBR ours again -- A survives
                STA     |_ufsImp,Y       ; MODBANK-OK: DBR = ours
                INX
                INX
                INY
                INY
                CPY     #VFSCORE_COUNT*2
                BNE     @rv_L
                SEC
                RTS


;------------------------------------------------------------------------------
; The device scan and probe driver moved to ufsprobe.mod at 1.12c, with the
; probes it drives.
;------------------------------------------------------------------------------

;------------------------------------------------------------------------------
; The C, and the runtime it cannot run without.  The same fcc runtime vfs.mod
; carries -- bank-agnostic and shared verbatim with the far bank -- plus this
; module's own copy of fcc_runtime_data.s, which is DA-declared storage the
; helpers reach DBR-relatively and therefore must exist in EVERY bank that runs
; fcc output.
;------------------------------------------------------------------------------
                PUT     ../../kernel/libc/alloc_state.s
                PUT     ../../kernel/far/fcc_dp.s       ; fcc register file (EQU)
                PUT     ../../kernel/far/fcc_rt.s       ; pure-computation half
                PUT     ../../kernel/far/fcc_ktrap.s    ; stack/soft-frame traps
                PUT     ../../../toolchain/lib/fcc_runtime_data.s

                ; The superblock reader (1.10a) and the allocators (1.10b).
                ; ufs_alloc AFTER ufs_vfsops because it calls that file's
                ; codec, and resolving forwards keeps the listing readable.
                ; The byte-order codec FIRST: every other file here asks it for
                ; an on-disk integer.  Split from ufs_vfsops at 1.11a so the
                ; host fixture that #includes it stops inheriting the mount.
                ; THE CLOCK FIRST, because ufs_vfsops and ufs_inode both call
                ; it and Merlin wants the label defined before `PEA label-1`.
                ; It is kernel support rather than UFS; kern_time.c says why it
                ; is in this module's bank and not vfs.mod's (apple/fgx#167).
                PUT     ../../kernel/vfs/kern_time.s
                PUT     ../../kernel/vfs/kern_time.data.s
                ; flock(2)'s locks: kernel support in this bank for kern_time's
                ; reason, vfs.mod being full.  kern_flock.c says so.
                PUT     ../../kernel/vfs/kern_flock.s
                PUT     ../../kernel/vfs/kern_flock.data.s
                ; fchmod(2)'s and fchown(2)'s vnode half, for the same reason.
                PUT     ../../kernel/vfs/kern_fsetattr.s
                PUT     ../../kernel/vfs/kern_fsetattr.data.s
                PUT     ../../kernel/vfs/ufs_sb.s
                PUT     ../../kernel/vfs/ufs_sb.data.s
                ; The on-disk INODE codec, split out of ufs_inode at 2.1 so
                ; src/userland/fsck can compile the same field list rather
                ; than carry a second copy.  Here rather than beside its
                ; caller because it asks ufs_sb.s for the byte order, and
                ; ufs_inode.s below asks IT -- so the order is the dependency.
                PUT     ../../kernel/vfs/ufs_dinode.s
                PUT     ../../kernel/vfs/ufs_dinode.data.s
                PUT     ../../kernel/vfs/ufs_vfsops.s
                PUT     ../../kernel/vfs/ufs_vfsops.data.s
                PUT     ../../kernel/vfs/ufs_alloc.s
                PUT     ../../kernel/vfs/ufs_alloc.data.s
                ; bmap (1.10c), AFTER ufs_vfsops: it calls that file's
                ; ufs_dget32, which is where the byte order is defined.
                PUT     ../../kernel/vfs/ufs_bmap.s
                PUT     ../../kernel/vfs/ufs_bmap.data.s
                ; The vnode ops vector BEFORE ufs_inode: iget names it when it
                ; mints a vnode, and resolving forwards keeps the listing
                ; readable (the same reasoning).

                ; The name lookup (1.11c), AFTER ufs_vnops so the vector can
                ; name it and AFTER ufs_inode is declared: it calls iget.

                PUT     ../../kernel/vfs/ufs_inode.s
                PUT     ../../kernel/vfs/ufs_inode.data.s
                ; THE PROBES LEFT THIS MODULE AT 1.12c.  They are
                ; ufsprobe.mod now, in a bank of their own, reaching back into
                ; this one through the VT_UFSCORE table above.  ufs.mod's
                ; shipping code had reached 50,992 bytes of the bank and two of
                ; the three gates no longer fitted beside it; src/modules/
                ; ufsprobe/ufsprobe.s carries the measurements.
                ; The &function bank-patch table, PUT LAST so that adding it
                ; cannot move the cells it describes -- see
                ; tools/gen_mod_bankpatch.py on why that makes one
                ; regeneration converge.
                PUT     fnptr_patchsites.s

ufs_end         EQU     *

; Placement guards (tools/gen_modplace.py writes MODP_* into modplace.s).
; Merlin's ERR fires on a NON-ZERO expression; strictly left to right.
                ERR     ufs_hdr-MODP_ORG
                ERR     ufs_end-MODP_ORG+ufs_bss/MODP_LIMIT
; ...and the ordinal, for the same reason vfs.s guards its own: the header's
; entry field is bank-relative against a LITERAL $070000.  Divided rather than
; `^MODP_ORG`, because Merlin's bank-byte operator is an OPERAND prefix and is
; silently ignored inside an expression.
                ERR     MODP_ORG/$10000-$07
