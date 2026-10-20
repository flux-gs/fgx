;==============================================================================
;
; FGX - Flux GS uniX
;
; File:     console.s
; Purpose:  Public API for the FGX console driver (src/drivers/console/)
; Created:  2026-04-18
;
; Phase 2 scope: stable API + memory layout + DP slot reservations. The
; implementation consolidates the code proven out by t52..t55 (Phase 1).
;
; ABI contract. All Con_* entries assume on entry:
;   - Native 65816 mode
;   - MX %00 (16-bit A, X, Y)
;   - DBR = kernel-bank (the kernel data bank; $02 = assembly ORG)
;   - DP  = $0000
;   - SHR enabled, SHADOW configured per prelude
; They return with the same CPU state. Any register may be clobbered unless
; the entry description explicitly lists a return value. Callers save what
; they need.
;
; The driver is NOT IRQ-safe in Phase 2. Single-threaded use only.
;
; Call Con_Init exactly once at boot before any other Con_* entry.
;
; Phase 2 omissions (API exists, renderer does not yet honor):
;   Con_SetFg / Con_SetBg   - stored in DP; renderer locked to V30 palette.
;                             Phase 3 plumbs 8-variant PreExpFont.
;   Multi-viewport / windows - single full-screen 25-row viewport only.
;                              Phase 4 generalizes with viewport handles.
;
;==============================================================================

;==============================================================================
; MEMORY LAYOUT
;
; All addresses owned by include/memmap.s.  This file declares only counts
; and strides, not addresses.  See memmap.s for:
;   - CON_CHARBUF / CON_ATTRBUF                  (bank $03 ring buffers)
;   - CON_ALT_CBUF / CON_ALT_ABUF                (bank $03 alt snapshots)
;   - CON_PREEXP_REG_BASE / CON_PREEXP_BOLD_BASE (bank $04 font tables)
;   - CON_EXPAND / CON_PREEXP / CON_VT_STATE /
;     CON_ALT_SAVE                               (bank $02 small tables)
;==============================================================================

; CON_EXPAND, CON_PREEXP, CON_ALT_SAVE, CON_VT_STATE: see include/memmap.s.
CON_EXP_STRIDE  EQU     32              ; Bytes per variant.
CON_EXP_COUNT   EQU     16              ; Variants total (attr 0..15).

; CON_PREEXP_REG_BASE, CON_PREEXP_BOLD_BASE (bank $04 font tables) and
; CON_CHARBUF / CON_ATTRBUF / CON_ALT_CBUF / CON_ALT_ABUF (bank $03 console
; ring buffers) are declared in include/memmap.s.
CON_PREEXP_NEW_STRIDE EQU  2016            ; 126 glyphs × 16 bytes per variant
CON_GLYPH_COUNT       EQU  126             ; 95 ASCII + 31 Special Graphics
CON_GLYPH_GFX_BASE    EQU  95              ; first Special-Graphics glyph index

CON_BUF_ROWS    EQU     100             ; Ring rows total.
CON_ROW_BYTES   EQU     80              ; Cols per row.
CON_VIS_ROWS    EQU     25              ; Visible viewport height.
CON_VIS_COLS    EQU     80              ; Visible viewport width.

CON_SHR_BASE    EQU     $012000         ; SHR pixel base (bank $01 shadowed).

;==============================================================================
; VT PARSER STATE (Plan 2)
;
; Persistent across Con_Write calls — parser picks up where it left off,
; matching Unix terminal semantics (byte-at-a-time with arbitrary chunking).
; CON_VT_STATE address is defined in include/memmap.s.
;==============================================================================

