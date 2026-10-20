;==============================================================================
;                          ███████ ██ ███    ███
;                          ██      ██ ████  ████
;                          ███████ ██ ██ ████ ██
;                               ██ ██ ██  ██  ██
;                          ███████ ██ ██      ██
;
;        ━━━━━━━━━━━━━━━ READ THIS BEFORE TOUCHING simtest ━━━━━━━━━━━━━━━
;
; WHAT WE ARE BUILDING (right now, this branch, this file):
;   An IRQ-driven serial I/O driver for FGX, validated as a standalone
;   prototype before being lifted into the kernel.  The primary deliverable
;   of this exercise is PROVING full-speed IRQ-driven serial I/O works
;   against MAME's serial terminal driver.
;
; WHY THIS IS A STANDALONE PROTOTYPE (not kernel-integrated yet):
;   The current FGX kernel manages VBL IRQ and leverages it for keyboard
;   polling and kernel tick scheduling (via Toolbox heartbeat).  When we
;   tried to add serial RX IRQ on top of that model, it BROKE BADLY.  So
;   we stepped back, studied GNO SIM (examples/gno/sys/sim/sim.asm), and
;   agreed SIM is the correct architectural pattern.  simtest is the
;   validation rig: prove SIM works for serial first, in isolation, with
;   no kernel confounds.
;
; WHAT GNO SIM ACTUALLY IS (so you stop drifting on this):
;   SIM patches the IIgs MAIN IRQ vector v_Main = $E10010.  It IS the
;   front of the IRQ dispatch chain — every IRQ on the machine runs SIM's
;   preamble first.  For each IRQ it:
;     1. Saves ROM state ($E1:0108..0119).
;     2. Pre-checks AppleTalk (BIT $E1:0103) — dispatches AppleTalk and exits.
;     3. Pre-checks MIDI (JSL $E1021C) — exits if MIDI claims it.
;     4. Reads RR3 chan A.  If a SIM handler is registered for the firing
;        SCC channel, JSL it.
;     5. Otherwise, JMP $FFBCFA (ROM 03) / $FFB843 (ROM 01) — chains into
;        ROM main handler, which dispatches VBL/ADB/sound/slot/etc and
;        runs the Toolbox heartbeat task chain we already depend on.
;
;   So SIM "owns" the IRQ entry point.  It dispatches custom handlers ONLY
;   for SCC (today).  Non-SCC IRQs are handed off to ROM main, which
;   continues to drive the FGX VBL/heartbeat path UNCHANGED.  Nothing the
;   kernel currently does for keyboard/tick breaks when SIM lands.
;
; ROADMAP (the long arc — don't conflate with this phase):
;   Phase 0 (here):  simtest standalone validates SIM dispatcher.  C0.5b
;                    onward installs a Toolbox heartbeat task INSIDE simtest
;                    so the NotScc → ROM main → firmware HB chain gets
;                    exercised against a real non-SCC IRQ source (proves
;                    the dispatcher coexists with VBL).
;   Phase 1:         lift SIM into src/kernel/sim.s, replace _KernIrq_Dispatch.
;                    Serial.mod migrates to SYS_SIM_INSTALL.  VBL/heartbeat
;                    KEEP working via ROM main (the kernel's own HB task
;                    chains the same way simtest's does now).
;   Phase 2+:        once stable, migrate other IRQ sources into SIM's
;                    registry (VBL, ADB, sound, ...) and retire Toolbox
;                    heartbeat.  THIS IS NOT IN SCOPE NOW — don't preempt.
;
; PRIMARY SOURCES — when in doubt, read these (not your memory):
;   - examples/gno/sys/sim/sim.asm        — the proven model, 716 lines
;   - examples/gno/sys/sim/sim.doc        — narrative description (ASCII)
;   - docs/superpowers/specs/2026-05-26-fgx-sim-design.md  — FGX spec
;   - docs/superpowers/plans/2026-05-26-fgx-sim.md         — phase plan
;==============================================================================
; simtest.s — standalone SIM-validation prototype.
;
; Boots at $02:2000 (same address as /FGX/KERNEL).  Stays in native MX %00
; throughout: gathers a snapshot via Toolbox calls into bank-$02 statics,
; then writes the rendered snapshot directly to text page 1 in 80-col mode
; — bank $E0:0400 (MAIN, odd display cols) and $E1:0400 (AUX, even cols).
;
; Phase-by-phase per docs/superpowers/plans/2026-05-26-fgx-sim.md:
;   C0.1:                boot + banner + idle loop.  No SCC, no SIM.
;   C0.2:                direct text-page-1 snapshot emit (80-col).  No COUT.
;   C0.3:                SCC chan B program + polled TX banner.
;   C0.4:                SIM dispatcher v1 + counter infrastructure.
;   C0.5:                IRQ-driven RX handler + ring + polled-TX echo.
;   C0.5a:               full IRQ-driven TX (SPSC ring + kickstart pattern).
;   C0.5b:               Toolbox HB bring-up validates NotScc dispatcher
;                        chain.  Plus C0.5c dispatcher exit DBR/stack fixes
;                        for all four ROM exit contracts ($FFBF58/$FFBCFA/
;                        $FFBD15/$FFBD16).
;   C0.5e (current HEAD):moved BRK detection to before the shadow-mask
;                        CMP #1.  CMP clobbered C, breaking the
;                        "was-emul-only" BCC, which misclassified any
;                        native IRQ entry with caller X=1 (main loop's
;                        MX %11 drain window) as BRK → wandering CPU
;                        crash after ~1 typed char interactively.
;                        See memory feedback_sim_brk_check_c_clobber.md.
;                        IRQ correctness is complete.
;   C0.6:                ^L / ^R / ^Z control bytes + SimRemove + runtime
;                        snapshot.  Pure UX/diagnostic; no IRQ design changes.
;   C0.7:                T0-T11 test matrix + spec sign-off → Phase 1.
;
; Spec: docs/superpowers/specs/2026-05-26-fgx-sim-design.md (rev 3) §6.0a-c.
;
; Architecture (single-phase, native mode throughout):
;   1. Gather phase: bank-$02 native, Toolbox calls populate _snapData.
;   2. Emit phase: same bank, same MX, writes directly to $E0:0400.
;      No bank-0 trampoline, no MVN, no XCE.  See
;      docs/iigs-lessons/lessons_iigs_hardware_firmware.md §10 for the
;      13+ commit history of why ROM COUT from bank ≠ $00 was abandoned.
;==============================================================================

                MX      %11
                ORG     $022000

;------------------------------------------------------------------------------
; Standalone DP + stack layout.  Conservative values that don't clash
; with anything the ROM/Toolbox uses by default.
;------------------------------------------------------------------------------
SIMT_DP         EQU     $1000               ; direct page (just below stage 2)
SIMT_STK_TOP    EQU     $1FFF               ; stack just below $2000 stage 2 zone

;------------------------------------------------------------------------------
; _snapData layout — bank-$02 cache populated by gather phase, read by
; tp1_print_snap via direct DBR-relative loads.
;
; Modem/Printer blocks contain 12 bytes each, in canonical param-ref order:
;   +0 PrntModem  +1 LineLnth  +2 DelLine    +3 AddLine
;   +4 Echo       +5 Buffer    +6 Baud       +7 DtStpBits
;   +8 Parity     +9 DCDHndShk +10 DSRHndShk +11 XnfHndShk
;------------------------------------------------------------------------------
SNAP_ROM            EQU 0                       ; 1 byte (Y.lo from IDROUTINE)
SNAP_ATALK          EQU 1                       ; 1 byte ($E10103)
SNAP_SERFLAG        EQU 2                       ; 1 byte ($E10104)
SNAP_MODEM_BLOCK    EQU 3                       ; 12 bytes (refs $0C..$17)
SNAP_PRINTER_BLOCK  EQU 15                      ; 12 bytes (refs $00..$0B)
SNAP_SIZE           EQU 27

; Field offsets within a 12-byte port block.
PB_PRNTMODEM        EQU 0
PB_LINELNTH         EQU 1
PB_DELLINE          EQU 2
PB_ADDLINE          EQU 3
PB_ECHO             EQU 4
PB_BUFFER           EQU 5
PB_BAUD             EQU 6
PB_DTSTPBITS        EQU 7
PB_PARITY           EQU 8
PB_DCD              EQU 9
PB_DSR              EQU 10
PB_XNFLOW           EQU 11

;------------------------------------------------------------------------------
; SCC chan B (modem port; slot 2).  Bank $E0 per FGX convention.
;------------------------------------------------------------------------------
SCC_B_CMD       EQU     $E0C038
SCC_B_DATA      EQU     $E0C03A
SCC_A_CMD       EQU     $E0C039             ; for future RR3 reads
RR0_RX_AVAIL    EQU     $01
RR0_TX_EMPTY    EQU     $04

;------------------------------------------------------------------------------
; Boot entry — JMPed to by stage 2 loader after MVN to $02:2000.
;------------------------------------------------------------------------------
SimtestEntry
                ; Switch to native mode + 16-bit.
                CLC
                XCE
                REP     #$30
                MX      %00

                ; Set DP + stack.
                LDA     #SIMT_DP
                TCD
                LDA     #SIMT_STK_TOP
                TCS

                ; DBR = $02 (our code+data bank).
                PHK
                PLB

                ; Mask IRQs until we're ready.
                SEI

                ; --- Gather phase: cache snapshot data into _snapData ---
                JSR     GatherSnapshotData

                ; --- Emit phase: direct writes to text page 1 ($E0:0400) ---
                JSR     tp1_video_init
                JSR     tp1_clear
                JSR     tp1_print_snap
                JSR     paint_stats_scaffold    ; rows 20-23 static labels

                ; --- SCC chan B program + polled-TX banner over modem port ---
                JSR     scc_program_chanB
                JSR     scc_tx_banner

                ; --- SIM dispatcher install (C0.4) ---
                ; Build the 4 ROM-exit JML slots from the cached ROM
                ; version, then patch $E10010 to vector through our
                ; dispatcher.
                JSR     SimInitExitTable
                JSR     _KernIrq_Install

                ; --- SIM handler install + SCC IRQ enable (C0.5) ---
                ; Register simtest_isr for chan B (mask $07), clear
                ; firmware SerFlag bits for chan B, then turn on SCC
                ; chan B IRQs (WR1=$12 RX+TX, WR9=$0A MIE+NV).  IRQs
                ; remain masked at CPU until Toolbox HB install below
                ; does CLI.
                JSR     SimInstall
                JSR     scc_enable_irqs

                ; --- Toolbox heartbeat install (C0.5b) ---
                ; Brings up minimal Toolbox + installs a VBL heartbeat
                ; task so the SIM dispatcher's NotScc path gets a real
                ; non-SCC IRQ source to chain to ROM main against.
                ; tbx_install_hb ends with CLI (its own PLP-then-CLI
                ; sequence), so no separate CLI needed below.
                JSR     tbx_init
                JSR     tbx_install_hb

                ; --- Main loop: WAI, drain kbd ring + Rx ring, repaint stats ---
                ; Initialize ring + TX state.  Statics are zeroed by Merlin
                ; DS but be explicit since this is the runtime entry.
                SEP     #$30
                MX      %11
                LDA     #0
                STA     _sccRxHead
                STA     _sccRxTail
                STA     _sccTxHead
                STA     _sccTxTail
                STA     _sccTxInProgress
                STA     _kbdRingHead
                STA     _kbdRingTail
                ; Both buffer cursors start at col 4 — just past the "TX> "
                ; / "RX< " 4-char prefix that paint_stats_scaffold painted.
                LDA     #4
                STA     _txCursor
                STA     _simtestCursor
                ; _kbdSecMod60 starts at 59 so the first INC _simStatSeconds
                ; happens after 60 VBLs (≈1 s), not immediately.
                LDA     #59
                STA     _kbdSecMod60
                REP     #$30
                MX      %00

@main_L         WAI
                SEP     #$30
                MX      %11

                ; --- Drain kbd ring: chars typed on the IIgs keyboard get
                ;     painted on row 22 (TX line) and transmitted out the
                ;     wire via tx_enqueue_byte. ---
@kbd_L          LDA     _kbdRingTail
                CMP     _kbdRingHead
                BEQ     @kbd_done
                LDX     _kbdRingTail
                LDA     _kbdRing,X
                INX
                STX     _kbdRingTail
                STA     _rxByteScratch         ; hand-off slot reused
                JSR     paint_tx_byte           ; row 22
                JSR     tx_enqueue_byte         ; transmit out chan B
                BRA     @kbd_L
@kbd_done

                ; --- Drain Rx ring: chars from the wire get painted on
                ;     row 23 (RX line).  NO echo — half-duplex. ---
@drain_L        LDA     _sccRxTail
                CMP     _sccRxHead
                BEQ     @drain_done
                LDX     _sccRxTail
                LDA     _sccRxBuf,X
                INX
                STX     _sccRxTail
                STA     _rxByteScratch
                JSR     paint_rx_byte           ; row 23
                BRA     @drain_L
@drain_done

                ; --- Repaint stats line (rows 20-21) from current
                ;     counter values, then back to WAI. ---
                REP     #$30
                MX      %00
                JSR     paint_stats_line

                BRA     @main_L

;------------------------------------------------------------------------------
; GatherSnapshotData — populate _snapData in bank-$02 native MX %00.
;
; Reads:
;   - ROM version via Misc.FWEntry($FE1F) IDROUTINE (Y.lo = version)
;   - ATlkFlag at $E10103 (LDAL direct)
;   - SerFlag  at $E10104 (LDAL direct)
;   - 12 control-panel fields for modem chan B (port 2) via
;       Misc.ReadBParam using parameter reference numbers $0C..$17
;       (p2PrntModem..p2XnfHndShk)
;   - 12 control-panel fields for printer chan A (port 1) via
;       Misc.ReadBParam using parameter reference numbers $00..$0B
;       (p1PrntModem..p1XnfHndShk)
;
; NB: ReadBParam takes a *parameter reference number*, NOT a raw BRAM
; byte offset.  The IIgs ROM maps the ref to whatever BRAM byte(s) it
; needs (some fields are bit-packed within shared bytes).  Reference
; numbers come from ORCACDefs/misctool.h.
;
; Toolbox dispatch convention (per gno-kern macros):
;   _FWEntry      LDX #$2403 / JSL $E10000
;   _ReadBParam   LDX #$0C03 / JSL $E10000
;
; _ReadBParam stack frame: PHA (result word) / PEA <refnum> / call / PLA
;   → low byte of pulled word = parameter value.
;
; _FWEntry stack frame (from examples/gno/sys/sim/sim.asm GetROMVersion):
;   PHA x4 (result space for A,X,Y,P 16-bit returns)
;   PHA x3 (input A,X,Y = 0)
;   PEA $FE1F (entry address)
;   call
;   PLY PLA PLA PLA — Y now holds returned Y register; TYA gives ROM ver
;------------------------------------------------------------------------------
GatherSnapshotData MX %00
                ; --- ROM version ---
                PHA                             ; result A
                PHA                             ; result X
                PHA                             ; result Y
                PHA                             ; result P
                LDA     #0
                PHA                             ; input A
                PHA                             ; input X
                PHA                             ; input Y
                PEA     $FE1F                   ; entry address
                LDX     #$2403                  ; Misc.FWEntry
                JSL     $E10000
                PLY                             ; pull returned Y
                PLA                             ; pull returned X
                PLA                             ; pull returned A (high word)
                PLA                             ; pull returned P
                TYA                             ; A.lo = ROM version
                SEP     #$30
                MX      %11
                STAL    _snapData+SNAP_ROM
                REP     #$30
                MX      %00

                ; --- ATlkFlag / SerFlag direct reads ---
                SEP     #$30
                MX      %11
                LDAL    $E10103
                STAL    _snapData+SNAP_ATALK
                LDAL    $E10104
                STAL    _snapData+SNAP_SERFLAG
                REP     #$30
                MX      %00

                ; --- Modem chan B params (refs $0C..$17 → 12 fields) ---
                LDX     #0
@gsd_modem      PHX                             ; preserve loop index
                LDA     #0
                PHA                             ; result placeholder
                TXA                             ; A = loop index (0..11)
                CLC
                ADC     #$000C                  ; refnum = $0C + index
                PHA                             ; refnum param
                LDX     #$0C03                  ; Misc.ReadBParam
                JSL     $E10000
                PLA                             ; pulled result word
                PLX                             ; restore loop index
                PHX                             ; (preserve again for store)
                SEP     #$30
                MX      %11
                STAL    _snapData+SNAP_MODEM_BLOCK,X
                REP     #$30
                MX      %00
                PLX
                INX
                CPX     #12
                BNE     @gsd_modem

                ; --- Printer chan A params (refs $00..$0B → 12 fields) ---
                LDX     #0
@gsd_printer    PHX
                LDA     #0
                PHA                             ; result placeholder
                TXA                             ; A = loop index (0..11) = refnum
                AND     #$00FF
                PHA                             ; refnum param
                LDX     #$0C03                  ; Misc.ReadBParam
                JSL     $E10000
                PLA                             ; pulled result word
                PLX
                PHX
                SEP     #$30
                MX      %11
                STAL    _snapData+SNAP_PRINTER_BLOCK,X
                REP     #$30
                MX      %00
                PLX
                INX
                CPX     #12
                BNE     @gsd_printer

                RTS

;==============================================================================
; Direct text-page-1 engine — 80-col mode.  All routines bank-$02 native
; MX %00 (with brief SEP/REP windows for byte stores).  Writes go straight
; to the Mega II video RAM at $E0:0400-$07FF (MAIN, odd display cols) and
; $E1:0400-$07FF (AUX, even display cols).  The IIgs VGC scans both banks
; whether or not shadowing is enabled — $E0/$E1 ARE the video chip's read
; path, the shadow register only affects whether bank-$00/$01 writes are
; mirrored down to them.  See docs/iigs-text-mode-mmio.md §2 for the full
; layout.
;==============================================================================

;------------------------------------------------------------------------------
; tp1_row_offsets — classic Apple II interleaved row addressing.
; Indexed by (row * 2); value is the byte offset from $0400 for the
; start of that text row.
;
;   rows  0..7  : $000,$080,$100,$180,$200,$280,$300,$380
;   rows  8..15 : $028,$0A8,$128,$1A8,$228,$2A8,$328,$3A8
;   rows 16..23 : $050,$0D0,$150,$1D0,$250,$2D0,$350,$3D0
;------------------------------------------------------------------------------
tp1_row_offsets DA      $0000,$0080,$0100,$0180,$0200,$0280,$0300,$0380
                DA      $0028,$00A8,$0128,$01A8,$0228,$02A8,$0328,$03A8
                DA      $0050,$00D0,$0150,$01D0,$0250,$02D0,$0350,$03D0

;------------------------------------------------------------------------------
; tp1_video_init — set up classic 80-col text mode.
;
; Writes NEWVIDEO=$00 (no SHR, no mono, no alt) and TBCOLOR=$F0
; (white fg, black bg), then strobes the classic soft switches:
; TXTON, PAGE1, 80-COL, primary charset, and clears
; 80STORE/RAMRD/RAMWRT to MAIN.  All I/O in bank $E0.
;
; In 80-col mode the display interleaves two banks per row:
;   AUX  ($E1:0400+) → even display cols (0, 2, 4, ..., 78)
;   MAIN ($E0:0400+) → odd  display cols (1, 3, 5, ..., 79)
; tp1_putc_at handles the bank selection per write.
;------------------------------------------------------------------------------
tp1_video_init  MX %00
                SEP     #$30
                MX      %11

                ; --- Register writes (real stores, $E0) ---
                LDA     #$00
                STAL    $E0C029                 ; NEWVIDEO = $00
                LDA     #$F0
                STAL    $E0C022                 ; TBCOLOR = $F0

                ; --- $C05x switches: read-or-write trigger ---
                LDAL    $00C051                 ; TXTON
                LDAL    $00C052                 ; MIXCLR
                LDAL    $00C054                 ; PAGE1
                LDAL    $00C056                 ; LORES (no hires bit)

                ; --- $C00x switches: WRITE-only trigger ---
                ; Reading these returns the keyboard register, NOT a toggle.
                STAL    $00C00D                 ; SET80VID (80-col text)
                STAL    $00C00E                 ; CLRALTCHAR (primary charset)
                STAL    $00C000                 ; CLR80STORE
                STAL    $00C002                 ; RAMRDOFF (read MAIN)
                STAL    $00C004                 ; RAMWRTOFF (write MAIN)

                REP     #$30
                MX      %00
                RTS

;------------------------------------------------------------------------------
; tp1_clear — fill text page 1 with high-ASCII space in both banks.
;
; 80-col mode reads from BOTH $E0:0400..$07FF (MAIN, odd cols) and
; $E1:0400..$07FF (AUX, even cols).  Clear both so unused bytes don't
; bleed garbage onto the screen.
;------------------------------------------------------------------------------
tp1_clear       MX %00
                SEP     #$30
                MX      %11
                LDA     #$A0                    ; high-ASCII space
                ; --- MAIN ($E0) pass: odd display columns ---
                LDX     #0
@tc_M           STAL    $E00400,X
                STAL    $E00500,X
                STAL    $E00600,X
                STAL    $E00700,X
                INX
                BNE     @tc_M
                ; --- AUX ($E1) pass: even display columns ---
                LDX     #0
@tc_A           STAL    $E10400,X
                STAL    $E10500,X
                STAL    $E10600,X
                STAL    $E10700,X
                INX
                BNE     @tc_A
                REP     #$30
                MX      %00
                RTS

;------------------------------------------------------------------------------
; tp1_putc_at — write one high-ASCII char to text page 1 at (row, col).
;
; Inputs (via bank-$02 scratch):
;   _tp1_arg_row  = row (0..23)
;   _tp1_arg_col  = col (0..79)   ; 80-col mode
;   _tp1_arg_char = char (will have $80 OR'd; pass plain ASCII)
;
; Entry MX %00 native.  Returns MX %00.
;
; 80-col bank mapping (see docs/iigs-text-mode-mmio.md §2):
;   AUX  ($E1) ← even display cols (col & 1 == 0): 0, 2, 4, ..., 78
;   MAIN ($E0) ← odd  display cols (col & 1 == 1): 1, 3, 5, ..., 79
;   byte_offset_within_row = col >> 1
;
; Implementation: computes effective offset (row_offset + (col>>1) + $0400),
; patches operand bytes (+1, +2) AND the bank byte (+3) of the trailing
; STAL, then performs the store.  Caller has SEI'd (single-task standalone),
; no IRQ races on the self-mod.
;------------------------------------------------------------------------------
tp1_putc_at     MX %00
                ; row index → Y = row * 2 (table is 16-bit entries).
                LDA     _tp1_arg_row            ; loads 16-bit; high byte = _tp1_arg_col
                AND     #$00FF                  ; isolate row byte
                ASL     A
                TAY                              ; Y = row*2 (0..46)
                LDA     tp1_row_offsets,Y       ; A = 16-bit row offset (0..$3D0)
                STA     _tp1_eff_offset         ; stash

                ; Compute bank byte from col bit 0:
                ;   col bit 0 == 0 → AUX  ($E1)
                ;   col bit 0 == 1 → MAIN ($E0)
                ; Stash in DP for the SEP-#$30 byte store below.
                SEP     #$30
                MX      %11
                LDA     _tp1_arg_col
                AND     #$01
                BNE     @pc_main
                LDA     #$E1
                BRA     @pc_bank_set
@pc_main        LDA     #$E0
@pc_bank_set    STA     _tp1_bank_sel
                REP     #$30
                MX      %00

                ; A = (col >> 1) (zero-extended) + row_offset + $0400.
                LDA     _tp1_arg_col            ; loads 16-bit; high byte = _tp1_arg_char
                AND     #$00FF
                LSR     A                       ; col >> 1
                CLC
                ADC     _tp1_eff_offset
                CLC
                ADC     #$0400
                STA     _tp1_smc+1              ; patch STAL operand low+high

                ; Patch the STAL bank byte (+3) from _tp1_bank_sel.
                SEP     #$30
                MX      %11
                LDA     _tp1_bank_sel
                STA     _tp1_smc+3              ; patch bank byte ($E0 or $E1)

                ; Emit char.
                LDA     _tp1_arg_char
                ORA     #$80                    ; high-ASCII bit
_tp1_smc        STAL    $E00400                 ; bytes +1,+2,+3 patched above
                REP     #$30
                MX      %00
                RTS

;------------------------------------------------------------------------------
; tp1_puts_at — write NUL-terminated string at (row, col).
;
; Inputs (via bank-$02 scratch):
;   _tp1_arg_row = row
;   _tp1_arg_col = starting col
;   _tp1_arg_ptr = 16-bit bank-$02 offset to NUL-terminated ASCII string
;
; Walks the string, advancing col on each char.  No wrap (caller responsible).
;------------------------------------------------------------------------------
tp1_puts_at     MX %00
                LDY     #0
@ps_L           SEP     #$30
                MX      %11
                LDA     (_tp1_arg_ptr),Y        ; needs DP-resident ptr -- see below
                BEQ     @ps_done
                STA     _tp1_arg_char
                REP     #$30
                MX      %00
                PHY
                JSR     tp1_putc_at
                PLY
                INY
                ; Advance col by 1.
                SEP     #$30
                MX      %11
                INC     _tp1_arg_col
                REP     #$30
                MX      %00
                BRA     @ps_L
@ps_done        REP     #$30
                MX      %00
                RTS

;------------------------------------------------------------------------------
; tp1_puthex2_at — write 2 hex digits at (row, col), advance _tp1_arg_col by 2.
;
; Inputs:
;   _tp1_arg_row, _tp1_arg_col = position
;   _tp1_arg_char              = byte to render
;------------------------------------------------------------------------------
tp1_puthex2_at  MX %00
                ; High nibble.
                SEP     #$30
                MX      %11
                LDA     _tp1_arg_char
                STA     _tp1_hex_byte           ; preserve original
                LSR     A
                LSR     A
                LSR     A
                LSR     A
                JSR     _tp1_emit_nibble
                ; Low nibble.
                LDA     _tp1_hex_byte
                AND     #$0F
                JSR     _tp1_emit_nibble
                REP     #$30
                MX      %00
                RTS

; _tp1_emit_nibble — entry SEP-#$30 MX %11.  A.lo = nibble 0..15.
; Renders one hex digit at (_tp1_arg_row, _tp1_arg_col), advances col.
_tp1_emit_nibble
                MX %11
                CMP     #10
                BCC     @en_d09
                CLC
                ADC     #'A'-10
                BRA     @en_emit
@en_d09         CLC
                ADC     #'0'
@en_emit        STA     _tp1_arg_char
                ; Need MX %00 for tp1_putc_at internals (CLC/ADC #$0400 etc).
                REP     #$30
                MX      %00
                PHA
                JSR     tp1_putc_at
                PLA
                SEP     #$30
                MX      %11
                INC     _tp1_arg_col
                RTS

;------------------------------------------------------------------------------
; tp1_putdec_at — emit a 32-bit unsigned value as N decimal digits at
; (_tp1_arg_row, _tp1_arg_col), zero-padded.  Advances _tp1_arg_col by N.
;
; In:   _tp1_arg_dec_val (DP $12..$15, 4 bytes LSB-first; clobbered)
;       _tp1_arg_dec_n   (DP $16, 1 byte; 1..10 digits to emit)
;       _tp1_arg_row, _tp1_arg_col set.  MX %00 / DBR=$02 on entry.
; Out:  N chars written; _tp1_arg_col += N.
;
; Algorithm: for each digit position from MSB to LSB, trial-subtract the
; corresponding power-of-10 from _tp1_arg_dec_val.  Count subtractions
; until 32-bit underflow; emit (count + '0').  X holds the table byte
; offset (entries are 4 bytes, big-endian by position so X advances by 4
; per digit).  Up to 9 subtractions per digit; cheap at 60 Hz.
;------------------------------------------------------------------------------
tp1_putdec_at   MX %00
                PHP
                PHX                             ; preserve X for caller
                REP     #$30
                MX      %00

                ; --- X = (10 - N) * 4 = byte offset into power-of-10 table
                ;     to skip the leading powers we don't want to emit. ---
                SEP     #$20
                MX      %10
                LDA     #10
                SEC
                SBC     _tp1_arg_dec_n          ; A = 10 - N (1..9)
                REP     #$20
                MX      %00
                AND     #$00FF
                ASL     A
                ASL     A
                TAX                             ; X = entries-to-skip * 4

                ; --- Outer digit loop: digits emitted so far in _putdec_idx ---
                SEP     #$20
                MX      %10
                STZ     _putdec_idx
                REP     #$20
                MX      %00

@putdec_outer
                ; --- digit = 0 ---
                SEP     #$20
                MX      %10
                STZ     _putdec_digit
                REP     #$20
                MX      %00

@putdec_inner
                ; --- 32-bit trial-subtract: tmp = val - pow10[X] ---
                SEC
                LDA     _tp1_arg_dec_val        ; low 16 bits of val (DP)
                SBC     _tp1_dec_pow10,X        ; low 16 bits of pow10 (DBR=$02)
                STA     _putdec_tmp
                LDA     _tp1_arg_dec_val+2      ; high 16 bits of val
                SBC     _tp1_dec_pow10+2,X      ; high 16 bits of pow10
                BCC     @putdec_done_inner      ; underflow → digit complete
                ; tmp >= 0: accept the subtract
                STA     _tp1_arg_dec_val+2
                LDA     _putdec_tmp
                STA     _tp1_arg_dec_val
                SEP     #$20
                MX      %10
                INC     _putdec_digit
                REP     #$20
                MX      %00
                BRA     @putdec_inner

@putdec_done_inner
                ; --- Emit ASCII digit at (_tp1_arg_row, _tp1_arg_col) ---
                SEP     #$30
                MX      %11
                LDA     _putdec_digit
                CLC
                ADC     #'0'
                STA     _tp1_arg_char
                REP     #$30
                MX      %00
                JSR     tp1_putc_at             ; writes char (does NOT advance col)

                ; --- Advance _tp1_arg_col for next digit.  Convention is
                ;     "tp1_putc_at writes; caller advances" (see how
                ;     _tp1_emit_nibble does it on line ~641).  MX %10 here
                ;     keeps X as 16-bit (table-offset register). ---
                SEP     #$20
                MX      %10
                INC     _tp1_arg_col
                REP     #$20
                MX      %00

                ; --- Advance to next-smaller power (X += 4) ---
                INX
                INX
                INX
                INX

                ; --- Loop while digits-emitted < N ---
                SEP     #$20
                MX      %10
                INC     _putdec_idx
                LDA     _putdec_idx
                CMP     _tp1_arg_dec_n
                REP     #$20
                MX      %00
                BCC     @putdec_outer

                PLX                             ; restore caller X
                PLP
                RTS

; --- tp1_putdec_at bank-$02 statics (not DP — survive SEP/REP transitions
;     without risk of DP-scratch aliasing).
_putdec_idx     DS      1
_putdec_digit   DS      1
_putdec_tmp     DS      2

; --- Power-of-10 table (32-bit, LSB first), entries [0..9] = 10^9..10^0.
;     Indexed by X as byte offset (entry i lives at X = i*4).
_tp1_dec_pow10  HEX     00CA9A3B                ; 10^9 = 1000000000 = $3B9ACA00
                HEX     00E1F505                ; 10^8 = 100000000  = $05F5E100
                HEX     80969800                ; 10^7 = 10000000   = $00989680
                HEX     40420F00                ; 10^6 = 1000000    = $000F4240
                HEX     A0860100                ; 10^5 = 100000     = $000186A0
                HEX     10270000                ; 10^4 = 10000      = $00002710
                HEX     E8030000                ; 10^3 = 1000       = $000003E8
                HEX     64000000                ; 10^2 = 100        = $00000064
                HEX     0A000000                ; 10^1 = 10         = $0000000A
                HEX     01000000                ; 10^0 = 1

;==============================================================================
; tp1_print_snap — render the =BOOT= snapshot to text page 1 (80-col).
;
; Side-by-side layout — modem column at col 0, printer column at col 40.
; Each port renders 13 decoded fields at rows 5..17, leaving rows 18+
; free for Task 4+ SIM-state additions.
;
;   row  0 :  =BOOT=
;   row  2 :  ROM ver:    XX  (ROM XX)                    ATalk:      XX
;   row  4 :  -- modem chan B (port 2) --                  -- printer chan A (port 1) --
;   row  5 :    PortType:  Modem                             PortType:  Printer
;   row  6 :    LineLngth: 80                                LineLngth: 80
;   ... 13 decoded rows (rows 5..17)
;   row 19 :  SerFlag:    XX
;==============================================================================
tp1_print_snap  MX %00
                ; --- row 0: =BOOT= ---
                JSR     _ps_set_row0
                LDA     #s_boot
                STA     _tp1_arg_ptr
                SEP     #$30
                MX      %11
                LDA     #0
                STA     _tp1_arg_col
                REP     #$30
                MX      %00
                JSR     tp1_puts_at

                ; --- row 2 col 0: ROM ver:    XX  (label) ---
                JSR     _ps_setup_row2_rom
                ; emit hex byte
                SEP     #$30
                MX      %11
                LDA     _snapData+SNAP_ROM
                STA     _tp1_arg_char
                REP     #$30
                MX      %00
                JSR     tp1_puthex2_at
                ; "  (" label
                LDA     #s_paren
                STA     _tp1_arg_ptr
                JSR     tp1_puts_at
                ; ROM XX string
                SEP     #$30
                MX      %11
                LDA     _snapData+SNAP_ROM
                CMP     #1
                BEQ     @ps_rom01
                CMP     #3
                BEQ     @ps_rom03
                REP     #$30
                MX      %00
                LDA     #s_romunk
                BRA     @ps_rom_emit
@ps_rom01       REP     #$30
                MX      %00
                LDA     #s_rom01
                BRA     @ps_rom_emit
@ps_rom03       REP     #$30
                MX      %00
                LDA     #s_rom03
@ps_rom_emit    STA     _tp1_arg_ptr
                JSR     tp1_puts_at
                ; trailing ')'
                SEP     #$30
                MX      %11
                LDA     #')'
                STA     _tp1_arg_char
                REP     #$30
                MX      %00
                JSR     tp1_putc_at

                ; --- row 2 col 40: ATalk:      XX ---
                SEP     #$30
                MX      %11
                LDA     #2
                STA     _tp1_arg_row
                LDA     #40
                STA     _tp1_arg_col
                REP     #$30
                MX      %00
                LDA     #s_atalk
                STA     _tp1_arg_ptr
                JSR     tp1_puts_at
                SEP     #$30
                MX      %11
                LDA     _snapData+SNAP_ATALK
                STA     _tp1_arg_char
                REP     #$30
                MX      %00
                JSR     tp1_puthex2_at

                ; --- row 4 col 0: modem header ---
                SEP     #$30
                MX      %11
                LDA     #4
                STA     _tp1_arg_row
                LDA     #0
                STA     _tp1_arg_col
                REP     #$30
                MX      %00
                LDA     #s_modem
                STA     _tp1_arg_ptr
                JSR     tp1_puts_at

                ; --- row 4 col 40: printer header ---
                SEP     #$30
                MX      %11
                LDA     #4
                STA     _tp1_arg_row
                LDA     #40
                STA     _tp1_arg_col
                REP     #$30
                MX      %00
                LDA     #s_printer
                STA     _tp1_arg_ptr
                JSR     tp1_puts_at

                ; --- Decoded rows 5..17 for modem (col base 0) ---
                SEP     #$30
                MX      %11
                LDA     #SNAP_MODEM_BLOCK
                STA     _pf_block_off
                LDA     #0
                STA     _pf_col_base
                REP     #$30
                MX      %00
                JSR     _ps_render_port

                ; --- Decoded rows 5..17 for printer (col base 40) ---
                SEP     #$30
                MX      %11
                LDA     #SNAP_PRINTER_BLOCK
                STA     _pf_block_off
                LDA     #40
                STA     _pf_col_base
                REP     #$30
                MX      %00
                JSR     _ps_render_port

                ; --- row 19 col 0: SerFlag:    XX ---
                SEP     #$30
                MX      %11
                LDA     #19
                STA     _tp1_arg_row
                LDA     #0
                STA     _tp1_arg_col
                REP     #$30
                MX      %00
                LDA     #s_serflag
                STA     _tp1_arg_ptr
                JSR     tp1_puts_at
                SEP     #$30
                MX      %11
                LDA     _snapData+SNAP_SERFLAG
                STA     _tp1_arg_char
                REP     #$30
                MX      %00
                JSR     tp1_puthex2_at

                RTS

; Helpers used above.

_ps_set_row0    MX %00
                SEP     #$30
                MX      %11
                LDA     #0
                STA     _tp1_arg_row
                LDA     #0
                STA     _tp1_arg_col
                REP     #$30
                MX      %00
                RTS

_ps_setup_row2_rom MX %00
                SEP     #$30
                MX      %11
                LDA     #2
                STA     _tp1_arg_row
                LDA     #0
                STA     _tp1_arg_col
                REP     #$30
                MX      %00
                LDA     #s_rom
                STA     _tp1_arg_ptr
                JSR     tp1_puts_at
                RTS

;------------------------------------------------------------------------------
; _ps_render_port — render 13 decoded field rows for one port block.
;
; Inputs (DP):
;   _pf_block_off : SNAP_MODEM_BLOCK or SNAP_PRINTER_BLOCK (byte)
;   _pf_col_base  : 0 or 40                                (byte)
;
; Walks pf_descriptors (13 entries × 4 bytes):
;   +0 field_offset within port block (PB_*)
;   +1 decoder_id (0..8; 0xFF in upper nibble bits indicate special)
;   +2..3 16-bit address of label string
;
; For each entry: set row = 5 + i, col = col_base + 3, puts label,
; then dispatches to decoder with A = raw byte value loaded from
; _snapData + _pf_block_off + field_offset.
;------------------------------------------------------------------------------
_ps_render_port MX %00
                LDX     #0                          ; X = entry index 0..12
@rp_L           PHX
                ; --- row = 5 + i ---
                SEP     #$30
                MX      %11
                TXA
                CLC
                ADC     #5
                STA     _tp1_arg_row
                ; --- col = col_base + 3 ---
                LDA     _pf_col_base
                CLC
                ADC     #3
                STA     _tp1_arg_col
                REP     #$30
                MX      %00

                ; --- pointer to descriptor entry: pf_descriptors + (X * 4) ---
                ; X is currently 16-bit (we're MX %00).  Multiply by 4 in A.
                PLX
                PHX
                TXA
                ASL     A
                ASL     A
                TAY                                  ; Y = X*4

                ; Load label addr (entry +2, +3) into _tp1_arg_ptr
                LDA     pf_descriptors+2,Y
                STA     _tp1_arg_ptr

                ; Save decoder_id + field_offset into DP for after puts call
                SEP     #$30
                MX      %11
                LDA     pf_descriptors+0,Y          ; field offset within block
                STA     _pf_field_off
                LDA     pf_descriptors+1,Y          ; decoder id
                STA     _pf_dec_id
                REP     #$30
                MX      %00

                ; --- emit label (advances _tp1_arg_col) ---
                JSR     tp1_puts_at

                ; --- load raw value from snap block ---
                ; absolute index: _snapData + _pf_block_off + _pf_field_off
                ; Compute index in Y (16-bit), then LDAL _snapData,Y for byte.
                SEP     #$30
                MX      %11
                LDA     _pf_block_off
                CLC
                ADC     _pf_field_off
                STA     _pf_value_idx
                REP     #$30
                MX      %00
                LDA     _pf_value_idx
                AND     #$00FF
                TAY
                SEP     #$30
                MX      %11
                LDA     _snapData,Y                  ; raw value byte
                STA     _pf_raw
                REP     #$30
                MX      %00

                ; --- dispatch decoder by id ---
                SEP     #$30
                MX      %11
                LDA     _pf_dec_id
                REP     #$30
                MX      %00
                JSR     _dispatch_decoder

                ; --- diagnostic: append ' (XX)' with raw byte ---
                ; tp1_puts_at has already advanced _tp1_arg_col past
                ; the decoded value.  Emit space, '(', hex, ')'.
                SEP     #$30
                MX      %11
                LDA     #' '
                STA     _tp1_arg_char
                REP     #$30
                MX      %00
                JSR     tp1_putc_at
                SEP     #$30
                MX      %11
                INC     _tp1_arg_col
                LDA     #'('
                STA     _tp1_arg_char
                REP     #$30
                MX      %00
                JSR     tp1_putc_at
                SEP     #$30
                MX      %11
                INC     _tp1_arg_col
                LDA     _pf_raw
                STA     _tp1_arg_char
                REP     #$30
                MX      %00
                JSR     tp1_puthex2_at          ; advances col by 2
                SEP     #$30
                MX      %11
                LDA     #')'
                STA     _tp1_arg_char
                REP     #$30
                MX      %00
                JSR     tp1_putc_at

                PLX
                INX
                CPX     #13
                BEQ     @rp_done
                BRL     @rp_L                       ; long branch — body grew past ±127
@rp_done        RTS

;------------------------------------------------------------------------------
; _dispatch_decoder — call decoder routine.
; Entry: A.lo = decoder id (MX %00 on entry).  _pf_raw holds raw value.
; Each decoder uses (_tp1_arg_row, _tp1_arg_col) as cursor and emits
; a decoded ASCII string.  All preserve MX %00 on exit.
;------------------------------------------------------------------------------
_dispatch_decoder MX %00
                AND     #$00FF
                CMP     #0
                BNE     @dd_n1
                JMP     _dec_portype
@dd_n1          CMP     #1
                BNE     @dd_n2
                JMP     _dec_linelnth
@dd_n2          CMP     #2
                BNE     @dd_n3
                JMP     _dec_off_on
@dd_n3          CMP     #3
                BNE     @dd_n4
                JMP     _dec_yes_no
@dd_n4          CMP     #4
                BNE     @dd_n5
                JMP     _dec_buffer
@dd_n5          CMP     #5
                BNE     @dd_n6
                JMP     _dec_baud
@dd_n6          CMP     #6
                BNE     @dd_n7
                JMP     _dec_databits
@dd_n7          CMP     #7
                BNE     @dd_n8
                JMP     _dec_stopbits
@dd_n8          CMP     #8
                BNE     @dd_unk
                JMP     _dec_parity
@dd_unk         ; unknown id — emit "?"
                SEP     #$30
                MX      %11
                LDA     #'?'
                STA     _tp1_arg_char
                REP     #$30
                MX      %00
                JSR     tp1_putc_at
                RTS

;------------------------------------------------------------------------------
; Decoder helpers.  Each takes _pf_raw as the raw byte and emits a decoded
; ASCII string at (_tp1_arg_row, _tp1_arg_col).  All return MX %00.
;
; The pattern: select a string pointer, stash in _tp1_arg_ptr, call
; tp1_puts_at.  Strings live in low ASCII; tp1_putc_at adds the $80 bit.
;------------------------------------------------------------------------------

; _emit_str — common tail: A = 16-bit string address, emit via tp1_puts_at.
_emit_str       MX %00
                STA     _tp1_arg_ptr
                JSR     tp1_puts_at
                RTS

; _dec_portype : 0=Printer, 1=Modem, else "?"
_dec_portype    MX %00
                SEP     #$30
                MX      %11
                LDA     _pf_raw
                CMP     #0
                BEQ     @dp_printer
                CMP     #1
                BEQ     @dp_modem
                REP     #$30
                MX      %00
                LDA     #s_unk
                BRL     _emit_str
@dp_printer     REP     #$30
                MX      %00
                LDA     #s_printer_v
                BRL     _emit_str
@dp_modem       REP     #$30
                MX      %00
                LDA     #s_modem_v
                BRL     _emit_str

; _dec_linelnth : 0=Unlmtd, 1=40, 2=72, 3=80, 4=132 (fixed 6-char width)
_dec_linelnth   MX %00
                SEP     #$30
                MX      %11
                LDA     _pf_raw
                CMP     #0
                BEQ     @dl_unlmtd
                CMP     #1
                BEQ     @dl_40
                CMP     #2
                BEQ     @dl_72
                CMP     #3
                BEQ     @dl_80
                CMP     #4
                BEQ     @dl_132
                REP     #$30
                MX      %00
                LDA     #s_unk
                BRL     _emit_str
@dl_unlmtd      REP     #$30
                MX      %00
                LDA     #s_v_unlmtd
                BRL     _emit_str
@dl_40          REP     #$30
                MX      %00
                LDA     #s_v_40
                BRL     _emit_str
@dl_72          REP     #$30
                MX      %00
                LDA     #s_v_72
                BRL     _emit_str
@dl_80          REP     #$30
                MX      %00
                LDA     #s_v_80
                BRL     _emit_str
@dl_132         REP     #$30
                MX      %00
                LDA     #s_v_132
                BRL     _emit_str

; _dec_off_on : 0=off, 1=on
_dec_off_on     MX %00
                SEP     #$30
                MX      %11
                LDA     _pf_raw
                BNE     @doo_on
                REP     #$30
                MX      %00
                LDA     #s_off
                BRL     _emit_str
@doo_on         REP     #$30
                MX      %00
                LDA     #s_on
                BRL     _emit_str

; _dec_yes_no : 0=no, 1=yes
_dec_yes_no     MX %00
                SEP     #$30
                MX      %11
                LDA     _pf_raw
                BNE     @dyn_yes
                REP     #$30
                MX      %00
                LDA     #s_no
                BRL     _emit_str
@dyn_yes        REP     #$30
                MX      %00
                LDA     #s_yes
                BRL     _emit_str

; _dec_buffer : 0=none, 1=256B
_dec_buffer     MX %00
                SEP     #$30
                MX      %11
                LDA     _pf_raw
                BNE     @db_256
                REP     #$30
                MX      %00
                LDA     #s_none
                BRL     _emit_str
@db_256         REP     #$30
                MX      %00
                LDA     #s_256b
                BRL     _emit_str

; _dec_parity : 0=even, 1=odd, 2=none (observed; CP order differs from storage)
_dec_parity     MX %00
                SEP     #$30
                MX      %11
                LDA     _pf_raw
                CMP     #0
                BEQ     @dpa_even
                CMP     #1
                BEQ     @dpa_odd
                CMP     #2
                BEQ     @dpa_none
                REP     #$30
                MX      %00
                LDA     #s_unk
                BRL     _emit_str
@dpa_none       REP     #$30
                MX      %00
                LDA     #s_none
                BRL     _emit_str
@dpa_odd        REP     #$30
                MX      %00
                LDA     #s_odd
                BRL     _emit_str
@dpa_even       REP     #$30
                MX      %00
                LDA     #s_even
                BRL     _emit_str

; _dec_baud : 1..15 → lookup in baud_strings table (16 entries; 0 = "?")
_dec_baud       MX %00
                SEP     #$30
                MX      %11
                LDA     _pf_raw
                AND     #$0F                         ; clamp to 0..15
                ASL     A
                REP     #$30
                MX      %00
                AND     #$001F
                TAY
                LDA     baud_strings,Y
                BRL     _emit_str

; _dec_databits : data_bits = 5 + (raw >> 1) for raw 0..7; else "?"
; Encoding (verified $06=8/1):
;   0=5  1=5  2=6  3=6  4=7  5=7  6=8  7=8
_dec_databits   MX %00
                SEP     #$30
                MX      %11
                LDA     _pf_raw
                CMP     #8
                BCS     @ddb_unk                ; raw >= 8 → unknown
                LSR     A                       ; raw >> 1 → 0..3
                CMP     #0
                BEQ     @ddb_5
                CMP     #1
                BEQ     @ddb_6
                CMP     #2
                BEQ     @ddb_7
                REP     #$30
                MX      %00
                LDA     #s_8
                BRL     _emit_str
@ddb_5          REP     #$30
                MX      %00
                LDA     #s_5
                BRL     _emit_str
@ddb_6          REP     #$30
                MX      %00
                LDA     #s_6
                BRL     _emit_str
@ddb_7          REP     #$30
                MX      %00
                LDA     #s_7
                BRL     _emit_str
@ddb_unk        REP     #$30
                MX      %00
                LDA     #s_unk
                BRL     _emit_str

; _dec_stopbits : stop_bits = 1 + (raw & 1).  even=1, odd=2.
; Shares raw byte with _dec_databits (PB_DTSTPBITS encodes both fields).
_dec_stopbits   MX %00
                SEP     #$30
                MX      %11
                LDA     _pf_raw
                AND     #$01
                BNE     @dsb_2
                REP     #$30
                MX      %00
                LDA     #s_1
                BRL     _emit_str
@dsb_2          REP     #$30
                MX      %00
                LDA     #s_2
                BRL     _emit_str

;------------------------------------------------------------------------------
; Per-port field descriptors.  13 entries × 4 bytes each.
;   +0 field_offset within port block (PB_*)
;   +1 decoder id (0..8)
;   +2..3 16-bit address of label string
;------------------------------------------------------------------------------
pf_descriptors
                DFB PB_PRNTMODEM, 0
                DA  s_lbl_portype
                DFB PB_LINELNTH,  1
                DA  s_lbl_linelnth
                DFB PB_ECHO,      2
                DA  s_lbl_echo
                DFB PB_ADDLINE,   3
                DA  s_lbl_addlf
                DFB PB_DELLINE,   3
                DA  s_lbl_delline
                DFB PB_BUFFER,    4
                DA  s_lbl_buffer
                DFB PB_BAUD,      5
                DA  s_lbl_baud
                DFB PB_DTSTPBITS, 6
                DA  s_lbl_databits
                DFB PB_DTSTPBITS, 7
                DA  s_lbl_stopbits
                DFB PB_PARITY,    8
                DA  s_lbl_parity
                DFB PB_DCD,       2
                DA  s_lbl_dcd
                DFB PB_DSR,       2
                DA  s_lbl_dsr
                DFB PB_XNFLOW,    2
                DA  s_lbl_xnflow

;------------------------------------------------------------------------------
; baud_strings — 16-entry table of 16-bit pointers to baud strings.
; Index = baud code (0..15).  Index 0 is invalid → "?".
;------------------------------------------------------------------------------
baud_strings
                DA s_b_unk          ; 0  (invalid)
                DA s_b_50           ; 1
                DA s_b_75           ; 2
                DA s_b_110          ; 3
                DA s_b_135          ; 4
                DA s_b_300          ; 5
                DA s_b_600          ; 6
                DA s_b_1200         ; 7
                DA s_b_1800         ; 8
                DA s_b_2400         ; 9
                DA s_b_3600         ; 10
                DA s_b_4800         ; 11
                DA s_b_7200         ; 12
                DA s_b_9600         ; 13
                DA s_b_19200        ; 14
                DA s_b_57600        ; 15

;------------------------------------------------------------------------------
; String constants (NUL-terminated, ASCII low form; tp1_putc_at ORs $80).
;------------------------------------------------------------------------------
s_boot          ASC '=BOOT='
                DFB $00
s_rom           ASC 'ROM ver:    '
                DFB $00
s_atalk         ASC 'ATalk:      '
                DFB $00
s_modem         ASC '-- modem chan B (port 2) --'
                DFB $00
s_printer       ASC '-- printer chan A (port 1) --'
                DFB $00
s_serflag       ASC 'SerFlag:    '
                DFB $00
s_paren         ASC '  ('
                DFB $00
s_rom01         ASC 'ROM 01'
                DFB $00
s_rom03         ASC 'ROM 03'
                DFB $00
s_romunk        ASC 'ROM ??'
                DFB $00

; C0.5f live-display labels — rendered once by paint_stats_scaffold.
s_stats_row20   ASC 'TIME 00:00  HB 000000  TOT 000000  NOTSCC 000000'
                DFB $00
s_stats_row21   ASC 'RX-IRQ 00000  TX-IRQ 00000  RX-BYTES 00000  TX-BYTES 00000'
                DFB $00
s_tx_prefix     ASC 'TX> '
                DFB $00
s_rx_prefix     ASC 'RX< '
                DFB $00

; Field labels — 11 chars wide so values align at col+14.
s_lbl_portype   ASC 'PortType:  '
                DFB $00
s_lbl_linelnth  ASC 'LineLngth: '
                DFB $00
s_lbl_echo      ASC 'Echo:      '
                DFB $00
s_lbl_addlf     ASC 'AddLF:     '
                DFB $00
s_lbl_delline   ASC 'DelLine:   '
                DFB $00
s_lbl_buffer    ASC 'Buffer:    '
                DFB $00
s_lbl_baud      ASC 'Baud:      '
                DFB $00
s_lbl_databits  ASC 'DataBits:  '
                DFB $00
s_lbl_stopbits  ASC 'StopBits:  '
                DFB $00
s_lbl_parity    ASC 'Parity:    '
                DFB $00
s_lbl_dcd       ASC 'DCD:       '
                DFB $00
s_lbl_dsr       ASC 'DSR:       '
                DFB $00
s_lbl_xnflow    ASC 'XnFlow:    '
                DFB $00

; Decoded-value strings.
s_unk           ASC '?'
                DFB $00
s_printer_v     ASC 'Printer'
                DFB $00
s_modem_v       ASC 'Modem  '
                DFB $00
s_v_unlmtd      ASC 'Unlmtd'
                DFB $00
s_v_40          ASC '40    '
                DFB $00
s_v_72          ASC '72    '
                DFB $00
s_v_80          ASC '80    '
                DFB $00
s_v_132         ASC '132   '
                DFB $00
s_off           ASC 'off'
                DFB $00
s_on            ASC 'on '
                DFB $00
s_no            ASC 'no '
                DFB $00
s_yes           ASC 'yes'
                DFB $00
s_none          ASC 'none'
                DFB $00
s_256b          ASC '256B'
                DFB $00
s_odd           ASC 'odd '
                DFB $00
s_even          ASC 'even'
                DFB $00
s_1             ASC '1'
                DFB $00
s_2             ASC '2'
                DFB $00
s_5             ASC '5'
                DFB $00
s_6             ASC '6'
                DFB $00
s_7             ASC '7'
                DFB $00
s_8             ASC '8'
                DFB $00

; Baud strings — indexed by baud code 1..15.
s_b_unk         ASC '?'
                DFB $00
s_b_50          ASC '50   '
                DFB $00
s_b_75          ASC '75   '
                DFB $00
s_b_110         ASC '110  '
                DFB $00
s_b_135         ASC '135  '
                DFB $00
s_b_300         ASC '300  '
                DFB $00
s_b_600         ASC '600  '
                DFB $00
s_b_1200        ASC '1200 '
                DFB $00
s_b_1800        ASC '1800 '
                DFB $00
s_b_2400        ASC '2400 '
                DFB $00
s_b_3600        ASC '3600 '
                DFB $00
s_b_4800        ASC '4800 '
                DFB $00
s_b_7200        ASC '7200 '
                DFB $00
s_b_9600        ASC '9600 '
                DFB $00
s_b_19200       ASC '19200'
                DFB $00
s_b_57600       ASC '57600'
                DFB $00

;------------------------------------------------------------------------------
; Bank-$02 static data.  Note: tp1_puts_at uses (_tp1_arg_ptr),Y which
; requires the pointer to live in *direct page*, not bank-$02 absolute.
; We rely on the fact that Merlin assembles (_tp1_arg_ptr),Y as
; "(dp),Y" only when _tp1_arg_ptr is itself a DP label.  Since these
; live in bank-$02 absolute, (...) syntax there would assemble as
; (abs),Y which is opcode for jmp only — not LDA.  Workaround: copy
; the pointer into DP at the top of tp1_puts_at, or use DP slots.
;
; Cleanest fix: stash these in DP.  We're at DP=$1000 (bank-$02
; offset), so we can carve out a few bytes there via fixed equates.
;------------------------------------------------------------------------------

; DP scratch (DP base = $1000, so these are at $1002..$100B).
_tp1_arg_row    EQU     $02                     ; DP offset
_tp1_arg_col    EQU     $03
_tp1_arg_char   EQU     $04
_tp1_arg_ptr    EQU     $06                     ; 2 bytes
_tp1_eff_offset EQU     $08                     ; 2 bytes
_tp1_hex_byte   EQU     $0A
_tp1_bank_sel   EQU     $0B                     ; $E0 or $E1 per col bit 0

; Per-port-field rendering scratch (snapshot decoder).
_pf_block_off   EQU     $0C                     ; SNAP_MODEM_BLOCK or _PRINTER_BLOCK
_pf_col_base    EQU     $0D                     ; 0 or 40
_pf_field_off   EQU     $0E                     ; PB_* offset within block
_pf_dec_id      EQU     $0F                     ; decoder id 0..8
_pf_value_idx   EQU     $10                     ; cached block_off + field_off
_pf_raw         EQU     $11                     ; raw byte value

; tp1_putdec_at args (4-byte value + 1-byte digit count).  $02..$11 are
; in use above; $12..$16 are the next contiguous free slots.
_tp1_arg_dec_val EQU    $12                     ; 4 bytes (LSB first)
_tp1_arg_dec_n   EQU    $16                     ; 1 byte (digit count, 1..10)

;==============================================================================
; SCC chan B programming + polled-TX banner.  Lifted verbatim from
; src/modules/serial/serial.s (phase-1 form: WR1=$00, no SerFlag clear,
; no WR9 master enable — no SCC interrupts yet).  IRQ work comes in
; C0.4 (SIM dispatcher) and C0.5 (test handler).
;==============================================================================

;------------------------------------------------------------------------------
; scc_program_chanB — program SCC chan B for 9600-8N1, RX+TX enabled,
; interrupts off.  Per Tech Note #18 sequence; PHP/SEI/PLP wraps the
; multi-step register accesses so a same-time chan A IRQ can't tear
; them.
;
; Baud time-constant math (PCLK = 3.6864 MHz, x16 clock):
;   TC = PCLK / (2 * N * baud) - 2
;   For x16 clock + 9600 baud:
;     TC = 3686400 / (2 * 16 * 9600) - 2 = 12 - 2 = 10 = $0A
;------------------------------------------------------------------------------
scc_program_chanB MX %00
                PHP
                SEP     #$30                            ; M=8 X=8 for byte bashing
                MX      %11
                SEI                                     ; block chan A IRQ races

                ; --- Sync: read RR0 once so the SCC state machine is
                ;     aligned to register-0 selection.
                LDAL    SCC_B_CMD

                ; WR4 = $44  (x16 clock, 1 stop, no parity)
                LDA     #$04
                STAL    SCC_B_CMD
                LDA     #$44
                STAL    SCC_B_CMD

                ; WR3 = $C0  (8 bits/char, RX DISABLED — will enable later)
                LDA     #$03
                STAL    SCC_B_CMD
                LDA     #$C0
                STAL    SCC_B_CMD

                ; WR5 = $62  (8 bits/char, TX DISABLED, DTR on, RTS off)
                LDA     #$05
                STAL    SCC_B_CMD
                LDA     #$62
                STAL    SCC_B_CMD

                ; WR11 = $50  (chan B → use chan A's xtal; RX clk = BRG;
                ;              TX clk = BRG)
                LDA     #$0B
                STAL    SCC_B_CMD
                LDA     #$50
                STAL    SCC_B_CMD

                ; WR12 = $0A  (BRG time-constant lo = 9600 @ 3.6864 MHz)
                LDA     #$0C
                STAL    SCC_B_CMD
                LDA     #$0A
                STAL    SCC_B_CMD

                ; WR13 = $00  (BRG TC hi = 0)
                LDA     #$0D
                STAL    SCC_B_CMD
                LDA     #$00
                STAL    SCC_B_CMD

                ; WR14 = $00  (BRG src = /RTxC, BRG disabled — preamble)
                LDA     #$0E
                STAL    SCC_B_CMD
                LDA     #$00
                STAL    SCC_B_CMD

                ; WR14 = $01  (enable BRG)
                LDA     #$0E
                STAL    SCC_B_CMD
                LDA     #$01
                STAL    SCC_B_CMD

                ; WR3 = $C1  (8 bits, RX ENABLED)
                LDA     #$03
                STAL    SCC_B_CMD
                LDA     #$C1
                STAL    SCC_B_CMD

                ; WR5 = $6A  (8 bits, TX ENABLED, DTR on, RTS off)
                LDA     #$05
                STAL    SCC_B_CMD
                LDA     #$6A
                STAL    SCC_B_CMD

                ; WR15 = $00  (no external/status interrupts)
                LDA     #$0F
                STAL    SCC_B_CMD
                LDA     #$00
                STAL    SCC_B_CMD

                ; WR1 = $00  (no SCC interrupts in slice 3; slice 4
                ;             flips bit 4 = RX-int-every-char + bit 1
                ;             = status-affects-vector)
                LDA     #$01
                STAL    SCC_B_CMD
                LDA     #$00
                STAL    SCC_B_CMD

                PLP
                RTS

;------------------------------------------------------------------------------
; scc_tx_banner — polled-TX a NUL-terminated string from tx_banner_str.
; Wait for RR0 bit 2 (Tx buffer empty) before each byte.  No IRQ here
; — slice 3 keeps it simple; slice 4+ will add IRQ-driven TX as needed.
;------------------------------------------------------------------------------
scc_tx_banner   MX %00
                PHP
                SEP     #$30
                MX      %11
                LDY     #0
@txb_L          LDA     tx_banner_str,Y
                BEQ     @txb_done
@txb_wait       LDAL    SCC_B_CMD                       ; RR0
                AND     #RR0_TX_EMPTY
                BEQ     @txb_wait
                LDA     tx_banner_str,Y
                STAL    SCC_B_DATA
                INY
                BRA     @txb_L
@txb_done       PLP
                RTS

tx_banner_str   DFB     $0D,$0A
                ASC     'simtest C0.5a: SCC chan B 9600-8N1 (IRQ TX/RX)'
                DFB     $0D,$0A,$00

;==============================================================================
; SIM dispatcher v1 (C0.4).
;
; Mirrors the gno-kern SIM (sim/sim.asm:ROM03IntVect lines 114-216).
; Hooks the IIgs main IRQ vector at $E10010 with our own dispatcher.
; Tier-1 handler registry walks _simHandlerTbl on RR3 hits; non-SCC IRQs
; chain straight to ROM's main IRQ handler.  Tier-0 (AppleTalk + MIDI)
; left as commented stubs per spec §3.3 — single comment-toggle when
; ready.
;
; Spec: docs/superpowers/specs/2026-05-26-fgx-sim-design.md §3.3
; Lesson: docs/iigs-lessons/lessons_iigs_hardware_firmware.md §10
;==============================================================================

;------------------------------------------------------------------------------
; SimInitExitTable — populate the 4 ROM-exit JML slots from ROMVersion.
;
; Each slot is "JML $FFxxxx" — 4 bytes: opcode $5C + 24-bit target.
; ROM 01 and ROM 03 have different exit addresses; default to ROM 03
; for ROM 0 / unknown.
;
; In:   MX %00.  DBR=$02.
; Out:  4 exit slots populated.  MX %00 preserved.
;------------------------------------------------------------------------------
SimInitExitTable MX %00
                PHP
                SEP     #$30
                MX      %11

                LDA     _snapData+SNAP_ROM
                CMP     #1
                BEQ     @sit_rom01

                ; ---- ROM 03 (and unknown) ----
                ; brk     = $FFBD16
                ; handled = $FFBF58
                ; sccChn  = $FFBD15
                ; main    = $FFBCFA
                LDA     #$5C
                STA     _simExitBrk
                LDA     #$16
                STA     _simExitBrk+1
                LDA     #$BD
                STA     _simExitBrk+2
                LDA     #$FF
                STA     _simExitBrk+3

                LDA     #$5C
                STA     _simExitHandled
                LDA     #$58
                STA     _simExitHandled+1
                LDA     #$BF
                STA     _simExitHandled+2
                LDA     #$FF
                STA     _simExitHandled+3

                LDA     #$5C
                STA     _simExitSccChn
                LDA     #$15
                STA     _simExitSccChn+1
                LDA     #$BD
                STA     _simExitSccChn+2
                LDA     #$FF
                STA     _simExitSccChn+3

                LDA     #$5C
                STA     _simExitMain
                LDA     #$FA
                STA     _simExitMain+1
                LDA     #$BC
                STA     _simExitMain+2
                LDA     #$FF
                STA     _simExitMain+3
                BRA     @sit_done

@sit_rom01
                ; ---- ROM 01 ----
                ; brk     = $FFB85F
                ; handled = $FFBA86
                ; sccChn  = $FFB85E
                ; main    = $FFB843
                LDA     #$5C
                STA     _simExitBrk
                LDA     #$5F
                STA     _simExitBrk+1
                LDA     #$B8
                STA     _simExitBrk+2
                LDA     #$FF
                STA     _simExitBrk+3

                LDA     #$5C
                STA     _simExitHandled
                LDA     #$86
                STA     _simExitHandled+1
                LDA     #$BA
                STA     _simExitHandled+2
                LDA     #$FF
                STA     _simExitHandled+3

                LDA     #$5C
                STA     _simExitSccChn
                LDA     #$5E
                STA     _simExitSccChn+1
                LDA     #$B8
                STA     _simExitSccChn+2
                LDA     #$FF
                STA     _simExitSccChn+3

                LDA     #$5C
                STA     _simExitMain
                LDA     #$43
                STA     _simExitMain+1
                LDA     #$B8
                STA     _simExitMain+2
                LDA     #$FF
                STA     _simExitMain+3

@sit_done       PLP
                RTS

;------------------------------------------------------------------------------
; _KernIrq_Install — patch the IIgs main IRQ vector at $E10010 with our
; dispatcher trampoline.  Must be called with IRQs masked (SEI'd).
;
; Saves the original 4-byte JML instruction (opcode + 24-bit target)
; into _kernIrqSavedVect for diagnostics / future chain-fallback.
;
; In:   IRQs masked.  MX %00.  DBR=$02.
; Out:  $E10010 patched.  MX %00 preserved.
;------------------------------------------------------------------------------
_KernIrq_Install MX %00
                PHP
                REP     #$30
                MX      %00

                ; --- Save original $E10010..$E10013 (4 bytes) ---
                LDAL    $E10010
                STA     _kernIrqSavedVect
                LDAL    $E10012
                STA     _kernIrqSavedVect+2

                ; --- Write "JML _KernIrq_Dispatch" at $E10010 ---
                SEP     #$20
                MX      %10
                LDA     #$5C                    ; JML opcode
                STAL    $E10010
                LDA     #<_KernIrq_Dispatch
                STAL    $E10011
                LDA     #>_KernIrq_Dispatch
                STAL    $E10012
                LDA     #^_KernIrq_Dispatch
                STAL    $E10013
                REP     #$20
                MX      %00

                PLP
                RTS

;------------------------------------------------------------------------------
; _KernIrq_Dispatch — SIM-style IRQ dispatcher entry point.
;
; Entered from ROM JML at $E10010 with the firmware IRQ frame on the
; stack.  CPU may be in emul or native, MX unknown.  We force native
; MX %00, save state to ROM-expected slots at $E1:0108..0119, read
; SCC RR3, then either:
;   - BRK detected     → JMP _simExitBrk    (ROM BRK handler)
;   - Not-SCC          → JMP _simExitMain   (ROM IRQ priority chain)
;   - SCC + claimed    → JMP _simExitHandled (ROM exit, IUS reset)
;   - SCC + unclaimed  → JMP _simExitSccChn (ROM "SCC unclaimed" exit)
;
; Mirrors sim.asm:ROM03IntVect (lines 117-216).
;------------------------------------------------------------------------------
_KernIrq_Dispatch
                ; --- Preamble: force native, MX %00, save state ---
                CLC
                XCE                             ; → native (carry-set if were emul)
                REP     #$30
                MX      %00
                PHP                             ; save the just-set 16-bit P
                PHB                             ; save caller DBR (8-bit push)
                PEA     $E1E1
                PLB                             ; DBR = $E1

                ; Save A/X/Y/D to ROM-expected slots in bank $E1.
                ; DBR=$E1 makes |$01xx reach $E1:01xx (ROM slot area).
                ; (STA/STX/STY/TDC don't touch C, so the was-emul bit set
                ; by XCE survives this block for the BRK check below.)
                STA     |$0108                  ; ASave
                STX     |$010A                  ; XSave (16-bit)
                STY     |$010C                  ; YSave (16-bit)
                TDC
                STA     |$0110                  ; DPSave

                ; --- BRK detection — MUST run before any C-clobbering
                ;     instruction (the shadow-mask CMP #1 below sets C
                ;     based on SNAP_ROM, which on ROM 03 leaves C=1 and
                ;     causes any native-mode IRQ entry with caller X=1
                ;     to misclassify as BRK).  See memory entry
                ;     feedback_sim_brk_check_c_clobber.md.
                ;
                ;     Logic: C from XCE is 0=was-native, 1=was-emul.
                ;     Native-mode IRQs use the NIRQ vector and never
                ;     reach here as BRK, so was-native → skip.  Emul-mode
                ;     shares the EIRQ/EBRK vector; distinguish via the
                ;     B bit (bit 4) of the firmware IRQ-frame P byte at
                ;     $04,S.  A may be clobbered — caller's A is already
                ;     in $E1:0108 above. ---
                BCC     @kid_brk_done           ; was-native → no BRK possible
                SEP     #$30
                MX      %11
                LDA     $04,S                   ; firmware IRQ frame P (8-bit)
                AND     #$10                    ; B bit (this path is taken only
                                                ;        when was-emul, so bit 4
                                                ;        is unambiguously B and
                                                ;        not the native X flag)
                BEQ     @kid_brk_real_8b        ; B=0 → real IRQ
                ; --- BRK: chain to ROM BRK handler.  gno contract at
                ;     $FFBD16: DBR=$E1, DP=0, MX %11, stack = $E1 leftover
                ;     + PHB + PHP + IRQ frame.  DBR=$E1 already; we are
                ;     in MX %11; need to force DP=0 before the JMP. ---
                REP     #$20
                MX      %00
                LDA     #$0000
                TCD
                SEP     #$20
                MX      %10
                JMP     _simExitBrk
@kid_brk_real_8b
                REP     #$30
                MX      %00
@kid_brk_done

                ; Save + modify shadow register $C035 with ROM-version
                ; gated AND mask (ROM 03 = $9F3E, ROM 01 = $9F1E).
                LDA     |$C035
                STA     |$0119                  ; ShadSave
                ORA     #$8000
                PHA                             ; stash ORA result
                SEP     #$20
                MX      %10
                ; LDAL (24-bit) not LDA — DBR is $E1 here from the preamble's
                ; PEA $E1E1/PLB; abs-addressing LDA would read from
                ; $E1:_snapData (ROM bytes) instead of $02:_snapData.
                ; Silent on ROM 03 (BEQ falls through to ROM 03 mask anyway)
                ; but breaks the ROM 01 path.
                LDAL    _snapData+SNAP_ROM
                CMP     #1
                BEQ     @kid_rom01_mask
                REP     #$20
                MX      %00
                LDA     1,S                     ; reload stashed value
                AND     #$9F3E                  ; ROM 03 mask
                BRA     @kid_apply_mask
@kid_rom01_mask REP     #$20
                MX      %00
                LDA     1,S
                AND     #$9F1E                  ; ROM 01 mask
@kid_apply_mask STA     |$C035
                PLY                             ; discard stash slot

                ; DP = 0 (ROM expects bank-0 zeropage layout).
                LDA     #$0000
                TCD

                ; --- Switch DBR to $02 for our own statics ---
                ; The preamble needed DBR=$E1 to reach the ROM slots at
                ; |$01xx and the shadow reg at |$C035.  From here on we
                ; need DBR=$02 so `INC _simStatTotal` etc. resolve into
                ; OUR bank, not bank $E1.
                ;
                ; CRITICAL: must be stack-neutral.  We use PHK/PLB (PB is
                ; $02 since we're in bank $02) — net 0 bytes.  An earlier
                ; PEA $0202/PLB pattern left a $02 byte on stack that
                ; ROM exit code (which expects gno's exact stack layout)
                ; misread, yielding bogus RTI returns (PC=$A9:xxxx etc).
                PHK
                PLB

                ; --- Counter: total IRQs (32-bit) ---
                INC     _simStatTotal
                BNE     @kid_no_carry_t
                INC     _simStatTotal+2
@kid_no_carry_t

                ; --- Switch to 8-bit for SCC byte access ---
                SEP     #$30
                MX      %11

@kid_check_scc
                ; --- Read RR3 on chan A to find pending SCC IRQ source ---
                LDA     #$03
                STAL    SCC_A_CMD               ; WR0 = $03 selects RR3
                LDAL    SCC_A_CMD               ; A = RR3
                BNE     @kid_scc_irq

                ; --- Not an SCC IRQ — chain to ROM main IRQ handler ---
                ; gno main-chain exit ($FFBCFA) contract: RR3 stash + PEA
                ; leftover + PHB + PHP + IRQ frame on stack, A=RR3, DBR=$E1,
                ; MX=%11.  We have nothing pushed since gno's hmm3 PHA's
                ; RR3 unconditionally and we didn't; push a fake RR3=0.
                REP     #$30
                MX      %00
                INC     _simStatNotScc
                BNE     @kid_nsc_nc
                INC     _simStatNotScc+2
@kid_nsc_nc     SEP     #$30
                MX      %11
                LDA     #$00                    ; fake RR3 stash (we know RR3=0)
                PHA                             ; +1, now at 1,S
                LDA     2,S                     ; peek PEA $E1 leftover (now at 2,S)
                PHA                             ; +1
                PLB                             ; -1, DBR=$E1; stack net +1 (fake RR3)
                LDA     1,S                     ; A = RR3 (= 0)
                JMP     _simExitMain

@kid_scc_irq
                ; --- SCC IRQ — counter, then Tier-1 walk ---
                PHA                             ; stash RR3 (8-bit)
                REP     #$30
                MX      %00
                INC     _simStatScc
                BNE     @kid_sc_nc
                INC     _simStatScc+2
@kid_sc_nc      SEP     #$30
                MX      %11
                PLA                             ; restore RR3

                ; --- Tier-0 stubs (deferred per spec §3.3) ---
                ; AppleTalk path: BIT |$0103 (ATlkFlag) / BEQ kid_no_atalk
                ;   PHA / AND #$07 / BNE kid_atalk_chanB
                ;   LDA |$C03B / STA |$0105 / LDA |$C03B / STA |$0106
                ;   JSL >v_AppleTalk / BRA kid_atalk_done
                ; MIDI path:
                ;   LDA >$010101 / STA |$011C
                ;   STZ |$E10101
                ;   JSL >$E1021C  ; MIDI firmware handler
                ;   BCC kid_handled  ; MIDI claimed
                ; (Single comment-toggle when AppleTalk/MIDI lands.)

                ; --- Tier-1 fast pre-check via _simChanOwned ---
                ; If RR3's set bits don't intersect anything we own, this
                ; is an SCC IRQ on a channel managed by IIgs serial
                ; firmware (or just stale state).  Per gno sim.asm
                ; "notOurSerIntr" path, chain to ROM main handler — NOT
                ; the SCC-unclaimed exit.  The unclaimed exit is reserved
                ; for "we own this channel but our handler returned SEC."
                PHA                             ; save RR3 (1,S after PHA)
                AND     _simChanOwned           ; any owned bits?
                BEQ     @kid_chan_not_owned

                ; --- Walk handler registry ---
                ; Loop counter X is in entries-of-4 (mask, addr_lo, addr_mi,
                ; addr_hi).  CPX against _simHandlerCount*4 in _simHandlerLimit.
                LDX     #0
@kid_walk_L     CPX     _simHandlerLimit        ; pre-computed count*4
                BEQ     @kid_handler_unclaimed
                LDA     1,S                     ; RR3
                AND     _simHandlerTbl,X        ; mask byte
                BEQ     @kid_walk_next

                ; --- Patch self-modifying JSL trampoline + dispatch ---
                LDA     #$5C
                STA     _simTramp
                LDA     _simHandlerTbl+1,X
                STA     _simTramp+1
                LDA     _simHandlerTbl+2,X
                STA     _simTramp+2
                LDA     _simHandlerTbl+3,X
                STA     _simTramp+3
                LDA     1,S                     ; A = RR3 for handler ABI
                JSL     _simTramp
                BCC     @kid_handled_pop

@kid_walk_next  INX
                INX
                INX
                INX
                BRA     @kid_walk_L

@kid_chan_not_owned
                ; SCC IRQ on a channel we don't own — chain to ROM main
                ; ($FFBCFA "notOurSerIntr" path).  gno contract:
                ; RR3 stash + PEA leftover + PHB + PHP + IRQ frame on stack,
                ; A=RR3, DBR=$E1, MX=%11.
                ; State here: RR3 stash already on stack (1,S); we just need
                ; to restore DBR=$E1 and load A=RR3.
                LDA     2,S                     ; peek PEA $E1 leftover
                PHA                             ; +1
                PLB                             ; -1 → DBR=$E1; net 0
                LDA     1,S                     ; A = RR3 stash
                JMP     _simExitMain

@kid_handler_unclaimed
                ; SCC IRQ on owned channel but no handler returned CLC —
                ; "SCC unclaimed" ROM exit ($FFBD15).  gno contract:
                ; PEA leftover + PHB + PHP + IRQ frame, DBR=$E1, MX=%11.
                ; State here: RR3 stash on stack — must pop it.
                PLA                             ; -1 pop RR3 stash
                LDA     1,S                     ; peek PEA $E1 leftover
                PHA                             ; +1
                PLB                             ; -1 → DBR=$E1; net 0
                JMP     _simExitSccChn

@kid_handled_pop
                ; Handler returned CLC ("we claim it") — $FFBF58 exit.
                ; gno contract: PHB + PHP + IRQ frame, DBR=$E1, MX=%00.
                ; State here: RR3 stash + PEA leftover + PHB + PHP + IRQ.
                ; Pop RR3 stash, then PLB the PEA leftover (DBR=$E1).
                PLA                             ; -1 pop RR3 stash
                REP     #$30
                MX      %00
                PLB                             ; -1 pop PEA leftover; DBR=$E1
                JMP     _simExitHandled

;==============================================================================
; SIM handler install + SCC IRQ enable + simtest_isr handler (C0.5).
;
; The standalone equivalent of what kernel SYS_SIM_INSTALL will do in
; Phase 1 (per spec §3.7).  All three routines live here so simtest is
; a single self-contained validation rig.
;==============================================================================

;------------------------------------------------------------------------------
; SimInstall — register simtest_isr for chan B (RR3 bits 0-2 = mask $07).
;
; Mirrors gno SIM's per-handler install logic (sim.asm doInstall epilogue:
; clear SerFlag firmware-claim bits for our port).  WR9 master-enable is
; left for scc_enable_irqs (split for clarity; gno does it in InitSCC2).
;
; In:   IRQs masked.  MX %00 / DBR=$02 / DP=$1000.
; Out:  _simHandlerTbl[0] populated, count=1, limit=4, owned=$07.  SerFlag
;       chan-B bits 0-2 cleared in $E1:0104.  MX %00 preserved.
;------------------------------------------------------------------------------
SimInstall      MX %00
                PHP
                SEP     #$30
                MX      %11

                ; --- Entry 0: mask byte (RR3 bits 0-2 = chan B) ---
                LDA     #$07
                STA     _simHandlerTbl

                ; --- Entry 0: 24-bit handler addr ---
                LDA     #<simtest_isr
                STA     _simHandlerTbl+1
                LDA     #>simtest_isr
                STA     _simHandlerTbl+2
                LDA     #^simtest_isr
                STA     _simHandlerTbl+3

                ; --- Count + limit + chan-owned mirror of gno ourSerFlag ---
                LDA     #1
                STA     _simHandlerCount
                LDA     #4                      ; count * 4 (loop bound)
                STA     _simHandlerLimit
                LDA     #$07
                STA     _simChanOwned

                ; --- Clear firmware SerFlag bits 0-2 (chan B claim).
                ;     Mirrors gno sim.asm doInstall: prevents IIgs serial
                ;     firmware from also trying to handle chan B IRQs. ---
                LDAL    $E10104                 ; SerFlag
                AND     #$F8
                STAL    $E10104

                PLP
                RTS

;------------------------------------------------------------------------------
; scc_enable_irqs — turn on SCC chan B interrupts.  Mirrors gno
; sccf.asm:InitSCC2 (lines 422-451).
;
; WR1 = $12  (INT on All Rx Chars + Tx Int Enable).  Tx IRQ is enabled
;            so chip setup is forward-compatible with IRQ-paced TX for
;            Kermit/XMODEM/PPP work; simtest_isr ACKs spurious TxIPs via
;            WR0=$28 (matches gno turnOffTxInt sccf.asm:142).
; WR9 = $0A  (MIE + NV — master interrupt enable, no vector).  WR9 is
;            chip-wide; written via chan B address.
; WR0 = $30  (error reset) followed by WR0 = $38 (Reset Highest IUS) to
;            clean up any latent SCC IRQ state from boot.
;
; In:   IRQs masked.  MX %00 / DBR=$02.
; Out:  SCC chan B IRQs live.  MX %00 preserved.
;------------------------------------------------------------------------------
scc_enable_irqs MX %00
                PHP
                SEI
                SEP     #$30
                MX      %11

                ; Sync the SCC state machine to register 0.
                LDAL    SCC_B_CMD

                ; WR1 = $12  (RX-all + TX IRQ enable)
                LDA     #$01
                STAL    SCC_B_CMD
                LDA     #$12
                STAL    SCC_B_CMD

                ; WR9 = $0A  (MIE + NV)
                LDA     #$09
                STAL    SCC_B_CMD
                LDA     #$0A
                STAL    SCC_B_CMD

                ; WR0 = $30  (error reset)
                LDA     #$00
                STAL    SCC_B_CMD
                LDA     #$30
                STAL    SCC_B_CMD

                ; WR0 = $38  (Reset Highest IUS)
                LDA     #$00
                STAL    SCC_B_CMD
                LDA     #$38
                STAL    SCC_B_CMD

                PLP
                RTS

;------------------------------------------------------------------------------
; simtest_isr — SIM handler for SCC chan B.
;
; Mirrors gno sccf.asm:IntVect (lines 28-149) at a minimal-feature level:
; RX drain + framing-error reset + per-byte Reset Highest IUS; TX-empty
; ACK only (no queue yet — future C0.7+ fills in the queue dequeue/write);
; Ext/Status not enabled (WR15=$00 in scc_program_chanB).
;
; Per spec §3.3 the SIM dispatcher does NOT do Reset Highest IUS — that's
; handler-side, since multiple chan B events can arrive in one IRQ window
; and each needs its own IUS clear.
;
; ABI (per SIM dispatcher trampoline at _KernIrq_Dispatch:_simTramp):
;   In:   A = RR3 contents (8-bit).  MX %11 / DBR=$02 / DP=$0000.
;         IRQs masked (firmware IRQ frame still on stack via dispatcher).
;   Out:  CLC + RTL = handled  (dispatcher takes _simExitHandled).
;         SEC + RTL = not ours (dispatcher takes _simExitSccChn).
;------------------------------------------------------------------------------
simtest_isr     MX %11
                ; Stash entry-time RR3 in our bank-$02 static so we can
                ; check each chan B source bit independently after the
                ; RX drain may have cleared others via Reset Highest IUS.
                STA     _isrEntryRR3

                ; --- RX path ---
                BIT     #$04                    ; chan B Rx IP?
                BEQ     @isr_skip_rx

                ; Counter: chan B Rx IP fires (32-bit, MX %00 wrap).
                REP     #$30
                MX      %00
                INC     _simStatRxIrqs
                BNE     @isr_rx_ncy
                INC     _simStatRxIrqs+2
@isr_rx_ncy     SEP     #$30
                MX      %11

@isr_rx_loop    LDA     #$01                    ; select RR1
                STAL    SCC_B_CMD
                LDAL    SCC_B_CMD               ; A = RR1 (status)
                PHA                             ; save for error check below
                LDAL    SCC_B_DATA              ; A = received byte; clears RR0 bit 0

                ; --- Ring full? (head+1 == tail) ---
                LDX     _sccRxHead
                INX
                CPX     _sccRxTail
                BEQ     @isr_drop_byte

                ; --- Not full: store + advance head ---
                DEX                             ; X = head
                STA     _sccRxBuf,X
                INX
                STX     _sccRxHead
                ; Counter: bytes successfully enqueued (32-bit, MX %00 wrap).
                REP     #$30
                MX      %00
                INC     _simStatRxBytes
                BNE     @isr_rxb_ncy
                INC     _simStatRxBytes+2
@isr_rxb_ncy    SEP     #$30
                MX      %11
                BRA     @isr_check_err

@isr_drop_byte  ; --- Full: increment 32-bit drop counter, byte discarded ---
                REP     #$30
                MX      %00
                INC     _simStatRxDrop
                BNE     @isr_drop_no_c
                INC     _simStatRxDrop+2
@isr_drop_no_c  SEP     #$30
                MX      %11

@isr_check_err  PLA                             ; restore RR1
                AND     #$60                    ; framing / parity error bits
                BEQ     @isr_no_err
                LDA     #$00
                STAL    SCC_B_CMD               ; select WR0
                LDA     #$30
                STAL    SCC_B_CMD               ; error reset
@isr_no_err     LDA     #$00
                STAL    SCC_B_CMD               ; select WR0
                LDA     #$38
                STAL    SCC_B_CMD               ; Reset Highest IUS (per byte)

                LDAL    SCC_B_CMD               ; RR0
                AND     #$01                    ; Rx Char Available?
                BNE     @isr_rx_loop            ; more data — drain it

@isr_skip_rx
                ; --- TX path: IRQ-driven dequeue.  Mirrors gno sccf.asm
                ;     t_Tx_Int (line 104) + turnOffTxInt (line 142). ---
                LDA     _isrEntryRR3
                BIT     #$02                    ; chan B Tx IP?
                BEQ     @isr_skip_tx

                ; Counter: chan B Tx IP fires (32-bit, MX %00 wrap).  Covers
                ; both the dequeue path and the idle/ACK path below.
                REP     #$30
                MX      %00
                INC     _simStatTxIrqs
                BNE     @isr_tx_ncy2
                INC     _simStatTxIrqs+2
@isr_tx_ncy2    SEP     #$30
                MX      %11

                ; --- Anything in the TX ring? ---
                LDA     _sccTxTail
                CMP     _sccTxHead
                BEQ     @isr_tx_idle            ; empty → ACK + mark idle

                ; --- Dequeue one byte + write to SCC data register ---
                LDX     _sccTxTail
                LDA     _sccTxBuf,X
                INX
                STX     _sccTxTail
                STAL    SCC_B_DATA              ; transmit; hold→shift later re-arms TxIP

                ; --- TX-sent counter (32-bit) ---
                ;
                ; CRITICAL: do NOT issue WR0=$28 (Reset Tx Int Pending) here.
                ; gno sccf.asm doTxChar uses ONLY $38 (Reset Highest IUS,
                ; which we do in @isr_done below).  Issuing $28 here clears
                ; the fresh TxIP that gets set when this byte's hold→shift
                ; transition happens microseconds later — that's the IRQ
                ; we need to fire to dequeue the next byte.  $28 kills the
                ; chain after one byte.  Symptom: TxSent=1 forever.
                REP     #$30
                MX      %00
                INC     _simStatTxSent
                BNE     @isr_tx_ncy
                INC     _simStatTxSent+2
@isr_tx_ncy     SEP     #$30
                MX      %11
                BRA     @isr_skip_tx

@isr_tx_idle    ; --- TX ring empty: ACK TxIP and clear in-progress flag.
                ;     Without WR0=$28 here, the chip would re-fire TxIP
                ;     continuously since buffer stays empty. ---
                LDA     #$00
                STAL    SCC_B_CMD
                LDA     #$28
                STAL    SCC_B_CMD               ; Reset Tx Interrupt Pending
                STZ     _sccTxInProgress

@isr_skip_tx
                ; --- Ext/Status (RR3 bit 0) is not enabled in WR15;
                ;     if it ever fires we'll see _simStatTotal climb but
                ;     no chan-claimed bit set, and the final Reset
                ;     Highest IUS below will clear it. ---

                ; --- Final Reset Highest IUS (covers TX/Ext paths) ---
                LDA     #$00
                STAL    SCC_B_CMD
                LDA     #$38
                STAL    SCC_B_CMD

                CLC                             ; handled
                RTL

;------------------------------------------------------------------------------
; paint_rx_byte — paint _rxByteScratch on text page 1 at (row 23, col
; _simtestCursor) via tp1_putc_at; advance cursor, wrap at col 80.
;
; In:   _rxByteScratch (1 byte).  MX %11 / DBR=$02.
; Out:  _simtestCursor advanced.  MX preserved (PHP/PLP).
;------------------------------------------------------------------------------
paint_rx_byte   MX %11
                PHP
                ; --- Stage tp1_putc_at args in bank-$02 DP scratch ---
                LDA     _rxByteScratch
                STA     _tp1_arg_char
                LDA     _simtestCursor
                STA     _tp1_arg_col
                LDA     #23
                STA     _tp1_arg_row
                REP     #$30
                MX      %00
                JSR     tp1_putc_at
                SEP     #$30
                MX      %11
                ; --- Advance cursor; wrap at col 80 → col 4 (preserve "RX< ") ---
                LDA     _simtestCursor
                INC     A
                CMP     #80
                BCC     @prb_save
                LDA     #4
@prb_save       STA     _simtestCursor
                PLP
                RTS

;------------------------------------------------------------------------------
; paint_tx_byte — paint _rxByteScratch on text page 1 at (row 22, col
; _txCursor) via tp1_putc_at; advance cursor, wrap from col 80 → col 4
; (preserving the "TX> " 4-char label prefix on the row).
;
; In:   _rxByteScratch (1 byte).  MX %11 / DBR=$02.
; Out:  _txCursor advanced.  MX preserved (PHP/PLP).
;------------------------------------------------------------------------------
paint_tx_byte   MX %11
                PHP
                LDA     _rxByteScratch
                STA     _tp1_arg_char
                LDA     _txCursor
                STA     _tp1_arg_col
                LDA     #22
                STA     _tp1_arg_row
                REP     #$30
                MX      %00
                JSR     tp1_putc_at
                SEP     #$30
                MX      %11
                ; --- Advance cursor; wrap at col 80 → col 4 (preserve "TX> ") ---
                LDA     _txCursor
                INC     A
                CMP     #80
                BCC     @ptb_save
                LDA     #4
@ptb_save       STA     _txCursor
                PLP
                RTS

;------------------------------------------------------------------------------
; paint_stats_scaffold — one-shot called from init after tp1_print_snap.
; Paints static labels on rows 20-23: stats headers and TX/RX buffer
; prefixes.  Numeric slots get overwritten every WAI wake by
; paint_stats_line; the labels stay put.
;
; Layout (80-col text page 1):
;   Row 20: "TIME 00:00  HB 000000  TOT 000000  NOTSCC 000000"
;   Row 21: "RX-IRQ 00000  TX-IRQ 00000  RX-BYTES 00000  TX-BYTES 00000"
;   Row 22: "TX> "
;   Row 23: "RX< "
;
; In:   MX %00 / DBR=$02.
; Out:  Labels painted.  MX %00 preserved.
;------------------------------------------------------------------------------
paint_stats_scaffold MX %00
                PHP
                REP     #$30
                MX      %00

                ; --- Row 20 label ---
                SEP     #$30
                MX      %11
                LDA     #20
                STA     _tp1_arg_row
                LDA     #0
                STA     _tp1_arg_col
                REP     #$30
                MX      %00
                LDA     #s_stats_row20
                STA     _tp1_arg_ptr
                JSR     tp1_puts_at

                ; --- Row 21 label ---
                SEP     #$30
                MX      %11
                LDA     #21
                STA     _tp1_arg_row
                LDA     #0
                STA     _tp1_arg_col
                REP     #$30
                MX      %00
                LDA     #s_stats_row21
                STA     _tp1_arg_ptr
                JSR     tp1_puts_at

                ; --- Row 22 prefix ---
                SEP     #$30
                MX      %11
                LDA     #22
                STA     _tp1_arg_row
                LDA     #0
                STA     _tp1_arg_col
                REP     #$30
                MX      %00
                LDA     #s_tx_prefix
                STA     _tp1_arg_ptr
                JSR     tp1_puts_at

                ; --- Row 23 prefix ---
                SEP     #$30
                MX      %11
                LDA     #23
                STA     _tp1_arg_row
                LDA     #0
                STA     _tp1_arg_col
                REP     #$30
                MX      %00
                LDA     #s_rx_prefix
                STA     _tp1_arg_ptr
                JSR     tp1_puts_at

                PLP
                RTS

;------------------------------------------------------------------------------
; paint_stats_line — repaint numeric slots on rows 20-21 from current
; counter values.  Called every main-loop WAI wake (~60 Hz).
;
; Clock: split _simStatSeconds into MM = seconds/60, SS = seconds%60.
; Counter rendering: 6 digits for {HB, TOT, NOTSCC}; 5 digits for
; {RX-IRQ, TX-IRQ, RX-BYTES, TX-BYTES}.
;
; Slot positions (col-indexed from row start) computed from the scaffold
; strings — see s_stats_row20 / s_stats_row21 in the string constants
; block.  Row 20: MM@5, SS@8, HB@15, TOT@27, NOTSCC@42.  Row 21:
; RX-IRQ@7, TX-IRQ@21, RX-BYTES@37, TX-BYTES@53.
;
; In:   MX %00 / DBR=$02.
; Out:  Slots updated.  MX %00 preserved.  Caller A/X clobbered.
;------------------------------------------------------------------------------
paint_stats_line MX %00
                PHP
                REP     #$30
                MX      %00

                ; ============== Row 20: TIME MM:SS ==============
                ; --- Copy _simStatSeconds into mutable scratch ---
                LDA     _simStatSeconds
                STA     _psl_secs
                LDA     _simStatSeconds+2
                STA     _psl_secs+2

                ; --- Compute MM by trial-subtracting 60 from _psl_secs.
                ;     Cap at 99 minutes — clock wraps if you leave it
                ;     running 100+ minutes. ---
                SEP     #$20
                MX      %10
                STZ     _psl_mm
                REP     #$20
                MX      %00
@psl_mm_loop    SEC
                LDA     _psl_secs
                SBC     #60
                STA     _psl_tmp
                LDA     _psl_secs+2
                SBC     #0
                BCC     @psl_mm_done
                STA     _psl_secs+2
                LDA     _psl_tmp
                STA     _psl_secs
                SEP     #$20
                MX      %10
                INC     _psl_mm
                REP     #$20
                MX      %00
                BRA     @psl_mm_loop
@psl_mm_done
                ; _psl_secs now holds SS (0..59), _psl_mm holds MM (0..255).

                ; --- Render MM (2 digits) at row 20, col 5 ---
                SEP     #$30
                MX      %11
                LDA     #20
                STA     _tp1_arg_row
                LDA     #5
                STA     _tp1_arg_col
                LDA     _psl_mm
                STA     _tp1_arg_dec_val
                STZ     _tp1_arg_dec_val+1
                STZ     _tp1_arg_dec_val+2
                STZ     _tp1_arg_dec_val+3
                LDA     #2
                STA     _tp1_arg_dec_n
                REP     #$30
                MX      %00
                JSR     tp1_putdec_at

                ; --- Render SS (2 digits) at row 20, col 8 ---
                SEP     #$30
                MX      %11
                LDA     #8
                STA     _tp1_arg_col
                LDA     _psl_secs
                STA     _tp1_arg_dec_val
                STZ     _tp1_arg_dec_val+1
                STZ     _tp1_arg_dec_val+2
                STZ     _tp1_arg_dec_val+3
                LDA     #2
                STA     _tp1_arg_dec_n
                REP     #$30
                MX      %00
                JSR     tp1_putdec_at

                ; --- Render HB (6 digits) at row 20, col 15 ---
                LDA     _simStatHbTicks
                STA     _tp1_arg_dec_val
                LDA     _simStatHbTicks+2
                STA     _tp1_arg_dec_val+2
                SEP     #$30
                MX      %11
                LDA     #15
                STA     _tp1_arg_col
                LDA     #6
                STA     _tp1_arg_dec_n
                REP     #$30
                MX      %00
                JSR     tp1_putdec_at

                ; --- Render TOT (6 digits) at row 20, col 27 ---
                LDA     _simStatTotal
                STA     _tp1_arg_dec_val
                LDA     _simStatTotal+2
                STA     _tp1_arg_dec_val+2
                SEP     #$30
                MX      %11
                LDA     #27
                STA     _tp1_arg_col
                LDA     #6
                STA     _tp1_arg_dec_n
                REP     #$30
                MX      %00
                JSR     tp1_putdec_at

                ; --- Render NOTSCC (6 digits) at row 20, col 42 ---
                LDA     _simStatNotScc
                STA     _tp1_arg_dec_val
                LDA     _simStatNotScc+2
                STA     _tp1_arg_dec_val+2
                SEP     #$30
                MX      %11
                LDA     #42
                STA     _tp1_arg_col
                LDA     #6
                STA     _tp1_arg_dec_n
                REP     #$30
                MX      %00
                JSR     tp1_putdec_at

                ; ============== Row 21: per-direction counters ==============
                ; --- RX-IRQ (5 digits) at row 21, col 7 ---
                LDA     _simStatRxIrqs
                STA     _tp1_arg_dec_val
                LDA     _simStatRxIrqs+2
                STA     _tp1_arg_dec_val+2
                SEP     #$30
                MX      %11
                LDA     #21
                STA     _tp1_arg_row
                LDA     #7
                STA     _tp1_arg_col
                LDA     #5
                STA     _tp1_arg_dec_n
                REP     #$30
                MX      %00
                JSR     tp1_putdec_at

                ; --- TX-IRQ (5 digits) at row 21, col 21 ---
                LDA     _simStatTxIrqs
                STA     _tp1_arg_dec_val
                LDA     _simStatTxIrqs+2
                STA     _tp1_arg_dec_val+2
                SEP     #$30
                MX      %11
                LDA     #21
                STA     _tp1_arg_col
                LDA     #5
                STA     _tp1_arg_dec_n
                REP     #$30
                MX      %00
                JSR     tp1_putdec_at

                ; --- RX-BYTES (5 digits) at row 21, col 37 ---
                LDA     _simStatRxBytes
                STA     _tp1_arg_dec_val
                LDA     _simStatRxBytes+2
                STA     _tp1_arg_dec_val+2
                SEP     #$30
                MX      %11
                LDA     #37
                STA     _tp1_arg_col
                LDA     #5
                STA     _tp1_arg_dec_n
                REP     #$30
                MX      %00
                JSR     tp1_putdec_at

                ; --- TX-BYTES (5 digits) at row 21, col 53 ---
                LDA     _simStatTxBytes
                STA     _tp1_arg_dec_val
                LDA     _simStatTxBytes+2
                STA     _tp1_arg_dec_val+2
                SEP     #$30
                MX      %11
                LDA     #53
                STA     _tp1_arg_col
                LDA     #5
                STA     _tp1_arg_dec_n
                REP     #$30
                MX      %00
                JSR     tp1_putdec_at

                PLP
                RTS

; --- paint_stats_line bank-$02 scratch ---
_psl_secs       DS      4                       ; mutable copy of _simStatSeconds
_psl_mm         DS      1
_psl_tmp        DS      2

;------------------------------------------------------------------------------
; tx_enqueue_byte — IRQ-driven TX.  Push _rxByteScratch into the TX ring;
; if the chip isn't currently transmitting, kickstart by writing the byte
; directly to SCC_B_DATA (sets in-progress; subsequent bytes get drained
; by simtest_isr's TX leg as TxIPs fire).
;
; SPSC ring: main loop is the sole producer (writes _sccTxHead); IRQ
; handler is the sole consumer (writes _sccTxTail).  We wrap SEI/PLP
; around the critical section so the handler can't observe a half-updated
; head while we're enqueueing.
;
; In:   _rxByteScratch (1 byte).  MX %11 / DBR=$02.
; Out:  byte queued (or dropped if ring full + _simStatTxDrop incremented).
;       MX preserved.
;
; Mirrors gno-style enqueue + tx_in_progress kickstart (sccf.asm
; references the same pattern via a separate transmit driver path).
;------------------------------------------------------------------------------
tx_enqueue_byte MX %11
                PHP
                SEI                             ; block handler while we update head

                ; --- Ring full?  (head+1 == tail) ---
                LDA     _sccTxHead
                INC     A
                CMP     _sccTxTail
                BEQ     @teb_drop

                ; --- Not full: write byte at head, advance head ---
                LDX     _sccTxHead
                LDA     _rxByteScratch
                STA     _sccTxBuf,X
                INX
                STX     _sccTxHead
                ; Counter: bytes enqueued for TX (32-bit, MX %00 wrap).
                REP     #$30
                MX      %00
                INC     _simStatTxBytes
                BNE     @teb_b_ncy
                INC     _simStatTxBytes+2
@teb_b_ncy      SEP     #$30
                MX      %11

                ; --- If transmission is already in progress, the IRQ
                ;     chain will pick up this byte on the next TxIP. ---
                LDA     _sccTxInProgress
                BNE     @teb_done

                ; --- Kickstart: chip is idle.  Dequeue what we just
                ;     queued and write it directly to SCC_B_DATA.  When
                ;     that byte completes, TxIP fires → simtest_isr's
                ;     TX leg either dequeues more or marks idle. ---
                LDA     #1
                STA     _sccTxInProgress
                LDX     _sccTxTail
                LDA     _sccTxBuf,X
                INX
                STX     _sccTxTail
                STAL    SCC_B_DATA
                BRA     @teb_done

@teb_drop       ; --- Ring full: 32-bit drop counter, byte discarded ---
                REP     #$30
                MX      %00
                INC     _simStatTxDrop
                BNE     @teb_drop_nc
                INC     _simStatTxDrop+2
@teb_drop_nc    SEP     #$30
                MX      %11

@teb_done       PLP
                RTS

;==============================================================================
; Toolbox bring-up + heartbeat task (C0.5b).  Per spec §6 step 5-7.
;
; Why this exists: without ANY non-SCC IRQ source enabled, the dispatcher's
; @kid_no_scc path (RR3=0 → JMP _simExitMain) never executes — _simStatNotScc
; stays 0 in every dump.  That path is what handles VBL/heartbeat IRQs in
; the kernel and is critical to validate before Phase 1 integration.
; Installing a Toolbox heartbeat task makes the firmware fire VBL IRQs at
; ~60 Hz; our SIM dispatcher sees them with RR3=0, takes the NotScc path,
; and chains to ROM main which runs the firmware HB queue (including our
; task body).
;
; Pattern lifted minimally from src/kernel/toolbox.s.  Differences vs the
; full FGX kernel:
;   - No _MMStartUp (returns idErr=$0207 from raw boot — see memory note
;     reference_iigs_toolbox_bringup_from_raw_boot.md).  We don't allocate
;     handles; the task struct lives in our bank-$02 static area.
;   - No Toolbox_AllocKernelDP (we own DP=$1000 outright).
;   - No pre-claim table (we don't run MM).
;
; What this exercises:
;   - VBL IRQs flow into SIM dispatcher (_simStatNotScc grows at 60 Hz).
;   - Dispatcher's NotScc → _simExitMain chain returns cleanly to ROM main.
;   - ROM main dispatches firmware HB queue → our _hbTickTask runs.
;   - SCC IRQs continue working alongside VBL (shared dispatcher).
;==============================================================================

;------------------------------------------------------------------------------
; tbx_init — TLStartUp + MTStartUp + GetNewID.  Halts simtest on any toolbox
; error (caller is responsible for the resulting blue-screen detection in
; debug; production C0.6 will add a visible halt message).
;
; In:   MX %00, IRQs masked (still inside boot SEI window).
; Out:  C=1, _simTbxUserID populated.  Halts on any toolbox failure.
;------------------------------------------------------------------------------
tbx_init        MX %00
                PHP
                REP     #$30
                MX      %00

                ; _TLStartUp ($0201) — no args, no Pascal return.
                LDX     #$0201
                JSL     $E10000
                BCS     @tbi_halt

                ; _MTStartUp ($0203) — no args, no Pascal return.
                LDX     #$0203
                JSL     $E10000
                BCS     @tbi_halt

                ; _GetNewID ($2003) — Pascal Word arg = class.  $1000 = app.
                PHA                             ; result placeholder
                PEA     $1000
                LDX     #$2003
                JSL     $E10000
                BCS     @tbi_halt
                PLA                             ; A = userID
                STA     _simTbxUserID

                PLP
                SEC
                RTS

@tbi_halt       ; Toolbox failure.  Spin so the operator notices via fgxdebug
                ;     PC inspection.  No console / no kernel halt path here.
                STP                             ; halts CPU; PC freezes here.

;------------------------------------------------------------------------------
; tbx_install_hb — SetHeartBeat + enable Mega II VBL source.
;
; In:   MX %00, IRQs masked.  _simTbxUserID populated.
; Out:  C=1, MX %00.  IRQs UNMASKED via CLI (PLP-then-CLI for I=0 persistence
;       across return; see toolbox.s comment block for the rationale).
;       _hbTickTask is live in firmware queue and fires at ~60 Hz.
;------------------------------------------------------------------------------
tbx_install_hb  MX %00
                PHP
                REP     #$30
                MX      %00

                ; _SetHeartBeat ($1203) — Pascal Long pointer to HB task.
                LDA     #^_hbTickTask
                PHA                             ; bank
                LDA     #_hbTickTask
                PHA                             ; offset
                LDX     #$1203
                JSL     $E10000
                BCS     @tih_halt

                ; Mega II VBL source enable: bit 3 of INTEN ($00C041).
                ; (Per memory feedback_iigs_irq.md, $C041 reads return kbd
                ; on IIgs, but writes go to INTEN regardless of language card
                ; state; safe to write.  We use bank $00 here as the kernel
                ; does — the soft-switch write semantics work from either
                ; $00 or $E0 on IIgs.)
                SEP     #$20
                MX      %10
                LDA     #$08
                STAL    $00C041
                REP     #$20
                MX      %00

                PLP                             ; restore caller P (was I=1)
                CLI                             ; unmask IRQs AFTER PLP
                SEC
                RTS

@tih_halt       STP                             ; halts CPU on SetHeartBeat failure

;------------------------------------------------------------------------------
; _hbTickTask — firmware heartbeat task descriptor + body.
;
; Layout (per IIgs firmware HB queue contract):
;   +0  HB_Link      4 bytes (firmware fills with next-task ptr)
;   +4  HB_TickCount 2 bytes (decremented each VBL; 0 = inactive)
;   +6  HB_Signature 2 bytes = $5A,$A5 (high-byte-first; HEX directive)
;   +8  body code    — firmware JSLs here on each fire
;
; Body:
;   - JSL'd not IRQ — PHP/PLP RTL not RTI.
;   - Reset HB_TickCount=1 each fire (firmware decrements to 0; without
;     reset, task goes dormant after one tick).
;   - VBL ACK via STAL $E0C047.  Without it, dispatcher re-fires VBL.
;   - Bumps _simStatHbTicks 32-bit counter.  Visible diagnostic via fgxdebug.
;   - No DP scratch usage (HB fires asynchronously w.r.t. main loop; touching
;     shared scratch is a data race per feedback_dp_scratch_aliasing.md).
;------------------------------------------------------------------------------
_hbTickTask     DA      0,0                     ; HB_Link
_hbTickCount    DW      1                       ; HB_TickCount (fire every VBL)
                HEX     5AA5                    ; HB_Signature ($5A,$A5 byte order)
                ; Body starts here at _hbTickTask+8 (firmware JSLs here)
                MX      %11
                PHP
                REP     #$30
                MX      %00
                PHB
                PHK
                PLB                             ; DBR = $02

                LDA     #1                      ; re-arm tick count
                STA     _hbTickCount

                INC     _simStatHbTicks         ; 16-bit low word
                BNE     @hb_noHi
                INC     _simStatHbTicks+2       ; 16-bit high word
@hb_noHi

                ; --- mod-60 counter → _simStatSeconds rollover ---
                ; HB-private 8-bit countdown.  Decrements each VBL; when it
                ; reaches 0, resets to 59 and INC _simStatSeconds.  Avoids
                ; any divide in paint_stats_line.
                SEP     #$20
                MX      %10
                LDA     _kbdSecMod60
                BNE     @hb_sec_dec
                LDA     #59
                STA     _kbdSecMod60
                REP     #$20
                MX      %00
                INC     _simStatSeconds
                BNE     @hb_sec_done
                INC     _simStatSeconds+2
                BRA     @hb_sec_done
@hb_sec_dec     DEC     _kbdSecMod60
                REP     #$20
                MX      %00
@hb_sec_done

                ; --- Keyboard poll: drain $E0:C000 into _kbdRing ---
                ; Mirrors src/kernel/toolbox.s:540-543.  Mega II latch is
                ; single-deep; HB drains every VBL.  Ring full → drop the
                ; byte silently (no counter — adds noise for a debug rig).
                ; No Ctrl/arrow disambiguation; simtest's TX path doesn't
                ; care about modifier semantics.
                ;
                ; CRITICAL: MX must be %11 (both 8-bit) for the LDX of
                ; _kbdRingHead.  Surrounding HB body runs MX %10 (X=16-bit);
                ; under that mode LDX _kbdRingHead reads 2 bytes and X
                ; picks up _kbdRingTail as its high byte, sending the
                ; subsequent STA _kbdRing,X out of range.
                SEP     #$30
                MX      %11
                LDAL    $E0C000
                BPL     @hb_no_kbd              ; bit 7 clear = no key
                AND     #$7F
                PHA                             ; stash keycode
                STAL    $E0C010                 ; clear strobe (write any value)
                ; Enqueue: full-check is (head + 1) == tail.
                LDA     _kbdRingHead
                INC     A
                CMP     _kbdRingTail
                BEQ     @hb_kbd_full
                LDX     _kbdRingHead            ; 8-bit X (MX %11)
                PLA                             ; restore keycode
                STA     _kbdRing,X
                INC     _kbdRingHead
                BRA     @hb_no_kbd
@hb_kbd_full    PLA                             ; discard
@hb_no_kbd
                REP     #$30
                MX      %00

                ; VBL ACK — mandatory, else dispatcher tight-loops on VBL.
                SEP     #$20
                MX      %10
                STAL    $E0C047                 ; VBL ACK (value irrelevant)
                REP     #$20
                MX      %00

                PLB                             ; restore caller DBR
                PLP                             ; restore caller P
                RTL

;==============================================================================
; SIM dispatcher state (bank-$02 statics).  Per spec §3.2.
;==============================================================================

SIM_HANDLER_MAX EQU     4

_simHandlerTbl   DS     SIM_HANDLER_MAX*4   ; {mask:1, addr_lo:1, addr_mi:1, addr_hi:1}
_simHandlerCount DS     1                   ; logical entry count (0..SIM_HANDLER_MAX)
_simHandlerLimit DS     1                   ; precomputed count*4 (loop bound)
_simChanOwned    DS     1                   ; OR of all live masks (mirrors gno ourSerFlag)

; Original $E10010 target (saved for diagnostics / future chain-fallback).
_kernIrqSavedVect DS    4

; ROM exit table — populated by SimInitExitTable at boot.
_simExitBrk      DS     4                   ; ROM 01: $FFB85F / ROM 03: $FFBD16
_simExitHandled  DS     4                   ; ROM 01: $FFBA86 / ROM 03: $FFBF58
_simExitSccChn   DS     4                   ; ROM 01: $FFB85E / ROM 03: $FFBD15
_simExitMain     DS     4                   ; ROM 01: $FFB843 / ROM 03: $FFBCFA

; Self-modifying JSL trampoline for handler dispatch.
_simTramp        DS     4                   ; $5C + 24-bit handler addr

; IRQ counters (32-bit each).  Per spec §6.0c.
_simStatTotal    DS     4
_simStatScc      DS     4
_simStatNotScc   DS     4
_simStatRxDrop   DS     4                  ; bytes dropped because RX ring full (C0.5)
_simStatTxSent   DS     4                  ; bytes drained by IRQ TX dequeue (C0.5a)
_simStatTxDrop   DS     4                  ; bytes dropped because TX ring full (C0.5a)
_simStatHbTicks  DS     4                  ; firmware HB task fires (C0.5b) — should grow at 60Hz
_simTbxUserID    DS     2                  ; Toolbox userID from _GetNewID (C0.5b)

;------------------------------------------------------------------------------
; C0.5 — chan B RX ring buffer + handler scratch + main-loop state.
;------------------------------------------------------------------------------
_sccRxBuf       DS      256                 ; producer=handler, consumer=main loop
_sccRxHead      DS      1                   ; producer index (8-bit, wraps natively)
_sccRxTail      DS      1                   ; consumer index
_isrEntryRR3    DS      1                   ; stash of A=RR3 on handler entry
_rxByteScratch  DS      1                   ; hand-off: drain → paint+enqueue
_simtestCursor  DS      1                   ; main-loop paint col on row 23 (0..79)

;------------------------------------------------------------------------------
; C0.5a — chan B TX ring buffer + transmission state.
;
; SPSC ring: main-loop tx_enqueue_byte is sole producer (writes head),
; simtest_isr TX leg is sole consumer (writes tail).
;------------------------------------------------------------------------------
_sccTxBuf       DS      256
_sccTxHead      DS      1                   ; producer (main loop)
_sccTxTail      DS      1                   ; consumer (handler)
_sccTxInProgress DS     1                   ; 0=idle, 1=byte in flight

;------------------------------------------------------------------------------
; C0.5f — live-display state (clock, kbd ring, per-direction counters).
;
; _kbdRing: SPSC ring fed by HB body (producer) on every VBL kbd poll,
; consumed by main loop (single consumer).  256-entry with natural
; 8-bit wrap, matching _sccRxBuf semantics.
;
; _simStatSeconds: clock value in seconds, advanced by HB body's
; mod-60 counter.  Avoids any divide in paint_stats_line.
;
; _simStat{Rx,Tx}Irqs and _simStat{Rx,Tx}Bytes: per-direction IRQ and
; byte counters incremented inside simtest_isr's per-leg paths and
; tx_enqueue_byte's not-dropped path.  Independent of the existing
; _simStatScc (per-IRQ-entry, both chans) and _simStatTxSent (Tx
; dequeue path only); both retained for fgxdebug compatibility.
;------------------------------------------------------------------------------
_kbdRing        DS      256                 ; producer = HB body, consumer = main loop
_kbdRingHead    DS      1                   ; 8-bit, natural wrap
_kbdRingTail    DS      1
_kbdSecMod60    DS      1                   ; HB-private mod-60 tick counter
_simStatSeconds DS      4                   ; wall-clock seconds since boot
_simStatRxIrqs  DS      4                   ; chan B Rx IP fires
_simStatTxIrqs  DS      4                   ; chan B Tx IP fires
_simStatRxBytes DS      4                   ; bytes enqueued into _sccRxBuf
_simStatTxBytes DS      4                   ; bytes enqueued into _sccTxBuf
_txCursor       DS      1                   ; row-22 column position (4..79)

; Snapshot data cache.  Populated by GatherSnapshotData in bank-$02
; native mode; consumed by tp1_print_snap directly.
_snapData       DS      SNAP_SIZE
