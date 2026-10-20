;==============================================================================
; sscon.s - FGXM module: the console on a Second Sight card, Host Text mode.
;
; The card scans an 80x25 cell buffer out of Mega II bank $E0 and draws the
; glyphs itself.  This module keeps that buffer a mirror of the console's own
; 100-row ring, row for row, so a full-screen scroll is one byte -- the card's
; start_line -- and nothing here renders a glyph.  It registers with the
; console through SYS_KCALL service KSVC_CONBACKEND, after which the far
; bank's five pixel sites (src/kernel/far/console/console_backend.s) call the
; routines in _ssTable instead of the SHR renderer.
;
; Plan and the card's interface, with sources:
; docs/history/plans/2026-09-18-second-sight-console-plan.md.
;
; DBR DISCIPLINE.  mod_init is entered with DBR = the kernel bank; the hooks
; with DBR = the far bank, at any time the console writes -- the interrupt-
; time echo included -- so per-call scratch lives in the console's own
; direct-page cells, which are per context, and never in this bank.  A
; routine that reads this bank's statics brackets PHB/PHK/PLB ... PLB.  A
; kernel static is read with the kernel bank in DBR, taken from the anchor,
; and the cell buffers with the console bank in DBR, taken from
; _kConsoleBank on every run because a virtual-console switch changes it;
; the mirror is addressed by register under a fixed bank-$E0 operand.  So no
; code byte is patched beyond the loader's own relocation, which is what the
; module-image check (tools/mame_test/modimage_check.py) holds every module
; to.
;==============================================================================

                MX      %11
                PUT     modplace.s
                ORG     MODP_ORG

;------------------------------------------------------------------------------
; Jump-table slots (fixed bank-0 ABI; see include/modules.s).
;------------------------------------------------------------------------------
KFGX_ANCHOR     EQU     $00032C             ; loader-written live kernel bank
MOD_JT_BASE     EQU     $00032E
SYS_KCALL       EQU     MOD_JT_BASE+$12     ; X = service number
KSVC_LOGSTRNE   EQU     2                   ; A = bank-rel string ptr, no EOL
KSVC_LOGDEC16   EQU     3                   ; A = value, decimal
KSVC_LOGHEX8    EQU     4                   ; A.lo = byte, 2 hex digits
KSVC_LOGEOL     EQU     5                   ; end the line
KSVC_CONBACKEND EQU     53                  ; A = table offset, Y = table bank

TOOL_DISPATCH   EQU     $E10000
_NewHandle      EQU     $0902

;------------------------------------------------------------------------------
; KERNEL DIRECT-PAGE CELLS, by offset (include/dpmap.s; the listing is the
; authority, as ramdisk.s notes).  A hook may clobber only what the SHR
; routine at its site clobbers, because the site's caller may hold the rest
; across the call: the render hooks use _conTmp0, _conTmp2 and
; _conScratch4-7, which both _Con_RenderRow_640 and _Con_RenderCell take;
; the scroll hooks use _conTmp2-4, the cells the MVN they replace consumed,
; and the same scratch, which the row render that follows them takes.
;------------------------------------------------------------------------------
_libcTmp2       EQU     $54                 ; long-ptr scratch (for [dp],Y)
_conScratch4    EQU     $D8                 ; source cell offset
_conScratch5    EQU     $DA                 ; mirror byte offset
_conScratch6    EQU     $DC                 ; cells left in the run; scroll: bottom row
_conScratch7    EQU     $DE                 ; char (lo), attr flags (hi); scroll: top ring row
_conTmp0        EQU     $E2                 ; render cell: the column
_conTmp2        EQU     $E6                 ; render: fg (lo), bg (hi); scroll: top row

;------------------------------------------------------------------------------
; The slot, from cfg/system.cfg (sscon.slot); the four registers follow.
; The braces make Merlin32 multiply first: it has no operator precedence.
;------------------------------------------------------------------------------
                PUT     ../../../include/config.s
