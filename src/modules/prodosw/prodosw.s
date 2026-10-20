;==============================================================================
; prodosw.s - the assembly root of prodosw.mod: the WRITE half of the ProDOS
; filesystem type, compiled from C.  ProDOS FST P6.
;
; WHY ProDOS IS TWO MODULES.  prodos.mod held the whole filesystem in one
; 65,536-byte bank until rename and truncate took it past the bank.  The write
; path -- prodos_write.c: the bitmap, write(2), create, remove, rename,
; truncate and the deferred free -- is this module; prodos.mod keeps the
; mount, the node layer, lookup, read and readdir, and the vnode vector.
;
; THE SEAM RUNS ONE WAY, ufsdir.mod's shape.  This module calls into prodos.mod
; through VT_PDCORE (prodos_import.s) and into vfs.mod through VT_VFSCORE
; (vfs_import.s); prodos.mod never calls this module by name.  It reaches the
; write half only through the struct pdwops that prodosw_init hands over, whose
; cells carry this module's bank from _Mod_StampFnPtrs.  So prodos.mod must be
; loaded first (/etc/modload.conf), and without this module a ProDOS volume
; mounts read-only.
;
; MODBANK-C-OK: every global, literal and runtime scratch this module's C
; touches is read DBR-relatively, which is correct here for prodos.mod's
; reason -- the C is only ever entered through MOD_KC_ENTER, an import shim or
; a vnode-op dispatch, each of which leaves DBR on this bank.
;==============================================================================

                MX      %11
                PUT     modplace.s
                ORG     MODP_ORG

                PUT     ../../../include/config.s       ; CFG_* build gates
                PUT     ../../../include/macros.s       ; FGX2_MODE/EXPORT/RELOC
                PUT     ../../../include/kernel.s       ; FGX_DP_KERNELC
                PUT     ../../../include/dpmap.s        ; DUM $00: the block
                PUT     ../../../include/modules.s      ; SYS_KCALL, KSVC_*,
                                                        ;   VT_VFSCORE, VT_PDCORE
                PUT     ../../../include/kernelc.s      ; MOD_KC_ENTER/LEAVE
                PUT     ../../../include/fs.s           ; DEV_* record layout
                PUT     ../../../include/vfs_equ.s      ; GENERATED from the C

;------------------------------------------------------------------------------
; FGXM header (40 bytes).  See include/fgxm.s.
;------------------------------------------------------------------------------
pw_bss          EQU     0
pw_hdr          ASC     'FGXM'                          ; +0  magic
                DFB     <MODP_ORG                       ; +4  load lo
                DFB     >MODP_ORG                       ; +5  load mid
                DFB     ^MODP_ORG                       ; +6  load hi
                DFB     $02                             ; +7  header format v2
                DA      mod_init-$0B0000                ; +8  entry, bank-rel
                DA      pw_end-pw_text                  ; +10 text bytes
                DA      pw_bss                          ; +12 bss bytes
                DA      pw_vtdir-pw_text                ; +14 vtdir offset
pw_name         ASC     'prodosw'                       ; +16 module name
                DS      16-*+pw_name                    ;     NUL-pad to 16
                DA      $0000                           ; +32 module version
                DA      $0000
                DS      4                               ; +36 reserved

pw_text         EQU     *

; VTDR: EMPTY.  Nothing calls into this module by name; see the head note.
pw_vtdir        ASC     'VTDR'
                DA      VT_END

; The C-to-kernel seam, then the module-to-module seams.  BEFORE mod_init, for
; ufs.s's reason: they define macros Merlin needs defined before use.
                PUT     ../common/kc_sys.s
                PUT     vfs_import.s
                PUT     prodos_import.s

;------------------------------------------------------------------------------
; mod_init - stamp the &function cells, resolve vfs.mod and prodos.mod, then
; run prodosw_init, which hands the write half to prodos.mod's vector.  A
; missing module runs NO C: every shim would read a zero target.
;------------------------------------------------------------------------------
mod_init        MX      %00
                PHP
                REP     #$30
                MX      %00
                PHB
                PHK
                PLB                     ; DBR = ours, for everything below

                JSR     _Mod_StampFnPtrs
                JSR     _Pw_ResolveVfs
                BCC     @mi_novfs       ; no vfs.mod: run NO C at all
                JSR     _Pw_ResolvePd
                BCC     @mi_nopd        ; no prodos.mod: likewise

                MOD_KC_ENTER
                PHK
                PEA     @mi_initret-1
                JMP     prodosw_init
                ; THE LABEL GETS ITS OWN LINE, for ufs.s's reason:
                ; tools/check_kc_dbr.py matches MOD_KC_LEAVE only at the start
                ; of a line.
