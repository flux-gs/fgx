;==============================================================================
; ufsdir.s - the assembly root of ufsdir.mod: the NAME half of the filesystem.
;
; WHY UFS IS TWO MODULES.
;
; ufs.mod is one 65,536-byte bank and its SHIPPING code reached 60,211 of them
; at UFS 1.12c -- 5,325 free, with 1.13 (mknod) and 2.6 (credentials) still
; ahead, and 1.12c alone having cost 9,215.  The escape used at 1.12c was to
; move the PROBES out; that bank is spent, and shipping code cannot go there
; because the probes need it whenever a gate is on.
;
; So the filesystem's own two halves separated:
;
;       ufs.mod      the BLOCK layer -- inodes, the superblock, the block and
;                    inode allocators, bmap, the mount.
;       this module  the NAME layer -- the vnode operations and the directory
;                    scan.
;
; THE SEAM WAS MEASURED, NOT CHOSEN BY SUBJECT.  Every pile call between the
; eight translation units was counted: 42 call sites cross from the name half
; into the block half, through 11 entry points, and -- after clrbuf moved to
; ufs_bmap.c beside its heaviest callers, and iget stopped naming the vnodeops
; table directly -- ZERO cross the other way.  No other division of these files
; comes close, and a seam with a one-way dependency is one where the shims can
; all live on one side.
;
; THE PROBES ARE UNAFFECTED.  ufsprobe.mod reaches the name half only through
; VOP_ vectors, whose entries carry the callee's bank since apple/fgx#178, and
; every one of VT_UFSCORE's original seventeen entries is a block-half
; function.  Measured, not assumed: no probe names a name-half symbol.
;
; MODBANK-C-OK: every global, literal and runtime scratch this module's C
; touches is read DBR-relatively, which is correct here for the same reason it
; is in ufs.mod -- the C is only ever entered through MOD_KC_ENTER, or through
; an import shim that establishes the same thing.
;==============================================================================

                MX      %11
                PUT     modplace.s
                ORG     MODP_ORG

                PUT     ../../../include/config.s       ; CFG_* build gates
                PUT     ../../../include/macros.s       ; FGX2_MODE/EXPORT/RELOC
                PUT     ../../../include/kernel.s       ; FGX_DP_KERNELC
                PUT     ../../../include/dpmap.s        ; DUM $00: the block
                                                        ;   layer's DP cells
                PUT     ../../../include/modules.s      ; SYS_KCALL, KSVC_*,
                                                        ;   VT_UFSCORE, UFSCORE_*
                PUT     ../../../include/kernelc.s      ; MOD_KC_ENTER/LEAVE
                PUT     ../../../include/fs.s           ; DEV_* record layout
                PUT     ../../../include/errno.s        ; ENODEV, for kc_chardev.s
                PUT     ../../../include/chardev.s      ; CHARDEV_MAX, for the
                                                ;   same file -- both came with
                                                ;   kc_chardev.s from vfs.mod
                PUT     ../../../include/vfs_equ.s      ; GENERATED from the C
                                                        ;   headers

;------------------------------------------------------------------------------
; FGXM header v2 (40 bytes).
;------------------------------------------------------------------------------
ud_bss          EQU     0

ud_hdr          ASC     'FGXM'                          ; +0  magic
                DFB     <MODP_ORG                       ; +4  load lo
                DFB     >MODP_ORG                       ; +5  load mid
                DFB     ^MODP_ORG                       ; +6  load hi -- the
                                                        ;     bank ORDINAL, $09
                DFB     $02                             ; +7  header format v2
                ; Entry, BANK-relative.  The subtrahend is the ordinal's base;
                ; the ERR at the foot of this file keeps it honest if
                ; gen_modplace.py's OWN_BANK ever moves this module.
                DA      mod_init-$090000                ; +8  entry, bank-rel
                DA      ud_end-ud_text                  ; +10 text bytes
                DA      ud_bss                          ; +12 bss bytes
                DA      ud_vtdir-ud_text                ; +14 vtdir offset
ud_name         ASC     'ufsdir'                        ; +16 module name
                DS      16-*+ud_name                    ;     NUL-pad to 16
                DA      $0000                           ; +32 module version
                ; +34 build identity.  $0000 = not build-locked: this module
                ; bakes no kernel addresses, and the ones it needs from vfs.mod
                ; and ufs.mod are resolved at load time through vtables.
                DA      $0000
                DS      4                               ; +36 reserved

ud_text         EQU     *

;------------------------------------------------------------------------------
; VTDR: EMPTY, AND THAT IS THE POINT OF THE SEAM.  Nothing calls into this
; module by name.  The block half reaches its one piece of state -- the
; vnodeops table -- because mod_init HANDS IT OVER, and every other entry into
; the name half is a VOP_ dispatch through that table, whose cells carry this
; module's bank from _Mod_StampFnPtrs.
;------------------------------------------------------------------------------
ud_vtdir        ASC     'VTDR'
                DA      VT_END

