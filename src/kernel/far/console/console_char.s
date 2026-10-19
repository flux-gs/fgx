;==============================================================================
; console_char.s - cursor-based character I/O.
;
; Public:
;   Con_PutChar      A (low byte) = char. Write at cursor with wrap+scroll.
;   Con_CR           advance cursor to next row, col 0, auto-scroll if follow.
;
; Internal:
;   _Con_WriteCharAtCursor   put A's char into CharBuf at (curRow, curCol).
; Scratch usage:
;   _conScratch7 (DP $DE) - Con_PutChar per-cell attr temp (G bit computed).
;==============================================================================

;------------------------------------------------------------------------------
; Con_PutChar - A (low byte) = char.
;
; Line-ending convention: Unix/VT100 native — CR ($0D) = carriage return
; (cursor to col 0, SAME row) and LF ($0A) = line feed (cursor down one
; row, SAME column) are DISTINCT terminal operations.  A visible newline
; is the CR+LF pair.  Cooked-tty output post-processing (ONLCR, in the
; kernel _Sys_Write discipline) maps a bare LF → CR+LF so Unix LF text
; displays correctly; raw mode (vi/curses) emits CR and LF verbatim.
; Con_CR is the internal full-newline (CR+LF) helper for kernel callers.
; Legacy CR-only Apple II / ProDOS text is converted at ingest (dos2unix).
;
; Right-margin wrap is deferred (xterm "xn"): writing the last column
; sets VT_PENDING_WRAP and leaves the cursor in that column.  The next
; printable arrival sees the flag, calls Con_CR to wrap, and writes at
; column 0 of the new row.  CR, LF, BS, Con_CR, Con_SetCursor, and the
; VT cursor-positioning handlers clear the flag.  This matches every
; mainstream terminal and lets 80-col content + CR be exactly one
; newline (instead of two under the older immediate-wrap behavior).
;
; Printable chars 32..126 write at cursor and advance.  CR, LF and BS are
; handled above; TAB moves to the next eight-column stop; every other
; control character is IGNORED -- no glyph and no column.  Those are
; `partab's classes, which is how the kernel's own t_col is kept
; (ttyoutput, src/kernel/tty/tty.c), so the screen and t_col agree.
; They used to be "rendered as space", which is apple/fgx#65.
;------------------------------------------------------------------------------
Con_PutChar
                ; MX-state-robust wrapper: this function's assembled bytes
                ; (starting with AND #$00FF) assume M=0.  If a caller enters
                ; with M=1 the CPU misdecodes the 3-byte AND as a 2-byte one
                ; and then treats the trailing \$00 operand as BRK.  Normalise
                ; here and restore at @ch_exit.
                PHP
                REP     #$30
                MX      %00
                AND     #$00FF              ; THE BYTE AS WRITTEN, all eight
                                            ; bits: $80-$FF are glyphs (code
                                            ; page 437 on the Second Sight
                                            ; card).  The SHR renderer masks
                                            ; to seven bits when it draws, so
                                            ; an ASC "..." string the kernel
                                            ; writes still shows as its text.
                ; Determine whether this cell's char is a DEC Special Graphics
                ; glyph. Active charset = VT_GL ? VT_G1_CHARSET : VT_G0_CHARSET.
                ; If active == DEC_GFX AND char in $60..$7E, set G bit (bit 7)
                ; of cell attr (_conScratch7 holds the cell-time attr).
                PHA                         ; save char (M=0)
                SEP     #$20
                LDA    |CON_VT_STATE+VT_ATTR
                AND     #$7F                ; clear any stale G bit
                STA     _conScratch7        ; cell attr tentative
                LDA    |CON_VT_STATE+VT_GL
                BEQ     @ch_useG0
                LDA    |CON_VT_STATE+VT_G1_CHARSET
                BRA     @ch_haveCs
@ch_useG0       LDA    |CON_VT_STATE+VT_G0_CHARSET
@ch_haveCs      CMP     #$01                ; DEC_GFX?
                BNE     @ch_gDone
                REP     #$20
                PLA                         ; char (16-bit)
                PHA                         ; re-save
                AND     #$00FF
                CMP     #$60
                BCC     @ch_gNotInRange16
                CMP     #$7F
                BCS     @ch_gNotInRange16
                SEP     #$20
                LDA     _conScratch7
                ORA     #$80                ; set G bit
                STA     _conScratch7
                BRA     @ch_gDone
@ch_gNotInRange16
                SEP     #$20
@ch_gDone       REP     #$20
                PLA                         ; char (16-bit) on stack
                AND     #$00FF
                CMP     #$0D                ; CR — carriage return (col 0, same row)
                BNE     @ch_notCR
                JSR     Con_CarriageReturn  ; clears VT_PENDING_WRAP internally
                BRA     @ch_exit
@ch_notCR       CMP     #$0A                ; LF — line feed (down one row, same col)
                BNE     @ch_notLF
                JSR     Con_LineFeed        ; clears VT_PENDING_WRAP internally
                BRA     @ch_exit
@ch_notLF       CMP     #$08                ; BS: cursor-back, no erase
                BNE     @ch_notBS
                JSR     _Con_ClearPendingWrap
                LDA    |CON_VT_STATE+VT_CUR_COL
                BEQ     @ch_exit            ; already at col 0 — ignore
                DEC    |CON_VT_STATE+VT_CUR_COL
                BRA     @ch_exit
@ch_notBS
                ; Deferred-wrap check: if a prior printable wrote the last
                ; column, do the wrap now so this char lands at col 0 of
                ; the next row.
                PHA                         ; save char across SEP/REP
                SEP     #$20
                LDA    |CON_VT_STATE+VT_PENDING_WRAP
                BEQ     @ch_no_pending
                LDA     #0
                STA    |CON_VT_STATE+VT_PENDING_WRAP
                REP     #$20
                JSR     Con_CR
                PLA
                BRA     @ch_clamp
@ch_no_pending  REP     #$20
                PLA
@ch_clamp       ; partab's CLASSES DECIDE, and they used to be a clamp: every
                ; byte below $20 that was not CR/LF/BS became a SPACE and took
                ; a column with it.  apple/fgx#65.
                ;
                ; THE SPECIFICATION IS IN THE KERNEL, NOT IN A TERMINAL MANUAL.
                ; `ttyoutput' tracks the column it believes this screen is in --
                ; `t_col' -- by looking each byte up in `partab' and switching
                ; on the class (src/kernel/tty/tty.c, upstream tty.c):
                ;
                ;       ORDINARY   col++
                ;       CONTROL    (no change)
                ;       BACKSPACE  col--
                ;       NEWLINE
                ;       RETURN     col = 0
                ;       TAB        col = (col | 07) + 1
                ;
                ; partab types `^C' as CONTROL (0001) and TAB as TAB (0004), so
                ; the kernel's column does not move for the first and jumps to
                ; the next eight-stop for the second.  A console that instead
                ; drew a space for both DISAGREED WITH THE KERNEL ABOUT WHERE
                ; THE CURSOR IS -- and t_col is not decoration: ttyrub backs
                ; over echoed input with it, ttyoutput expands tabs from it, and
                ; ttyecho counts the width of a `^X' with it.
                ;
                ; MEASURED, and it is what apple/fgx#65 reported twenty days
                ; before the cause was found: with ctlecho off, every echoed
                ; `^C' silently ate a column, so a rapid burst walked the prompt
                ; rightwards until the line wrapped -- and a wrap on the last
                ; row scrolls.  "^C on the last screen line scrolls" and
                ; "rapid ^C occasionally emits a blank line" are that one bug.
                CMP     #$09                ; TAB: to the next eight-stop
                BEQ     @ch_tab
                CMP     #$20
                BCC     @ch_exit            ; CONTROL: no glyph, no column
                CMP     #$7F
                BEQ     @ch_exit            ; DEL: likewise
@ch_write
                PHA                         ; save char
                JSR     _Con_WriteCharAtCursor
                ; Fast per-cell render (avoids the ~6 ms full-row repaint
                ; per keystroke that would otherwise make typing prohibitive).
                LDA    |CON_VT_STATE+VT_CUR_ROW
                LDX    |CON_VT_STATE+VT_CUR_COL
                JSR     _Con_RenderCell
                PLA
                ; Deferred-wrap commit: if we just wrote the last column,
                ; set the pending flag and DON'T advance.  Otherwise INC.
                LDA    |CON_VT_STATE+VT_CUR_COL
                CMP     _Con_RowBytesM1
                BCC     @ch_advance
                ; col == last col: defer the wrap.
                SEP     #$20
                LDA     #1
                STA    |CON_VT_STATE+VT_PENDING_WRAP
                REP     #$20
                BRA     @ch_exit
@ch_advance     INC    |CON_VT_STATE+VT_CUR_COL
                BRA     @ch_exit
@ch_tab         ; `col = (col | 07) + 1' -- ttyoutput's own arithmetic for the
                ; TAB class, so the screen lands where t_col says it did.
                ;
                ; CLAMPED TO THE LAST COLUMN AND NEVER WRAPPED.  Upstream's
                ; expression has no ceiling because it is arithmetic on a
                ; counter, not a cursor; a real tab stops at the right margin.
                ; Clamping here is also what keeps the deferred-wrap flag
                ; meaningful -- it is set by a PRINTABLE that filled the last
                ; column, and a tab writes no glyph to defer.
                LDA    |CON_VT_STATE+VT_CUR_COL
                ORA     #$0007
                INC
                CMP     _Con_RowBytesM1
                BCC     @ch_tabSet
                LDA     _Con_RowBytesM1
