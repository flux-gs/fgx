;==============================================================================
; ufsprobe.s - the assembly root of ufsprobe.mod: the FILESYSTEM'S SELF-TESTS,
; in a bank of their own.
;
; WHY TEST CODE HAS ITS OWN MODULE, WHICH READS LIKE AN EXTRAVAGANCE.
;
; ufs.mod is one 64 KB bank and the probes lived in it.  They were split from
; one gate into two at UFS 1.12a and into three at 1.12b, both times because
; the SHIPPING code had grown and the probe no longer fitted beside it.  At
; 1.12c the shipping side reached 50,992 bytes and two of the three gates
; stopped assembling again:
;
;       shipping                     50,992   (14,544 free)
;       kernel.ufsprobe    (blocks)  65,388   fits, 148 bytes to spare
;       kernel.ufsvnprobe  (read)    over 65,536
;       kernel.ufswprobe   (write)   over 65,536
;
; A fourth split would have bought one increment: 1.12c's remaining directory
; operations put shipping near 60 KB, and past that no probe of any size fits.
; The pattern was not "this gate is too big" -- it was that test code and
; shipping code were competing for one bank, and the shipping side wins every
; time.  So the probes left.
;
; A BANK ORDINAL COSTS ADDRESS SPACE, WHICH THIS MACHINE HAS, rather than bank
; space, which it does not.  And the arrangement is not new: vfs.mod and ufs.mod
; already reach each other through vtables, which is exactly what this module
; does in both directions.
;
; IT IS ONLY EVER LOADED WHEN A GATE IS ON.  At the shipping configuration this
; file assembles to a header and nothing else -- no probe C, no shims, no
; driver.  /etc/modload.conf is what decides, and it must load this AFTER both
; vfs and ufs.
;
; THE C IS UNCHANGED AND IS NOT COPIED.  ufs_probe.c, ufs_vnprobe.c and
; ufs_wprobe.c are the same files, from the same `kernelc` ninja edges, moved
; from one module's PUT list to another's -- the third time this campaign has
; made that claim and the third time it has held.
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
                                                        ;   layer's DP cells,
                                                        ;   which kc_blkio writes
                PUT     ../../../include/modules.s      ; SYS_KCALL, KSVC_*,
                                                        ;   VT_UFSCORE, UFSCORE_*
                PUT     ../../../include/kernelc.s      ; MOD_KC_ENTER/LEAVE
                PUT     ../../../include/fs.s           ; DEV_* record layout,
                                                        ;   for the probe driver's
                                                        ;   device scan
                PUT     ../../../include/vfs_equ.s      ; GENERATED from the C
                                                        ;   headers

;------------------------------------------------------------------------------
; FGXM header v2 (40 bytes).
;------------------------------------------------------------------------------
up_bss          EQU     0

up_hdr          ASC     'FGXM'                          ; +0  magic
                DFB     <MODP_ORG                       ; +4  load lo
                DFB     >MODP_ORG                       ; +5  load mid
                DFB     ^MODP_ORG                       ; +6  load hi -- the
                                                        ;     bank ORDINAL, $08
                DFB     $02                             ; +7  header format v2
                ; Entry, BANK-relative.  The subtrahend is the ordinal's base;
                ; the ERR at the foot of this file keeps it honest if
                ; gen_modplace.py's OWN_BANK ever moves this module.
                DA      mod_init-$080000                ; +8  entry, bank-rel
                DA      up_end-up_text                  ; +10 text bytes
                DA      up_bss                          ; +12 bss bytes
                DA      up_vtdir-up_text                ; +14 vtdir offset
up_name         ASC     'ufsprobe'                      ; +16 module name
                DS      16-*+up_name                    ;     NUL-pad to 16
                DA      $0000                           ; +32 module version
                ; +34 build identity.  $0000 = not build-locked: this module
                ; bakes no kernel addresses, and the ones it needs from vfs.mod
                ; and ufs.mod are resolved at load time through vtables.
                DA      $0000
                DS      4                               ; +36 reserved

up_text         EQU     *

;------------------------------------------------------------------------------
; VTDR: empty, and this one stays empty.  Nothing calls INTO a probe; the
; kernel's only interaction with this module is loading it, at which point
; mod_init runs the whole thing and returns.
;------------------------------------------------------------------------------
up_vtdir        ASC     'VTDR'
                DA      VT_END

;------------------------------------------------------------------------------
; The C-to-kernel seam, SHARED with vfs.mod and ufs.mod.  BEFORE mod_init: it
; defines the ENTERK/LEAVEK macros, and Merlin needs a MAC defined before the
; line that uses one.
;------------------------------------------------------------------------------
                PUT     ../common/kc_sys.s

                PUT     ufs_import.s
                PUT     vfs_import.s