;------------------------------------------------------------------------------
; The C-to-kernel seam, SHARED with vfs.mod, ufs.mod and ufsprobe.mod.  BEFORE
; mod_init: it defines the ENTERK/LEAVEK macros, and Merlin needs a MAC defined
; before the line that uses one.
;------------------------------------------------------------------------------
                PUT     ../common/kc_sys.s

;--- cdevsw's bulk chardev ops, WITH spec_vnops.c since 2026-09-05.  It was
;--- vfs.mod's on the same rule that puts it here now: not ../common/kc_sys.s's,
;--- which every module PUTs, because only this module's C calls these.
                PUT     kc_chardev.s

                PUT     ufs_import.s
                PUT     vfs_import.s

;==============================================================================
; mod_init - resolve BOTH modules, then hand over the ops table.
;
; TWO RESOLVERS, NOT ONE, and the two failures differ: a name layer that cannot
; reach ufs.mod has no inodes to name, and one that cannot reach vfs.mod cannot
; read a directory block.  Each says which module is missing, because the fix
; in both cases is a line in /etc/modload.conf.
;
; THE DP CAPTURE MUST BE FIRST, exactly as in the other three modules -- every
; kc_sys shim needs the kernel's real direct page, and mod_init is the only
; moment it is free, because the loader calls us with D already set to it.
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
                ; The vnodeops table is entirely such cells, and it is the one
                ; thing this module exists to hand over.
                JSR     _Mod_StampFnPtrs
                JSR     _Ud_ResolveVfs
                BCC     @mi_novfs       ; no vfs.mod: run NO C at all
                JSR     _Ud_ResolveUfs
                BCC     @mi_noufs       ; no ufs.mod: likewise

                ; THE NAME CACHE'S ARENA, FIRST.  ufs_dirinit hands vfs.mod a
                ; table whose cells reach cache_purge, and vfs.mod may call it
                ; on the very next vnode handout -- so the buckets have to be
                ; built before the handover, not after it.
                JSR     _Ud_CacheInit

                ; THE HANDOVER.  iget refuses to mint a vnode until this has
                ; run, so it is the first C in the module that anything outside
                ; can reach.
                MOD_KC_ENTER
                PHK
                PEA     @mi_initret-1
                JMP     ufs_dirinit
                ; THE LABEL GETS ITS OWN LINE -- tools/check_kc_dbr.py matches
                ; MOD_KC_LEAVE only at the start of a line, and a label sharing
                ; the line leaves the bracket open as far as the checker is
                ; concerned.
@mi_initret     ANOP
                MOD_KC_LEAVE

@mi_out         PLB
                PLP
                SEC                     ; LOAD succeeded either way -- see below
                RTL

;------------------------------------------------------------------------------
; A MISSING MODULE IS A LOAD-ORDER PROBLEM AND IT SAYS SO, LOUDLY.
;
; It reports a successful LOAD, on the same reasoning ufs.mod's does: the image
; is placed and inert, and rolling it back helps nobody.  What it must NOT do is
; carry on into the C -- every shim reads its target out of a table that is
; still zero, so the first call would pile-call bank 0 offset $FFFF and the
; machine would come apart a long way from the cause.  And because the handover
; never ran, iget refuses to mint a vnode, so the filesystem is absent rather
; than half-present.
;------------------------------------------------------------------------------
@mi_novfs       LDA     #@mi_msgNoVfs
                BRA     @mi_say
@mi_noufs       LDA     #@mi_msgNoUfs
@mi_say         LDX     #KSVC_LOGSTRNE
                JSL     SYS_KCALL
                LDX     #KSVC_LOGEOL
                JSL     SYS_KCALL
                BRA     @mi_out

@mi_msgNoVfs    ASC     'ufsdir: vfs.mod not loaded - load it first (modload.conf)',$00
@mi_msgNoUfs    ASC     'ufsdir: ufs.mod not loaded - load it first (modload.conf)',$00