@ch_tabSet      STA    |CON_VT_STATE+VT_CUR_COL
@ch_exit        PLP
                RTS

;------------------------------------------------------------------------------
; _Con_ClearPendingWrap - clear VT_PENDING_WRAP.  MX-state-robust.  Clobbers A.
;------------------------------------------------------------------------------
_Con_ClearPendingWrap
                PHP
                SEP     #$20
                LDA     #0
                STA    |CON_VT_STATE+VT_PENDING_WRAP
                PLP
                RTS

;------------------------------------------------------------------------------
; Con_CarriageReturn - CR ($0D): cursor to column 0, SAME row.  Clears wrap.
; The carriage-return half of a newline; pairs with Con_LineFeed.
;------------------------------------------------------------------------------
Con_CarriageReturn
                PHP
                REP     #$30
                MX      %00
                SEP     #$20
                LDA     #0
                STA    |CON_VT_STATE+VT_PENDING_WRAP
                REP     #$20
                LDA     #0
                STA    |CON_VT_STATE+VT_CUR_COL
                PLP
                RTS

;------------------------------------------------------------------------------
; Con_LineFeed - LF ($0A): cursor down one row, SAME column.  Clears wrap.
; Scroll-region-aware (shares the row-advance tail with Con_CR).
;------------------------------------------------------------------------------
Con_LineFeed
                PHP
                REP     #$30
                MX      %00
                SEP     #$20
                LDA     #0
                STA    |CON_VT_STATE+VT_PENDING_WRAP
                REP     #$20
                BRA     _Con_RowAdvance