VT_STATE            EQU     $00             ; current parser state
VT_INT1             EQU     $01             ; first intermediate byte or 0
VT_INT2             EQU     $02             ; second intermediate byte or 0
VT_PRIVATE          EQU     $03             ; CSI private marker or 0
VT_NPARAMS          EQU     $04             ; params collected so far (0..16)
VT_PARAM_CUR        EQU     $05             ; index currently accumulating
VT_PARAMS           EQU     $08             ; 16 × 2 bytes, param[i] at +$08+i*2
VT_SGR_FG           EQU     $28             ; current SGR fg (0..15 or $FF)
VT_SGR_BG           EQU     $29             ; current SGR bg (0..15 or $FF)
VT_SGR_FLAGS        EQU     $2A             ; bit 0=bold, 1=reverse, 2=underline, 3=blink
VT_DEF_COLOR        EQU     $2B             ; default colour pair, bg<<4 | fg (CSI 8 ])
VT_SAVED_ROW        EQU     $2C             ; DECSC-saved cursor row
VT_SAVED_COL        EQU     $2D             ; DECSC-saved cursor col
VT_SAVED_ATTR       EQU     $2E             ; DECSC-saved attr
VT_SAVED_PAL        EQU     $2F             ; DECSC-saved auto-palette
VT_ROW_PALETTE      EQU     $30             ; current auto-picked palette for cursor's row ($FF = none)
VT_SR_TOP           EQU     $31             ; scroll region top (vpRow, 0..24)
VT_SR_BOT           EQU     $32             ; scroll region bottom (vpRow, 0..24)
VT_G0_CHARSET       EQU     $33             ; 0 = US-ASCII, 1 = DEC Special Graphics
VT_CURSOR_VISIBLE   EQU     $34             ; bit 0: DECTCEM (1 = visible)
VT_AUTOWRAP         EQU     $35             ; bit 0: DECAWM (1 = wrap)
VT_G1_CHARSET       EQU     $36             ; 0 = US-ASCII, 1 = DEC Special Graphics
VT_GL               EQU     $37             ; 0 = G0 in GL, 1 = G1 in GL
VT_SAVED_G0         EQU     $38             ; DECSC-saved G0 charset
VT_SAVED_G1         EQU     $39             ; DECSC-saved G1 charset
VT_SAVED_GL         EQU     $3A             ; DECSC-saved GL shift
VT_CURS_RENDERED    EQU     $3B             ; 1 if inverse block cursor is drawn
VT_CURS_SAVED_ATTR  EQU     $3C             ; original AttrBuf byte at rendered cell
VT_CURS_SAVED_ROW   EQU     $3D             ; RETIRED at apple/fgx#287, free.  It
                                            ;   held the VIEWPORT row the cursor
                                            ;   was rendered at, which goes stale
                                            ;   the moment VT_TOP_ROW moves --
                                            ;   Con_HideCursor restored the cell
                                            ;   named by VT_CURS_SAVED_RROW and
                                            ;   repainted the one named by this,
                                            ;   so a scroll in between left the
                                            ;   inverse block's pixels on screen
                                            ;   for good.  The screen row is
                                            ;   derived from the ring row now.
                                            ;   Do not resurrect it as a row: a
                                            ;   remembered viewport row is the
                                            ;   defect, not the storage.
VT_CURS_SAVED_COL   EQU     $3E             ; col where cursor was rendered
VT_PENDING_WRAP     EQU     $3F             ; deferred-wrap (xterm xn) flag:
                                            ;   set after a printable writes
                                            ;   the last column; the next
                                            ;   printable does the wrap.
                                            ;   Cleared by Con_CR, LF, BS,
                                            ;   Con_SetCursor, and the VT
                                            ;   cursor-positioning handlers.
VT_TAB_STOPS        EQU     $40             ; 10 bytes (80 cols / 8 = 10 bytes, bit per col)