SS_SLOT         EQU     CFG_SSCON_SLOT
SS_IO           EQU     {SS_SLOT*16}+$E0C080
SS_CMD          EQU     SS_IO               ; command byte (write)
SS_WDATA        EQU     SS_IO+1             ; argument byte (write)
SS_RDATA        EQU     SS_IO+2             ; answer byte (read)
SS_HS           EQU     SS_IO+8             ; handshake: $A5 done, $A6 refused

;------------------------------------------------------------------------------
; The mirror: the ring's geometry, two bytes a cell, then the control block
; and the palette, one Memory Manager block in bank $E0.
;------------------------------------------------------------------------------
SS_COLS         EQU     80
SS_VIS_ROWS     EQU     25
SS_BUF_ROWS     EQU     100
SS_ROW_BYTES    EQU     160                 ; SS_COLS*2
SS_CELL_BYTES   EQU     16000               ; SS_BUF_ROWS*SS_ROW_BYTES
SS_CTRL_OFF     EQU     16000
SS_PAL_OFF      EQU     16032
SS_BLOCK_BYTES  EQU     16080
SS_BLANK        EQU     $0120               ; char $20, attr $01: fg 1 on bg 0
SS_ATTR_LOCKFIX EQU     $C011               ; attrLocked|attrFixed|attrNoCross|attrBank
                                            ; (Toolbox Reference vol. 1, table 12-4)

;------------------------------------------------------------------------------
; Kernel statics, as bank-relative offsets read with the kernel bank in DBR.
; GENERATED from the kernel build listing every build.
;------------------------------------------------------------------------------
                PUT     kernel_exports.s

;------------------------------------------------------------------------------
; FGXM header v2 (40 bytes).
;------------------------------------------------------------------------------
sscon_hdr       ASC     'FGXM'                          ; +0  magic
                DFB     <MODP_ORG                       ; +4  load lo
                DFB     >MODP_ORG                       ; +5  load mid
                DFB     ^MODP_ORG                       ; +6  load hi
                DFB     $02                             ; +7  header format v2
                DA      mod_init-$050000                ; +8  entry, bank-rel
                DA      sscon_end-sscon_text            ; +10 text bytes
                DA      0                               ; +12 bss bytes
                DA      sscon_vtdir-sscon_text          ; +14 vtdir offset
sscon_modname   ASC     'sscon'                         ; +16 module name
                DS      16-*+sscon_modname              ;     NUL-pad to 16
                DA      $0000                           ; +32 module version
                DA      KERN_BUILD_ID                   ; +34 kernel build id
                DS      4                               ; +36 reserved

sscon_text      EQU     *

VT_END          EQU     $0000
sscon_vtdir     ASC     'VTDR'                          ; no vtables: the
                DA      VT_END                          ; console calls the table

;==============================================================================
; mod_init - Mod_Load JSLs here with DBR = KERNEL bank and MX %00.
;
; Finds the card, takes the block, brings Host Text up, registers.  Returns
; C=1 in every case: a machine without the card loads the module and logs
; why nothing happened, the way the RAM disk module loads without a buffer.
;==============================================================================
mod_init        MX      %00
                PHB
                PHK
                PLB                                     ; DBR = this bank
                ; This bank into the table's five routine entries, the
                ; template copy's source bank and the line-drawing table's
                ; long load: the loader's own relocation, assembled as $05.
                SEP     #$20
                MX      %10
                PHK
                PLA
                STA     _ssTable+2
                STA     _ssTable+5
                STA     _ssTable+8
                STA     _ssTable+11
                STA     _ssTable+14
                STA     _ssTplMvn+2
                STA     _ssGfxL+3
                REP     #$20
                MX      %00
                JSR     _Ss_Probe
                BCS     @mi_card
                LDA     #_ssMsgNoCard
                JSR     _Ss_LogSlot
                BRA     @mi_out