;------------------------------------------------------------------------------
; Con_CR - full newline (CR + LF): advance cursor to (row+1, col 0).
; INTERNAL full-newline helper for kernel callers (boot/dmesg/toolbox) and the
; deferred-wrap path.  Scroll-region-aware:
;   - row < VT_SR_BOT: just increment (no scroll)
;   - row == VT_SR_BOT: if follow, scroll region up; else clamp at bot
;   - row > VT_SR_BOT: advance with clamp at VisRowsM1 (cursor outside region)
; Default VT_SR_BOT = 24, so behaviour is identical to previous code when
; no DECSTBM has been set.
;------------------------------------------------------------------------------
Con_CR
                PHP                             ; MX-state-robust wrapper
                REP     #$30
                MX      %00
                ; Explicit row advance clears any deferred-wrap state.
                SEP     #$20
                LDA     #0
                STA    |CON_VT_STATE+VT_PENDING_WRAP
                REP     #$20
                LDA     #0
                STA    |CON_VT_STATE+VT_CUR_COL
_Con_RowAdvance SEP     #$20
                LDA    |CON_VT_STATE+VT_CUR_ROW
                CMP     |CON_VT_STATE+VT_SR_BOT
                BCC     @cr_inc                 ; row < bot -> simple advance
                BEQ     @cr_atBot               ; row == bot -> scroll
                ; row > bot (cursor outside region): advance with clamp
                INC
                CMP     _Con_VisRows
                BCC     @cr_store8
                LDA     _Con_VisRowsM1
                BRA     @cr_store8