;==============================================================================
; _Ud_CacheInit - allocate the name cache's arena and build its chains.
;
; THE CACHE CARVES ITS OWN, and that is the whole reason this routine exists.
; nchinit was the middle link of vfs.mod's `ndinit(nchinit(vntblinit(arena)))'
; while the cache lived in that bank; it moved here with vfs_cache.c, beside
; the ufs_lookup.c that is its only hot-path caller, and a carve cannot be
; split across two banks -- the pointer that walks it is DBR-relative.  So the
; chain lost a link at that end and this module Kmallocs its own base.
;
; _Vfs_PoolInit IS THE MODEL, line for line, including why:
;
;   NC_POOL_BYTES is GENERATED (include/vfs_equ.s) from the C headers, so
;   there is no second copy of the size to disagree with nchinit's loop.
;
;   THE ARENA MUST NOT STRADDLE A BANK BOUNDARY.  nchinit derives every entry
;   as base + i*sizeof(struct namecache) with a 16-bit add and no carry into
;   the bank, so a base near the top of one would wrap its later entries back
;   to the bottom.  Kmalloc satisfies this by construction; the check says so
;   rather than trusting it silently.
;
;   ON FAILURE IT STILL CALLS nchinit, WITH A NULL BASE, and that is the one
;   place this routine differs from its model.  Skipping the call would leave
;   nchashtbl holding NULL rather than sixteen self-sentinelled buckets, and
;   cache_purgevfs walks those buckets on every unmount whether the cache is
;   on or off -- so a failed allocation would turn an unmount into a null
;   dereference.  nchinit's null arm builds the table, empties the LRU, clears
;   doingcache and still sets the capability counter; the module comes up with
;   no cache, which is the filesystem this tree shipped until the cache was
;   wired -- correct, and slower.
;
;   THE HANDOVER HAPPENS EITHER WAY, in ufs_dirinit just below.  getnewvnode
;   mints v_id through that table on every vnode handout, and that mint is not
;   the cache's to switch off.
;
; In:  MX %00, DBR = ours.   Out: the table built, with or without a pool.
;==============================================================================
_Ud_CacheInit   MX      %00
                LDA     #NC_POOL_BYTES
                LDY     #M_KERN
                LDX     #KSVC_KMALLOC
                JSL     SYS_KCALL
                BCC     @uci_fail
                STA     |_udNcOff       ; MODBANK-OK: mod_init only (DBR=ours)
                PHX
                PLA
                AND     #$00FF
                STA     |_udNcBank      ; MODBANK-OK: mod_init only (DBR=ours)
                LDA     |_udNcOff
                CLC
                ADC     #NC_POOL_BYTES-1
                BCS     @uci_fail

                LDX     |_udNcOff
                LDY     |_udNcBank
                BRA     @uci_call

                ; The arena is gone, so the base is NULL and nchinit takes the
                ; empty-table arm.  It is logged: a machine running uncached is
                ; not broken, but it is slow for a reason the user cannot see.
@uci_fail       LDA     #@uci_bad
                LDX     #KSVC_LOGSTRNE
                JSL     SYS_KCALL
                LDX     #KSVC_LOGEOL
                JSL     SYS_KCALL
                LDX     #0
                LDY     #0

@uci_call       ANOP
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
                PEA     @uci_ret-1
                JMP     nchinit
@uci_ret        PLA
                PLA
                MOD_KC_LEAVE
                RTS

@uci_bad        ASC     'ufsdir: name cache arena failed - running uncached',$00

; Where the arena landed.  Waived at the DECLARATION for the reason vfs.mod's
; four are: both are touched only from mod_init's call tree, whose first act is
; PHK/PLB.
_udNcOff        DS      2       ; MODBANK-OK: mod_init only (DBR=ours)
_udNcBank       DS      2       ; MODBANK-OK: mod_init only (DBR=ours)

;==============================================================================
; _Ud_ResolveVfs / _Ud_ResolveUfs - find a module's vtable and copy it in.
;
; ONE ROUTINE'S SHAPE, TWICE, and it is ufsprobe.mod's verbatim but for the
; vtable id, the entry count and the two destination cells.  Written out rather
; than shared because the copy loop's `LDY #COUNT` and its destination are
; assembly-time constants, and a shared routine would need them in registers
; across the DBR switch -- which is precisely the window in which this routine
; has no direct page and no long pointer to keep anything in.
;
; In:  nothing.  MX %00.  DBR = ours.
; Out: C=1 + the bank and table cells populated; C=0 if the module is absent.
;==============================================================================
_Ud_ResolveVfs  MX      %00
                LDA     #VT_VFSCORE
                LDX     #KSVC_FINDVTABLE
                JSL     SYS_KCALL
                BCS     @rv_have
                RTS                             ; C=0 already
@rv_have        TAY                             ; park the table address
                TXA
                AND     #$00FF
                STA     |_udVfsBank     ; MODBANK-OK: DBR = ours (mod_init set it)
                TYX                             ; X = table address

                ; THE TABLE IS IN THE OTHER MODULE'S BANK AND THE DESTINATION IS
                ; IN OURS, so the copy cannot be one loop.  Read the entries with
                ; DBR there and STACK them; put our own DBR back; unstack into
                ; the table.  No direct page and no long pointer -- a module has
                ; no direct page of its own, and LDAL would bake a bank at
                ; assembly time, which is the trap that has cost this tree two
                ; sessions.
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
                LDA     |_udVfsBank        ; MODBANK-OK: DBR is ours here
                PHA
                PLB                             ; DBR = vfs.mod
                REP     #$20
                MX      %00
                LDA     |$0000,X                ; the entry, from vfs.mod
                PHK
                PLB                             ; DBR ours again -- A survives
                STA     |_udVImp,Y       ; MODBANK-OK: DBR = ours
                INX
                INX
                INY
                INY
                CPY     #VFSCORE_COUNT*2
                BNE     @rv_L
                SEC
                RTS