@mi_card        JSR     _Ss_Alloc
                BCS     @mi_block
                LDA     #_ssMsgNoRoom
                JSR     _Ss_LogLine
                BRA     @mi_out
@mi_block       JSR     _Ss_SetMode
                BCC     @mi_refused
                JSR     _Ss_Fill
                JSR     _Ss_Layout
                JSR     _Ss_Arm
                BCC     @mi_refused
                ; Register: A = the table, Y = this bank.
                SEP     #$20
                MX      %10
                PHK
                PLA
                REP     #$20
                MX      %00
                AND     #$00FF
                TAY
                LDA     #_ssTable
                LDX     #KSVC_CONBACKEND
                JSL     SYS_KCALL
                ; "sscon: 80x25 in slot N, cells at $E0:XXXX"
                LDA     #_ssMsgUp
                JSR     _Ss_LogSlot0
                LDA     #_ssMsgCells
                LDX     #KSVC_LOGSTRNE
                JSL     SYS_KCALL
                LDA     _ssBase+2
                LDX     #KSVC_LOGHEX8
                JSL     SYS_KCALL
                LDA     #_ssMsgColon
                LDX     #KSVC_LOGSTRNE
                JSL     SYS_KCALL
                LDA     _ssBase+1
                LDX     #KSVC_LOGHEX8
                JSL     SYS_KCALL
                LDA     _ssBase
                LDX     #KSVC_LOGHEX8
                JSL     SYS_KCALL
                LDX     #KSVC_LOGEOL
                JSL     SYS_KCALL
                BRA     @mi_out
@mi_refused     LDA     #_ssMsgRefused
                JSR     _Ss_LogLine
@mi_out         PLB
                SEC
                RTL

;------------------------------------------------------------------------------
; _Ss_LogLine - A = string: the string, then the end of the line.
; _Ss_LogSlot - the string, the slot number, the end of the line.
; _Ss_LogSlot0 - the string and the slot number, the line left open.
; DBR = this bank.
;------------------------------------------------------------------------------
_Ss_LogLine     MX      %00
                LDX     #KSVC_LOGSTRNE
                JSL     SYS_KCALL
                LDX     #KSVC_LOGEOL
                JMP     SYS_KCALL_JMP
_Ss_LogSlot     MX      %00
                JSR     _Ss_LogSlot0
                LDX     #KSVC_LOGEOL
                JMP     SYS_KCALL_JMP
_Ss_LogSlot0    MX      %00
                LDX     #KSVC_LOGSTRNE
                JSL     SYS_KCALL
                LDA     #SS_SLOT
                LDX     #KSVC_LOGDEC16
                JMP     SYS_KCALL_JMP
SYS_KCALL_JMP   JSL     SYS_KCALL
                RTS

;------------------------------------------------------------------------------
; _Ss_Probe - GetStatus at the slot: twelve bytes back, of which bytes 1-5
; read 'GSVGA' from a card and floating-bus noise from an empty slot.
; C=1 when the card answered.  DBR = this bank.
;------------------------------------------------------------------------------
_Ss_Probe       MX      %00
                SEP     #$20
                MX      %10
                LDA     #$00
                STAL    SS_CMD
                LDX     #0
@pb_rd          LDAL    SS_RDATA
                STA     _ssStatus,X
                INX
                CPX     #12
                BCC     @pb_rd
                ; the handshake, twice, so a deferred status is not left for
                ; the next command to inherit
                LDAL    SS_HS
                LDAL    SS_HS
                LDX     #0
@pb_cmp         LDA     _ssStatus+1,X
                CMP     _ssSig,X
                BNE     @pb_no
                INX
                CPX     #5
                BCC     @pb_cmp
                REP     #$20
                MX      %00
                SEC
                RTS
@pb_no          REP     #$20
                MX      %00
                CLC
                RTS

