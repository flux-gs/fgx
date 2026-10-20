;==============================================================================
; uthernet.s - Uthernet II (WIZnet W5100) boot-time detection.
;
; First networking step (design: docs/superpowers/specs/
; 2026-06-03-fgx-networking-uthernet2-design.md; plan: docs/superpowers/plans/
; 2026-06-03-fgx-networking-phase0.md).  Probe the card at boot and log it,
; proving bank-$E0 indirect-bus access works before any module/IRQ machinery.
;
; The Uthernet II exposes the W5100 indirect-bus interface in the slot I/O
; space: base = (slot<<4)+$84, so slot 1's Mode Register (MR) = $E0C094.
; (FGX I/O rule: bank $E0, never $00.)  Detection = WIZnet's reset signature
; (ported from examples/hdtelnet/hdtelnet.s wizinit2/slotdet):
;   1. write MR=$80 (reset) -> the chip auto-clears MR to $00;
;   2. write MR=$03 (indirect + addr auto-increment) -> reads back $03.
; A non-W5100 device fails one of these.  Detection only touches MR; the
; indirect address/data registers ($E0C095-97) come with the driver later.
;==============================================================================

U2_MR           EQU     $E0C094         ; W5100 Mode Register, slot 1, bank $E0
U2_ARH          EQU     $E0C095         ; W5100 indirect address, high byte
U2_ARL          EQU     $E0C096         ; W5100 indirect address, low byte
U2_DAT          EQU     $E0C097         ; W5100 indirect data (auto-increments addr)
SLTROMSEL       EQU     $E0C02D         ; slot select: bit n=1 -> slot n peripheral
                                        ; card (vs IIgs internal port); gates $C0nX I/O

;------------------------------------------------------------------------------
; _ProbeUthernet2 - boot probe; logs the detection result to the kern log.
; MX %00 in/out (PHP/PLP).  Clobbers A, Y.  Logs "uthernet2: W5100 @ slot 1
; MR=$XX" on success, "uthernet2: absent (slot 1) MR=$XX" otherwise (the MR
; readback is logged either way for first-bring-up observability).
;------------------------------------------------------------------------------
_ProbeUthernet2 MX      %00
                PHP
                REP     #$30
                MX      %00
                ; --- absent check: _ScanSlots sets _u2Slot=0 if no W5100 found ---
                LDA     |_u2Slot
                AND     #$00FF
                BEQ     @u2_absent              ; _ScanSlots found no W5100 anywhere
                ; --- reset: write MR=$80; W5100 auto-clears MR to $00 ---
                SEP     #$20
                MX      %10
                ; Route detected slot to the peripheral card (not the IIgs internal
                ; port) so the W5100 I/O appears at $E0C0(slot*16+4)x.  Read-
                ; modify-write SLTROMSEL to preserve the other slots.
                LDAL    SLTROMSEL
                ORA     |_u2SltBit              ; route detected slot -> card
                STAL    SLTROMSEL
                LDA     #$80
