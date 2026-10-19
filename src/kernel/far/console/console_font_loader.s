;==============================================================================
; console_font_loader.s - disk font loading and default revert.
;
; Public:
;   Con_LoadFontFromFile - open .FNT path, load glyphs, rebuild cache, repaint.
;   Con_RevertToDefault  - reload the active mode's default .FNT, rebuild.
;   _Con_LoadGlyphsFromPath - shared core: open/validate/read glyphs into the
;                          heap font buffer + point cur_font_long_ptr at it
;                          (NO rebuild/repaint).  Used by Con_Init (boot),
;                          Con_LoadFontFromFile, and Con_RevertToDefault.
;
; The default font is NO LONGER a compiled-in glyph blob: it is loaded from
; disk (/lib/fonts/DEFAULT.FNT) at Con_Init and on
; `font default`, into the same heap buffer (cur_font_data_ptr) that runtime
; .FNT loads use.  One font resident at a time, sized from the mode descriptor
; (CM_GlyphBytes), so different console resolutions size dynamically.
;
; FGXF v1 file layout:
;   48 B header: "FGXF" + version + cell_w + cell_h + flags + name(16)
;                + author(16) + license(8).
;   glyph block: CM_GlyphBytes bytes (760 for 640 mode, 756 for 320).
;==============================================================================

FGXF_MAGIC_0    EQU     $46                 ; 'F'
FGXF_MAGIC_1    EQU     $47                 ; 'G'
FGXF_MAGIC_2    EQU     $58                 ; 'X'
FGXF_MAGIC_3    EQU     $46                 ; 'F'
FGXF_VERSION    EQU     $01

FGXF_ERR_BAD_MAGIC   EQU   $E0
FGXF_ERR_BAD_VERSION EQU   $E1
FGXF_ERR_TRUNCATED   EQU   $E2
FGXF_ERR_WRONG_MODE  EQU   $E3        ; cell_h doesn't match active mode

;------------------------------------------------------------------------------
; Con_RevertToDefault - reload the active mode's default font from disk
; (CM_FontPath), rebuild the cache, repaint.  Preserves caller's MX (PHP/PLP).
; Out: C=0 on success; C=1 + A = errno-like code if the default .FNT won't load.
;------------------------------------------------------------------------------
Con_RevertToDefault
                PHP
                REP     #$30
                ; THE DEFAULT IS THE BLOCK THE BOOT PROGRAM STAGED, not a file
                ; read back off the volume.  It is the same bytes, it cannot
                ; fail for a filesystem reason, and it is one fewer caller of the
                ; legacy reader -- which is the whole direction of the UFS
                ; campaign.  `font <name>' still opens a file; `font default'
                ; no longer needs to.
                JSR     _Con_GlyphsFromBoot
                BCS     @rv_fail
                ; Clear CurrentFontName so listings see default as current.
                SEP     #$20
                LDA     #0
_cfp106         STAL    CurrentFontName         ; core-bank static
                REP     #$20
                JSR     Con_RebuildFontCache
                JSR     Con_RenderAll
                PLP
                CLC
                RTS
@rv_fail        PLP
                SEC
                RTS