;------------------------------------------------------------------------------
; _Ss_Alloc - NewHandle(SS_BLOCK_BYTES, _kFgxUserID, locked|fixed|no-cross|
; fixed-bank, $E00000), then dereference the handle into _ssBase and derive
; the control block and palette addresses.  C=1 on success.  DBR = this
; bank in and out; the kernel bank for the owner id.
;------------------------------------------------------------------------------
_Ss_Alloc       MX      %00
                PEA     $0000                           ; result space
                PEA     $0000
                PEA     $0000                           ; size hi
                PEA     SS_BLOCK_BYTES                  ; size lo
                SEP     #$20
                MX      %10
                LDAL    KFGX_ANCHOR                     ; the live kernel bank
                PHA
                PLB                                     ; DBR = kernel bank
                REP     #$20
                MX      %00
                LDA    |_kFgxUserID
                PHK
                PLB                                     ; DBR = this bank
                PHA                                     ; owner
                PEA     SS_ATTR_LOCKFIX
                PEA     $00E0                           ; location hi: bank $E0
                PEA     $0000                           ; location lo
                LDX     #_NewHandle
                JSL     TOOL_DISPATCH
                BCS     @al_fail
                PLA                                     ; handle lo
                STA     _libcTmp2
                PLA                                     ; handle hi: bank in the low byte
                SEP     #$20
                MX      %10
                STA     _libcTmp2+2
                REP     #$20
                MX      %00
                LDA     [_libcTmp2]                     ; master pointer: address lo
                STA     _ssBase
                CLC
                ADC     #SS_CTRL_OFF
                STA     _ssCtrl
                CLC
                ADC     #SS_PAL_OFF-SS_CTRL_OFF
                STA     _ssPal
                LDY     #2
                LDA     [_libcTmp2],Y                   ; address bank in the low byte
                SEP     #$20
                MX      %10
                STA     _ssBase+2
                STA     _ssCtrl+2
                STA     _ssPal+2
                REP     #$20
                MX      %00
                SEC
                RTS
@al_fail        PLA                                     ; discard the result space
                PLA
                CLC
                RTS

;------------------------------------------------------------------------------
; _Ss_SetMode - raster $03 (80x25, 9x16 cells) with the Host Text flag.
; _Ss_Arm - SetTextCtrl with the control block's address, main side.
; Both C=1 on $A5.  DBR = this bank.
;------------------------------------------------------------------------------
_Ss_SetMode     MX      %00
                SEP     #$20
                MX      %10
                LDA     #$01
                STAL    SS_CMD
                LDA     #$03
                STAL    SS_WDATA
                LDA     #$04
                STAL    SS_WDATA
                BRA     _Ss_Wait
_Ss_Arm         MX      %00
                SEP     #$20
                MX      %10
                LDA     #$50
                STAL    SS_CMD
                LDA     _ssCtrl
                STAL    SS_WDATA
                LDA     _ssCtrl+1
                STAL    SS_WDATA
                LDA     #$00
                STAL    SS_WDATA
;------------------------------------------------------------------------------
; _Ss_Wait - poll the handshake: $A5 done (C=1), $A6 refused (C=0), or give
; up after 1024 reads (C=0).  The answer appears on the second read at the
; earliest.  Entered M=1; leaves MX %00.
;------------------------------------------------------------------------------
_Ss_Wait        MX      %10
                LDX     #1024
@w_L            LDAL    SS_HS
                CMP     #$A5
                BEQ     @w_ok
                CMP     #$A6
                BEQ     @w_bad
                DEX
                BNE     @w_L
@w_bad          REP     #$20
                MX      %00
                CLC
                RTS
@w_ok           REP     #$20
                MX      %00
                SEC
                RTS