;==============================================================================
; mod_init - resolve BOTH modules, then run whichever probe is gated in.
;
; TWO RESOLVERS, NOT ONE, and they are separate because the two failures are:
; a probe that cannot reach ufs.mod has nothing to test, and one that cannot
; reach vfs.mod cannot read a block.  Each says which module is missing rather
; than reporting a generic failure, because the fix in both cases is a line in
; /etc/modload.conf and the message should name it.
;
; THE DP CAPTURE MUST BE FIRST, exactly as in vfs.mod and ufs.mod -- every
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

                DO      UFSANYPROBE=1
                ; BEFORE ANYTHING ELSE, and before any C: fcc's --module-bank
                ; leaves every &function cell's bank byte zero because the
                ; assembler cannot know this module's bank.  PHK in here can.
                JSR     _Mod_StampFnPtrs
                JSR     _Up_ResolveVfs
                BCC     @mi_novfs       ; no vfs.mod: run NO C at all
                JSR     _Up_ResolveUfs
                BCC     @mi_noufs       ; no ufs.mod: likewise

                JSR     _Probe_Drive
                FIN

@mi_out         PLB
                PLP
                SEC                     ; LOAD succeeded either way -- see below
                RTL

                DO      UFSANYPROBE=1
;------------------------------------------------------------------------------
; A MISSING MODULE IS A LOAD-ORDER PROBLEM AND IT SAYS SO, LOUDLY.
;
; It reports a successful LOAD, on the same reasoning ufs.mod's does: the image
; is placed and inert, and rolling it back helps nobody.  What it must NOT do is
; carry on into the C -- every shim reads its target out of a table that is
; still zero, so the first call would pile-call bank 0 offset $FFFF and the
; machine would come apart a long way from the cause.
;------------------------------------------------------------------------------
@mi_novfs       LDA     #@mi_msgNoVfs
                BRA     @mi_say
@mi_noufs       LDA     #@mi_msgNoUfs
@mi_say         LDX     #KSVC_LOGSTRNE
                JSL     SYS_KCALL
                LDX     #KSVC_LOGEOL
                JSL     SYS_KCALL
                BRA     @mi_out

@mi_msgNoVfs    ASC     'ufsprobe: vfs.mod not loaded - load it first (modload.conf)',$00
@mi_msgNoUfs    ASC     'ufsprobe: ufs.mod not loaded - load it first (modload.conf)',$00
                FIN

;==============================================================================
; _Up_ResolveVfs / _Up_ResolveUfs - find a module's vtable and copy it in.
;
; ONE ROUTINE'S SHAPE, TWICE, and it is ufs.mod's _Ufs_ResolveVfs verbatim but
; for the vtable id, the entry count and the two destination cells.  Written out
; rather than shared because the copy loop's `LDY #COUNT` and its destination
; are assembly-time constants, and a shared routine would need them in registers
; across the DBR switch -- which is precisely the window in which this routine
; has no direct page and no long pointer to keep anything in.
;
; WHAT COMES BACK is the table's BANK-RELATIVE address and its bank; the loader
; converts the module's text-relative VTDR offset for exactly this (modload.s).
;
; In:  nothing.  MX %00.  DBR = ours.
; Out: C=1 + the bank and table cells populated; C=0 if the module is absent.
;==============================================================================
_Up_ResolveVfs  MX      %00
                LDA     #VT_VFSCORE
                LDX     #KSVC_FINDVTABLE
                JSL     SYS_KCALL
                BCS     @rv_have
                RTS                             ; C=0 already
@rv_have        TAY                             ; park the table address
                TXA
                AND     #$00FF
                STA     |_upVfsBank     ; MODBANK-OK: DBR = ours (mod_init set it)
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
                LDA     |_upVfsBank        ; MODBANK-OK: DBR is ours here
                PHA
                PLB                             ; DBR = vfs.mod
                REP     #$20
                MX      %00
                LDA     |$0000,X                ; the entry, from vfs.mod
                PHK
                PLB                             ; DBR ours again -- A survives
                STA     |_upVImp,Y       ; MODBANK-OK: DBR = ours
                INX
                INX
                INY
                INY
                CPY     #VFSCORE_COUNT*2
                BNE     @rv_L
                SEC
                RTS

_Up_ResolveUfs  MX      %00
                LDA     #VT_UFSCORE
                LDX     #KSVC_FINDVTABLE
                JSL     SYS_KCALL
                BCS     @ru_have
                RTS                             ; C=0 already