;------------------------------------------------------------------------------
; THE CONSOLE SCALARS -- cursor, viewport and colour.  Formerly direct page
; $C0..$CF (include/dpmap.s); moved here 2026-08-13.
;
; They were always PER-VC state: console_switch.s saved and restored them at
; every virtual-console switch, and had to do it in a THIRD copy loop using
; dp,X because the direct page is an address space the far bank cannot reach
; DBR-relative.  That loop is what silently saved the wrong 16 bytes when it
; was first written as LDAL $0000C0,X, under an ERR guard that compared a DUM
; offset to itself and could not fail.  Living here, they are ordinary far-bank
; statics inside the block the VC switch already copies, so the DP half of that
; routine -- and its entire failure mode -- is deleted rather than fixed.
;
; They must stay INSIDE the per-VC range (below VCS_VT_LEN, far.s) and are
; therefore placed immediately after VT_TAB_STOPS, ahead of the globals below.
; The order matches the old DP layout so the two can be diffed byte for byte.
;
; Freeing $C0..$CF also hands 16 bytes back to a direct page that is full.
;------------------------------------------------------------------------------
VT_WRITE_PTR        EQU     $4A             ; 2 B: CharBuf write pointer
VT_TOP_ROW          EQU     $4C             ; 2 B: first displayed row in CharBuf
VT_FOLLOW           EQU     $4E             ; 1 B: 1 = viewport follows the cursor
VT_CURS_SAVED_RROW  EQU     $4F             ; 1 B: RING row the cursor was drawn
                                            ;   into, as opposed to the VIEWPORT
                                            ;   row in VT_CURS_SAVED_ROW.  It is
                                            ;   here rather than beside its two
                                            ;   siblings at $3D/$3E because this
                                            ;   is the only free byte left inside
                                            ;   the per-VC range, and per-VC is
                                            ;   where it has to be: it describes
                                            ;   one console's rendered cursor.
                                            ;   It was _conRenderState's old slot,
                                            ;   held as a pad so the scalar block
                                            ;   still diffed against DP $C0..$CF
                                            ;   after the 2026-08-13 move -- a
                                            ;   one-off convenience, now spent.
                                            ;   Safe to make live: every reader of
                                            ;   VT_FOLLOW ($4E) takes it 8-bit, so
                                            ;   nothing pulls this byte in above
                                            ;   it (the trap VT_RENDER_STATE's own
                                            ;   pad at $5B documents).
VT_BUF_ROWS         EQU     $50             ; 2 B: rows of scrollback in CharBuf
VT_CUR_ROW          EQU     $52             ; 2 B: cursor row (CharBuf row)
VT_CUR_COL          EQU     $54             ; 2 B: cursor column
VT_FG               EQU     $56             ; 1 B: foreground colour index
VT_FG_PAD           EQU     $57             ; 1 B: pad (was _conFgPad)
VT_BG               EQU     $58             ; 1 B: background colour index
VT_ATTR             EQU     $59             ; 1 B: current attribute byte

;------------------------------------------------------------------------------
; PAST HERE IS NOT PER-VC.  VCS_VT_LEN stops at $5A, so everything below is
; global to the console and survives a VC switch untouched.
;------------------------------------------------------------------------------
; _conRenderState is here rather than with the scalars above BECAUSE it is not
; session state.  It rode in the old DP block only by sitting inside $C0..$CF,
; and Con_LoadVCState deliberately forced it to 0 rather than restoring it: it
; describes a transient batching/suspension of the PIXEL pipeline, and a stale
; value is dangerous in both directions (a saved 2 freezes the incoming VC's
; pixels; a saved 3 reads as a live direct-SHR claim).
;
; BEING OUT HERE DOES NOT MAKE THE RESET REDUNDANT.  It stops the value coming
; back stale from a saved block; it does not clear the LIVE one, which still
; describes the outgoing VC's pipeline at the moment of the switch.
; Con_LoadVCState therefore still forces it to 0, and its header says why.
;
; It is also the ONE console scalar the CORE kernel touches, from syscall.s
; and process.s, through patched LDAL/STAL.
VT_RENDER_STATE     EQU     $5A             ; 1 B: 0=immediate, 3=suspended
                                            ;   (direct-SHR claim)
                                            ; $5B: pad, and it is LOAD-BEARING.
                                            ;   Two core-bank readers take this
                                            ;   cell 16-bit and AND #$00FF, so
                                            ;   the byte above is read every
                                            ;   time.  It stays zero because
                                            ;   Con_Init zeroes the region; put
                                            ;   a live field here and those
                                            ;   reads start carrying it.