;------------------------------------------------------------------------------
; _Ss_Fill - every cell of the mirror blank: the first word, then a forward
; move that copies the pair along.  Leaves DBR = this bank.  MX %00.
;------------------------------------------------------------------------------
_Ss_Fill        MX      %00
                LDX     _ssBase                         ; src = base
                LDA     #SS_BLANK
                STAL    $E00000,X                       ; the first pair
                TXA
                INC
                INC
                TAY                                     ; dst = base + 2
                LDA     #SS_CELL_BYTES-3
                MVN     $E0,$E0
                PHK
                PLB
                RTS

;------------------------------------------------------------------------------
; _Ss_Layout - the control block from its template, with the addresses
; filled in, and the palette after it.
; MX %00, DBR = this bank.
;------------------------------------------------------------------------------
_Ss_Layout      MX      %00
                LDA     _ssBase
                STA     _ssCtrlTpl+$0A                  ; buffer_addr
                LDA     _ssPal
                STA     _ssCtrlTpl+$0E                  ; pal_addr
                LDX     #_ssCtrlTpl
                LDY     _ssCtrl
                LDA     #32+48-1                        ; block + palette
_ssTplMvn       MVN     $05,$E0                         ; source bank patched
                PHK
                PLB
                RTS

;==============================================================================
; THE HOOKS.  Entered from the far bank's five sites with DBR = the far bank,
; MX %00; RTL.  Per-call scratch is the console's direct-page cells named at
; the top; the console-bank byte of the four cell loads is refreshed first.
;==============================================================================

;------------------------------------------------------------------------------
; _Ss_RenderRow - A = viewport row, X = ring row, Y = VT_TOP_ROW.
; start_line = Y; mirror row X = ring row X, all 80 cells.
;------------------------------------------------------------------------------
_Ss_RenderRow   MX      %00
                PHB
                PHK
                PLB
                TXA
                JSR     _Ss_RowOffsets                  ; scratch4 = X*80, scratch5 = mirror row
                TYA
                LDX     _ssCtrl
                SEP     #$20
                MX      %10
                STAL    $E00004,X                       ; start_line
                REP     #$20
                MX      %00
                LDA     #SS_COLS
                STA     _conScratch6
                JSR     _Ss_Cells
                PLB
                RTL

;------------------------------------------------------------------------------
; _Ss_RenderCell - A = viewport row, X = column, Y = ring row.
;------------------------------------------------------------------------------
_Ss_RenderCell  MX      %00
                PHB
                PHK
                PLB
                STX     _conTmp0                        ; column
                TYA
                JSR     _Ss_RowOffsets
                LDA     _conScratch4
                CLC
                ADC     _conTmp0
                STA     _conScratch4
                LDA     _conTmp0
                ASL
                CLC
                ADC     _conScratch5
                STA     _conScratch5
                LDA     #1
                STA     _conScratch6
                JSR     _Ss_Cells
                PLB
                RTL

;------------------------------------------------------------------------------
; _Ss_Clear - Y = VT_TOP_ROW.  The whole mirror blank; the ring rows the
; console keeps are repainted by the next render of each.
;------------------------------------------------------------------------------
_Ss_Clear       MX      %00
                PHB
                PHK
                PLB
                JSR     _Ss_Fill
                PLB
                RTL

;------------------------------------------------------------------------------
; _Ss_ScrollUp - A = top, X = bottom, Y = VT_TOP_ROW after the ring advance.
; The full screen: the ring moved, so the card's top moves with it and the
; caller repaints the revealed row.  A region: rows top+1..bottom move up a
; row in the mirror, the way the SHR path moves their pixels.
; _Ss_ScrollDown - A = top, X = bottom, Y = VT_TOP_ROW: rows top..bottom-1
; move down a row.  Neither touches _conTmp0/_conTmp1.
;------------------------------------------------------------------------------
_Ss_ScrollUp    MX      %00
                PHB
                PHK
                PLB
                STA     _conTmp2                        ; top
                STX     _conScratch6                    ; bottom
                STY     _conScratch7                    ; ring row at the top
                CMP     #0
                BNE     @su_region
                CPX     #SS_VIS_ROWS-1
                BNE     @su_region
                TYA
                LDX     _ssCtrl
                SEP     #$20
                MX      %10
                STAL    $E00004,X                       ; start_line
                REP     #$20
                MX      %00
                PLB
                RTL
