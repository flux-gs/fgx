;==============================================================================
; console_init.s - one-time setup routines for the FGX console driver.
;
; Public:
;   Con_Init     one-time boot setup. Full chain: SCBs, palette, expand
;                tables, PreExpFont, SHR clear, DP state zeroed.
;   Con_Clear    clear SHR + home cursor. Does NOT touch ring buffer.
;
; Internal helpers (not in API):
;   _Con_InitSCBs, _Con_InstallPalettes, _Con_BuildExpand,
;   _Con_BuildPreExpFontForVariant, _Con_BuildAllPreExpFonts
;
; Runtime geometry state (see bottom of file). Phase 8 Con_SetFont will
; update these; for now Con_Init initializes them to the 6x8 80x25 defaults.
;==============================================================================

;------------------------------------------------------------------------------
; Con_RepatchBank - point every baked console-framebuffer operand at bank A.
;
; In:   MX %00.  A = new framebuffer bank in the LOW byte, high byte MUST be
;       clear (callers AND #$00FF -- the loader's stale-B TAX bug of 2026-08-04
;       was exactly this shape).  DBR = this far bank.
; Out:  _kConsoleBank updated; _ConBankPatchBytes/2 operands rewritten.
;       Clobbers A, X, Y.
;
; _kConsoleBank IS the single source of truth: this routine stores A there
; FIRST and the loop then reads it back, rather than keeping the bank in a
; register.  That is deliberate -- main.s reads the same static, so a switch
; that patched the operands without updating it would leave the two
; disagreeing, which is the silent-wrong-bank class this kernel keeps paying
; for.  An extraction that appears to take A while still reading the static is
; the bug this comment exists to prevent; both happen, in that order.
;
; RE-RUNNABLE.  The loop has no one-shot state: it rewrites absolute bank bytes
; from a generated offset table, so calling it again with a different bank
; simply re-points them.  That is what makes a VC switch possible at all.
;
; NOT ISR-SAFE, and never call it from one.  It leaves the console engine's
; operands half-rewritten for the duration; a task preempted mid-loop and
; resumed elsewhere in the engine would read some operands at the old bank and
; some at the new -- the wrong-bank smear of #20/!58.  Slice D drains the switch
; request at a safe point for this reason.
;------------------------------------------------------------------------------
Con_RepatchBank ENT
                MX      %00
                SEP     #$20
                MX      %10
_cfp108         STAL    _kConsoleBank           ; core-bank static (low byte)
                REP     #$30
                MX      %00
                LDX     #0
@crb_loop       CPX     #_ConBankPatchBytes
                BCS     @crb_done
                LDY     _ConBankPatchTbl,X      ; Y = in-bank offset of a bank byte
                SEP     #$20
                MX      %10
_cfp109         LDAL    _kConsoleBank           ; core-bank static (low byte)
                STA     |$0000,Y                ; DBR = far bank -> patches our own
                REP     #$30
                MX      %00
                INX
                INX
                BRA     @crb_loop
@crb_done       RTS