@ru_have        TAY
                TXA
                AND     #$00FF
                STA     |_upUfsBank     ; MODBANK-OK: DBR = ours
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
                LDA     |_upUfsBank        ; MODBANK-OK: DBR is ours here
                PHA
                PLB                             ; DBR = ufs.mod
                REP     #$20
                MX      %00
                LDA     |$0000,X                ; the entry, from ufs.mod
                PHK
                PLB                             ; DBR ours again -- A survives
                STA     |_upImp,Y       ; MODBANK-OK: DBR = ours
                INX
                INX
                INY
                INY
                CPY     #UFSCORE_COUNT*2
                BNE     @ru_L
                SEC
                RTS

;------------------------------------------------------------------------------
; The device scan and probe driver, SHARED with vfs.mod and ufs.mod.  This
; module supplies the identity; the driver supplies the device-selection
; history.
;
; ONE NAME FOR FOUR ENTRY POINTS.  ufs_probe.c, ufs_vnprobe.c, ufs_wprobe.c and
; ufs_devprobe.c each define `ufs_probe`, and the gates PUT exactly one of them -- so the
; driver needs no conditional here.  Merlin32 collects EQU labels BEFORE it
; evaluates `DO`, so a PROBE_ENTRY defined in each of three mutually exclusive
; DO blocks is reported as defined three times; turning the choice into a FILE
; choice puts it somewhere the assembler can make it.
;------------------------------------------------------------------------------
                DO      UFSANYPROBE=1
PROBE_ENTRY     EQU     ufs_probe
PROBE_MSGOK     ASC     'ufs: ok',$00
PROBE_MSGBAD    ASC     'ufs: BROKEN, case ',$00
PROBE_MSGSKIP   ASC     'ufs: no scratch disk, probe skipped',$00
                PUT     ../common/probe_dev.s
                FIN

;------------------------------------------------------------------------------
; The C, and the runtime it cannot run without.  The same fcc runtime vfs.mod
; and ufs.mod carry -- bank-agnostic and shared verbatim with the far bank --
; plus this module's own copy of fcc_runtime_data.s, which is DA-declared
; storage the helpers reach DBR-relatively and therefore must exist in EVERY
; bank that runs fcc output.
;------------------------------------------------------------------------------
                PUT     ../../kernel/libc/alloc_state.s
                PUT     ../../kernel/far/fcc_dp.s       ; fcc register file (EQU)
                PUT     ../../kernel/far/fcc_rt.s       ; pure-computation half
                PUT     ../../kernel/far/fcc_ktrap.s    ; stack/soft-frame traps
                PUT     ../../../toolchain/lib/fcc_runtime_data.s

                ; ONE OF THE FIVE, OR NONE.  The gates are mutually
                ; exclusive (include/kernelc.s refuses any combination) and at
                ; the shipping configuration this module assembles to its
                ; header, the import shims and the fcc runtime -- inert, in a
                ; bank nothing else wants, and never loaded.
                DO      UFSPROBE=1
                PUT     ../../kernel/vfs/ufs_probe.s
                PUT     ../../kernel/vfs/ufs_probe.data.s
                FIN
                DO      UFSVNPROBE=1
                PUT     ../../kernel/vfs/ufs_vnprobe.s
                PUT     ../../kernel/vfs/ufs_vnprobe.data.s
                FIN
                DO      UFSWPROBE=1
                PUT     ../../kernel/vfs/ufs_wprobe.s
                PUT     ../../kernel/vfs/ufs_wprobe.data.s
                FIN
                DO      UFSDEVPROBE=1
                PUT     ../../kernel/vfs/ufs_devprobe.s
                PUT     ../../kernel/vfs/ufs_devprobe.data.s
                FIN
                DO      VNOPSPROBE=1
                PUT     ../../kernel/vfs/vnops_probe.s
                PUT     ../../kernel/vfs/vnops_probe.data.s
                FIN
                ; The &function bank-patch table, PUT LAST so that adding it
                ; cannot move the cells it describes -- see
                ; tools/gen_mod_bankpatch.py on why that makes one
                ; regeneration converge.
                PUT     fnptr_patchsites.s

up_end          EQU     *

; Placement guards (tools/gen_modplace.py writes MODP_* into modplace.s).
; Merlin's ERR fires on a NON-ZERO expression; strictly left to right.
                ERR     up_hdr-MODP_ORG
                ERR     up_end-MODP_ORG+up_bss/MODP_LIMIT
; ...and the ordinal, for the same reason vfs.s and ufs.s guard their own: the
; header's entry field is bank-relative against a LITERAL $080000.
                ERR     MODP_ORG/$10000-$08