;------------------------------------------------------------------------------
; _Con_GlyphsFromBoot - take the default font from the block the BOOT PROGRAM
; staged in this bank, with no filesystem involved at all.
;
; Stage 2 reads /lib/fonts/default.fnt off whichever volume it booted from and
; writes the whole FGXF file at KFAR_BOOT_FONT (include/kfar.s, which carries
; the rationale).  This validates the same three header fields the disk path
; validates and then points the active font at the staged glyph block.
;
; NO COPY INTO THE HEAP BLOCK, and that is the shape the console already had:
; CON_FONT_LONG_PTR is `the active font (default or heap)' and exists precisely
; so the default need not live in the heap.  Loading the default from disk into
; the heap block had collapsed the two into one; the staged block restores the
; distinction and the heap block goes back to being what a RUNTIME `font <name>'
; loads into.
;
; TRUNCATION CANNOT BE SEEN FROM HERE, and the disk path could see it (a short
; read answers FGXF_ERR_TRUNCATED).  What replaces it is the loader clearing a
; magic byte before it tries, so a volume with no font is refused rather than
; validated against whatever a cold power-on left in this bank -- which is the
; failure that matters, because it is the one that is not a build error.
;
; In:   Caller's MX preserved.  _conMode must be populated (Con_InitMode).
; Out:  C=0 on success; C=1 + A = errno-like code on failure.
;------------------------------------------------------------------------------
_Con_GlyphsFromBoot
                PHP
                REP     #$30
                SEP     #$20
                LDA    |_conBootFont+0
                CMP     #FGXF_MAGIC_0
                BNE     @gb_badmagic
                LDA    |_conBootFont+1
                CMP     #FGXF_MAGIC_1
                BNE     @gb_badmagic
                LDA    |_conBootFont+2
                CMP     #FGXF_MAGIC_2
                BNE     @gb_badmagic
                LDA    |_conBootFont+3
                CMP     #FGXF_MAGIC_3
                BNE     @gb_badmagic
                LDA    |_conBootFont+4
                CMP     #FGXF_VERSION
                BNE     @gb_badversion
                ; cell_h decides the glyph-block size and mode compatibility;
                ; cell_w is advisory in 640 mode (varying widths pack into the
                ; eight-pixel byte), exactly as the disk path has it.
                LDA    |_conBootFont+6
                CMP     _conMode+CM_CellHpx
                BNE     @gb_badcell
                REP     #$20
                LDA     #KFAR_BOOT_FONT_GLYPHS
                STA    |CON_FONT_LONG_PTR
                SEP     #$20
                PHK                             ; the far bank, from the CPU
                PLA                             ;   rather than from a constant
                STA    |CON_FONT_LONG_PTR+2
                REP     #$20
                PLP
                CLC
                RTS

@gb_badmagic    REP     #$20
                LDA     #FGXF_ERR_BAD_MAGIC
                BRA     @gb_fail
@gb_badversion  REP     #$20
                LDA     #FGXF_ERR_BAD_VERSION
                BRA     @gb_fail
@gb_badcell     REP     #$20
                LDA     #FGXF_ERR_WRONG_MODE
@gb_fail        PLP
                SEC
                RTS

;------------------------------------------------------------------------------
; Con_LoadFontFromFile - load a .FNT, rebuild the cache, repaint.
; In:   X = bank-$02 ptr to null-terminated path.
; Out:  C=0 on success; C=1 on failure (A = errno-like code).
; Clobbers A, X, Y, flags.  Caller's MX preserved via PHP/PLP.
;------------------------------------------------------------------------------
Con_LoadFontFromFile
                PHP
                REP     #$30
                JSR     _Con_LoadGlyphsFromPath   ; X = path ptr
                BCS     @lf_fail
                JSR     Con_RebuildFontCache
                JSR     Con_RenderAll
                PLP
                CLC
                RTS
@lf_fail        PLP
                SEC
                RTS