;------------------------------------------------------------------------------
; Con_Init - full boot setup. Call once before any other Con_* entry.
;------------------------------------------------------------------------------
Con_Init
                ; --- Phase 2B: re-bank the console framebuffer operands from baked
                ;     $03 to the dynamic _kConsoleBank.  Runs ONCE here, BEFORE any
                ;     CON_*BUF access.  _ConBankPatchTbl (generated:
                ;     console_bankpatch.s) lists each baked-$03 operand BANK byte's
                ;     in-bank offset (STAL/LDAL +3; MVN +1/+2).  No-op when
                ;     _kConsoleBank == $03 (the static default).
                ;
                ;     THE SITES ARE IN THE FAR BANK NOW, and so is this code.  The
                ;     original walked them through a 24-bit DP pointer whose bank
                ;     came from _BANKK -- the live KERNEL bank -- which would now
                ;     patch 75 operands in the wrong bank.  Since DBR is already
                ;     this bank (Con_Init's PHK/PLB) and the sites are here too,
                ;     absolute-indexed reaches them directly and the pointer goes
                ;     away entirely.  Same simplification Far_BankInit uses.
                ;     Slice D extracted the loop as Con_RepatchBank so a virtual
                ;     console switch can re-run it.  Boot passes the static's own
                ;     value, so this call is a self-assignment and byte-identical
                ;     in effect to the in-line loop it replaces.
                MX      %00
                SEP     #$20
                MX      %10
_cfp107         LDAL    _kConsoleBank           ; core-bank static (low byte)
                REP     #$30
                MX      %00
                AND     #$00FF                  ; clear stale B: the loader's
                                                ;   stale-B TAX bug (2026-08-04)
                                                ;   is this exact shape
                JSR     Con_RepatchBank

                ; Zero all bank-$02 regions owned by the console driver
                ; (see include/memmap.s).  Ensures any read-before-write
                ; returns 0, not uninitialized RAM.  Canary bytes at each
                ; _end are preserved.
                _ZeroBankRegion _conMode;KMem_ConMode_end
                _ZeroBankRegion CON_VT_STATE;KMem_ConVtState_end
                _ZeroBankRegion CON_EXPAND;KMem_ConExpand_end
                _ZeroBankRegion CON_ALT_SAVE;KMem_ConAltSave_end
                _ZeroBankRegion CON_VC_STATE;KMem_ConVcState_end

                ; Populate _conMode from the sole descriptor entry.  There
                ; is one mode and no file to choose it with; Con_LoadMode
                ; went with the 320 mode and the sysbeep setting.
                LDA     #CONMODE_640
                JSR     Con_InitMode            ; copy descriptor → _conMode

                ; Allocate the heap font buffer (M_FONT), sized from the
                ; active mode's CM_GlyphBytes (760) so
                ; different resolutions size dynamically.  Stored as a 24-bit
                ; ptr in cur_font_data_ptr (DP).
                REP     #$30
                LDA     _conMode+CM_GlyphBytes
                LDX     #M_FONT
_cfp015         JSL     _FarSh_Kmalloc
                BCS     @ci_cfdOK
                LDA     #_panic_msg_cfd
                STA     _conStrPtr
_cfp016         JSL     _FarSh_LogStr
_cfp017         JSL     _FarSh_Halt
                RTL                             ; was a tail-call JMP
@ci_cfdOK
                LDA     _kmallocResult
                STA    |CON_FONT_DATA_PTR
                SEP     #$20
                LDA     _kmallocResult+2
                STA    |CON_FONT_DATA_PTR+2
                REP     #$20

                ; Default font: the block the BOOT PROGRAM staged in this bank
                ; (KFAR_BOOT_FONT, include/kfar.s).  Still no compiled-in glyph
                ; blob -- these bytes came off the volume at this boot -- and
                ; still fatal on failure, reported through the firmware-text boot
                ; console because there is no bitmap font to render SHR with.
                ;
                ; CONSOLE INIT NOW READS NO DISK AT ALL, which is what let the
                ; root filesystem move.  This was the last read standing: it runs
                ; before any module is loaded, so the VFS cannot serve it, and a
                ; kernel booted from a 2.11BSD root died here.
                REP     #$30
                JSR     _Con_GlyphsFromBoot         ; sets CON_FONT_LONG_PTR
                BCC     @ci_fontOK
                LDA     #_panic_msg_font
                STA     _conStrPtr
_cfp018         JSL     _FarSh_LogStr
_cfp019         JSL     _FarSh_Halt
                RTL                             ; was a tail-call JMP
@ci_fontOK

                ; Border color 2 = blue (the IIgs ROM's system-blue at
                ; #000099), matching the default palette below.
                ;
                ; READ-MODIFY-WRITE, not a blind store (2026-07-26): $C034 is
                ; the border colour in its LOW nibble and the CLOCK CONTROL bits
                ; in its HIGH nibble, so `LDA #2 / STAL` also zeroed the clock
                ; chip's control state on every boot -- after _KCaptureBootTime
                ; had already read the clock successfully, which is why nothing
                ; noticed.  SYS_BORDER (syscall.s) already preserves the high
                ; nibble; this now matches it.  The old comment claimed the
                ; write also acked a pending VGC interrupt: it does not -- VGC
                ; interrupt acking is $C023 / $C032, not $C034.
                SEP     #$20
                LDAL    $E0C034
                AND     #$F0                    ; keep clock-control nibble
                ORA     #2                      ; border = blue
                STAL    $E0C034
                REP     #$20

                JSR     _Con_InitSCBs
                JSR     _Con_InstallPalettes

                ; Visible-row count from _conMode.CM_Rows (25 / 33).
                REP     #$20
                SEP     #$20
                LDA     _conMode+CM_Rows
                STA     _Con_VisRows
                SEC
                SBC     #1
                STA     _Con_VisRowsM1
                REP     #$20

                ; Init driver state (fg/bg must be set BEFORE _Con_BuildV16)
                LDA     #CON_BUF_ROWS
                STA    |CON_VT_STATE+VT_BUF_ROWS
                LDA     #0
                STA    |CON_VT_STATE+VT_WRITE_PTR
                STA    |CON_VT_STATE+VT_TOP_ROW
                STA    |CON_VT_STATE+VT_CUR_ROW
                STA    |CON_VT_STATE+VT_CUR_COL
                SEP     #$20
                LDA     #1
                STA    |CON_VT_STATE+VT_FOLLOW
                STZ    |CON_VT_STATE+VT_RENDER_STATE         ; Phase 0: start in immediate-render mode
                ; Default fg/bg: ANSI 7 on 0, which the SHR draws as its grey
                ; on its blue (console_vtcolor.s, _Con_FgSlot / _Con_BgSlot)
                ; and the Second Sight card as light grey on black.  It is
                ; also the console's default pair, which CSI 8 ] replaces and
                ; SGR 0/39/49 return to; a VC used for the first time is
                ; seeded from this one's block, the pair with it.
                LDA     #$07
                STA    |CON_VT_STATE+VT_DEF_COLOR
                STA    |CON_VT_STATE+VT_FG
                LDA     #0
                STA    |CON_VT_STATE+VT_BG
                LDA     #0
                STA    |CON_VT_STATE+VT_ATTR
                REP     #$20

                JSR     _Con_BuildAllPreExpFonts  ; all 16 regular PreExpFont variants (bank $04)
                JSR     _Con_BuildBoldPreExpFonts ; all 16 bold PreExpFont variants (bank $04)
                JSR     _Con_BuildUnderlineFill   ; 16-word fg-fill table
                ; The pre-build loops sweep _conFg/_conBg across 0..3 to
                ; generate every (fg,bg) variant; on exit they hold the
                ; LAST variant's values (fg=3, bg=3).  Restore the
                ; defaults so the first Con_PutChar stamps the default pair
                ; into CON_FGBUF/CON_BGBUF.
                SEP     #$20
                LDA     #7
                STA    |CON_VT_STATE+VT_FG
                LDA     #0
                STA    |CON_VT_STATE+VT_BG
                REP     #$20
                JSR     _Con_FillCharBuf    ; fill all ring rows with ' '
                JSR     _Con_FillAttrBuf    ; fill ATTRBUF=0, FGBUF=_conFg, BGBUF=_conBg
                JSR     Con_Clear
                JSR     Con_VtReset
                RTS

;------------------------------------------------------------------------------
; Con_Clear - clear SHR (all 32000 bytes) and home cursor. Ring buffer
; content is untouched.
;------------------------------------------------------------------------------
Con_Clear
                JSR     _Con_FlushPending   ; the clear writes real pixels
                BIT    |_conBackendOn       ; a module's renderer? (console_backend.s)
                BMI     @cc_be
                JSR     _Con_ClearShr
                BRA     @cc_home
@cc_be          LDY    |CON_VT_STATE+VT_TOP_ROW
_Con_HkClear    JSL     $000000             ; operand written by Con_SetBackend
@cc_home        LDA     #0
                STA    |CON_VT_STATE+VT_CUR_ROW
                STA    |CON_VT_STATE+VT_CUR_COL
                RTS

;------------------------------------------------------------------------------
; _Con_ClearShr - the SHR screen to the background colour, all 32000 bytes.
; Con_Clear's pixel half.  MX %00 in and out.
;------------------------------------------------------------------------------
_Con_ClearShr
                ; Compute the bg fill byte from _conBg, an ANSI index, through
                ; the renderer's fold to its slot:
                ;   640 (2 bpp, 4 px/byte): byte = slot * $55
                SEP     #$30
                LDA    |CON_VT_STATE+VT_BG
                AND     #$0F
                TAX
                LDA     _Con_BgSlot,X
                STA     _conScratch0
                ASL
                ASL
                ORA     _conScratch0        ; A = bg*5
                STA     _conScratch1
                ASL
                ASL
                ASL
                ASL
                ORA     _conScratch1        ; A = bg*5 + (bg*5)<<4 = bg*$55
                STAL    CON_SHR_BASE
                REP     #$30
                LDX     #$2000              ; SHR offset within bank $01
                LDY     #$2001              ; dst = src+1 (byte-by-byte propagate)
                LDA     #31998              ; count - 1 for MVN
                MVN     $01,$01
                SEP     #$20
                _DBRK
                REP     #$20
                RTS

;------------------------------------------------------------------------------
; _Con_FillCharBuf - fill all CharBuf rows with space ($20). Ensures render
; of any ring row shows blanks, not RAM garbage, before apps write content.
;------------------------------------------------------------------------------
_Con_FillCharBuf
                SEP     #$20
                LDA     #$20
_kcb015         STAL    CON_CHARBUF         ; write first space (bank $03)
                REP     #$20
                REP     #$30
                LDX     #$0000              ; src = $030000 CharBuf[0]
                LDY     #$0001              ; dst = $030001 CharBuf[1]
                LDA     #7998               ; CON_BUF_ROWS*CON_ROW_BYTES - 2
_kcm016         MVN     $03,$03
                SEP     #$20
                _DBRK
                REP     #$20
                RTS

;------------------------------------------------------------------------------
; _Con_InitSCBs - fill 200 SHR scanline-control bytes with the mode's
; SCB template (bit 7 = 1 for 640 mode) + palette 0.
; Phase 2's per-row palette switching can later rewrite individual SCBs.
;------------------------------------------------------------------------------
_Con_InitSCBs
                SEP     #$20
                LDA     _conMode+CM_ScbModeByte    ; $80 (the 640-mode bit)
                ORA     #0                          ; OR palette idx 0
                LDX     #0
@ci_sL          STAL    $019D00,X
                INX
                CPX     #200
                BCC     @ci_sL
                REP     #$20
                RTS

;------------------------------------------------------------------------------
; _Con_InstallPalettes - copy 512 bytes from the mode's palette bank
; (pointed at by _conMode+CM_PaletteDataPtr) into the SHR palette area at
; $019E00.  Reads the 24-bit src ptr from _conMode and copies via a
; long-indirect [_conScratch6],Y, so the descriptor decides the palette
; rather than this routine.
;------------------------------------------------------------------------------
_Con_InstallPalettes
                ; Stage the 3-byte palette ptr into _conScratch6/7 as a
                ; long indirect; SEP/REP carefully because we need a byte
                ; copy of the bank.
                SEP     #$20
                LDA     _conMode+CM_PaletteDataPtr
                STA     _conScratch6
                LDA     _conMode+CM_PaletteDataPtr+1
                STA     _conScratch6+1
                ; RELOC: the descriptor's baked bank byte (^_Con_PaletteData) is
                ; the assembly-time kernel ORG = $02, but _Con_PaletteData really
                ; lives in the *live* kernel bank.  Use PHK (running kernel bank),
                ; NOT the stale $02 byte — else [_conScratch6] reads an empty bank
                ; and palette 0 loads all-zero = a black SHR screen (glyphs still
                ; render, charbuf still has text, so headless text checks pass).
                ; Behaviour-identical at clean boot (PHK = $02).  The lo16 offset
                ; above is bank-independent and stays from the descriptor.
                PHK
                PLA                             ; A = live kernel bank
                STA     _conScratch6+2
                REP     #$30
                LDY     #0
@ip_L           LDA     [_conScratch6],Y
                TYX
                STAL    $019E00,X
                INY
                INY
                CPY     #512
                BCC     @ip_L
                RTS

;------------------------------------------------------------------------------
; ANSI palette bank.  16 palettes × 16 entries × 2 bytes = 512 bytes (the
; entire SHR palette area at $E1:9E00-$E1:9FFF).
;
; Model: every palette shares the same bg (IIgs system blue $0009) and
; differs only in fg.  The VT-color layer picks a palette per row via
; SCB (Con_SetRowPalette) and sets fg slot = 1 always (Con_SetFg #1).
;
; Mapping: palette idx == ANSI 30..37 / 90..97 minus base.
;   0 black     8 br.black
;   1 red       9 br.red
;   2 green    10 br.green
;   3 yellow   11 br.yellow
;   4 blue     12 br.blue
;   5 magenta  13 br.magenta
;   6 cyan     14 br.cyan
;   7 white    15 br.white
;
; Layout per palette: [slot0=bg, slot1=fg, slot2=fg, slot3=fg] × 4 groups.
; Slots 2/3 hold the fg color too so SetFg with any slot in 1..3 still
; produces the intended color (1-bit font compatibility).
;------------------------------------------------------------------------------
_Con_PaletteData
                ; Palette 0 — system theme.  Multi-color: slots hold the
                ; per-cell fg colors the renderer picks via _conAttr bit 0..1.
                ;   slot 0 = bg    $0009 (IIgs system blue)
                ;   slot 1 = fg    $0CCC (default grey)
                ;   slot 2 = red   $0E00 (warm accent — SGR 31/33/35)
                ;   slot 3 = green $00D0 (cool accent — SGR 32/34/36)
                DW  $0009,$0CCC,$0E00,$00D0
                DW  $0009,$0CCC,$0E00,$00D0
                DW  $0009,$0CCC,$0E00,$00D0
                DW  $0009,$0CCC,$0E00,$00D0
                ; Palette 1 — red.
                DW  $0009,$0E00,$0E00,$0E00
                DW  $0009,$0E00,$0E00,$0E00
                DW  $0009,$0E00,$0E00,$0E00
                DW  $0009,$0E00,$0E00,$0E00
                ; Palette 2 — green.
                DW  $0009,$00D0,$00D0,$00D0
                DW  $0009,$00D0,$00D0,$00D0
                DW  $0009,$00D0,$00D0,$00D0
                DW  $0009,$00D0,$00D0,$00D0
                ; Palette 3 — yellow.
                DW  $0009,$0DD0,$0DD0,$0DD0
                DW  $0009,$0DD0,$0DD0,$0DD0
                DW  $0009,$0DD0,$0DD0,$0DD0
                DW  $0009,$0DD0,$0DD0,$0DD0
                ; Palette 4 — blue (light, since true blue ~= bg).
                DW  $0009,$05BF,$05BF,$05BF
                DW  $0009,$05BF,$05BF,$05BF
                DW  $0009,$05BF,$05BF,$05BF
                DW  $0009,$05BF,$05BF,$05BF
                ; Palette 5 — magenta.
                DW  $0009,$0D0D,$0D0D,$0D0D
                DW  $0009,$0D0D,$0D0D,$0D0D
                DW  $0009,$0D0D,$0D0D,$0D0D
                DW  $0009,$0D0D,$0D0D,$0D0D
                ; Palette 6 — cyan.
                DW  $0009,$00DD,$00DD,$00DD
                DW  $0009,$00DD,$00DD,$00DD
                DW  $0009,$00DD,$00DD,$00DD
                DW  $0009,$00DD,$00DD,$00DD
                ; Palette 7 — white (= default grey, ANSI 37 lands here).
                DW  $0009,$0CCC,$0CCC,$0CCC
                DW  $0009,$0CCC,$0CCC,$0CCC
                DW  $0009,$0CCC,$0CCC,$0CCC
                DW  $0009,$0CCC,$0CCC,$0CCC
                ; Palette 8 — bright black / dim grey.
                DW  $0009,$0888,$0888,$0888
                DW  $0009,$0888,$0888,$0888
                DW  $0009,$0888,$0888,$0888
                DW  $0009,$0888,$0888,$0888
                ; Palette 9 — bright red / salmon.
                DW  $0009,$0F66,$0F66,$0F66
                DW  $0009,$0F66,$0F66,$0F66
                DW  $0009,$0F66,$0F66,$0F66
                DW  $0009,$0F66,$0F66,$0F66
                ; Palette 10 — bright green.
                DW  $0009,$05F5,$05F5,$05F5
                DW  $0009,$05F5,$05F5,$05F5
                DW  $0009,$05F5,$05F5,$05F5
                DW  $0009,$05F5,$05F5,$05F5
                ; Palette 11 — bright yellow.
                DW  $0009,$0FF4,$0FF4,$0FF4
                DW  $0009,$0FF4,$0FF4,$0FF4
                DW  $0009,$0FF4,$0FF4,$0FF4
                DW  $0009,$0FF4,$0FF4,$0FF4
                ; Palette 12 — bright blue / sky.
                DW  $0009,$08CF,$08CF,$08CF
                DW  $0009,$08CF,$08CF,$08CF
                DW  $0009,$08CF,$08CF,$08CF
                DW  $0009,$08CF,$08CF,$08CF
                ; Palette 13 — bright magenta / pink.
                DW  $0009,$0F5F,$0F5F,$0F5F
                DW  $0009,$0F5F,$0F5F,$0F5F
                DW  $0009,$0F5F,$0F5F,$0F5F
                DW  $0009,$0F5F,$0F5F,$0F5F
                ; Palette 14 — bright cyan.
                DW  $0009,$04FF,$04FF,$04FF
                DW  $0009,$04FF,$04FF,$04FF
                DW  $0009,$04FF,$04FF,$04FF
                DW  $0009,$04FF,$04FF,$04FF
                ; Palette 15 — bright white.
                DW  $0009,$0FFF,$0FFF,$0FFF
                DW  $0009,$0FFF,$0FFF,$0FFF
                DW  $0009,$0FFF,$0FFF,$0FFF
                DW  $0009,$0FFF,$0FFF,$0FFF

;------------------------------------------------------------------------------
; _Con_BuildV16 - build the 16-entry V16 table from current _conFg / _conBg.
;
; Each entry i (4 bits) packs 4 pixels into one byte: for each bit of i (MSB
; first), the 2-bit pixel value is fg if the bit is set else bg. Result byte
; has pixel 0 in the top 2 bits, pixel 3 in the low 2 bits.
;
; Called by Con_Init and by Con_SetFg/Con_SetBg whenever colors change.
;------------------------------------------------------------------------------
_Con_BuildV16
                SEP     #$20
                LDX     #0                  ; i in 0..15
@bv_L           LDA     #0
                STA     _conTmp0            ; accumulator
                TXA                         ; A = i
                ASL
                ASL
                ASL
                ASL                         ; move low nibble to high so bit 7 = bit 3 of i
                STA     _conTmp1            ; working i (bits rotate out of MSB)
                LDY     #4
@bv_B           ASL     _conTmp0
                ASL     _conTmp0            ; acc <<= 2
                ASL     _conTmp1            ; C = next bit (MSB first)
                BCS     @bv_fg
                LDA    |CON_VT_STATE+VT_BG
                BRA     @bv_or
@bv_fg          LDA    |CON_VT_STATE+VT_FG
@bv_or          AND     #$03
                ORA     _conTmp0
                STA     _conTmp0
                DEY
                BNE     @bv_B
                LDA     _conTmp0
                ; RELOC: _Con_BuildExpand reads V16 DBR-relative ((_conScratch0),Y),
                ; so write it DBR-relative too (STAL baked $02 while the read uses
                ; DBR=kernel bank -> V16 reads zero -> ExpandWord/PreExpFont all
                ; zero -> blank glyphs -> blue screen).  Both builders run with the
                ; same DBR (called back-to-back), so |abs == STAL at $02.
                STA    |_Con_V16,X
                INX
                CPX     #16
                BCC     @bv_L
                REP     #$20
                RTS

;------------------------------------------------------------------------------
; _Con_BuildExpand - populate ExpandWord table at CON_EXPAND from _Con_V16.
; For each font-byte value 0..255, writes the 16-bit 640-mode pixel pattern
; encoding fg/bg per bit.
;------------------------------------------------------------------------------
_Con_V16        DS      16                  ; runtime-built V16 table

_Con_BuildExpand
                LDA     #_Con_V16
                STA     _conScratch0        ; src ptr (V16 table, low-16)
                LDA     #CON_EXPAND
                STA     _conScratch1        ; dst ptr (ExpandWord table)
                LDX     #0
@ci_beL         TXA
                LSR
                PHA
                AND     #$000F              ; low nibble = 4 low pixels
                TAY
                SEP     #$20
                LDA     (_conScratch0),Y
                REP     #$20
                AND     #$00FF
                XBA                         ; put low-nibble expansion in high byte
                STA     _conTmp0
                PLA
                LSR
                LSR
                LSR
                LSR                         ; high nibble = 4 high pixels
                TAY
                SEP     #$20
                LDA     (_conScratch0),Y
                REP     #$20
                AND     #$00FF
                ORA     _conTmp0
                PHX
                TXY
                STA     (_conScratch1),Y
                PLX
                INX
                INX
                CPX     #512
                BCC     @ci_beL
                RTS

;------------------------------------------------------------------------------
; _Con_BuildPreExpFontForVariant - build one PreExpFont variant into bank $04.
; Inputs:
;   _conFontPtr (3-byte DP long pointer) = variant base address in bank $04
;   CON_EXPAND = ExpandWord already built for this variant's (fg, bg)
; Layout at destination: [ (char-32)*16 + scanline*2 ] = 16-bit pixel pattern.
;------------------------------------------------------------------------------
_Con_BuildPreExpFontForVariant
                LDA     #CON_EXPAND
                STA     _conScratch0        ; expand-table ptr (bank $02)
                ; Stage the far-bank pointer into the direct page ONCE, outside
                ; the loop: [ptr],Y needs the pointer in DP, and doing it per
                ; iteration would pay a 3-byte copy per glyph byte.
                LDA    |CON_FONT_LONG_PTR
                STA     _conFontStage
                SEP     #$20
                LDA    |CON_FONT_LONG_PTR+2
                STA     _conFontStage+2
                REP     #$20
                LDA     #0
                STA     _conTmp0            ; running font-byte index
                ; Pass 1: ASCII glyphs, read through the staged pointer
@bpv_A          LDY     _conTmp0
                SEP     #$20
                LDA     [_conFontStage],Y
                REP     #$20
                AND     #$00FF
                ASL                         ; *2 for word index into ExpandWord
                TAY
                LDA     (_conScratch0),Y
                PHA
                LDA     _conTmp0
                ASL                         ; dst byte offset = idx * 2
                TAY                         ; Y = dest offset
                PLA
                STA     [_conFontPtr],Y     ; store 16-bit word at variant+Y
                INC     _conTmp0
                LDA     _conTmp0
                CMP     #760
                BCC     @bpv_A
                ; Pass 2: DEC glyphs from Font_DEC_Graphics,X
                LDA     #0
                STA     _conTmp1
@bpv_D          LDX     _conTmp1
                SEP     #$20
                LDA     Font_DEC_Graphics,X
                REP     #$20
                AND     #$00FF
                ASL
                TAY
                LDA     (_conScratch0),Y
                PHA
                LDA     _conTmp1
                CLC
                ADC     #760
                ASL
                TAY
                PLA
                STA     [_conFontPtr],Y
                INC     _conTmp1
                LDA     _conTmp1
                CMP     #248
                BCC     @bpv_D
                RTS

;------------------------------------------------------------------------------
; _Con_BuildBoldPreExpFontForVariant - same as regular variant, but each
; source font byte is pre-bolded via (byte | (byte >> 1)) to thicken strokes
; one pixel to the right. Our 2-pixel right padding absorbs the shift.
; Inputs identical to regular builder:
;   _conFontPtr = 24-bit variant base in bank $04
;   CON_EXPAND  = ExpandWord table for this variant's (fg, bg)
;------------------------------------------------------------------------------
_Con_BuildBoldPreExpFontForVariant
                LDA     #CON_EXPAND
                STA     _conScratch0        ; expand-table ptr
                ; Stage the far-bank pointer into the direct page ONCE, outside
                ; the loop: [ptr],Y needs the pointer in DP, and doing it per
                ; iteration would pay a 3-byte copy per glyph byte.
                LDA    |CON_FONT_LONG_PTR
                STA     _conFontStage
                SEP     #$20
                LDA    |CON_FONT_LONG_PTR+2
                STA     _conFontStage+2
                REP     #$20
                LDA     #0
                STA     _conTmp0            ; running font-byte index
                ; Pass 1: ASCII, bolded — read through the staged pointer
@bbv_A          LDY     _conTmp0
                SEP     #$20
                LDA     [_conFontStage],Y   ; raw glyph byte
                STA     _conScratch4        ; save raw
                LSR                         ; byte >> 1
                ORA     _conScratch4        ; byte | (byte >> 1)  (bold)
                REP     #$20
                AND     #$00FF
                ASL                         ; *2 for ExpandWord word index
                TAY
                LDA     (_conScratch0),Y
                PHA                         ; save expansion
                LDA     _conTmp0
                ASL                         ; dst offset = idx * 2
                TAY
                PLA
                STA     [_conFontPtr],Y     ; store at variant+Y
                INC     _conTmp0
                LDA     _conTmp0
                CMP     #760
                BCC     @bbv_A
                ; Pass 2: DEC, bolded
                LDA     #0
                STA     _conTmp1
@bbv_D          LDX     _conTmp1
                SEP     #$20
                LDA     Font_DEC_Graphics,X
                STA     _conScratch4
                LSR
                ORA     _conScratch4
                REP     #$20
                AND     #$00FF
                ASL
                TAY
                LDA     (_conScratch0),Y
                PHA
                LDA     _conTmp1
                CLC
                ADC     #760
                ASL
                TAY
                PLA
                STA     [_conFontPtr],Y
                INC     _conTmp1
                LDA     _conTmp1
                CMP     #248
                BCC     @bbv_D
                RTS

;------------------------------------------------------------------------------
; _Con_BuildAllPreExpFonts - build all 16 PreExpFont variants in bank $04.
; For each attr 0..15:
;   fg = attr & $03
;   bg = (attr >> 2) & $03
; Builds V16, ExpandWord (bank $02 scratch), then PreExpFont for variant.
; Called once from Con_Init.
; Cost: ~16 × ~5ms = ~80ms at Con_Init. (16 × 2016 = 32256 B)
;------------------------------------------------------------------------------
_Con_BuildAllPreExpFonts
                ; Variant counter lives in _conTmp6 ($EE); _conTmp0/_conTmp1 are
                ; clobbered by BuildV16/BuildExpand/BuildPreExpFontForVariant.
                SEP     #$20
                LDA     #0
                STA     _conTmp6            ; variant idx 0..15
@bav_varL       LDA     _conTmp6
                AND     #$03
                STA    |CON_VT_STATE+VT_FG
                LDA     _conTmp6
                LSR
                LSR
                AND     #$03
                STA    |CON_VT_STATE+VT_BG
                REP     #$20
                ; Build V16 and ExpandWord for this (fg, bg)
                JSR     _Con_BuildV16
                JSR     _Con_BuildExpand
                ; Compute variant base = CON_PREEXP_REG_BASE + variant*2016
                ; (via _Con_RegularVariantBaseTbl's 16-bit within-bank offsets).
                SEP     #$20
                LDA     _conTmp6
                REP     #$20
                AND     #$000F
                ASL                         ; *2 for word index
                TAX
                LDA     _Con_RegularVariantBaseTbl,X
                STA     _conFontPtr         ; low 16 bits
                SEP     #$20
_cfp110         LDAL    _kFontsBank         ; RELOC: dynamic fonts bank (was ^CON_PREEXP_REG_BASE=$04)
                STA     _conFontPtr+2
                REP     #$20
                JSR     _Con_BuildPreExpFontForVariant
                ; Next variant
                SEP     #$20
                INC     _conTmp6
                LDA     _conTmp6
                CMP     #16
                BCC     @bav_varL
                REP     #$20
                RTS

;------------------------------------------------------------------------------
; _Con_BuildBoldPreExpFonts - build all 16 bold variants into CON_PREEXP_BOLD_BASE.
; Uses the same (fg, bg) derivation from variant idx as the regular builder,
; but writes through _Con_BoldVariantBaseTbl and the bolded-glyph helper.
;------------------------------------------------------------------------------
_Con_BuildBoldPreExpFonts
                SEP     #$20
                LDA     #0
                STA     _conTmp6            ; variant idx 0..15
@bbav_varL      LDA     _conTmp6
                AND     #$03
                STA    |CON_VT_STATE+VT_FG
                LDA     _conTmp6
                LSR
                LSR
                AND     #$03
                STA    |CON_VT_STATE+VT_BG
                REP     #$20
                JSR     _Con_BuildV16
                JSR     _Con_BuildExpand
                SEP     #$20
                LDA     _conTmp6
                REP     #$20
                AND     #$000F
                ASL                         ; *2 for word index
                TAX
                LDA     _Con_BoldVariantBaseTbl,X
                STA     _conFontPtr
                SEP     #$20
_cfp111         LDAL    _kFontsBank         ; RELOC: dynamic fonts bank (was ^CON_PREEXP_BOLD_BASE=$04)
                STA     _conFontPtr+2
                REP     #$20
                JSR     _Con_BuildBoldPreExpFontForVariant
                SEP     #$20
                INC     _conTmp6
                LDA     _conTmp6
                CMP     #16
                BCC     @bbav_varL
                REP     #$20
                RTS

_Con_RegularVariantBaseTbl
                DW      $0000               ; variant  0: $040000 (+     0)
                DW      $07E0               ; variant  1: $0407E0 (+  2016)
                DW      $0FC0               ; variant  2: $040FC0 (+  4032)
                DW      $17A0               ; variant  3: $0417A0 (+  6048)
                DW      $1F80               ; variant  4: $041F80 (+  8064)
                DW      $2760               ; variant  5: $042760 (+ 10080)
                DW      $2F40               ; variant  6: $042F40 (+ 12096)
                DW      $3720               ; variant  7: $043720 (+ 14112)
                DW      $3F00               ; variant  8: $043F00 (+ 16128)
                DW      $46E0               ; variant  9: $0446E0 (+ 18144)
                DW      $4EC0               ; variant 10: $044EC0 (+ 20160)
                DW      $56A0               ; variant 11: $0456A0 (+ 22176)
                DW      $5E80               ; variant 12: $045E80 (+ 24192)
                DW      $6660               ; variant 13: $046660 (+ 26208)
                DW      $6E40               ; variant 14: $046E40 (+ 28224)
                DW      $7620               ; variant 15: $047620 (+ 30240)

;------------------------------------------------------------------------------
; _Con_BoldVariantBaseTbl - low-16 of bold PreExp variant bases in bank $04.
; Layout identical to _Con_RegularVariantBaseTbl but offset by $8000.
;------------------------------------------------------------------------------
_Con_BoldVariantBaseTbl
                DW      $8000               ; variant  0: $048000
                DW      $87E0               ; variant  1
                DW      $8FC0               ; variant  2
                DW      $97A0               ; variant  3
                DW      $9F80               ; variant  4
                DW      $A760               ; variant  5
                DW      $AF40               ; variant  6
                DW      $B720               ; variant  7
                DW      $BF00               ; variant  8
                DW      $C6E0               ; variant  9
                DW      $CEC0               ; variant 10
                DW      $D6A0               ; variant 11
                DW      $DE80               ; variant 12
                DW      $E660               ; variant 13
                DW      $EE40               ; variant 14
                DW      $F620               ; variant 15

;------------------------------------------------------------------------------
; _Con_BuildUnderlineFill - for each of 16 variants, compute ExpandWord[$FF]
; and store into _Con_UnderlineFill[variant]. Temporarily rebuilds V16 and
; ExpandWord tables for each variant's (fg, bg), then reads the $FF slot
; (the "all fg pixels" pattern).
;------------------------------------------------------------------------------
_Con_BuildUnderlineFill
                SEP     #$20
                LDA     #0
                STA     _conTmp6            ; variant idx
@buf_L          LDA     _conTmp6
                AND     #$03
                STA    |CON_VT_STATE+VT_FG
                LDA     _conTmp6
                LSR
                LSR
                AND     #$03
                STA    |CON_VT_STATE+VT_BG
                REP     #$20
                JSR     _Con_BuildV16
                JSR     _Con_BuildExpand    ; writes CON_EXPAND (bank $02)
                ; Compute destination index variant*2.
                SEP     #$20
                LDA     _conTmp6
                REP     #$20
                AND     #$00FF
                ASL                         ; word index
                TAX                         ; X = destination byte offset
                ; Load ExpandWord[$FF] (word at CON_EXPAND+$1FE) and store.
                LDA     CON_EXPAND+$1FE
                STA     _Con_UnderlineFill,X
                SEP     #$20
                INC     _conTmp6
                LDA     _conTmp6
                CMP     #16
                BCC     @buf_L
                REP     #$20
                RTS

;------------------------------------------------------------------------------
; _Con_UnderlineFill - 16 words, one per variant. Entry i = the 16-bit
; 640-mode pixel pattern that paints all 4 horizontal pixels at variant i's
; fg slot. Read at render time when attr bit 6 (underline) is set.
;------------------------------------------------------------------------------
_Con_UnderlineFill  DS      32               ; 16 words, runtime-built

;==============================================================================
; Runtime geometry state.
;
; These words are READ by driver routines instead of CON_* compile-time
; constants where the value would vary with the active font. Phase 8's
; Con_SetFont will write new values into these slots to support alternate
; fonts (e.g., 4x8 at 160 columns, 8x16 at 12 rows) without rebuilding
; the driver.
;
; For Phase 3.5 these are initialized to the 6x8 defaults (80 cols x 25
; rows, 80-byte stride); no API changes.
;==============================================================================

;------------------------------------------------------------------------------
; Boot panic strings.  Written to dmesg on subsystem-init OOM; system halts
; afterward — message lives in the kernel log ring for any later inspection.
;------------------------------------------------------------------------------
_panic_msg_cfd  ASC     'PANIC: cannot alloc CurrentFontData (M_FONT)',00
_panic_msg_font ASC     'PANIC: boot program staged no usable font',00

_Con_RowBytes     DW    80                ; CharBuf stride per row
_Con_RowBytesM1   DW    79                ; row bytes - 1 (for MVN count)
_Con_RowBytesM2   DW    78                ; row bytes - 2 (for ClearRingRow MVN)
_Con_VisRows      DW    25                ; visible viewport rows
_Con_VisRowsM1    DW    24                ; visible rows - 1 (= bottom row idx)

;==============================================================================
; END console_init.s
;==============================================================================
