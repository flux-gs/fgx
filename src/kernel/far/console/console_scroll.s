;==============================================================================
; console_scroll.s - scrollback navigation primitives.
;==============================================================================

                MX      %00

;------------------------------------------------------------------------------
; Con_ScrollRegionUp - scroll SHR region (VT_SR_TOP..VT_SR_BOT) up by 1 row.
; Clears the revealed bottom row in CharBuf/AttrBuf and re-renders it.
; Entry/exit: M=0, X=0 (matches Con_RenderRow convention).
;
; _conTmp0 = top (byte)
; _conTmp1 = bot (byte)
; _conTmp2 = MVN src (bank $01 address of row top+1)
; _conTmp3 = MVN dst (bank $01 address of row top)
; _conTmp4 = count_m1
;------------------------------------------------------------------------------
Con_ScrollRegionUp
                SEP     #$20
                ; A PARTIAL REGION MOVES REAL PIXELS, and while a full-screen
                ; scroll is pending they sit where they were before it: draw the
                ; pending scroll first.
                LDA    |CON_VT_STATE+VT_RENDER_STATE
                CMP     #2
                BNE     @sru_noFlush
                LDA    |CON_VT_STATE+VT_SR_TOP
                BNE     @sru_flush
                LDA    |CON_VT_STATE+VT_SR_BOT
                CMP     _Con_VisRowsM1
                BEQ     @sru_noFlush
@sru_flush      MX      %10
                REP     #$20
                JSR     _Con_FlushPending
                SEP     #$20