;------------------------------------------------------------------------------
; THE FD AND THE GLYPH COUNT ARE THIS ROUTINE'S OWN, NOT RENDER SCRATCH.
;
; `_Con_LoadGlyphsFromPath' holds the descriptor across four calls that sleep on
; block I/O -- `_FarSh_Fs_OpenCore', both `_Ld_VnodeRead's and
; `_FarSh_Fs_Close' -- and `Con_LoadFontFromFile' above is reached from font(1)
; through far slot 137, so another task runs inside that window.  The `_conScratch'
; cells cannot carry a value through it: they are `DS 2' at $D8 and $DC in
; include/dpmap.s, the SHARED kernel direct page, and the ordinary output path
; writes them on every character drawn -- `_Con_RenderRow_640' and
; `_Con_HkRenderCell' here, `_Ss_RenderRow', `_Ss_RenderCell' and both scroll
; routines in sscon.s, 19 writes across 5 files.  One character printed by a
; second task while this one waits on the disk would hand the loader that task's
; descriptor to read glyphs from and to CLOSE: apple/fgx#460, the class of #100
; and #206.
;
; Dedicated storage rather than a push/pop bracket around each sleeping call:
; four brackets cost more bytes than two words, and a fifth call added later
; would reopen the hole.
;------------------------------------------------------------------------------
_conFontFd      DS      2                   ; the .FNT descriptor, held across I/O
_conFontGlyphs  DS      2                   ; CM_GlyphBytes for this load

;------------------------------------------------------------------------------
; _Con_LoadGlyphsFromPath - open .FNT at X=path, validate the 48-byte header,
; read the mode's CM_GlyphBytes glyph bytes into the heap font buffer
; (cur_font_data_ptr), and point cur_font_long_ptr at it.  Does NOT rebuild the
; PreExp cache or repaint -- the caller does (Con_Init builds at boot;
; Con_LoadFontFromFile/Con_RevertToDefault rebuild+render after).
;
; In:   X = bank-$02 ptr to null-terminated path.  cur_font_data_ptr must be
;       allocated (Con_Init) and >= CM_GlyphBytes.  Caller's MX preserved.
; Out:  C=0 on success; C=1 + A = errno-like code on failure.
;------------------------------------------------------------------------------
_Con_LoadGlyphsFromPath
                PHP
                REP     #$30

                ; THE PATH IS IN THE CORE BANK, so this is `_FarSh_Fs_OpenCore'
                ; and not `_FarSh_Fs_Open'.  The latter captures its CALLER's
                ; DBR as the string's bank, which is right for a far-bank
                ; caller's own string and wrong here: `_Sys_FontLoad' hands over
                ; `#_Sys_PathBuf', a core-bank offset, and `_fw_Con_LoadFont-
                ; FromFile' has already set DBR to this bank -- so the copy read
                ; the far bank at the core bank's offset and opened whatever was
                ; there.  That shim's own header names this failure.
                ; Result: C=1 + A=fd on success.
_cfp010         JSL     _FarSh_Fs_OpenCore
                BCS     @lg_opened
                JMP     @lg_fail_noclose

@lg_opened      STA     _conFontFd          ; save fd
                ; Read the 48-byte header into CON_FONT_HDR_BUF in ONE call.
                ;
                ; `_Ld_VnodeRead' IS THE READER FOR A DESCRIPTOR ON THE MOUNTED
                ; ROOT, and it is in this bank -- Load_Binary uses it for
                ; exactly this and for the same reason.  The per-byte
                ; `_FarSh_Fs_Read' loop this replaces reached the CORE bank's
                ; `Fs_Read', which answers EBADF for every descriptor now that
                ; nothing writes `FCB_StorageType' (apple/fgx#357).
                ;
                ; The destination pair is a core-bank absolute, so the far-bank
                ; writes go through _cfp-marked STALs.
                SEP     #$20
                MX      %10
                PHK
                PLA                     ; A.lo = the LIVE far bank
_cfp021         STAL    _frnDstBank
                REP     #$30
                MX      %00
                LDA     #CON_FONT_HDR_BUF
_cfp022         STAL    _frnDstOff
                LDA     _conFontFd
                LDX     #48
                JSR     _Ld_VnodeRead   ; C=1 + Y = bytes, C=0 + A = errno
                BCC     @lg_hdrErr
                CPY     #48
                BCC     @lg_shortTramp  ; short read = truncated file
                BRA     @lg_hdrDone