@su_region      ; for r = top .. bottom-1: mirror[ring(r)] <- mirror[ring(r+1)]
                LDA     _conTmp2
@su_L           CMP     _conScratch6
                BCS     @su_done
                PHA
                INC
                JSR     _Ss_RingAddr                    ; A = offset of ring(r+1)
                TAX                                     ; src
                PLA
                PHA
                JSR     _Ss_RingAddr
                TAY                                     ; dst
                JSR     _Ss_MoveRow
                PLA
                INC
                BRA     @su_L
@su_done        PLB
                RTL

_Ss_ScrollDown  MX      %00
                PHB
                PHK
                PLB
                STA     _conTmp2                        ; top
                STX     _conScratch6                    ; bottom
                STY     _conScratch7                    ; ring row at the top
                ; for r = bottom down to top+1: mirror[ring(r)] <- mirror[ring(r-1)]
                LDA     _conScratch6
@sd_L           CMP     _conTmp2
                BEQ     @sd_done
                BCC     @sd_done
                PHA
                DEC
                JSR     _Ss_RingAddr
                TAX                                     ; src = ring(r-1)
                PLA
                PHA
                JSR     _Ss_RingAddr
                TAY                                     ; dst = ring(r)
                JSR     _Ss_MoveRow
                PLA
                DEC
                BRA     @sd_L
@sd_done        PLB
                RTL

;------------------------------------------------------------------------------
; _Ss_RingAddr - A = viewport row -> A = mirror offset of ring row
; (_conScratch7 + A) mod SS_BUF_ROWS, in bank $E0.  Preserves X, Y.
;------------------------------------------------------------------------------
_Ss_RingAddr    MX      %00
                CLC
                ADC     _conScratch7
                CMP     #SS_BUF_ROWS
                BCC     @ra_ok
                SBC     #SS_BUF_ROWS
@ra_ok          PHX
                JSR     _Ss_Mul80
                ASL                                     ; *160
                CLC
                ADC     _ssBase
                PLX
                RTS

;------------------------------------------------------------------------------
; _Ss_MoveRow - X = source offset, Y = destination offset, both in bank
; $E0: one 160-byte row.  Restores DBR = this bank.
;------------------------------------------------------------------------------
_Ss_MoveRow     MX      %00
                LDA     #SS_ROW_BYTES-1
                MVN     $E0,$E0
                PHK
                PLB
                RTS

;------------------------------------------------------------------------------
; _Ss_RowOffsets - A = ring row -> _conScratch4 = A*80 (the cell buffers'
; row offset), _conScratch5 = A*160 + the block's offset (the mirror row,
; in bank $E0).  DBR = this bank.  Clobbers A.
; _Ss_Mul80 - A = A*80, on the stack, so it touches no cell.
;------------------------------------------------------------------------------
_Ss_RowOffsets  MX      %00
                JSR     _Ss_Mul80
                STA     _conScratch4
                ASL
                CLC
                ADC     _ssBase
                STA     _conScratch5
                RTS
_Ss_Mul80       MX      %00
                PHA                                     ; row
                ASL
                ASL
                CLC
                ADC     1,S                             ; *5
                ASL
                ASL
                ASL
                ASL                                     ; *80
                STA     1,S
                PLA
                RTS