; _w5SiteBase - the anchor the W5100 patch table's offsets are measured from,
; and it must stay the FIRST fixed-base U2_* site in the kernel listing.
;
; Without it the table held absolute offsets, so any change to the kernel's size
; -- anywhere, including code with nothing to do with networking -- rewrote all
; 51 entries and made two branches conflict on a generated file whose merge is
; never meaningful (apple/fgx#79).  Anchored, the entries are deltas WITHIN this
; file, so they change only when this file does.
;
; gen_w5100_patchsites.py refuses a negative delta rather than emitting one, so
; adding a U2_* site earlier in the kernel than this one fails the build with an
; instruction to move the label rather than silently producing a table that
; patches the wrong addresses.
_w5SiteBase     STAL    U2_MR
                LDAL    U2_MR
                STA     _u2_mr                  ; reset readback (expect $00)
                BNE     @u2_absent
                ; --- mode: write MR=$03 (indirect + auto-inc); reads back $03 ---
                LDA     #$03
                STAL    U2_MR
                LDAL    U2_MR
                STA     _u2_mr                  ; mode readback (expect $03)
                CMP     #$03
                BNE     @u2_absent
                ; --- present ---
                REP     #$20
                MX      %00
                ; Patch the slot digit in @u2_okMsg ('uthernet2: W5100 @ slot X MR=$')
                ; and in @rpMsg ('net: u2sX mac=') with the actual detected slot.
                ; DBR=kernel-bank; strings live in writable kernel-bank RAM.
                ; Digit offset in @u2_okMsg: 24 ('uthernet2: W5100 @ slot ' = 24 chars).
                LDA     |_u2Slot
                AND     #$00FF
                CLC
                ADC     #$30                    ; slot -> ASCII digit ('1'..'7')
                SEP     #$20
                MX      %10
                STA     |@u2_okMsg+24           ; patch 'slot X' digit in ok msg
                REP     #$20
                MX      %00
                LDA     #@u2_okMsg
                STA     _conStrPtr
                JSR     Kern_LogStrNoEOL
                SEP     #$20
                MX      %10
                LDA    |_u2_mr                  ; = $03
                JSR     Kern_LogHex8
                REP     #$20
                MX      %00
                JSR     Kern_LogEOL
                ; --- register the primary interface (u2s1) + derive its MAC,
                ;     then log it.  Out-of-line so _ProbeUthernet2 stays short
                ;     (keeps the @u2_absent branches in range). ---
                JSR     _Net_RegPrimary
                ; NOTE: _Net_BringUp below registers the W5100 ISR + arms IMR
                ; (_ArmUthernet2), but does NOT open/MACRAW any socket — socket 0
                ; stays CLOSED, so no IRQ fires at boot.  The firehose risk is
                ; from MACRAW-promiscuous on an OPEN socket (netdump's job, on
                ; /dev/bpf0 open), not from registering the ISR or arming IMR
                ; over a closed socket.  Foreground UDP bus sequences mask the
                ; W5100 IRQ via U2_LOCK so an IRQ mid-sequence can't corrupt the
                ; shared indirect AR.
                JSR     _Net_BringUp            ; polled W5100 reset/mode + SHAR;
                                                ; registers ISR + arms IMR (no DHCP)
                PLP
                RTS
; @u2_absent: reachable at MX %00 (new absence check: _ScanSlots found no card)
;             AND at MX %10 (BNE above: card found but MR readback wrong).
; REP #$20 below normalises M width for both entry paths before doing M8 byte ops.
@u2_absent      REP     #$20
                MX      %00
                ; For the early-exit path (_u2Slot=0): _u2_mr was never written.
                ; Narrow to M8 to zero it so we log 'MR=$00' (not stale BSS).
                SEP     #$20
                MX      %10
                STZ     _u2_mr
                ; A CARD THAT IS NOT THERE SAYS NOTHING.  2.11BSD's boot log
                ; names the interfaces it ATTACHED -- `attaching de0 csr
                ; 174510', `de0: DELUA addr 08:00:2b:b7:ea:e6' -- and is silent
                ; about every controller the kernel probed for and did not
                ; find.  `uthernet2: absent (slot 0) MR=$00' was on the console
                ; of every machine without a card, which is most of them, and
                ; it reported a register readback nobody but the driver's
                ; author can use.  The card being PRESENT is still announced.
                REP     #$20
                MX      %00
                PLP
                RTS
@u2_okMsg       ASC     'uthernet2: W5100 @ slot 1 MR=$',00
_u2_mr          DS      2
_ifS1Off        DS      2               ; slot-1 ifnet record byte-offset (set by
                                        ; _Ifnet_Register; used for SHAR write +
                                        ; the DHCP-result writeback, T6)
_w5SockInUse    DS      1               ; W5100 hw-socket allocator bitmap: bits
                                        ; 0..3 = sockets 0..3 (1 = in use).  Shared
                                        ; by the socket core (socket()) + the
                                        ; /dev/bpf0 capture driver.  Zero from the
                                        ; loaded kernel image (inline DS), like
                                        ; _u2_mr / _ifS1Off.
_tcpNextPort    DS      2               ; TCP: next ephemeral local port (host order)

;------------------------------------------------------------------------------
; _Net_RegPrimary - register the primary interface (u2sN, N = detected slot) in
; the ifnet table, derive its MAC, cache the record offset in _ifS1Off, and log
; "net: u2sN mac=aa:bb:cc:dd:ee:ff" (read from the record, so override-aware).
; MX %00 in/out (PHP/PLP).  Called from _ProbeUthernet2 on detect.
;------------------------------------------------------------------------------
_Net_RegPrimary MX      %00
                PHP
                REP     #$30
                MX      %00
                LDA     |_u2Slot                ; detected slot (was: LDA #1)
                AND     #$00FF
                JSR     _Ifnet_Register         ; -> X = record offset
                STX     _ifS1Off
                JSR     _Ifnet_LoadHwaddr       ; /etc/hwaddr.conf override (if any)
                ; Patch the slot digit in @rpMsg ('net: u2sX mac=').
                ; Digit offset: 8 ('net: u2s' = 8 chars).
                LDA     |_u2Slot
                AND     #$00FF
                CLC
                ADC     #$30                    ; slot -> ASCII digit
                SEP     #$20
                MX      %10
                STA     |@rpMsg+8               ; patch 'u2sX' digit in MAC log msg
                REP     #$20
                MX      %00
                LDA     #@rpMsg
                STA     _conStrPtr
                JSR     Kern_LogStrNoEOL
                LDA     _ifS1Off
                AND     #$00FF
                CLC
                ADC     #IF_Mac                 ; Y = record MAC offset (clean, M16)
                TAY
                SEP     #$20
                MX      %10
                ; Kern_LogHex8 / _nbMacColon clobber Y, so PHY/PLY around them
                ; (the record is index-read, unlike the chip auto-inc MAC log).
                LDA     [_ifTablePtr],Y         ; MAC[0]
                PHY
                JSR     Kern_LogHex8
                JSR     _nbMacColon
                PLY
                INY
                LDA     [_ifTablePtr],Y         ; MAC[1]
                PHY
                JSR     Kern_LogHex8
                JSR     _nbMacColon
                PLY
                INY
                LDA     [_ifTablePtr],Y         ; MAC[2]
                PHY
                JSR     Kern_LogHex8
                JSR     _nbMacColon
                PLY
                INY
                LDA     [_ifTablePtr],Y         ; MAC[3]
                PHY
                JSR     Kern_LogHex8
                JSR     _nbMacColon
                PLY
                INY
                LDA     [_ifTablePtr],Y         ; MAC[4]
                PHY
                JSR     Kern_LogHex8
                JSR     _nbMacColon
                PLY
                INY
                LDA     [_ifTablePtr],Y         ; MAC[5]
                JSR     Kern_LogHex8
                REP     #$20
                MX      %00
                JSR     Kern_LogEOL
                PLP
                RTS
@rpMsg          ASC     'net: u2s1 mac=',00     ; digit [8] patched at runtime -> u2sN

;------------------------------------------------------------------------------
; _ArmUthernet2 - register the W5100 ISR as a SIM non-SCC generic source and
; enable the chip's interrupts (IMR=$EF).  Called from _ProbeUthernet2 on
; detect.  MX %00 in/out.  No socket activity exists yet, so no IRQ fires until
; something triggers a W5100 event (Task 8) — this stays behavior-neutral.
;------------------------------------------------------------------------------
_ArmUthernet2   MX      %00
                PHP
                REP     #$30
                MX      %00
                ; Register _Uthernet2_ISR as a non-SCC generic source.
                ; RELOC: the handler runs at the LIVE kernel bank, not the baked
                ; ^_Uthernet2_ISR ($02 = assembly ORG).  Pass PHK (running kernel
                ; bank) as the SIM handler bank, else the dispatcher JMLs to
                ; $02:offset (empty after the direct kernel load) -> wild crash
                ; into ROM on the first W5100 IRQ (the boot IRQ self-test).
                ; Behaviour-identical at clean boot (PHK = $02).
                SEP     #$20
                MX      %10
                PHK
                PLA                             ; A.lo = live kernel bank
                REP     #$20
                MX      %00
                AND     #$00FF
                TAY                             ; Y.lo = handler bank = live kernel bank
                LDA     #_Uthernet2_ISR         ; 16-bit handler offset
                JSR     _Sim_InstallGeneric     ; C ignored (registry has room)
                SEP     #$20
                MX      %10
                ; --- clear pending IRQs so arming starts clean: discard the DISCOVER's
                ;     SEND_OK (S0_IR) + any IR system bits, else they fire the instant we
                ;     arm and storm before the OFFER's RECV (W5100 events are per-edge;
                ;     a pending edge re-fires on arm). ---
                LDA     #$04
                STAL    U2_ARH
                LDA     #$02
                STAL    U2_ARL                  ; AR=$0402 (S0_IR)
                LDA     #$FF
                STAL    U2_DAT                  ; S0_IR <- $FF (write-1-to-clear)
                LDA     #$00
                STAL    U2_ARH
                LDA     #$15
                STAL    U2_ARL                  ; AR=$0015 (IR)
                LDA     #$FF
                STAL    U2_DAT                  ; IR <- $FF (clears system bits 7-5)
                ; --- enable W5100 interrupts: IMR ($0016) = $01 (socket 0 only) ---
                LDA     #$00
                STAL    U2_ARH
                LDA     #$16
                STAL    U2_ARL
                LDA     #$01
                STA     |_u2Imr         ; socket-0-only enable (mask system/other-socket
                STAL    U2_DAT          ;   storm sources); U2_UNLOCK restores this. IMR<-$01
                REP     #$20
                MX      %00
                PLP
                RTS

;------------------------------------------------------------------------------
; _Uthernet2_ISR - SIM generic-source handler for the W5100 slot IRQ.  Reached
; from _KernIrq_Dispatch's non-SCC walk (via the _simTramp JML; RTLs back).
; Entry: MX %11 (M8/X8), DBR=kernel-bank ($02 = assembly ORG; sim.s PHK/PLB),
; DP=0.  Honors the SIM handler contract: stays DBR=kernel-bank / DP=0 / MX %11,
; touches no $E1:0108-0119 and not the I flag; clobbers
; A, X (the walk PHX/PLX's its index around us).
;
; Read IRQR ($0015): 0 -> SEC (not ours).  Else bump _u2IrqCount, record
; _u2IrqLastIR, then CLEAR the source (write IRQR back to clear system bits;
; write $00 to all 4 sockets' Sn_IR) so the W5100 INT deasserts BEFORE the
; firmware chain, and RTL with CLC (claimed).
;------------------------------------------------------------------------------
_Uthernet2_ISR  MX      %11
                DO      U2_XPARENT=0
                ; --- IMR-gating: skip if foreground owns the bus (no W5100 access).
                ;     The shared generic walk calls us on EVERY non-SCC IRQ (incl.
                ;     sound), so a plain-memory _u2Locked check must gate any AR use. ---
                LDA     |_u2Locked              ; DBR=kernel (ISR); matches net.s/bpf.s + the kernel macro
                BEQ     @u2i_go
                SEC                             ; foreground locked -> not ours
                RTL
                FIN
@u2i_go
                ; The IIgs IRQ entry can reset SLTROMSEL to internal -> our $E0C09x
                ; reads would then hit the slot-1 internal ROM (garbage IRQR) and we'd
                ; falsely claim every IRQ. Re-assert slot-1 = external for our reads;
                ; restored at every exit so the firmware chain sees the original value.
                LDAL    SLTROMSEL
                STA    |_u2SltSave
                ORA     |_u2SltBit
                STAL    SLTROMSEL
                DO      U2_XPARENT=1
                ; --- transparent-ISR: snapshot the foreground AR (restored on exit) ---
                LDAL    U2_ARH
                STAL    _arSaveH
                LDAL    U2_ARL
                STAL    _arSaveL
                FIN
                ; --- read IRQR ($0015) for ownership ---
                LDA     #$00
                STAL    U2_ARH
                LDA     #$15
                STAL    U2_ARL
                LDAL    U2_DAT                  ; A = IRQR
                BNE     @u2i_mine
                DO      U2_XPARENT=1
                LDAL    _arSaveH                ; not ours: restore AR before bailing
                STAL    U2_ARH
                LDAL    _arSaveL
                STAL    U2_ARL
                FIN
                LDA    |_u2SltSave              ; restore slot routing for the firmware chain
                STAL    SLTROMSEL
                SEC                             ; IRQR=0 -> not our interrupt
                RTL
@u2i_mine       STA    |_u2IrqLastIR            ; record the IRQR we saw
                INC     _u2IrqCount             ; bump (8-bit; >0 means it fired)
                LDA     #1                      ; flag a socket event so swtch @sw_save
                STA     _kSockWakePending       ; wakes WCHAN_SOCK (M8: low byte; A
                                                ; reloaded by the next instruction)
                ; --- clear IRQR system bits (write-1-to-clear) ---
                LDA     #$00
                STAL    U2_ARH
                LDA     #$15
                STAL    U2_ARL
                LDA    |_u2IrqLastIR
                STAL    U2_DAT                  ; write IRQR back -> clears its set bits
                ; --- per-socket: read Sn_IR ($0n02), set _u2RxReady bit on RECV ($04),
                ;     then clear Sn_IR <- $FF (write-1-to-clear).  LAZY: no data copy here
                ;     (foreground recv drains the RX buffer).  Sn_IR is write-1-to-clear
                ;     (MAME m_ir &= ~data; datasheet agrees) — $00 would clear nothing and
                ;     leave the W5100 INT asserted (infinite IRQ). ---
                LDX     #$04                    ; AR hi walks socket pages $04..$07
@u2i_sL         TXA
                STAL    U2_ARH
                LDA     #$02
                STAL    U2_ARL                  ; AR lo = $02 (Sn_IR offset)
                LDAL    U2_DAT                  ; A = Sn_IR (AR auto-incs to $0n03)
                AND     #$04                    ; RECV bit set?
                BEQ     @u2i_clr
                ; set _u2RxReady bit (1 << (socket# = X-4))
                TXA
                SEC
                SBC     #$04                    ; A = socket index 0..3
                TAY                             ; Y = shift count (dispatch saved caller Y)
                LDA     #$01
@u2i_shl        CPY     #$00
                BEQ     @u2i_set
                ASL
                DEY
                BRA     @u2i_shl
@u2i_set        ORA     _u2RxReady              ; DBR=kernel-bank (SIM handler contract)
                STA    |_u2RxReady
                ; one-shot guard: disarm the W5100 IRQ (IMR=0) the instant we flag a
                ; RECV, so the LEVEL-triggered RECV can't re-fire before foreground
                ; drains the RX buffer (the lazy-ISR firehose that hung Phase 0b).
                LDA     #$00
                STA     |_u2Imr                 ; shadow = disarmed (U2_UNLOCK keeps it 0)
                STAL    U2_ARH
                LDA     #$16
                STAL    U2_ARL
                LDA     #$00
                STAL    U2_DAT                  ; IMR <- $00 (chip)
@u2i_clr        TXA                             ; re-point AR to $0n02 for the clear write
                STAL    U2_ARH
                LDA     #$02
                STAL    U2_ARL
                LDA     #$FF
                STAL    U2_DAT                  ; Sn_IR <- $FF (write-1-to-clear)
                INX
                CPX     #$08
                BCC     @u2i_sL
                DO      U2_XPARENT=1
                ; --- transparent-ISR: restore the foreground AR ---
                LDAL    _arSaveH
                STAL    U2_ARH
                LDAL    _arSaveL
                STAL    U2_ARL
                FIN
                LDA    |_u2SltSave              ; restore slot routing before chaining
                STAL    SLTROMSEL
                CLC                             ; claimed
                RTL

;==============================================================================
; _Net_BringUp - polled W5100 reset/mode/init + SHAR-from-record.  DHCP is no
;
; Runs at boot (from _ProbeUthernet2) with the chip IMR=0 — NO interrupts, so
; the indirect-bus address pointer is ours exclusively (no ISR re-entrancy).
; All loops are bounded so boot always completes.  Sequence:
;   1. reset + indirect/auto-inc mode;
;   2. _W5_RunInit: RMSR/TMSR, RTR/RCR, SHAR (our MAC), socket-0 UDP + dest;
;   3. open socket 0 (UDP, src port 68), bounded wait for SR=UDP;
;   4. build a DHCP DISCOVER in the TX buffer and SEND it (broadcast, no ARP);
;   5. bounded-poll S0_RX_RSR for the OFFER; log the received size and, if any,
;      the offered IP (yiaddr) read straight from the RX buffer — never faked.
; MX %00 in/out (PHP/PLP); DBR forced to the live kernel-bank (PHK/PLB) for the
; abs,X/abs,Y table reads ($02 = assembly ORG only).
;==============================================================================
W5_SHAR0        EQU     $0009           ; source MAC, byte 0
W5_S0_CR        EQU     $0401           ; socket 0 command
W5_S0_SR        EQU     $0403           ; socket 0 status
W5_S0_RXRSR     EQU     $0426           ; socket 0 received-size
W5_S0_TXWR      EQU     $0424           ; socket 0 TX write pointer
W5_TXBASE       EQU     $4000           ; socket 0 TX buffer base (TMSR=$55)
W5_RXBASE       EQU     $6000           ; socket 0 RX buffer base (RMSR=$55)
W5_RXMASK       EQU     $07FF           ; 2 KB RX ring mask (RMSR=$55)
W5_S0_MR        EQU     $0400           ; socket 0 mode register
W5_S0_RXRD      EQU     $0428           ; socket 0 RX read pointer (16-bit BE)
W5_SR_UDP       EQU     $22             ; Sn_SR value for an open UDP socket
W5_MR_MACRAW    EQU     $44             ; Sn_MR MACRAW($04) + MAC-filter($40) — capture
W5_SR_MACRAW    EQU     $42             ; Sn_SR value for an open MACRAW socket
W5_CR_RECV      EQU     $40             ; Sn_CR RECV (commit RX_RD advance)
BPF_SNAPLEN     EQU     60              ; bytes captured per frame (header-only view)

_Net_BringUp    MX      %00
                PHB
                PHK
                PLB                     ; DBR = kernel-bank for abs,X/abs,Y table reads
                PHP
                REP     #$30
                MX      %00
                ; --- slot 1 -> card (idempotent); reset + mode the W5100 ---
                SEP     #$30
                MX      %11
                LDAL    SLTROMSEL
                ORA     |_u2SltBit
                STAL    SLTROMSEL
                LDA     #$80
                STAL    U2_MR           ; reset (auto-clears to $00; zeros ptrs)
                LDA     #$03
                STAL    U2_MR           ; indirect + address auto-increment
                DO      U2_DIAG=1
                ; --- AR-readback diagnostic (U2_DIAG): write AR=$1A2B, read it
                ;     back, read DAT once (auto-inc), re-read AR.  r=$1A2B & i=$1A2C
                ;     => the W5100 indirect AR is read-back-able + tracks auto-inc
                ;     (transparent-ISR / U2_XPARENT=1 viable on this target).  The
                ;     real-hardware measurement instrument; read via dmesg. ---
                LDA     #$1A
                STAL    U2_ARH
                LDA     #$2B
                STAL    U2_ARL
                REP     #$30
                MX      %00
                LDA     #@arMsg
                STA     _conStrPtr
                JSR     Kern_LogStrNoEOL        ; "net: ARtest w=$1A2B r=$"
                SEP     #$20
                MX      %10
                LDAL    U2_ARH                  ; AR readback hi
                JSR     Kern_LogHex8
                LDAL    U2_ARL                  ; AR readback lo
                JSR     Kern_LogHex8
                LDAL    U2_DAT                  ; one data read -> AR auto-increments
                REP     #$20
                MX      %00
                LDA     #@arMsgI
                STA     _conStrPtr
                JSR     Kern_LogStrNoEOL        ; " i=$"
                SEP     #$20
                MX      %10
                LDAL    U2_ARH                  ; AR hi after one auto-inc
                JSR     Kern_LogHex8
                LDAL    U2_ARL                  ; AR lo after one auto-inc
                JSR     Kern_LogHex8
                REP     #$30
                MX      %00
                JSR     Kern_LogEOL
                SEP     #$30
                MX      %11
                FIN
                ; --- fixed-register init (MX %11 in/out) ---
                JSR     _W5_RunInit
                ; --- SHAR (our MAC) from the ifnet record (was in _w5InitTbl) ---
                JSR     _W5_WriteSharFromRec
                REP     #$30
                MX      %00
                ; Register the W5100 ISR with SIM + arm IMR=$01.  Socket 0 is
                ; CLOSED here — /dev/bpf0 capture (_Net_CaptureStart) re-modes it
                ; to MACRAW on open — so NO RECV IRQ fires until then: no boot
                ; firehose.  This is what boot DHCP's _ArmUthernet2 used to do
                ; (deleted with boot DHCP in T9); netdump's MACRAW capture ASSUMES
                ; the ISR is registered, else a captured frame's RECV IRQ is
                ; unhandled and storms (hang).  Done ONCE here on purpose —
                ; _Sim_InstallGeneric is NOT idempotent, so it must not live in
                ; _Net_CaptureStart (repeated opens would bloat the SIM registry).
                JSR     _ArmUthernet2
                LDA     #49152              ; TCP ephemeral local-port base ($C000)
                STA     _tcpNextPort
                ; (The MACRAW capture self-test that used to live here under
                ;  U2_DIAG=1 moved to bpf.mod with the capture driver in P0.4;
                ;  exercise capture via the userland `netdump` tool instead.)
                PLP
                PLB
                RTS
                DO      U2_DIAG=1
@arMsg          ASC     'net: ARtest w=$1A2B r=$',00
@arMsgI         ASC     ' i=$',00
                FIN

;------------------------------------------------------------------------------
; _nbMacColon - emit a ':' MAC-octet separator.  M8/X8 in and out (PHP/PLP);
; widens to M16/X16 internally for the string emit.
;------------------------------------------------------------------------------
_nbMacColon     MX      %10
                PHP
                REP     #$30
                MX      %00
                LDA     #@colStr
                STA     _conStrPtr
                JSR     Kern_LogStrNoEOL
                PLP
                RTS
@colStr         ASC     ':',00

;------------------------------------------------------------------------------
; _W5_RunInit - write the fixed-register init table to the W5100 over the
; indirect bus.  Table = {addr_hi, addr_lo, value} triples, $FF hi = end.
; (addr_hi is always $00/$04 for real registers, so $FF is an unambiguous
; terminator while a value byte of $FF stays legal.)  MX %11 in/out.
;------------------------------------------------------------------------------
_W5_RunInit     MX      %11
                LDX     #$00
@ri_lp          LDA     _w5InitTbl,X            ; addr hi (or $FF terminator)
                CMP     #$FF
                BEQ     @ri_done
                STAL    U2_ARH
                INX
                LDA     _w5InitTbl,X            ; addr lo
                STAL    U2_ARL
                INX
                LDA     _w5InitTbl,X            ; value
                STAL    U2_DAT
                INX
                BRA     @ri_lp
@ri_done        RTS

; W5100 fixed-register init: RX/TX mem 2KB/socket, retry 200ms x8, socket 0 =
; UDP src port 68, dest 255.255.255.255:67.  SHAR (our MAC) is NO LONGER here —
; it is written by _W5_WriteSharFromRec from the ifnet record (derived default
; 00:08:DC:F6:00:<slot> + /etc/hwaddr.conf override), so a per-card/per-machine
; MAC is possible.
_w5InitTbl      HEX     001A55                  ; RMSR = 2KB/socket
                HEX     001B55                  ; TMSR = 2KB/socket
                HEX     001707                  ; RTR hi  (retry timeout 0x07D0)
                HEX     0018D0                  ; RTR lo
                HEX     001908                  ; RCR = 8 retries
                HEX     040002                  ; S0_MR = UDP
                HEX     040400                  ; S0_PORT hi
                HEX     040544                  ; S0_PORT lo = 68 (DHCP client)
                HEX     040CFF                  ; S0_DIPR = 255.255.255.255
                HEX     040DFF
                HEX     040EFF
                HEX     040FFF
                HEX     041000                  ; S0_DPORT hi
                HEX     041143                  ; S0_DPORT lo = 67 (DHCP server)
                HEX     FF                       ; terminator

;------------------------------------------------------------------------------
; _W5_WriteSharFromRec - write the W5100 SHAR (source MAC) from the slot-1 ifnet
; record (offset _ifS1Off, field IF_Mac).  MX %11 (M8/X8) in/out; DBR=kernel-bank
; (for _ifS1Off).  Set AR -> SHAR0 once; U2_DAT auto-increments (MR=$03), so 6 writes
; walk SHAR[0..5].  [_ifTablePtr],Y is DBR-independent (DP long-pointer).
;------------------------------------------------------------------------------
_W5_WriteSharFromRec MX %11
                LDA     #>W5_SHAR0      ; AR hi = $00
                STAL    U2_ARH
                LDA     #<W5_SHAR0      ; AR lo = $09
                STAL    U2_ARL
                LDA     _ifS1Off        ; record offset (8-bit; < 256)
                CLC
                ADC     #IF_Mac
                TAY                     ; Y = record MAC offset
                LDX     #6
@ws_lp          LDA     [_ifTablePtr],Y ; MAC byte from the record
                STAL    U2_DAT          ; -> SHAR (AR auto-increments)
                INY
                DEX
                BNE     @ws_lp
                RTS

;------------------------------------------------------------------------------
; _W5_WriteIpFromRec - push the slot-1 ifnet record's IP config to the W5100:
;   GAR  ($0001) <- IF_Gateway, SUBR ($0005) <- IF_Netmask, SIPR ($000F) <- IF_Ip.
; The chip needs SIPR to answer ARP for / accept unicast traffic at its leased
; address (DHCP worked without it: broadcast send + source 0.0.0.0).  Called
; from the SYS_IFCONFIG IFC_SET path when the slot-1 interface's IP is assigned
; (dhclient) — so it runs at runtime with the ISR armed and is U2_LOCK-wrapped.
; MX %00 in/out.  DBR=kernel-bank.  Uses _ifS1Off + _ifTablePtr.
;------------------------------------------------------------------------------
_W5_WriteIpFromRec MX   %00
                REP     #$30
                MX      %00
                U2_LOCK
                SEP     #$30            ; M8/X8 for the single-byte bus writes
                MX      %11
                ; --- GAR ($0001) <- IF_Gateway (record +28) ---
                LDA     #$00
                STAL    U2_ARH
                LDA     #$01
                STAL    U2_ARL          ; AR = $0001 (GAR0)
                LDA     _ifS1Off
                CLC
                ADC     #IF_Gateway
                TAY
                LDX     #4
@wi_gw          LDA     [_ifTablePtr],Y
                STAL    U2_DAT
                INY
                DEX
                BNE     @wi_gw
                ; --- SUBR ($0005) <- IF_Netmask (record +20) ---
                LDA     #$00
                STAL    U2_ARH
                LDA     #$05
                STAL    U2_ARL          ; AR = $0005 (SUBR0)
                LDA     _ifS1Off
                CLC
                ADC     #IF_Netmask
                TAY
                LDX     #4
@wi_nm          LDA     [_ifTablePtr],Y
                STAL    U2_DAT
                INY
                DEX
                BNE     @wi_nm
                ; --- SIPR ($000F) <- IF_Ip (record +16) ---
                LDA     #$00
                STAL    U2_ARH
                LDA     #$0F
                STAL    U2_ARL          ; AR = $000F (SIPR0)
                LDA     _ifS1Off
                CLC
                ADC     #IF_Ip
                TAY
                LDX     #4
@wi_ip          LDA     [_ifTablePtr],Y
                STAL    U2_DAT
                INY
                DEX
                BNE     @wi_ip
                REP     #$30
                MX      %00
                U2_UNLOCK
                RTS

;------------------------------------------------------------------------------
; _SlotHasRom - decide if the slot whose record is at _ssRecOff has a firmware
; ROM.  Returns A.lo != 0 if ROM present (skip the destructive W5100 probe).
; Heuristic (calibrated by slotscan_detect / slotscan_disk_safe tests): ROM
; present unless the 6 sig bytes are all identical (uniform open-bus floating).
; Conservative: ties -> "ROM present" so we never I/O-probe a real card.
;------------------------------------------------------------------------------
_SlotHasRom     MX      %00
                LDX     |_ssRecOff              ; record offset (word -> X16)
                SEP     #$20
                MX      %10
                LDA     |_slotTab+1,X           ; sig[0] (recOff+1)
                STA     |_ssTmp                 ; reference byte
                REP     #$20
                MX      %00
                LDY     #1                      ; sig index 1..5
@hr_loop        CPY     #6
                BCS     @hr_uniform             ; all 6 equal -> floating -> no ROM
                TYA
                CLC
                ADC     |_ssRecOff
                INC                             ; idx = recOff + 1 + Y (skip flags)
                TAX
                SEP     #$20
                MX      %10
                LDA     |_slotTab,X             ; sig[Y]
                CMP     |_ssTmp
                REP     #$20
                MX      %00
                BNE     @hr_hasRom              ; a differing byte -> structured -> ROM
                INY
                BRA     @hr_loop
@hr_hasRom      LDA     #1                      ; M16: A = $0001
                RTS
@hr_uniform     LDA     #0
                RTS

;------------------------------------------------------------------------------
; _SlotIsStorage - true (A.lo != 0) if the slot at _ssRecOff presents a ProDOS
; block-storage firmware ID: $Cn01=$20, $Cn03=$00, $Cn05=$03 (= sig[0],sig[1],
; sig[2]).  Covers SmartPort AND Disk II ($Cn07 differs: $00 vs $3C).  We must
; NOT run the destructive W5100 I/O probe on these (their $C0nX I/O are disk
; soft switches).  Everything else (internal-port firmware, empty, unknown) is
; probed.
;------------------------------------------------------------------------------
_SlotIsStorage  MX      %00
                LDX     |_ssRecOff
                SEP     #$20
                MX      %10
                LDA     |_slotTab+1,X           ; sig[0] = $Cn01
                CMP     #$20
                BNE     @is_no
                LDA     |_slotTab+2,X           ; sig[1] = $Cn03
                CMP     #$00
                BNE     @is_no
                LDA     |_slotTab+3,X           ; sig[2] = $Cn05
                CMP     #$03
                BNE     @is_no
                REP     #$20
                MX      %00
                LDA     #1                      ; storage -> skip probe
                RTS
@is_no          REP     #$20
                MX      %00
                LDA     #0
                RTS

;------------------------------------------------------------------------------
; _ScanSlots - boot-time card scan.  For each slot 1..7: route it external,
; (Pass 1) read the $Cn00 ROM signature bytes and decide if a firmware ROM is
; present, (Pass 2 - Task 5) if NO ROM, do the destructive W5100 reset/verify
; probe.  Caches results in _slotTab; sets _u2Slot/_u2SltBit to the first W5100
; found.  Runs at boot before _ProbeUthernet2 (no IRQs live yet); SEI + SLTROMSEL
; save/restore for safety.  Does NOT bind anything (Phase A).
;------------------------------------------------------------------------------
; SLREC_SZ + SLF_OCCUPIED/W5100/HASROM/BOUND are defined in syscall.s (Task 2).
; signature offsets captured into sig[0..5] (this DFB table is kernel-bank data):
_ssSigOffs      DFB     $01,$03,$05,$07,$0B,$0C

_ScanSlots      MX      %00
                PHP
                PHB
                PHK
                PLB                             ; DBR = kernel bank for _slotTab
                REP     #$30
                MX      %00
                SEP     #$20
                MX      %10
                SEI
                LDAL    SLTROMSEL
                STA     |_ssSltSave             ; save to restore at end
                REP     #$30
                MX      %00
                STZ     |_u2Slot                ; (clears _u2Slot + _u2SltBit, M16)
                ; clear _slotTab (49 bytes)
                SEP     #$20
                MX      %10
                LDX     #0
@sc_clr         CPX     #SLREC_SZ*7
                BCS     @sc_clrDone
                STZ     |_slotTab,X
                INX
                BRA     @sc_clr
@sc_clrDone     REP     #$30
                MX      %00

                ; --- per-slot loop, slot in _ssSlot = 1..7 ---
                LDA     #1
                STA     |_ssSlot
@sc_loop        ; route this slot external in SLTROMSEL.  Compute (1<<slot) in
                ; M16 so the index/byte stay clean (width drift is THE bug class).
                REP     #$30
                MX      %00
                LDA     |_ssSlot
                AND     #$00FF
                TAX                             ; X = slot (clean high byte)
                LDA     #1
@sc_bit         ASL                             ; ASL-first: shift slot times -> 1<<slot
                                                ;   (DEX-first would give 1<<(slot-1) -- the bug fixed here)
                DEX
                BNE     @sc_bit                 ; (slot iterations: 1 reaches $02)
@sc_bitDone     SEP     #$20
                MX      %10
                STA     |_ssSltBitTmp           ; (1<<slot) low byte
                LDAL    SLTROMSEL
                ORA     |_ssSltBitTmp
                STAL    SLTROMSEL
                ; NB: we deliberately do NOT touch the slot-3 SETINTC3ROM/SETSLOTC3ROM
                ; soft switch.  It is NOT covered by the SLTROMSEL save/restore, so
                ; writing it would leave slot 3 mis-routed after boot.  Slot 3 thus
                ; reads its internal 80-col ROM here -> classified HASROM -> never
                ; destructively probed (safe).  Detecting a W5100 in slot 3 is an
                ; unsupported corner (a bad NIC slot); the non-default test uses slot 5.
                REP     #$30
                MX      %00

                ; --- Pass 1: read sig[0..5] from $E0C000 + (slot<<8) + off ---
                ; page index = slot<<8
                LDA     |_ssSlot
                AND     #$00FF
                XBA                             ; A = slot<<8
                STA     |_ssPage
                ; record offset = (slot-1)*7   (x*7 = x*8 - x)
                LDA     |_ssSlot
                AND     #$00FF
                DEC
                STA     |_ssTmp
                ASL
                ASL
                ASL                             ; (slot-1)*8
                SEC
                SBC     |_ssTmp                 ; *8 - *1 = *7
                STA     |_ssRecOff
                ; capture the 6 signature bytes (X = sig index 0..5, X16 throughout)
                LDX     #0
@sc_sig         CPX     #6
                BCS     @sc_sigDone
                PHX                             ; save sig index
                SEP     #$20
                MX      %10
                LDA     |_ssSigOffs,X           ; sig offset byte
                REP     #$20
                MX      %00
                AND     #$00FF
                CLC
                ADC     |_ssPage                ; src index = (slot<<8) + off
                TAX                             ; X = ROM source index (sig idx is
                                                ;   on the stack; long,X is the only
                                                ;   valid abs-long indexed mode -
                                                ;   65816 has no LDAL abs-long,Y)
                SEP     #$20
                MX      %10
                LDAL    $E0C000,X               ; read $Cn ROM byte
                STA     |_ssSigByte
                REP     #$20
                MX      %00
                PLX                             ; sig index
                PHX
                TXA
                CLC
                ADC     |_ssRecOff
                INC                             ; dst = recOff + 1 + index (skip flags)
                TAX
                SEP     #$20
                MX      %10
                LDA     |_ssSigByte
                STA     |_slotTab,X
                REP     #$20
                MX      %00
                PLX
                INX
                BRA     @sc_sig
@sc_sigDone     REP     #$30
                MX      %00

                ; --- naming flag: SLF_HASROM|OCCUPIED if the sig is structured
                ;     (non-uniform).  Display only; does NOT gate the probe. ---
                JSR     _SlotHasRom
                AND     #$00FF
                BEQ     @sc_chkProbe
                SEP     #$20
                MX      %10
                LDX     |_ssRecOff
                LDA     #SLF_HASROM
                ORA     #SLF_OCCUPIED
                STA     |_slotTab,X
                REP     #$30
                MX      %00
@sc_chkProbe    ; --- Pass-2 gate: probe for the W5100 UNLESS this slot is a
                ;     recognized block-storage controller (disk-safety). ---
                JSR     _SlotIsStorage
                AND     #$00FF
                BEQ     @sc_doProbe             ; not storage -> probe
                JMP     @sc_next                ; storage -> skip (JMP: may be far)
@sc_doProbe     ; --- Pass 2: destructive W5100 reset/verify probe at
                ;     $E0C084 + (slot<<4).  slot<<4 in M16 (clean) -> X, then SEP
                ;     for the single-byte bus I/O. ---
                REP     #$30
                MX      %00
                LDA     |_ssSlot
                AND     #$00FF
                ASL
                ASL
                ASL
                ASL                             ; slot<<4
                TAX                             ; X = slot<<4 (X16)
                SEP     #$20
                MX      %10
                LDA     #$80                    ; reset
                STAL    $E0C084,X               ; MR <- $80
                LDAL    $E0C084,X               ; auto-clears to $00 if W5100
                BNE     @sc_notW5
                LDA     #$03                    ; indirect + auto-inc
                STAL    $E0C084,X
                LDAL    $E0C084,X
                CMP     #$03
                BNE     @sc_notW5
                ; W5100 confirmed -> flags |= W5100|OCCUPIED (X still 16-bit; value reloaded w/ recOff)
                LDX     |_ssRecOff
                LDA     |_slotTab,X
                ORA     #SLF_W5100
                ORA     #SLF_OCCUPIED
                STA     |_slotTab,X
                ; record the FIRST W5100 slot found
                LDA     |_u2Slot
                BNE     @sc_notW5               ; already recorded one
                LDA     |_ssSlot
                STA     |_u2Slot
                LDA     |_ssSltBitTmp
                STA     |_u2SltBit
@sc_notW5       REP     #$30
                MX      %00
@sc_next        ; restore SLTROMSEL + advance slot (M8: _ssSlot is a byte; REP
                ; #$30 does not touch carry, leaving carry from CMP intact for
                ; the BCS)
                SEP     #$20
                MX      %10
                LDA     |_ssSltSave
                STAL    SLTROMSEL
                LDA     |_ssSlot
                INC
                STA     |_ssSlot
                CMP     #8
                REP     #$30
                MX      %00
                BCS     @sc_doneLoop            ; slot >= 8 -> done (inverted +
                JMP     @sc_loop                ;   JMP: the loop body exceeds the
                                                ;   relative-branch range)
@sc_doneLoop    ; restore SLTROMSEL (already restored each iter; restore once more)
                SEP     #$20
                MX      %10
                LDA     |_ssSltSave
                STAL    SLTROMSEL
                REP     #$30
                MX      %00
                PLB
                PLP
                RTS

;------------------------------------------------------------------------------
; _W5_PatchSlot - bind the kernel's W5100 register accesses to the detected slot.
;
; The kernel's ~51 fixed-base STAL/LDAL U2_MR/ARH/ARL/DAT sites bake slot 1
; ($E0C094..97).  After _ScanSlots has found the card (boot, before
; _ProbeUthernet2), this rewrites each instruction's operand LOW byte so it
; addresses the detected slot's W5100 base = $E0C084 + (_u2Slot<<4); the four
; registers sit at base+0/+1/+2/+3 (regoff from the patch table).  So:
;     newlow = $84 + (_u2Slot<<4) + regoff
; The high operand bytes ($C0,$E0) are identical for every slot 1..7, so only
; the low byte changes -- a single-byte self-mod per site.  For slot 1, newlow
; == the baked $94/$95/$96/$97 -> every store is a NO-OP (backward compatible;
; the slot-1 net path is unchanged).
;
; Self-mod idiom: identical to _RelocPatchWaveE (main.s).  _DBRK sets DBR = live
; kernel bank, so STA: $0000,X writes to kernel-bank:offset -- i.e. into the
; kernel's own (relocated) code.  _w5PatchTbl (GENERATED: w5100_patchsites.s) is
; DA(offset)+DFB(regoff) triples, $FFFF-terminated.
;
; Guard: _u2Slot==0 (no card) -> RTS (nothing to bind).  Note net.mod/bpf.mod
; have their OWN U2_* sites and are patched separately (a later task); the
; kernel-only patch keeps slot 1 working and binds the kernel's own accesses.
;
; Entry: called from FGX boot after _ScanSlots, MX %00.  Preserves MX/flags
; (PHP); DBR restored (PHB/PLB).  Clobbers A, X, Y.
;------------------------------------------------------------------------------
_W5_PatchSlot   MX      %00
                PHP
                PHB
                ; --- DBR = live kernel bank FIRST, so the |abs reads/writes
                ;     below (_u2Slot, _wpBaseLow, _w5PatchTbl) AND the STA: $0000,X
                ;     self-mod all land in the kernel bank regardless of the
                ;     caller's DBR.  Same idiom as _RelocPatchWaveE. ---
                _DBRK                           ; (MX-agnostic: PHK/PLB)
                REP     #$30
                MX      %00
                ; --- guard: no W5100 detected -> nothing to bind ---
                SEP     #$20
                MX      %10
                LDA     |_u2Slot
                BEQ     @wp_done                ; 0 = no card
                ; --- precompute the slot base low byte: $84 + (_u2Slot<<4).
                ;     regoff (0..3) is added per-site inside the loop. ---
                ASL
                ASL
                ASL
                ASL                             ; _u2Slot<<4 (slot 1..7 -> $10..$70)
                CLC
                ADC     #$84                    ; base low byte for this slot's W5100
                STA     |_wpBaseLow             ; e.g. slot1=$94, slot5=$D4
                REP     #$30
                MX      %00
                LDY     #0
@wp_loop        LDX     _w5PatchTbl,Y           ; X = operand-low-byte offset (M16/X16)
                CPX     #$FFFF
                BEQ     @wp_done                ; sentinel -> done
                INY
                INY                             ; Y -> the DFB regoff byte
                SEP     #$20
                MX      %10
                LDA     _w5PatchTbl,Y           ; A.lo = regoff (0..3)
                CLC
                ADC     |_wpBaseLow             ; newlow = $84 + (slot<<4) + regoff
                STA:    $0000,X                 ; self-mod: kernel-bank:offset <- newlow
                REP     #$30
                MX      %00
                INY                             ; past the DFB byte -> next entry
                BRA     @wp_loop
@wp_done        REP     #$30
                MX      %00
                PLB                             ; restore caller DBR (balances entry PHB)
                PLP
                RTS

_wpBaseLow      DS      1                       ; scratch: $84 + (_u2Slot<<4), set per call