@lg_hdrErr      JMP     @lg_fail_close
@lg_shortTramp  JMP     @lg_short
@lg_hdrDone

                ; Validate magic
                SEP     #$20
                LDA    |CON_FONT_HDR_BUF+0
                CMP     #FGXF_MAGIC_0
                BNE     @lg_magicTramp
                LDA    |CON_FONT_HDR_BUF+1
                CMP     #FGXF_MAGIC_1
                BNE     @lg_magicTramp
                LDA    |CON_FONT_HDR_BUF+2
                CMP     #FGXF_MAGIC_2
                BNE     @lg_magicTramp
                LDA    |CON_FONT_HDR_BUF+3
                CMP     #FGXF_MAGIC_3
                BEQ     @lg_chkVer
@lg_magicTramp  BRL     @lg_badmagic
@lg_chkVer      LDA    |CON_FONT_HDR_BUF+4
                CMP     #FGXF_VERSION
                BEQ     @lg_chkCell
                BRL     @lg_badversion

@lg_chkCell     ; Validate cell height (640 fonts pack varying widths into
                ; the 8-pixel byte, so cell_w is advisory; cell_h is what
                ; determines glyph-block size and mode compatibility).
                LDA    |CON_FONT_HDR_BUF+6
                STA     _conScratch3
                LDA     _conMode+CM_CellHpx
                CMP     _conScratch3
                BEQ     @lg_cellOK
                BRL     @lg_badcell

@lg_cellOK      ; Glyph-block byte count comes from the mode descriptor
                ; (CM_GlyphBytes) -- dynamic per resolution, not hardcoded.
                REP     #$20
                LDA     _conMode+CM_GlyphBytes
                STA     _conFontGlyphs

                ; Read glyph_block_size glyph bytes into the heap font block
                ; via [cur_font_data_ptr],Y.  cur_font_data_ptr is allocated
                ; at Con_Init via Kmalloc(M_FONT), sized from CM_GlyphBytes.
                ; Stage the far-bank pointer into the direct page ONCE, outside
                ; the loop: [ptr],Y needs the pointer in DP, and doing it per
                ; iteration would pay a 3-byte copy per glyph byte.
                LDA    |CON_FONT_DATA_PTR
_cfp023         STAL    _frnDstOff
                SEP     #$20
                MX      %10
                LDA    |CON_FONT_DATA_PTR+2
_cfp024         STAL    _frnDstBank
                REP     #$30
                MX      %00
                LDA     _conFontFd
                LDX     _conFontGlyphs      ; CM_GlyphBytes
                JSR     _Ld_VnodeRead
                BCC     @lg_glyphErr
                CPY     _conFontGlyphs
                BCC     @lg_short           ; short read = truncated file
                BRA     @lg_glyphDone
@lg_glyphErr    JMP     @lg_fail_close
@lg_glyphDone

                ; Close file
                LDA     _conFontFd
_cfp013         JSL     _FarSh_Fs_Close

                ; Point active long ptr at the freshly loaded heap block.
                LDA    |CON_FONT_DATA_PTR
                STA    |CON_FONT_LONG_PTR
                SEP     #$20
                LDA    |CON_FONT_DATA_PTR+2
                STA    |CON_FONT_LONG_PTR+2
                REP     #$20

                PLP
                CLC
                RTS

@lg_badmagic    REP     #$20
                LDA     #FGXF_ERR_BAD_MAGIC
                JMP     @lg_fail_close
@lg_badversion  REP     #$20
                LDA     #FGXF_ERR_BAD_VERSION
                JMP     @lg_fail_close
@lg_badcell     REP     #$20
                LDA     #FGXF_ERR_WRONG_MODE
                JMP     @lg_fail_close
@lg_short
                REP     #$20
                LDA     #FGXF_ERR_TRUNCATED
                ; fall through

@lg_fail_close
                PHA                         ; save error code
                LDA     _conFontFd
_cfp014         JSL     _FarSh_Fs_Close
                PLA
                ; fall through
@lg_fail_noclose
                PLP
                SEC
                RTS