; $5C..$67: free.
VT_BRACKET_RENDER   EQU     $68             ; 1 B: VT_RENDER_STATE as it stood when
                                            ;   Con_EnterVC opened a write bracket,
                                            ;   put back by Con_LeaveVC.  GLOBAL,
                                            ;   like VT_RENDER_STATE itself: it
                                            ;   describes a bracket in progress,
                                            ;   not a session.  Con_LeaveVC used to
                                            ;   end every bracket at 0 because
                                            ;   Con_LoadVCState forces that, which
                                            ;   silently cancelled a SYS_SCREEN_CTL
                                            ;   suspension and let console output
                                            ;   paint over an SHR owner's pixels
                                            ;   (apple/fgx#135).
                                            ;
                                            ;   ONE CELL FOR ALL BRACKETS, and
                                            ;   that is safe only because NO
                                            ;   BRACKET EVER SLEEPS.  Checked:
                                            ;   _Ttyv_Write is pure Con_Write;
                                            ;   the chardev op that can sleep
                                            ;   (_PtyM_Write) is never bracketed
                                            ;   (_Vc_FromCdIdx says C=0 for a
                                            ;   non-ttyv line); and
                                            ;   _Vc_DrainSwitch drains only at
                                            ;   safe points.  Let a bracketed
                                            ;   write block -- the D1.5 backend
                                            ;   ring at ttyv.s, or output flow
                                            ;   control -- and two interleaved
                                            ;   brackets both save a live 3 and
                                            ;   both restore it, freezing the
                                            ;   console at "suspended" with no
                                            ;   owner and nothing to clear it.
                                            ;   Make it per-bracket state before
                                            ;   making a bracket sleep.

; Parser state machine values (for VT_STATE).
VT_S_GROUND         EQU     0
VT_S_ESCAPE         EQU     1
VT_S_ESC_INT        EQU     2
VT_S_CSI_ENTRY      EQU     3
VT_S_CSI_PARAM      EQU     4
VT_S_CSI_INT        EQU     5
VT_S_CSI_IGNORE     EQU     6

;------------------------------------------------------------------------------
; Attribute byte format (Phase 4 layout):
;   bits 0..1  fg palette slot (0..3 within row's active palette)
;   bits 2..3  bg palette slot (0..3 within row's active palette)
;   bit  4     B  bold        (selects bold PreExp variant table)
;   bit  5     I  inverse     (nibble-swaps fg/bg at variant lookup)
;   bit  6     U  underline   (ORs fg-fill pattern onto scanline 7)
;   bit  7     G  graphics    (1 = char is DEC Special Graphics glyph)
; Variant index for renderer = low nibble (possibly swapped for I).
;------------------------------------------------------------------------------

;==============================================================================
; DIRECT PAGE RESERVATIONS
;
; The console driver owns DP slots $C0..$EF.  All console DP labels are
; declared in include/dpmap.s under the single authoritative DUM block;
; block/fs transient cells that used to alias $D0..$DD have been moved
; to $10..$1F, eliminating the cross-module overlap.
;==============================================================================

;==============================================================================
; PUBLIC ENTRY POINTS
;
; Declared as labels in the implementation files under src/drivers/console/.
; This section documents the contract; the actual code lives elsewhere.
;==============================================================================

;------------------------------------------------------------------------------
; Con_Init - one-time setup: SCBs, palette, font, SHR, DP state.
;
; In:   (none)                    Out: A/X/Y clobbered
; DP:   writes all _con* cells
; Mem:  reads/writes CON_PREEXP_REG_BASE, CON_PREEXP_BOLD_BASE, CON_SHR_BASE
;------------------------------------------------------------------------------
; Con_Clear - clear SHR display and home cursor. Ring buffer untouched.
;
; In:   (none)                    Out: A/X/Y clobbered
; DP:   writes _conCurRow, _conCurCol
; Mem:  writes CON_SHR_BASE
;------------------------------------------------------------------------------

;------------------------------------------------------------------------------
; Con_PutChar - write char at cursor with wrap and auto-scroll.
;
; In:   A (lo) = char ($0A=$0D=32-126)   Out: A/X/Y clobbered
;       _conFollow (affects scroll)      _conCurRow, _conCurCol advanced
; DP:   reads CON_VT_STATE, _conAttr, _conFollow; writes _conScratch*, CharBuf, AttrBuf
; Mem:  reads/writes CON_CHARBUF, CON_ATTRBUF, CON_SHR_BASE (render)
;------------------------------------------------------------------------------
; Con_PutLine - write null-terminated string then CR.
;
; In:   _conStrPtr = ptr to null-term string (bank $02)  Out: A/X/Y clobbered
; DP:   read/write as per Con_PutChar
; Mem:  read/write as per Con_PutChar
;------------------------------------------------------------------------------
; Con_CR - advance cursor to next row, col 0; auto-scroll if needed.
;
; In:   (none)                    Out: A/X/Y clobbered
;       _conFollow affects scroll
; DP:   reads CON_VT_STATE (scroll region); writes _conCurRow, _conCurCol
; Mem:  reads/writes CON_SHR_BASE if scrolling
;------------------------------------------------------------------------------
; Con_SetCursor - position cursor (clamped to viewport).
;
; In:   A = row (clamped to 0..24), X = col (clamped to 0..79)
;       Out: (none)
; DP:   writes _conCurRow, _conCurCol
; Mem:  (none)
;------------------------------------------------------------------------------
; Con_GetCursor - read current cursor position.
;
; In:   (none)                    Out: A = row, X = col
; DP:   reads _conCurRow, _conCurCol
; Mem:  (none)
;------------------------------------------------------------------------------

;------------------------------------------------------------------------------
; Con_SetRowPalette - set SCB palette for one 8-scanline row.
;
; In:   A = vpRow (0..24), X = palette idx (0..15)  Out: A/X/Y clobbered
; DP:   (none)
; Mem:  writes SHR SCBs ($019D00 + vpRow*8)
;------------------------------------------------------------------------------
; Con_SetFg - set foreground color and update _conAttr bits 0..1.
;
; In:   A (lo) = color slot 0..3 (clamped)   Out: (none)
; DP:   writes _conFg, _conAttr
; Mem:  (none)
;------------------------------------------------------------------------------
; Con_SetBg - set background color and update _conAttr bits 2..3.
;
; In:   A (lo) = color slot 0..3 (clamped)   Out: (none)
; DP:   writes _conBg, _conAttr
; Mem:  (none)
;------------------------------------------------------------------------------

;------------------------------------------------------------------------------
; Con_ScrollBack - pan viewport backward, shift pixels down, render top rows.
;
; In:   A = rows to pan back (clamped at 0)  Out: A/X/Y clobbered
; DP:   writes _conTopRow, _conFollow; reads _conBufRows, _Con_VisRows
; Mem:  reads/writes CON_SHR_BASE, CON_CHARBUF, CON_ATTRBUF (render)
;------------------------------------------------------------------------------
; Con_ScrollFwd - pan viewport forward, shift pixels up, render bottom rows.
;
; In:   A = rows to pan fwd (clamped)   Out: A/X/Y clobbered
; DP:   writes _conTopRow, _conFollow; reads _conBufRows, _Con_VisRows
; Mem:  reads/writes CON_SHR_BASE, CON_CHARBUF, CON_ATTRBUF
;------------------------------------------------------------------------------
; Con_RenderRow - re-render one visible row from CharBuf to SHR.
;
; In:   A = vpRow (0..24, clamped)   Out: A/X/Y clobbered
; DP:   reads/writes _Con_rr*, _conFontPtr, _conTmp*, _conScratch*
; Mem:  reads CON_CHARBUF, CON_ATTRBUF, CON_PREEXP_*; writes CON_SHR_BASE
;------------------------------------------------------------------------------
; Con_RenderAll - full 25-row repaint from CharBuf to SHR.
;
; In:   (none)                    Out: A/X/Y clobbered
; DP:   as per Con_RenderRow
; Mem:  as per Con_RenderRow
;------------------------------------------------------------------------------
; Con_SetFollow - enable/disable auto-scroll on write.
;
; In:   A (lo) = 0 or 1             Out: (none)
; DP:   writes _conFollow
; Mem:  (none)
;------------------------------------------------------------------------------
; Con_ShowCursor - render inverse block at cursor position; save original attr.
;
; In:   (none)                    Out: A/X/Y, flags preserved
; DP:   reads _conCurRow, _conCurCol, _conTopRow; writes CON_VT_STATE cursor fields
; Mem:  reads/writes CON_ATTRBUF, CON_SHR_BASE (render cell)
;------------------------------------------------------------------------------
; Con_HideCursor - restore original attr at saved cursor, re-render.
;
; In:   (none)                    Out: A/X/Y, flags preserved
; DP:   reads CON_VT_STATE (saved pos); writes CON_VT_STATE::VT_CURS_RENDERED
; Mem:  reads/writes CON_ATTRBUF, CON_SHR_BASE (render cell)
;------------------------------------------------------------------------------
; Con_Write - feed one byte through VT100 parser.
;
; In:   A (lo) = byte              Out: A/X/Y clobbered
; DP:   reads/writes CON_VT_STATE, affects _conCurRow/_conCurCol (via Con_PutChar)
; Mem:  reads/writes CON_CHARBUF, CON_ATTRBUF, CON_SHR_BASE (per parsed action)
;------------------------------------------------------------------------------
; Con_WriteBuf - feed buffer through VT100 parser.
;
; In:   _conStrPtr = ptr to buf (bank $02), X = length  Out: A/X/Y clobbered
; DP:   as per Con_Write
; Mem:  as per Con_Write
;------------------------------------------------------------------------------
; Con_VtReset - reset parser to GROUND state and clear SGR attributes.
;
; In:   (none)                    Out: A/X/Y clobbered
; DP:   writes CON_VT_STATE
; Mem:  (none)
;------------------------------------------------------------------------------
; Con_PollKey - non-blocking keyboard read (6502 IRQ via firmware).
;
; In:   (none)                    Out: C=0 if no key, C=1 + A=key code
; DP:   (none)
; Mem:  reads $C000/$C010 (keyboard, IIgs firmware)
;------------------------------------------------------------------------------
; Con_GetKey - blocking keyboard read; echoes to screen.
;
; In:   (none)                    Out: A = key code
; DP:   (none)
; Mem:  reads/writes $C000/$C010, CON_VT_STATE (echo via Con_Write)
;------------------------------------------------------------------------------

;==============================================================================
; _conMode — mode descriptor.  Populated at Con_Init from a per-mode entry
; in console_mode.s.  All mode-dependent code (renderer, SCB init, palette
; install, SGR-fg mapping) reads from this struct rather than hardcoding
; constants.  Total size: 20 bytes.  Stored at _conMode in bank-$02
; statics (see include/memmap.s).
;==============================================================================
CM_Cols            EQU  0      ; 1 byte — column count (80)
CM_Rows            EQU  1      ; 1 byte — visible row count (25 / 33)
CM_CellWpx         EQU  2      ; 1 byte — cell width in pixels (8 / 4)
CM_CellHpx         EQU  3      ; 1 byte — cell height in pixels (8 / 6)
CM_Bpp             EQU  4      ; 1 byte — bits per pixel (2 / 4)
CM_ScbModeByte     EQU  5      ; 1 byte — SCB byte template ($80 / $00)
CM_GlyphBytes      EQU  6      ; 2 bytes — glyph-block size for this mode/font
                               ;   (760 = 95×8 for 640, 756 = 126×6 for 320).
                               ;   Sizes the heap font buffer + the loader's
                               ;   read count, so new resolutions are dynamic.
CM_FontPath        EQU  8      ; 3 bytes — 24-bit ptr to the default font's
                               ;   disk path string (bank $02).  The boot/
                               ;   revert default font is loaded from disk into
                               ;   the heap; no glyph blob is compiled in.
CM_RenderRowFn     EQU  11     ; 3 bytes — 24-bit ptr to row renderer
CM_SgrToFgFn       EQU  14     ; 3 bytes — 24-bit ptr to SGR-fg mapper
CM_PaletteDataPtr  EQU  17     ; 3 bytes — 24-bit ptr to palette bank
CM_SIZE            EQU  20

; Mode IDs (index into _Con_ModeTable in console_mode.s).
CONMODE_640        EQU  0
; CONMODE_320 was EQU 1, "reserved for Phase 2".  That phase never came and
; the 320 console was not usable, so mode, renderer, palette and font were
; removed on 2026-09-01.  The descriptor table it indexed still exists with
; one entry, so a future second mode is an addition rather than a rewrite.

;==============================================================================
; END OF FILE
;==============================================================================