@cr_atBot
                LDA    |CON_VT_STATE+VT_FOLLOW
                BEQ     @cr_clampBot
                REP     #$20
                PHX                             ; MVN inside scroll clobbers X/Y
                PHY
                JSR     Con_ScrollRegionUp
                PLY
                PLX
                SEP     #$20
                LDA     |CON_VT_STATE+VT_SR_BOT
                STA    |CON_VT_STATE+VT_CUR_ROW
                BRA     @cr_exit
@cr_clampBot
                LDA     |CON_VT_STATE+VT_SR_BOT
                STA    |CON_VT_STATE+VT_CUR_ROW
                BRA     @cr_exit
@cr_inc         INC
@cr_store8      STA    |CON_VT_STATE+VT_CUR_ROW
@cr_exit        PLP
                RTS

;------------------------------------------------------------------------------
; _Con_WriteCharAtCursor - A (low byte) = char. Stores at
; CharBuf[ (topRow + curRow) mod bufRows, curCol ]. Preserves A.
;------------------------------------------------------------------------------
_Con_WriteCharAtCursor
                PHA                         ; save char
                ; Compute logical row = (topRow + curRow) mod bufRows
                LDA    |CON_VT_STATE+VT_TOP_ROW
                CLC
                ADC    |CON_VT_STATE+VT_CUR_ROW
                CMP    |CON_VT_STATE+VT_BUF_ROWS
                BCC     @wc_noWrap
                SBC    |CON_VT_STATE+VT_BUF_ROWS