@mi_initret     ANOP
                MOD_KC_LEAVE

@mi_out         PLB
                PLP
                SEC
                RTL

@mi_novfs       LDA     #@mi_msgNoVfs
                BRA     @mi_say
@mi_nopd        LDA     #@mi_msgNoPd
@mi_say         LDX     #KSVC_LOGSTRNE
                JSL     SYS_KCALL
                LDX     #KSVC_LOGEOL
                JSL     SYS_KCALL
                BRA     @mi_out

@mi_msgNoVfs    ASC     'prodosw: vfs.mod not loaded',$00
@mi_msgNoPd     ASC     'prodosw: prodos.mod not loaded - load it first (modload.conf)',$00

;------------------------------------------------------------------------------
; _Pw_ResolveVfs / _Pw_ResolvePd - copy a module's vtable into this module's
; import table.  ufsdir.s's _Ud_ResolveVfs and _Ud_ResolveUfs, one entry at a
; time for apple/fgx#194's reason.  C=1 on success, C=0 if the module is absent.
;------------------------------------------------------------------------------
_Pw_ResolveVfs  MX      %00
                LDA     #VT_VFSCORE
                LDX     #KSVC_FINDVTABLE
                JSL     SYS_KCALL
                BCS     @rv_have
                RTS                             ; C=0 already
@rv_have        TAY                             ; park the table address
                TXA
                AND     #$00FF
                STA     |_pwVfsBank     ; MODBANK-OK: DBR = ours (mod_init set it)
                TYX                             ; X = table address
                REP     #$30
                MX      %00
                LDY     #0
@rv_L           SEP     #$20
                MX      %10
                LDA     |_pwVfsBank     ; MODBANK-OK: DBR is ours here
                PHA
                PLB                             ; DBR = vfs.mod
                REP     #$20
                MX      %00
                LDA     |$0000,X                ; the entry, from vfs.mod
                PHK
                PLB                             ; DBR ours again -- A survives
                STA     |_pwVImp,Y      ; MODBANK-OK: DBR = ours
                INX
                INX
                INY
                INY
                CPY     #VFSCORE_COUNT*2
                BNE     @rv_L
                SEC
                RTS

_Pw_ResolvePd   MX      %00
                LDA     #VT_PDCORE
                LDX     #KSVC_FINDVTABLE
                JSL     SYS_KCALL
                BCS     @rp_have
                RTS                             ; C=0 already
@rp_have        TAY
                TXA
                AND     #$00FF
                STA     |_pwPdBank      ; MODBANK-OK: DBR = ours
                TYX
                REP     #$30
                MX      %00
                LDY     #0
@rp_L           SEP     #$20
                MX      %10
                LDA     |_pwPdBank      ; MODBANK-OK: DBR is ours here
                PHA
                PLB                             ; DBR = prodos.mod
                REP     #$20
                MX      %00
                LDA     |$0000,X                ; the entry, from prodos.mod
                PHK
                PLB                             ; DBR ours again -- A survives
                STA     |_pwPImp,Y      ; MODBANK-OK: DBR = ours
                INX
                INX
                INY
                INY
                CPY     #PDCORE_COUNT*2
                BNE     @rp_L
                SEC
                RTS

;------------------------------------------------------------------------------
; The fcc runtime and the C.
;------------------------------------------------------------------------------
                PUT     ../../kernel/libc/alloc_state.s
                PUT     ../../kernel/far/fcc_dp.s       ; fcc register file (EQU)
                PUT     ../../kernel/far/fcc_rt.s       ; pure-computation half
                PUT     ../../kernel/far/fcc_ktrap.s    ; stack/soft-frame traps
                PUT     ../../../toolchain/lib/fcc_runtime_data.s
                ; The clock a write stamps entries with: the kernel clock in
                ; local time, through kern_time.c's kern_ltime.
                PUT     ../../kernel/vfs/kern_time.s
                PUT     ../../kernel/vfs/kern_time.data.s
                PUT     ../../kernel/vfs/prodos_write.s
                PUT     ../../kernel/vfs/prodos_write.data.s
                ; LAST: the only output whose size depends on a scan of this
                ; module's own listing, so nothing after it can move a cell.
                PUT     fnptr_patchsites.s

pw_end          EQU     *
                ERR     pw_hdr-MODP_ORG
                ERR     pw_end-MODP_ORG+pw_bss/MODP_LIMIT
; ...and the ordinal: the header's entry field is bank-relative against a
; LITERAL $0B0000.
                ERR     MODP_ORG/$10000-$0B