;------------------------------------------------------------------------------
; _Ss_Cells - _conScratch6 cells from cell offset _conScratch4 to mirror
; offset _conScratch5 in bank $E0.  A cell is the ring's character,
; translated for the card's code page 437 when the line-drawing set is on,
; and an attribute of the foreground index in the low nibble and the
; background in the high one; inverse swaps them, bold takes the bright
; half.  The cell buffers are read with the live console bank in DBR; DBR
; is this bank again on exit.  MX %00 in and out.
;------------------------------------------------------------------------------
_Ss_Cells       MX      %00
                SEP     #$20
                MX      %10
                LDAL    KFGX_ANCHOR                     ; the live kernel bank
                PHA
                PLB                                     ; DBR = kernel bank
                LDA    |_kConsoleBank                   ; the live console bank
                PHA
                PLB                                     ; DBR = console bank
                REP     #$20
                MX      %00
@c_L            LDX     _conScratch4
                SEP     #$20
                MX      %10
                LDA    |$0000,X                         ; CON_CHARBUF
                STA     _conScratch7
                LDA    |$2000,X                         ; CON_ATTRBUF
                STA     _conScratch7+1
                LDA    |$4000,X                         ; CON_FGBUF
                AND     #$0F
                STA     _conTmp2
                LDA    |$6000,X                         ; CON_BGBUF
                AND     #$0F
                STA     _conTmp2+1
                ; inverse: swap the two
                LDA     _conScratch7+1
                BIT     #$20
                BEQ     @c_noInv
                LDA     _conTmp2
                PHA
                LDA     _conTmp2+1
                STA     _conTmp2
                PLA
                STA     _conTmp2+1
                LDA     _conScratch7+1
@c_noInv        ; bold: the bright half
                BIT     #$10
                BEQ     @c_noBold
                LDA     _conTmp2
                ORA     #$08
                STA     _conTmp2
                LDA     _conScratch7+1
@c_noBold       ; line drawing: $60-$7E through the table
                BIT     #$80
                BEQ     @c_char
                LDA     _conScratch7
                CMP     #$60
                BCC     @c_char
                CMP     #$7F
                BCS     @c_char
                SEC
                SBC     #$60
                SEP     #$10                            ; an 8-bit index: TAX in
                MX      %11                             ; 16-bit X would carry B
                TAX
_ssGfxL         LDAL    _ssGfx,X                        ; this bank, by the loader's relocation
                REP     #$10
                MX      %10
                STA     _conScratch7
@c_char         LDA     _conScratch7
                CMP     #$20
                BCS     @c_attr
                LDA     #$20                            ; a control code is blank
                STA     _conScratch7
@c_attr         LDA     _conTmp2+1
                ASL
                ASL
                ASL
                ASL
                ORA     _conTmp2
                STA     _conScratch7+1                  ; the card's attribute
                REP     #$20
                MX      %00
                LDA     _conScratch7                    ; char lo, attr hi
                LDX     _conScratch5
                STAL    $E00000,X                       ; the mirror cell
                INC     _conScratch4
                INC     _conScratch5
                INC     _conScratch5
                DEC     _conScratch6
                BEQ     @c_done
                JMP     @c_L
@c_done         PHK
                PLB                                     ; DBR = this bank
                RTS

;------------------------------------------------------------------------------
; Tables and statics.
;------------------------------------------------------------------------------
; The registration table: five routines, their bank bytes the assembled $05
; until mod_init relocates them.  Layout: console_backend.s.
_ssTable        DA      _Ss_RenderRow                   ; MODBANK-OK: written by mod_init and _Ss_Alloc under mod_init's PHB/PHK/PLB
                DFB     ^_Ss_RenderRow
                DA      _Ss_RenderCell
                DFB     ^_Ss_RenderCell
                DA      _Ss_Clear
                DFB     ^_Ss_Clear
                DA      _Ss_ScrollUp
                DFB     ^_Ss_ScrollUp
                DA      _Ss_ScrollDown
                DFB     ^_Ss_ScrollDown