_Ud_ResolveUfs  MX      %00
                LDA     #VT_UFSCORE
                LDX     #KSVC_FINDVTABLE
                JSL     SYS_KCALL
                BCS     @ru_have
                RTS                             ; C=0 already
@ru_have        TAY
                TXA
                AND     #$00FF
                STA     |_udUfsBank     ; MODBANK-OK: DBR = ours
                TYX

                ; ONE ENTRY AT A TIME, NOT A STACK ROUND TRIP -- apple/fgx#194.
                ; This loop used to read the WHOLE table with DBR on ufs.mod,
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
                ; DBR on ufs.mod, carried in A, and stored with DBR on ours, and
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
@ru_L          SEP     #$20
                MX      %10
                LDA     |_udUfsBank        ; MODBANK-OK: DBR is ours here
                PHA
                PLB                             ; DBR = ufs.mod
                REP     #$20
                MX      %00
                LDA     |$0000,X                ; the entry, from ufs.mod
                PHK
                PLB                             ; DBR ours again -- A survives
                STA     |_udImp,Y       ; MODBANK-OK: DBR = ours
                INX
                INX
                INY
                INY
                CPY     #UFSCORE_COUNT*2
                BNE     @ru_L
                SEC
                RTS

;------------------------------------------------------------------------------
; The C, and the runtime it cannot run without.  The same fcc runtime the other
; three modules carry -- bank-agnostic and shared verbatim with the far bank --
; plus this module's own copy of fcc_runtime_data.s, which is DA-declared
; storage the helpers reach DBR-relatively and therefore must exist in EVERY
; bank that runs fcc output.
;------------------------------------------------------------------------------
                PUT     ../../kernel/libc/alloc_state.s
                PUT     ../../kernel/far/fcc_dp.s       ; fcc register file (EQU)
                PUT     ../../kernel/far/fcc_rt.s       ; pure-computation half
                PUT     ../../kernel/far/fcc_ktrap.s    ; stack/soft-frame traps
                PUT     ../../../toolchain/lib/fcc_runtime_data.s

                ; THE NAME HALF.  ufs_vnops.s carries the vnodeops table and
                ; every operation in it; ufs_lookup.s the scan, direnter,
                ; dirremove, dirrewrite, dirempty and checkpath.  Both are the
                ; SAME generated files ufs.mod used to PUT, from the same
                ; `kernelc` edges -- moved, not copied, which is the fourth time
                ; this campaign has made that claim and the fourth time it has
                ; held.
                ; spec_vnops BEFORE ufs_vnops, which is its only caller: the
                ; ten spec_* in ufs_vnops.c's device-vnode ops vector were
                ; cross-bank shims into vfs.mod until 2026-09-05 and are
                ; direct calls now.
                PUT     ../../kernel/vfs/spec_vnops.s
                PUT     ../../kernel/vfs/spec_vnops.data.s
                PUT     ../../kernel/vfs/ufs_vnops.s
                PUT     ../../kernel/vfs/ufs_vnops.data.s
                PUT     ../../kernel/vfs/ufs_lookup.s
                PUT     ../../kernel/vfs/ufs_lookup.data.s

                ; THE NAME CACHE, whole, on the rule that put spec_vnops.c
                ; here: ufs_lookup.c is the only caller of cache_lookup and
                ; cache_enter, and the cache's state is read on every one of
                ; those calls.  Module C reaches its globals DBR-relatively, so
                ; the halves cannot be split -- and vfs.mod, where this used to
                ; sit unwired, had 94 bytes free.
                PUT     ../../kernel/vfs/vfs_cache.s
                PUT     ../../kernel/vfs/vfs_cache.data.s

                ; The &function bank-patch table, PUT LAST so that adding it
                ; cannot move the cells it describes -- see
                ; tools/gen_mod_bankpatch.py on why that makes one
                ; regeneration converge.
                PUT     fnptr_patchsites.s

ud_end          EQU     *

; Placement guards (tools/gen_modplace.py writes MODP_* into modplace.s).
; Merlin's ERR fires on a NON-ZERO expression; strictly left to right.
                ERR     ud_hdr-MODP_ORG
                ERR     ud_end-MODP_ORG+ud_bss/MODP_LIMIT
; ...and the ordinal, for the same reason the other three guard their own: the
; header's entry field is bank-relative against a LITERAL $090000.
                ERR     MODP_ORG/$10000-$09
