;==============================================================================
; console_mode.s — mode descriptor table + boot-time loader.
;
; The console pipeline reads all mode-dependent parameters (dimensions,
; pixel format, font ptr, render-row fn, SGR mapping, palette ptr) from
; the _conMode struct (laid out per CM_* offsets in include/console.s).
; This file owns the per-mode descriptor table and the helper that
; copies the chosen entry into _conMode at Con_Init.
;
; ONE MODE, AND NO FILE.  A 320-pixel descriptor and its renderer lived here
; from Phase 1 under a "Phase 2 adds M320" note; that phase never came and the
; 320 console was not usable, so it was removed (2026-09-01) rather
; than carried.  The TABLE stays, with one entry: it is what _conMode is
; copied from and what the whole console pipeline reads, and keeping its shape
; is what would make revisiting a second mode an addition rather than a
; rewrite.
;
; Con_LoadMode WENT WITH IT.  It read /etc/conmode for two settings: the mode,
; which no longer has an alternative, and sysbeep, which was early testing
; scaffolding for turning the bell on and off (2026-09-01) -- the bell
; is simply on now.  With neither left the function had nothing to read, and
; deleting it removes a disk read from CONSOLE INIT, which runs before any
; module is loaded and therefore long before the VFS exists.  That is one of
; the five pre-mountroot filesystem dependencies the UFS root swap has to
; clear, gone rather than moved.
;==============================================================================

;------------------------------------------------------------------------------
; Con_InitMode - copy the descriptor at index A into _conMode.
;
; Entry: A = mode ID (0..N-1).  MX %00.
; Exit:  _conMode populated.  A clamped to in-range on bogus input.
;
; Layout: dst = _conMode (20 bytes in bank-$02 statics).
;         src = _Con_ModeTable + A * 20 (bank-$02 code).
; Copy via MVN within bank $02.
;------------------------------------------------------------------------------
Con_InitMode   MX      %00
                ; Clamp A to known range (fall back to M640 on overflow).
                CMP     #_Con_ModeCount
                BCC     @cim_ok
                LDA     #CONMODE_640
@cim_ok         AND     #$00FF
                ; Compute id*20 = (id*16) + (id*4).
                STA     _conScratch0            ; save id
                ASL                             ; id*2
                ASL                             ; id*4
                STA     _conScratch1            ; save id*4
                LDA     _conScratch0
                ASL
                ASL
                ASL
                ASL                             ; id*16
                CLC
                ADC     _conScratch1            ; id*20
                CLC
                ADC     #_Con_ModeTable         ; src offset (low 16 in bank $02)
                ; MVN: src in X, dst in Y, count-1 in A, banks in operand.
                TAX                             ; X = src offset
                LDY     #_conMode               ; Y = dst offset
                LDA     #20-1                   ; A = byte count - 1
                ; Reloc: src (_Con_ModeTable) and dst (_conMode) are kernel statics
                ; that moved to the kernel bank; the baked MVN $02,$02 read/wrote the
                ; STALE $02 copies, so _conMode read 0 at $20 -> Kmalloc(0) font fail.
                ; DBR=kernel-bank for the self-mod store, patch the MVN src+dst banks
                ; to the live kernel bank (PHK); the MVN then leaves DBR=kernel-bank
                ; (replaces the old PHK/PLB).  Behavior-identical at $02 (PHK=$02).
                PHK
                PLB                             ; DBR = kernel bank (self-mod target)
                PHA                             ; save count
                SEP     #$20
                MX      %10
                PHK
                PLA                             ; A.lo = live kernel bank
                STA     @cim_mvn+1              ; patch MVN dst bank
                STA     @cim_mvn+2              ; patch MVN src bank
                REP     #$20
                MX      %00
                PLA                             ; restore count
@cim_mvn        MVN     $02,$02                 ; src+dst banks patched -> kernel bank
                RTS

;------------------------------------------------------------------------------
; Mode descriptor table.  Each entry is 20 bytes laid out per CM_* offsets
; in include/console.s.
;
; NOTE (reloc): CM_RenderRowFn / CM_SgrToFgFn are reserved-UNWIRED -- row
; render is dispatched by mode-branch (console_render.s), NOT through the
; stored pointer, and there is no SGR->fg mapper to point at: SGR stores the
; ANSI colour index and the renderer folds it (console_vtcolor.s,
; _Con_FgSlot).  The bank bytes are $00 placeholders; the old baked
; assembly-ORG $02 was a footgun (a future reader honoring it would JSL into
; a foreign bank).  If ever wired, re-bank to the LIVE kernel bank at init
; (PHK), as CM_PaletteDataPtr does.
;------------------------------------------------------------------------------
_Con_ModeTable
                ; --- M640 (idx 0) ---
                DFB  80                       ; CM_Cols
                DFB  25                       ; CM_Rows
                DFB  8                        ; CM_CellWpx
                DFB  8                        ; CM_CellHpx
                DFB  2                        ; CM_Bpp
                DFB  $80                      ; CM_ScbModeByte (640-mode bit)
                DA   760                      ; CM_GlyphBytes (95 ASCII × 8)
                ; 3-byte pointers (low + mid + bank).  Hand-rolled because
                ; ADRL emits 4 bytes per call and misaligns the struct.
                DA   _Con_FontPathDefault     ; CM_FontPath (low 16)
                DFB  ^_Con_FontPathDefault    ; CM_FontPath (bank)
                DA   _Con_RenderRow_640       ; CM_RenderRowFn (reserved-unwired; see note)
                DFB  $00                       ;   bank $00 placeholder — re-bank if wired
                DA   $0000                    ; CM_SgrToFgFn (reserved-unwired; SGR stores the ANSI index)
                DFB  $00                       ;   bank $00 placeholder — re-bank if wired
                DA   _Con_PaletteData         ; CM_PaletteDataPtr (USED)
                DFB  ^_Con_PaletteData         ;   re-banked via PHK at console_init.s
_Con_ModeCount  EQU  1                       ; M640, and only M640

;------------------------------------------------------------------------------
; Default-font disk paths (per mode).  Loaded into the heap font buffer at
; Con_Init and on `font default`.  Byte-identical to the former compiled-in
; Font_Default_ASCII / Font_3x5 blobs (generated by tools/gen_fnt.py /
; gen_fnt_3x5.py --upper-fallback).  Bank $02 strings — Fs_Open takes the lo16.
;------------------------------------------------------------------------------
_Con_FontPathDefault  ASC  '/lib/fonts/DEFAULT.FNT',00

;==============================================================================
; END console_mode.s
;==============================================================================