; The control block template (32 bytes) followed by the 48-byte palette
; block, copied to the mirror's tail by _Ss_Layout.  The palette is the
; sixteen VGA text colours in ANSI order, R,G,B, so a cell's colour index --
; the ANSI index the console stores -- is the card's palette index and the
; attribute byte is bg<<4 | fg with no translation.  Brown at 3 is the VGA's
; own, the colour ANSI art was drawn against.
_ssCtrlTpl      DFB     $06                             ; MODBANK-OK: _Ss_Layout under mod_init's bracket.  +0 flags: WRAP, palette from block, main side
                DFB     SS_COLS                         ; +1
                DFB     SS_VIS_ROWS                     ; +2
                DFB     SS_BUF_ROWS                     ; +3
                DFB     0                               ; +4 start_line
                DFB     0,0                             ; +5 cursor x, +6 cursor y
                DFB     0,0                             ; +7 frozen top, +8 frozen bottom
                DFB     0                               ; +9 reserved
                DA      $0000                           ; +$0A buffer_addr, filled
                DA      $0000                           ; +$0C attr_addr: interleaved
                DA      $0000                           ; +$0E pal_addr, filled
                DA      $0000                           ; +$10 cursor style: none
                DS      14                              ; +$12 reserved
                DFB     $00,$00,$00                     ; 0  black
                DFB     $AA,$00,$00                     ; 1  red
                DFB     $00,$AA,$00                     ; 2  green
                DFB     $AA,$55,$00                     ; 3  brown
                DFB     $00,$00,$AA                     ; 4  blue
                DFB     $AA,$00,$AA                     ; 5  magenta
                DFB     $00,$AA,$AA                     ; 6  cyan
                DFB     $AA,$AA,$AA                     ; 7  light grey
                DFB     $55,$55,$55                     ; 8  dark grey
                DFB     $FF,$55,$55                     ; 9  bright red
                DFB     $55,$FF,$55                     ; 10 bright green
                DFB     $FF,$FF,$55                     ; 11 yellow
                DFB     $55,$55,$FF                     ; 12 bright blue
                DFB     $FF,$55,$FF                     ; 13 bright magenta
                DFB     $55,$FF,$FF                     ; 14 bright cyan
                DFB     $FF,$FF,$FF                     ; 15 white

; VT100 line drawing, $60-$7E, on code page 437.
_ssGfx          DFB     $04,$B1,$20,$20,$20,$20,$F8,$F1 ; MODBANK-OK: _Ss_Cells under the hooks' bracket.  ` a b c d e f g
                DFB     $20,$20,$D9,$BF,$DA,$C0,$C5,$C4 ; h i j k l m n o
                DFB     $C4,$C4,$C4,$C4,$C3,$B4,$C1,$C2 ; p q r s t u v w
                DFB     $B3,$F3,$F2,$E3,$F0,$9C,$FA     ; x y z { | } ~

_ssSig          ASC     'GSVGA'                         ; MODBANK-OK: _Ss_Probe runs under mod_init's PHB/PHK/PLB
_ssMsgNoCard    ASC     'sscon: no card in slot ',00
_ssMsgNoRoom    ASC     'sscon: no room in bank $E0 for the cells',00
_ssMsgRefused   ASC     'sscon: the card refused Host Text',00
_ssMsgUp        ASC     'sscon: 80x25 in slot ',00
_ssMsgCells     ASC     ', cells at $',00
_ssMsgColon     ASC     ':',00

; Every routine below the header brackets PHB/PHK/PLB ... PLB before it
; touches these: mod_init at its top, each hook at its entry.
_ssBase         DS      3                               ; MODBANK-OK: the block; read under the brackets above
_ssCtrl         DS      3                               ; MODBANK-OK: its control block; under the brackets
_ssPal          DS      3                               ; MODBANK-OK: its palette; under the brackets
_ssStatus       DS      12                              ; MODBANK-OK: GetStatus's answer; _Ss_Probe under mod_init's bracket

sscon_end       EQU     *

;==============================================================================
; END sscon.s
;==============================================================================