@wc_noWrap      ; A WRITE ONTO THE RENDERED CURSOR CELL RETIRES THE CURSOR.
                ; apple/fgx#255.
                ;
                ; Con_ShowCursor OR-s the inverse bit into ONE AttrBuf cell and
                ; sets VT_CURS_RENDERED, and it is idempotent on that flag (the
                ; BNE at the top of it).  So a write that lands on that cell
                ; destroys the drawn cursor while leaving the flag set, and every
                ; later show is then a no-op.  The cursor does
                ; not come back until something HIDES first, which is why typing
                ; at a VC's `login:' prompt took the cursor away for the rest of
                ; the line's life while the `Password:' write brought it back.
                ;
                ; IT IS A BACKSTOP, NOT THE MECHANISM, and that changed at
                ; apple/fgx#287.  It was written as the whole cursor fix for the
                ; discipline's echo through kc_cdwrite, which hid nothing; that
                ; seam now hides first like every other writer (far_shims.s,
                ; `_FarSh_CdWrite'), so on every bracketed rail the flag is
                ; already clear here and the three instructions below exit at the
                ; first test.
                ;
                ; WHAT STILL REACHES IT UNBRACKETED is the kernel printing to the
                ; console directly rather than through a tty -- the boot log and
                ; the panic path -- and for those the write path remains the only
                ; place that knows a cell was overwritten.  A retire could not
                ; have covered the echo seam on its own in any case: it fires
                ; only when a byte lands ON the drawn cell, and BS, CR, LF and
                ; TAB move the caret and write no cell.
                ;
                ; RING ROW AND COLUMN, NOT THE VIEWPORT ROW: _conTopRow advances
                ; on every full-screen scroll, so a viewport comparison would
                ; drift the moment the console scrolled between the show and this
                ; write.  VT_CURS_SAVED_RROW is what Con_ShowCursor actually used
                ; -- recorded for exactly this reason at apple/fgx#116 -- and A
                ; holds the same ring row here.
                ;
                ; THE COMMON PATH IS THREE INSTRUCTIONS: a bracketed write has
                ; already hidden the cursor, so VT_CURS_RENDERED is 0 and the
                ; first test exits.
                PHA                         ; ring row, live for RingOffset below
                SEP     #$20
                LDA    |CON_VT_STATE+VT_CURS_RENDERED
                BEQ     @wc_curDone         ; no cursor drawn: nothing to retire
                LDA     1,S                 ; ring row (low byte of the push)
                CMP    |CON_VT_STATE+VT_CURS_SAVED_RROW
                BNE     @wc_curDone
                LDA    |CON_VT_STATE+VT_CUR_COL
                CMP    |CON_VT_STATE+VT_CURS_SAVED_COL
                BNE     @wc_curDone
                ; This write IS the cursor cell.  Clear the flag only -- the
                ; saved attr must NOT be restored, because the cell now holds
                ; the character just written rather than what was under the
                ; cursor.  Con_HideCursor's restore would put the old attribute
                ; back over new content; retiring the record is the whole fix.
                STZ    |CON_VT_STATE+VT_CURS_RENDERED
@wc_curDone     REP     #$20
                PLA                         ; ring row back
                JSR     _Con_RingOffset     ; A = logical_row * 80
                CLC
                ADC    |CON_VT_STATE+VT_CUR_COL          ; + curCol
                TAX                         ; X = byte offset from CharBuf base
                PLA                         ; A = char
                SEP     #$20
_kcb008         STAL    CON_CHARBUF,X       ; bank $03 CharBuf
                LDA     _conScratch7        ; cell attr (G bit + B/I/U flags)
_kcb009         STAL    CON_ATTRBUF,X
                LDA    |CON_VT_STATE+VT_FG              ; per-cell fg palette index
_kcb010         STAL    CON_FGBUF,X
                LDA    |CON_VT_STATE+VT_BG              ; per-cell bg palette index
_kcb011         STAL    CON_BGBUF,X
                REP     #$20
                RTS

;------------------------------------------------------------------------------
; Con_ShowCursor - render an inverse block cursor at (_conCurRow, _conCurCol).
; Idempotent: no-op if cursor is already on screen. Preserves all registers.
;
; Works by OR'ing the I (inverse) bit into the current AttrBuf cell and
; re-rendering. The original attr byte is stashed in CON_VT_STATE so
; Con_HideCursor can restore it without knowing anything about the cell's
; prior contents.
;------------------------------------------------------------------------------
Con_ShowCursor  MX      %00
                PHP
                PHA
                PHX
                PHY
                REP     #$30
                SEP     #$20
                LDA    |CON_VT_STATE+VT_CURS_RENDERED
                BNE     @sc_doneSep
                REP     #$20
                ; Compute cbOffset = ((topRow + curRow) mod bufRows) * 80 + curCol
                LDA    |CON_VT_STATE+VT_TOP_ROW
                CLC
                ADC    |CON_VT_STATE+VT_CUR_ROW
                CMP    |CON_VT_STATE+VT_BUF_ROWS
                BCC     @sc_noWrap
                SBC    |CON_VT_STATE+VT_BUF_ROWS
@sc_noWrap      ; SAVE THE RING ROW, not just the viewport row below.  The hide
                ; used to recompute the cell from VT_CURS_SAVED_ROW plus the
                ; CURRENT VT_TOP_ROW, so the two routines agreed only while the
                ; console had not scrolled between them -- and _conTopRow
                ; advances on every full-screen scroll.  A scroll in that window
                ; sent the restore to a different ring cell, which left the real
                ; cursor's inverse bit set forever AND overwrote an unrelated
                ; live cell with the attribute saved from under the cursor.
                ; VT_CURS_RENDERED is cleared either way, so the next show drew
                ; a SECOND cursor.  Recording what the show actually used is
                ; what makes the two unable to disagree (apple/fgx#116).
                PHA
                SEP     #$20
                STA    |CON_VT_STATE+VT_CURS_SAVED_RROW
                REP     #$20
                PLA
                JSR     _Con_RingOffset     ; A = logical_row * 80
                CLC
                ADC    |CON_VT_STATE+VT_CUR_COL
                TAX                         ; X = AttrBuf offset
                SEP     #$20
_kcb012         LDAL    CON_ATTRBUF,X
                STA    |CON_VT_STATE+VT_CURS_SAVED_ATTR
                ORA     #$20                ; I bit
_kcb013         STAL    CON_ATTRBUF,X
                REP     #$20
                ; THE VIEWPORT ROW IS NOT RECORDED, because a recorded one is a
                ; row that can go stale.  Con_HideCursor derives it from the ring
                ; row above and the CURRENT VT_TOP_ROW; VT_CURS_SAVED_ROW ($3D)
                ; is retired and its byte is free.
                LDA    |CON_VT_STATE+VT_CUR_COL
                SEP     #$20
                STA    |CON_VT_STATE+VT_CURS_SAVED_COL
                LDA     #1
                STA    |CON_VT_STATE+VT_CURS_RENDERED
                REP     #$20
                LDA    |CON_VT_STATE+VT_CUR_ROW
                LDX    |CON_VT_STATE+VT_CUR_COL
                JSR     _Con_RenderCell
@sc_done        PLY
                PLX
                PLA
                PLP
                RTS
@sc_doneSep     REP     #$20
                BRA     @sc_done

;------------------------------------------------------------------------------
; Con_HideCursor - restore original AttrBuf byte at the rendered position and
; re-render. Idempotent: no-op if cursor isn't currently on screen. Preserves
; all registers.
;------------------------------------------------------------------------------
Con_HideCursor  MX      %00
                PHP
                PHA
                PHX
                PHY
                REP     #$30
                SEP     #$20
                LDA    |CON_VT_STATE+VT_CURS_RENDERED
                BEQ     @hc_doneSep
                REP     #$20
                ; cbOffset = savedRingRow * 80 + savedCol, and savedRingRow is
                ; the row the SHOW resolved rather than one recomputed here from
                ; a VT_TOP_ROW that may have moved since.  The recomputation is
                ; gone entirely, which is the point: there is nothing left for
                ; the two routines to disagree about (apple/fgx#116).
                ;
                ; AND THE RENDER AT THE TAIL IS HELD TO THE SAME RULE NOW.  It
                ; took its row from VT_CURS_SAVED_ROW -- the VIEWPORT row the
                ; show recorded -- so the restore above and the repaint below
                ; named DIFFERENT CELLS the moment _conTopRow moved between the
                ; show and this hide.  apple/fgx#116 corrected the restore and
                ; left the repaint on the viewport row, which is the half that
                ; was still able to disagree; the row is derived from the ring
                ; row below and VT_CURS_SAVED_ROW is retired.  apple/fgx#287.
                LDA    |CON_VT_STATE+VT_CURS_SAVED_RROW
                AND     #$00FF
                JSR     _Con_RingOffset     ; A = logical_row * 80
                STA     _conTmp0
                LDA    |CON_VT_STATE+VT_CURS_SAVED_COL
                AND     #$00FF
                CLC
                ADC     _conTmp0
                TAX                         ; X = AttrBuf offset
                SEP     #$20
                LDA    |CON_VT_STATE+VT_CURS_SAVED_ATTR
_kcb014         STAL    CON_ATTRBUF,X
                LDA     #0
                STA    |CON_VT_STATE+VT_CURS_RENDERED
                REP     #$20
                ; Render the cell with restored attr, at the screen row the ring
                ; row is showing at NOW: screenRow = (ringRow - topRow) mod
                ; bufRows.  MEASURED 2026-09-01 with the old viewport row: with
                ; _conTopRow at 20, the restore corrected ring row 42 and the
                ; repaint went to screen row 23, so screen row 22 kept the
                ; inverse block's PIXELS with nothing in AttrBuf to explain them.
                ; That is a permanent ghost -- the row is only correct again when
                ; something else repaints it -- and it is invisible to any check
                ; that counts AttrBuf, which is why `vccursor' stayed green.
                LDA    |CON_VT_STATE+VT_CURS_SAVED_RROW
                AND     #$00FF
                SEC
                SBC    |CON_VT_STATE+VT_TOP_ROW
                BCS     @hc_haveRow
                CLC
                ADC    |CON_VT_STATE+VT_BUF_ROWS
@hc_haveRow     ; OFF SCREEN IS A REAL ANSWER, not an impossible one: the cell
                ; can have scrolled into the scrollback since the show.  AttrBuf
                ; is already correct, and the visible screen holds no part of
                ; that row, so there is nothing to repaint -- rendering anyway
                ; would paint scrollback content over a live screen row.
                CMP     #CON_VIS_ROWS
                BCS     @hc_done
                PHA
                LDA    |CON_VT_STATE+VT_CURS_SAVED_COL
                AND     #$00FF
                TAX
                PLA
                JSR     _Con_RenderCell
@hc_done        PLY
                PLX
                PLA
                PLP
                RTS
@hc_doneSep     REP     #$20
                BRA     @hc_done

;==============================================================================
; END console_char.s
;==============================================================================