@sru_noFlush
                ; Keep the DECSC-saved row in sync with the scroll so userland
                ; tools (sh's tab-completion menu) can rely on DECSC/DECRC even
                ; when drawing below the cursor pushes the saved line up.
                ; Only decrement when the saved row sits inside the active
                ; scroll region (SR_TOP..SR_BOT) — otherwise leave it alone.
                LDA    |CON_VT_STATE+VT_SAVED_ROW
                CMP     |CON_VT_STATE+VT_SR_TOP
                BCC     @sru_savedSkip          ; saved < top: outside region
                BEQ     @sru_savedClampTop      ; saved == top: would underflow
                CMP     |CON_VT_STATE+VT_SR_BOT
                BEQ     @sru_savedDec           ; saved == bot: still inside
                BCS     @sru_savedSkip          ; saved > bot: outside region
@sru_savedDec
                DEC
                STA    |CON_VT_STATE+VT_SAVED_ROW
                BRA     @sru_savedSkip
@sru_savedClampTop
                ; saved == top: row N can't go below scroll top, so leave at top.
@sru_savedSkip
                ; Ring-buffer alignment for FULL-SCREEN scroll
                ; (SR_TOP == 0, SR_BOT == _Con_VisRowsM1).  The SHR MVN below
                ; shifts pixels, but the existing flow leaves CharBuf/AttrBuf
                ; for rows top..bot-1 stale — so any later full repaint (e.g.
                ; ESC [ J → Con_RenderAll) overwrites the (correctly-shifted)
                ; pixels with the stale CharBuf content.  Advancing
                ; _conTopRow keeps the logical→visual mapping in lockstep
                ; with the pixel shift: vpRow R now reads from
                ; CharBuf[(topRow+1 + R) mod bufRows] = what used to be at
                ; vpRow R+1 — exactly what the pixel MVN moved up.  The
                ; bottom logical row is then cleared by the existing tail of
                ; this routine.  A partial region (DECSTBM-set) cannot advance
                ; the ring -- the rows outside it would move too -- so it
                ; copies its cells up a row instead (_Con_ShiftRegionUp).
                LDA    |CON_VT_STATE+VT_SR_TOP
                BNE     @sru_skipRingAdvance
                LDA    |CON_VT_STATE+VT_SR_BOT
                CMP     _Con_VisRowsM1
                BNE     @sru_skipRingAdvance
                REP     #$30
                LDA    |CON_VT_STATE+VT_TOP_ROW
                INC
                CMP    |CON_VT_STATE+VT_BUF_ROWS
                BCC     @sru_topRowOK
                LDA     #0
@sru_topRowOK   STA    |CON_VT_STATE+VT_TOP_ROW
                SEP     #$20
@sru_skipRingAdvance
                LDA    |CON_VT_STATE+VT_SR_TOP
                STA     _conTmp0                ; top (low byte)
                LDA    |CON_VT_STATE+VT_SR_BOT
                STA     _conTmp1                ; bot (low byte)
                ; A TASK THAT OWNS THE SCREEN KEEPS ITS PIXELS.  Render state 3 is
                ; SYS_SCREEN_CTL's suspension: a task draws on SHR directly, and
                ; a full-screen scroll must not move its pixels.  The _conTopRow
                ; ring advance above has already kept the CharBuf coherent, so the
                ; Con_RenderAll that the release runs repaints this scroll too.
                ; A partial region (top != 0 or bot != last) did not advance the
                ; ring; its cells are copied below and its pixels moved as usual.
                ; (M=1 here.)
                ;
                ; AN OPEN CONSOLE WRITE COUNTS THE SCROLL INSTEAD (states 1 and
                ; 2): the pixels move once, by every row the write scrolled, when
                ; the write ends (_Con_FlushPending).  The first such scroll in a
                ; write starts the count and the dirty row afresh; each later one
                ; carries the dirty row up with the text on it.
                LDA    |CON_VT_STATE+VT_RENDER_STATE
                BEQ     @sru_noDefer            ; immediate: move the pixels
                LDA     _conTmp0
                BNE     @sru_noDefer            ; top != 0 -> partial region
                LDA     _conTmp1
                CMP     _Con_VisRowsM1
                BNE     @sru_noDefer            ; bot != last -> partial region
                LDA    |CON_VT_STATE+VT_RENDER_STATE
                CMP     #3
                BEQ     @sru_skipMvn            ; owned: keep the 3
                CMP     #2
                BEQ     @sru_count
                LDA     #2
                STA    |CON_VT_STATE+VT_RENDER_STATE
                LDA     #0
                STA    |CON_VT_STATE+VT_PEND_ROWS
                DEC     A                       ; $FF: no row drawn yet
                STA    |CON_VT_STATE+VT_DIRTY_LO
@sru_count      MX      %10
                LDA    |CON_VT_STATE+VT_PEND_ROWS
                CMP     _Con_VisRows
                BCS     @sru_dirty              ; a screenful: nothing survives
                INC     A
                STA    |CON_VT_STATE+VT_PEND_ROWS
@sru_dirty      MX      %10
                LDA    |CON_VT_STATE+VT_DIRTY_LO
                BEQ     @sru_skipMvn            ; row 0 stays row 0
                CMP     #$FF
                BEQ     @sru_skipMvn            ; none
                DEC     A
                STA    |CON_VT_STATE+VT_DIRTY_LO
@sru_skipMvn    MX      %10
                REP     #$20
                JMP     @sru_clearTail          ; skip the MVN; clear + render
@sru_noDefer
                REP     #$20
                ; Degenerate: top == bot -> just clear and re-render that row
                LDA     _conTmp0
                AND     #$00FF
                CMP     _conTmp1
                BNE     @sru_multi
                JMP     @sru_oneRow
@sru_multi      ; The cells first, unless the ring advance above already moved
                ; them: only a full-screen region advances the ring.
                LDA     _conTmp0
                AND     #$00FF
                BNE     @sru_shift
                LDA     _conTmp1
                AND     #$00FF
                CMP     _Con_VisRowsM1
                BEQ     @sru_pixels
@sru_shift      JSR     _Con_ShiftRegionUp
@sru_pixels     ; src = bank $01 address of row top+1
                LDA     _conTmp0
                AND     #$00FF
                INC
                ASL                             ; *2 for word table index
                TAX
                LDA     _Con_RowOffsets,X
                CLC
                ADC     #$2000                  ; + SHR base
                STA     _conTmp2                ; MVN src
                ; dst = bank $01 address of row top
                LDA     _conTmp0
                AND     #$00FF
                ASL
                TAX
                LDA     _Con_RowOffsets,X
                CLC
                ADC     #$2000
                STA     _conTmp3                ; MVN dst
                ; count_m1 = (bank $01 end-of-bot) - src
                ;   end-of-bot (exclusive) = $2000 + RowOffsets[bot+1], or
                ;   if bot==24: $2000 + 25*1280 = $9D00
                LDA     _conTmp1
                AND     #$00FF
                CMP     #24
                BCS     @sru_useLast
                INC
                ASL
                TAX
                LDA     _Con_RowOffsets,X
                CLC
                ADC     #$2000
                BRA     @sru_haveEnd
@sru_useLast
                LDA     #$9D00                  ; $2000 + 25*1280
@sru_haveEnd
                SEC
                SBC     _conTmp2                ; count = end - src
                DEC                             ; count_m1
                STA     _conTmp4
                BIT    |_conBackendOn           ; a module's renderer? (console_backend.s)
                BMI     @sru_be
                ; Execute MVN: X=src, Y=dst, A=count_m1, bank $01 -> $01
                LDX     _conTmp2
                LDY     _conTmp3
                LDA     _conTmp4
                MVN     $01,$01
                ; Restore DBR = kernel-bank (MVN leaves DBR = dest bank = $01)
                SEP     #$20
                _DBRK
                REP     #$20
                BRA     @sru_clearTail
@sru_be         ; A = top, X = bottom, Y = the ring row now at the top of the
                ; screen: a full-screen scroll is the ring advance above and
                ; the back-end shows it by moving its own top; a region it
                ; moves the way the MVN moves pixels.
                LDA     _conTmp1
                AND     #$00FF
                TAX
                LDY    |CON_VT_STATE+VT_TOP_ROW
                LDA     _conTmp0
                AND     #$00FF
_Con_HkScrollUp JSL     $000000                 ; operand written by Con_SetBackend
@sru_clearTail
                ; Clear CharBuf + AttrBuf for row bot; re-render (Con_RenderRow
                ; skips its pixel work while a task owns the screen).
                LDA     _conTmp1
                AND     #$00FF
                JSR     _Con_LogicalRowFromVp
                JSR     _Con_ClearRingRow
                LDA     _conTmp1
                AND     #$00FF
                JSR     _Vt_FillAttrRow_At
                LDA     _conTmp1
                AND     #$00FF
                JMP     Con_RenderRow

@sru_oneRow
                ; Single-row region: clear and re-render that row
                LDA     _conTmp1
                AND     #$00FF
                JSR     _Con_LogicalRowFromVp
                JSR     _Con_ClearRingRow
                LDA     _conTmp1
                AND     #$00FF
                JSR     _Vt_FillAttrRow_At
                LDA     _conTmp1
                AND     #$00FF
                JMP     Con_RenderRow

;------------------------------------------------------------------------------
; Con_ScrollRegionDown - scroll SHR region (top..bot) down by 1 row.
; Clears the revealed top row in CharBuf/AttrBuf and re-renders it.
; Entry/exit: M=0, X=0.
;
; MVP: moves rows top..bot-1 down into rows top+1..bot.
;   src_end = bank $01 address of last byte of row bot-1
;   dst_end = bank $01 address of last byte of row bot
;   count_m1 = (bot - top) * 1280 - 1
;
; _conTmp0 = top (byte)
; _conTmp1 = bot (byte)
; _conTmp2 = MVP src_end
; _conTmp3 = MVP dst_end
; _conTmp4 = rows count (bot - top)
; _conTmp5 = count_m1
;------------------------------------------------------------------------------
Con_ScrollRegionDown
                JSR     _Con_FlushPending       ; it moves real pixels too
                SEP     #$20
                LDA    |CON_VT_STATE+VT_SR_TOP
                STA     _conTmp0
                LDA    |CON_VT_STATE+VT_SR_BOT
                STA     _conTmp1
                REP     #$20
                LDA     _conTmp0
                AND     #$00FF
                CMP     _conTmp1
                BNE     @srd_multi
                JMP     @srd_oneRow
@srd_multi      ; The cells first: a scroll down never moves the ring (retreating
                ; it would hand the top row the newest scrollback line and then
                ; clear it), so every region copies its cells down a row.
                JSR     _Con_ShiftRegionDown
                ; src_end = $2000 + RowOffsets[bot] - 1  (last byte of row bot-1)
                LDA     _conTmp1
                AND     #$00FF
                ASL
                TAX
                LDA     _Con_RowOffsets,X
                CLC
                ADC     #$2000
                DEC
                STA     _conTmp2                ; src_end
                ; dst_end = $2000 + RowOffsets[bot+1] - 1 (last byte of row bot)
                ;   if bot == 24: $9D00 - 1 = $9CFF
                LDA     _conTmp1
                AND     #$00FF
                CMP     #24
                BCS     @srd_useLast
                INC
                ASL
                TAX
                LDA     _Con_RowOffsets,X
                CLC
                ADC     #$2000
                DEC
                BRA     @srd_haveEnd
@srd_useLast
                LDA     #$9CFF                  ; $9D00 - 1
@srd_haveEnd
                STA     _conTmp3                ; dst_end
                ; count_m1 = (bot - top) * 1280 - 1
                LDA     _conTmp1
                AND     #$00FF
                SEC
                SBC     _conTmp0                ; rows = bot - top (low 16)
                STA     _conTmp4
                ; count_bytes = rows * 1280 = rows * 5 * 256
                ;   rows * 5: multiply by 4 (ASL ASL) + rows
                ASL
                ASL                             ; rows * 4
                STA     _conTmp5
                LDA     _conTmp4
                CLC
                ADC     _conTmp5                ; rows * 5
                XBA                             ; move to high byte: rows * 5 * 256
                AND     #$FF00                  ; rows * 1280
                DEC                             ; count_m1
                STA     _conTmp5
                BIT    |_conBackendOn           ; a module's renderer? (console_backend.s)
                BMI     @srd_be
                ; Execute MVP: X=src_end, Y=dst_end, A=count_m1
                LDX     _conTmp2
                LDY     _conTmp3
                LDA     _conTmp5
                MVP     $01,$01
                ; Restore DBR = kernel-bank
                SEP     #$20
                _DBRK
                REP     #$20
                BRA     @srd_tail
@srd_be         ; A = top, X = bottom, Y = the ring row at the top of the screen
                LDA     _conTmp1
                AND     #$00FF
                TAX
                LDY    |CON_VT_STATE+VT_TOP_ROW
                LDA     _conTmp0
                AND     #$00FF
_Con_HkScrollDown JSL   $000000                 ; operand written by Con_SetBackend
@srd_tail       ; Clear CharBuf + AttrBuf for row top; re-render
                LDA     _conTmp0
                AND     #$00FF
                JSR     _Con_LogicalRowFromVp
                JSR     _Con_ClearRingRow
                LDA     _conTmp0
                AND     #$00FF
                JSR     _Vt_FillAttrRow_At
                LDA     _conTmp0
                AND     #$00FF
                JMP     Con_RenderRow

@srd_oneRow
                LDA     _conTmp0
                AND     #$00FF
                JSR     _Con_LogicalRowFromVp
                JSR     _Con_ClearRingRow
                LDA     _conTmp0
                AND     #$00FF
                JSR     _Vt_FillAttrRow_At
                LDA     _conTmp0
                AND     #$00FF
                JMP     Con_RenderRow

;------------------------------------------------------------------------------
; _Con_ShiftRegionUp / _Con_ShiftRegionDown - move the cells of rows
; _conTmp0 (top) .. _conTmp1 (bot) one row up or down, as the pixel MVN/MVP
; moves the pixels: up copies each row from the one below it, top first; down
; copies each row from the one above it, bot first.  The row left behind (bot
; going up, top going down) is the scroll's own to clear, and its tail does.
; apple/fgx#535: before these, a later Con_RenderAll painted a region's stale
; cells over the moved pixels.
;
; _conTmp0 and _conTmp1 are BYTES, written under SEP #$20, so the bounds are
; masked copies on the stack: a 16-bit compare against the scratch word
; carries whatever its high byte last held.  M=0, X=0; clobbers A, X, Y.
;------------------------------------------------------------------------------
_Con_ShiftRegionUp
                LDA     _conTmp1
                AND     #$00FF
                PHA                             ; bot, masked
                LDA     _conTmp0
                AND     #$00FF
@sau_loop       CMP     1,S
                BCS     @sau_done               ; row == bot: nothing below it
                PHA                             ; vp row r
                INC
                JSR     _Con_LogicalRowFromVp
                PHA                             ; source: logical of r + 1
                LDA     3,S
                JSR     _Con_LogicalRowFromVp
                TAX                             ; destination: logical of r
                PLA
                JSR     _Con_CopyRingRow
                PLA
                INC
                BRA     @sau_loop
@sau_done       PLX                             ; drop the bound
                RTS

_Con_ShiftRegionDown
                LDA     _conTmp0
                AND     #$00FF
                PHA                             ; top, masked
                LDA     _conTmp1
                AND     #$00FF
@sad_loop       CMP     1,S
                BEQ     @sad_done               ; row == top: nothing above it
                BCC     @sad_done
                PHA                             ; vp row r
                DEC
                JSR     _Con_LogicalRowFromVp
                PHA                             ; source: logical of r - 1
                LDA     3,S
                JSR     _Con_LogicalRowFromVp
                TAX                             ; destination: logical of r
                PLA
                JSR     _Con_CopyRingRow
                PLA
                DEC
                BRA     @sad_loop
@sad_done       PLX                             ; drop the bound
                RTS

;------------------------------------------------------------------------------
; Con_IndexDown - VT IND (ESC D). Cursor row++; if past VT_SR_BOT, scroll
; region up by 1 (leaving cursor at bot).
; Entry/exit: M=0 (matches other public Con_* entries).
;------------------------------------------------------------------------------
Con_IndexDown
                SEP     #$20
                LDA    |CON_VT_STATE+VT_CUR_ROW
                CMP     |CON_VT_STATE+VT_SR_BOT
                BCC     @id_normal              ; row < bot -> just inc
                BEQ     @id_scroll              ; row == bot -> scroll
                ; row > bot (cursor outside region): clamp to bot
                LDA     |CON_VT_STATE+VT_SR_BOT
                STA    |CON_VT_STATE+VT_CUR_ROW
                REP     #$20
                RTS
@id_normal      INC    |CON_VT_STATE+VT_CUR_ROW
                REP     #$20
                RTS
@id_scroll
                REP     #$20
                JMP     Con_ScrollRegionUp      ; scrolls + re-renders; leaves cursor at bot

;------------------------------------------------------------------------------
; Con_ReverseIndex - VT RI (ESC M). Cursor row--; if above VT_SR_TOP,
; scroll region down by 1 (leaving cursor at top).
;------------------------------------------------------------------------------
Con_ReverseIndex
                SEP     #$20
                LDA    |CON_VT_STATE+VT_CUR_ROW
                CMP     |CON_VT_STATE+VT_SR_TOP
                BEQ     @ri_scroll              ; row == top -> scroll
                BCC     @ri_scroll              ; row < top -> scroll
                DEC    |CON_VT_STATE+VT_CUR_ROW
                REP     #$20
                RTS
@ri_scroll
                REP     #$20
                JMP     Con_ScrollRegionDown

;==============================================================================
; END console_scroll.s
;==============================================================================

;------------------------------------------------------------------------------
; _Con_MarkDirty - a render skipped while a scroll is pending: remember the
; topmost viewport row it would have drawn, for _Con_FlushPending.
; A = vpRow.  MX %00 in and out; X and Y preserved.
;------------------------------------------------------------------------------
_Con_MarkDirty
                SEP     #$20
                CMP    |CON_VT_STATE+VT_DIRTY_LO
                BCS     @md_done
                STA    |CON_VT_STATE+VT_DIRTY_LO
@md_done        MX      %10
                REP     #$20
                RTS

;------------------------------------------------------------------------------
; _Con_FlushPending - draw a pending full-screen scroll (render state 2): one
; MVN moves the rows still on screen up by VT_PEND_ROWS, then every row from
; the newly exposed ones, or the topmost row drawn while pending if that is
; higher, to the bottom is rendered from the cells.  A screenful or more
; leaves nothing to move, so that renders the whole viewport.  Leaves state 1;
; does nothing in any other state.
;
; The cells are already right -- the ring advanced and the rows cleared as each
; scroll was counted -- so the pixels end exactly as the immediate path leaves
; them, one row move instead of one per line.
;
; MX %00 in and out.  Clobbers A, X, Y, _conTmp2.
;------------------------------------------------------------------------------
_Con_FlushPending
                SEP     #$20
                LDA    |CON_VT_STATE+VT_RENDER_STATE
                CMP     #2
                BEQ     @fp_go
                REP     #$20
                RTS
@fp_go          MX      %10
                LDA     #1
                STA    |CON_VT_STATE+VT_RENDER_STATE
                REP     #$20
                LDA    |CON_VT_STATE+VT_PEND_ROWS
                AND     #$00FF
                CMP     _Con_VisRows
                BCC     @fp_move
                JMP     Con_RenderAll
@fp_move        PHA                             ; n, the rows owed
                ASL
                TAX
                LDA     _Con_RowOffsets,X
                CLC
                ADC     #$2000
                STA     _conTmp2                ; src = row n
                LDA     _Con_VisRows
                DEC
                ASL
                TAX
                LDA     _Con_RowOffsets,X
                CLC
                ADC     #1280+$2000             ; end of the last row
                SEC
                SBC     _conTmp2
                DEC                             ; count - 1
                LDX     _conTmp2
                LDY     #$2000                  ; dst = row 0
                MVN     $01,$01
                SEP     #$20
                _DBRK                           ; MVN left DBR = $01
                REP     #$20
                PLA                             ; n
                EOR     #$FFFF
                SEC
                ADC     _Con_VisRows            ; first exposed row = vis - n
                STA     _conTmp2
                LDA    |CON_VT_STATE+VT_DIRTY_LO
                AND     #$00FF
                CMP     _conTmp2
                BCC     @fp_first               ; a higher row was drawn
                LDA     _conTmp2
@fp_first
@fp_L           PHA
                JSR     Con_RenderRow
                PLA
                INC
                CMP     _Con_VisRows
                BCC     @fp_L
                RTS

;------------------------------------------------------------------------------
; Con_WriteArm / Con_WriteDone / Con_DrainPending - the console write that lets
; a full-screen scroll be counted rather than moved.
;
; Con_WriteArm and Con_WriteDone open and close one write(2) (_Vc_WriteEnter,
; _Vc_WriteLeave).  Arming takes only an immediate console with no module
; renderer, so a task's claim (3) is never touched.  Done returns an armed
; console with nothing pending to immediate, and LEAVES A PENDING SCROLL
; PENDING: the next write's scrolls add to it, so a program writing a line at
; a time moves the pixels once for many lines.  Con_DrainPending draws it and
; returns the console to immediate; the core calls it once the pending scroll
; is CON_SCROLL_TICKS old (ttyv.s _Con_DrainScroll).
; MX %00 in and out.  Con_DrainPending clobbers A, X, Y.
;------------------------------------------------------------------------------
Con_WriteArm
                BIT    |_conBackendOn           ; a module's renderer
                BMI     @wa_done
                SEP     #$20
                LDA    |CON_VT_STATE+VT_RENDER_STATE
                BNE     @wa_sep                 ; armed already, or claimed
                INC     A
                STA    |CON_VT_STATE+VT_RENDER_STATE
@wa_sep         MX      %10
                REP     #$20
@wa_done        RTS

Con_DrainPending
                JSR     _Con_FlushPending       ; 2 -> 1, drawn
Con_WriteDone   SEP     #$20
                LDA    |CON_VT_STATE+VT_RENDER_STATE
                CMP     #1
                BNE     @wd_sep
                LDA     #0
                STA    |CON_VT_STATE+VT_RENDER_STATE
@wd_sep         MX      %10
                REP     #$20
                RTS
