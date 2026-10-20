;==============================================================================
; sim.s - SIM (Serial Interrupt Manager) kernel implementation.
;
; Lifted from src/standalone/simtest/simtest.s at tag
; sim-c05f-live-irq-display.  Phase 1 of the SIM design:
;   docs/superpowers/specs/2026-05-26-fgx-sim-design.md (parent)
;   docs/superpowers/specs/2026-05-27-fgx-sim-kernel-lift-design.md (this lift)
;
; Replaces the passthrough dispatcher that previously lived in
; src/kernel/irq.s (deleted in C1 of this lift).
;
; Owns IRQ entry at $E10010.  Non-SCC IRQs chain to ROM main handler
; (which fires the firmware HB queue, which fires _HBTickTask — tick,
; uptime, kbd ring all keep working unchanged).  SCC IRQs walk
; _simHandlerTbl; registered handlers return CLC if claimed.
;
; DBR contract for handlers: dispatcher does PHK/PLB before JSL'ing the
; handler, so handler entry DBR = kernel-bank ($02 = assembly ORG).  Handlers
; reading _sccRxBuf / _sccTxBuf (both in memmap.s, in the kernel bank) need no
; DBR swap.
; Handlers touching their own module-bank statics MUST PHB/PHK/PLB
; around the access and restore DBR before RTL.
;
; BRK detect ordering invariant: feedback_sim_brk_check_c_clobber.md.
; The BRK check must run after PHP/PHB/PEA/PLB and BEFORE any
; C-clobbering instruction.  The shadow-mask CMP #1 fires later and
; would invalidate the C-from-XCE if positioned before.
;==============================================================================

;------------------------------------------------------------------------------
; SCC address EQUs (chan A / chan B command + data).  Bank $E0: bank $00
; I/O is RAMWRT-shadowed, and $E0 always reaches hardware.
;------------------------------------------------------------------------------
SCC_A_CMD       EQU     $E0C039
SCC_A_DATA      EQU     $E0C03B
SCC_B_CMD       EQU     $E0C038
SCC_B_DATA      EQU     $E0C03A

                MX      %00

;==============================================================================
; PUBLIC ENTRY POINTS — surfaced via ENT for cross-bank reach.
;==============================================================================

;------------------------------------------------------------------------------
; _SimInitExitTable - cache ROM-version-gated JML targets into the four
; _simExit* slots.  Called once at boot from main.s after _DetectHardware.
;
; Hard-halts on ROM 0 (unsupported — FGX targets ROM 01 / ROM 03 only).
;
; In:   IRQs masked.  MX %00.  DBR = boot DBR ($02; this runs early in boot,
;       before relocation hands off — see the PHK/PLB to kernel-bank below).
;       ROMVersion populated.
; Out:  4 × _simExit* slots populated with "$5C $lo $mi $hi" JML cells.
;       MX %00 preserved.
;------------------------------------------------------------------------------
_SimInitExitTable ENT
                MX      %00
                PHP
                SEP     #$30
                MX      %11

                LDA     ROMVersion
                BNE     @sit_rom_ok             ; non-zero ROM = supported
                BRL     @sit_rom0_halt          ; ROM 0 = unsupported (long branch out)
@sit_rom_ok
                ; Reloc: the IRQ dispatcher runs at DBR=kernel-bank and reaches these
                ; exit cells via `JMP _simExitMain` (DBR-rel target in the kernel bank).
                ; _SimInitExitTable runs at the boot DBR ($02), so plain STA here would
                ; build the cells in $02 while the dispatcher executes the (unbuilt =
                ; $00 = BRK) $20 copy -> IRQ storm / wild jump.  Set DBR=kernel-bank
                ; (PHK/PLB) for the cell stores; restore at @sit_done.  (ROMVersion was
                ; already read above at the boot DBR; PLB sets N/Z from DBR but the
                ; CMP #1 below re-sets them from A, which PHB/PHK/PLB leave intact.)
                PHB
                PHK
                PLB                             ; DBR = kernel bank ($20 reloc / $02 native)
                CMP     #1
                BEQ     @sit_rom01

                ; ---- ROM 03 (default — handles ROM 03 and any future
                ;      that hasn't been explicitly tested).
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

@sit_done       PLB                             ; restore DBR (matches PHB at @sit_rom_ok)
                REP     #$30
                MX      %00
                PLP
                RTS

@sit_rom0_halt
                ; ROM 0 -- log + halt.  FGX supports ROM 01 and ROM 03
                ; and has not been validated against ROM 00.
                LDX     #_TBM_SIM_ROM_Fail
                JSL     SYS_KERNLOG
                JMP     _Kern_Halt

_TBM_SIM_ROM_Fail ASC   "sim: ROM 0 unsupported",00

;------------------------------------------------------------------------------
; _KernIrq_Install — patch the IIgs main IRQ vector at $E10010 with our
; dispatcher trampoline.  Must be called with IRQs masked (SEI'd).
;
; Saves the original 4-byte JML instruction (opcode + 24-bit target)
; into _kernIrqSavedVect for diagnostics / future chain-fallback.
;
; In:   IRQs masked.  MX %00.  DBR = boot DBR ($02 = assembly ORG).
; Out:  $E10010 patched.  MX %00 preserved.
;------------------------------------------------------------------------------
_KernIrq_Install ENT
                MX      %00
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
                ; bank byte = running kernel bank (PHK), not baked
                ; ^_KernIrq_Dispatch (=$02), so the ROM's $E10010 JML reaches the
                ; dispatcher wherever the loader places the kernel (relocatable).
                PHK
                PLA
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
_KernIrq_Dispatch ENT
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
                PHB                             ; cnt.v_intr++ (pdp/mch_trap.s:64):
                PHK                             ;   a real IRQ, BRK has gone
                PLB
                INC    |_vmIntr
                BNE     @kid_counted
                INC    |_vmIntr+2
@kid_counted    PLB                             ; DBR = $E1 again

                ; Save + modify shadow register $C035 with ROM-version
                ; gated AND mask (ROM 03 = $9F3E, ROM 01 = $9F1E).
                LDA     |$C035
                STA     |$0119                  ; ShadSave
                ORA     #$8000
                PHA                             ; stash ORA result
                SEP     #$20
                MX      %10
                ; DBR is $E1 here (preamble PEA $E1E1/PLB), so reach the kernel
                ; static ROMVersion by briefly switching DBR to the running kernel
                ; bank (PHK) — relocation-safe, replaces the old baked-$02 LDAL.
                ; (Stack-neutral: PHB+PHK then PLB+PLB = net 0; the 16-bit ORA
                ; stash at 1,S is untouched.)
                PHB
                PHK
                PLB                             ; DBR = running kernel bank
                LDA     ROMVersion              ; DBR-relative read (was LDAL $02)
                PLB                             ; restore DBR = $E1
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

                ; --- Switch DBR to the kernel bank for our own statics ---
                ; The preamble needed DBR=$E1 to reach the ROM slots at
                ; |$01xx and the shadow reg at |$C035.  From here on we
                ; need DBR=kernel-bank so `INC _simStatTotal` etc. resolve
                ; into OUR bank, not bank $E1.
                ;
                ; CRITICAL: must be stack-neutral.  We use PHK/PLB (PB =
                ; the live kernel bank, since the dispatcher executes there
                ; under relocation; $02 = assembly ORG) — net 0 bytes.  An
                ; earlier PEA $0202/PLB pattern left a fixed bank byte on
                ; stack that ROM exit code (which expects gno's exact stack
                ; layout) misread, yielding bogus RTI returns (PC=$A9:xxxx).
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

                ; --- Non-SCC IRQ: offer to generic-source handlers (Phase 0b) ---
                ; e.g. the Uthernet/W5100 slot IRQ.  State here: MX %11,
                ; DBR=kernel-bank (set above; $02 = ORG), DP=0.  Each handler
                ; services its hardware and clears its INT so
                ; the source deasserts BEFORE we chain to firmware below.  The walk
                ; is stack-neutral (JSL/RTL + PHX/PLX) so @kid_nsc_nc's frame math
                ; is unaffected; an empty registry (_simGenericLimit=0) makes it a
                ; no-op.  CLC/SEC from a handler is informational — we chain to
                ; ROM-main either way (a claimed source is already cleared).
                LDX     #0
@kid_gen_L      CPX     _simGenericLimit        ; count*3 (0 when none registered)
                BEQ     @kid_gen_done
                LDA     #$5C                    ; JML opcode (reuse the _simTramp cell)
                STAL    _simTramp               ; bank-0 gateway cell (relocation-invariant)
                LDA     _simGenericTbl,X
                STAL    _simTramp+1
                LDA     _simGenericTbl+1,X
                STAL    _simTramp+2
                LDA     _simGenericTbl+2,X
                STAL    _simTramp+3
                PHX                             ; handler may clobber X
                JSL     _simTramp               ; JML -> handler -> RTL back here
                PLX                             ; (does not disturb C from the handler)
                BCC     @kid_gen_claimed        ; CLC = handler claimed + cleared it
                INX
                INX
                INX
                BRA     @kid_gen_L
@kid_gen_claimed
                ; A generic handler CLAIMED the IRQ (CLC) and already cleared its
                ; source.  Take the ROM "we handled it" exit (_simExitHandled,
                ; $FFBF58) — NOT the chain-to-ROM-main below.  Chaining to ROM-main
                ; after a claimed NON-SCC IRQ corrupts the RTI return when no
                ; firmware-visible source remains (the timing-dependent yank-to-ROM
                ; that hung Phase 0b).  Mirrors the SCC @kid_handled_pop exit, minus
                ; the RR3 stash the non-SCC path never pushed.
                ; Stack here: [PEA leftover + PHB + PHP + IRQ frame], DBR=kernel-bank, MX=%11.
                REP     #$30
                MX      %00
                PLB                             ; pop PEA leftover -> DBR=$E1
                JMP     _simExitHandled
@kid_gen_done

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
                STAL    _simTramp               ; bank-0 gateway cell (relocation-invariant)
                LDA     _simHandlerTbl+1,X
                STAL    _simTramp+1
                LDA     _simHandlerTbl+2,X
                STAL    _simTramp+2
                LDA     _simHandlerTbl+3,X
                STAL    _simTramp+3
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

;------------------------------------------------------------------------------
; _Sys_SimInstallImpl - SYS_SIM_INSTALL jumptable target (slot 25; the JT is
; the bank-0 gateway at $00:032E, was $02FE00 — relocatable kernel).
;
; Install a SIM handler for an SCC channel.  Per spec
; docs/superpowers/specs/2026-05-27-fgx-sim-kernel-lift-design.md §2.3.
;
; ABI:
;   In:   MX %00.
;         A.lo = channel mask ($07 chan B / $38 chan A; OR for both).
;         X    = handler offset within caller's bank.
;         Y.lo = caller's bank byte (caller did PHK/PLA/TAY).
;   Out:  C=1 + A=0 on success.
;         C=0 + A=errno on failure:
;           ESIM_DUP     ($01) mask overlaps existing entry
;           ESIM_FULL    ($02) handler table at SIM_HANDLER_MAX
;           ESIM_ATALK   ($03) AppleTalk owns requested port
;
; Side effects on success:
;   - Append entry {mask, addr_lo, addr_mi, addr_hi} to _simHandlerTbl.
;   - OR mask into _simChanOwned.
;   - Increment _simHandlerCount; _simHandlerLimit = count*4.
;   - Clear firmware SerFlag bits for owned port at $E1:0104.
;   - On first install (count 0→1): WR9 = $0A (MIE+NV) to chan B.
;
; All SCC accesses + SerFlag RMW are bracketed by SEI/PHP/PLP.
;
; NOTE: arg-stash order matters.  Original draft had 16-bit STA _simInArgMask
; which would clobber the next byte (_simInArgOff lo).  Corrected here:
; STX (16-bit handler offset) first, then drop to M=8 for the 1-byte stores.
;------------------------------------------------------------------------------
_Sys_SimInstallImpl ENT
                MX      %00
                PHB
                PHK
                PLB                             ; DBR = kernel-bank (PB; $02 = ORG)

                ; --- Stash inputs (M=16 entry → drop to M=8/X=8 for byte ops) ---
                STX     _simInArgOff            ; 2-byte STX (16-bit X)
                ; DEVIATION-FROM-PLAN: spec says SEP #$20 / MX %10 here, but
                ; downstream code (CPX #imm, LDX #0, INX×4, TAX after ASL ASL,
                ; CPX _simHandlerLimit) assumes 8-bit X.  With X still 16-bit
                ; the 1-byte loads/compares either read 2 bytes from 1-byte
                ; slots or pick up hidden-B in TAX (feedback_sep20_vs_sep30
                ; _x_flag_mismatch.md, feedback_65816_tax_mismatched_mx.md).
                ; Use SEP #$30 / MX %11 throughout the impl body.
                SEP     #$30
                MX      %11
                STA     _simInArgMask           ; 1-byte STA (8-bit A)
                TYA
                STA     _simInArgBank           ; 1-byte STA (Y.lo via TYA)

                ; --- ATalk port-ownership check ---
                ; mask $07 covers chan B → port 2; mask $38 covers chan A → port 1.
                ; If _apTalkPort != 0 and matches the requested port, refuse.
                LDA     _apTalkPort
                BEQ     @ssi_atalkOK            ; no AppleTalk → skip
                ; A = _apTalkPort (1=A, 2=B)
                LDX     _simInArgMask           ; X.lo = mask (X 8-bit at MX %11)
                CPX     #$07
                BNE     @ssi_atalk_chkA
                CMP     #2                      ; AppleTalk owns chan B?
                BNE     @ssi_atalkOK
                BRL     @ssi_err_atalk          ; out-of-range BEQ → BRL trampoline
@ssi_atalk_chkA CPX     #$38
                BNE     @ssi_atalkOK            ; some other mask — no specific port
                CMP     #1                      ; AppleTalk owns chan A?
                BNE     @ssi_atalkOK
                BRL     @ssi_err_atalk
@ssi_atalkOK

                ; --- Duplicate-mask check ---
                LDA     _simHandlerCount
                BEQ     @ssi_capOK              ; empty table → no dups possible
                LDX     #0
@ssi_dup_L      LDA     _simHandlerTbl,X
                AND     _simInArgMask
                BEQ     @ssi_dup_next
                BRL     @ssi_err_dup            ; out-of-range BNE → BRL trampoline
@ssi_dup_next   INX
                INX
                INX
                INX
                CPX     _simHandlerLimit
                BCC     @ssi_dup_L

                ; --- Capacity check ---
@ssi_capOK      LDA     _simHandlerCount
                CMP     #SIM_HANDLER_MAX
                BCC     @ssi_cap_pass
                BRL     @ssi_err_full           ; out-of-range BCS → BRL trampoline
@ssi_cap_pass

                ; --- Append entry into _simHandlerTbl[count*4] ---
                LDA     _simHandlerCount
                ASL                             ; ×2
                ASL                             ; ×4
                TAX                             ; X.lo = byte offset (8-bit X at MX %11)
                LDA     _simInArgMask
                STA     _simHandlerTbl,X

                ; Store 24-bit handler addr: bytes +1 (lo), +2 (mi), +3 (bank).
                ; _simInArgOff is 2 bytes (lo, mi).  _simInArgBank is 1 byte.
                LDA     _simInArgOff            ; lo
                STA     _simHandlerTbl+1,X
                LDA     _simInArgOff+1          ; mi
                STA     _simHandlerTbl+2,X
                LDA     _simInArgBank
                STA     _simHandlerTbl+3,X

                ; --- Update count / limit / chan-owned (all 8-bit at MX %10) ---
                INC     _simHandlerCount
                LDA     _simHandlerCount
                ASL
                ASL
                STA     _simHandlerLimit
                LDA     _simChanOwned
                ORA     _simInArgMask
                STA     _simChanOwned

                ; --- Wrap SCC/SerFlag access in SEI ---
                PHP
                SEI

                ; --- SerFlag clear at $E1:0104 ---
                ; chan B (mask=$07) → AND with $F8; chan A (mask=$38) → AND with $C7.
                LDA     _simInArgMask
                CMP     #$07
                BNE     @ssi_sf_chkA
                LDAL    $E10104
                AND     #$F8
                STAL    $E10104
                BRA     @ssi_sf_done
@ssi_sf_chkA    CMP     #$38
                BNE     @ssi_sf_done            ; mask we don't have a SerFlag rule for
                LDAL    $E10104
                AND     #$C7
                STAL    $E10104
@ssi_sf_done

                ; --- First install? Enable WR9 = $0A (MIE+NV) ---
                LDA     _simHandlerCount
                CMP     #1
                BNE     @ssi_wr9_done
                ; Sync SCC state machine to register 0, then WR9 := $0A.
                LDAL    SCC_B_CMD
                LDA     #$09
                STAL    SCC_B_CMD
                LDA     #$0A
                STAL    SCC_B_CMD
                ; WR0 = $30 (error reset) + WR0 = $38 (Reset Highest IUS)
                LDA     #$00
                STAL    SCC_B_CMD
                LDA     #$30
                STAL    SCC_B_CMD
                LDA     #$00
                STAL    SCC_B_CMD
                LDA     #$38
                STAL    SCC_B_CMD
@ssi_wr9_done   PLP

                ; --- Success exit: C=1, A=0.  REP #$30 because entry SEP'd
                ; both M and X; exit ABI is MX %00. ---
                REP     #$30
                MX      %00
                LDA     #0
                PLB
                SEC
                RTL

@ssi_err_atalk  REP     #$30
                MX      %00
                LDA     #ESIM_ATALK
                PLB
                CLC
                RTL

@ssi_err_dup    REP     #$30
                MX      %00
                LDA     #ESIM_DUP
                PLB
                CLC
                RTL

@ssi_err_full   REP     #$30
                MX      %00
                LDA     #ESIM_FULL
                PLB
                CLC
                RTL

;------------------------------------------------------------------------------
; _Sys_SimRemoveImpl - SYS_SIM_REMOVE jumptable target (slot 26; the JT is
; the bank-0 gateway at $00:032E, was $02FE00 — relocatable kernel).
;
; Find and remove a handler entry matching (mask, addr).  Per spec §2.3.
;
; ABI: same as _Sys_SimInstallImpl (A.lo = mask, X = handler offset,
;      Y.lo = caller bank).
;   Out: C=1 + A=0 on success.
;        C=0 + A=ESIM_NOENT on no-match.
;
; Side effects on success:
;   - Compact _simHandlerTbl; decrement count; rebuild _simChanOwned and
;     _simHandlerLimit.
;   - On last remove (count → 0): WR9 = $00.
;   - SerFlag is NOT restored.  Future install re-clears (no-op if
;     already clear).
;
; NOTE: original draft had a confused XBA dance in the find-loop's 3-byte
; address compare.  Corrected here to straight byte-by-byte compare at M=8.
;------------------------------------------------------------------------------
_Sys_SimRemoveImpl ENT
                MX      %00
                PHB
                PHK
                PLB

                STX     _simInArgOff
                ; DEVIATION-FROM-PLAN: SEP #$30 instead of SEP #$20 — body
                ; assumes X is 8-bit (CPX _simHandlerLimit, INX, TAX after
                ; ASL).  See Install ABI note.
                SEP     #$30
                MX      %11
                STA     _simInArgMask
                TYA
                STA     _simInArgBank

                ; --- Linear scan _simHandlerTbl for matching entry.
                ; Match criterion: (mask, addr_lo, addr_mi, bank) all equal.
                LDX     #0
@ssr_find_L     CPX     _simHandlerLimit
                BCC     @ssr_find_in
                BRL     @ssr_err_noent          ; out-of-range BCS → BRL trampoline
@ssr_find_in    LDA     _simHandlerTbl,X
                CMP     _simInArgMask
                BNE     @ssr_next
                LDA     _simHandlerTbl+1,X
                CMP     _simInArgOff            ; lo
                BNE     @ssr_next
                LDA     _simHandlerTbl+2,X
                CMP     _simInArgOff+1          ; mi
                BNE     @ssr_next
                LDA     _simHandlerTbl+3,X
                CMP     _simInArgBank
                BEQ     @ssr_match
@ssr_next       TXA
                CLC
                ADC     #4
                TAX
                BRA     @ssr_find_L

@ssr_match
                ; --- Compact: copy entries [X+4 .. limit) down to [X .. limit-4) ---
                ; Y = source byte offset; X = dest byte offset (4 less than Y).
                TXA
                CLC
                ADC     #4
                TAY
@ssr_compact_L  CPY     _simHandlerLimit
                BCS     @ssr_compact_done
                LDA     _simHandlerTbl,Y
                STA     _simHandlerTbl,X
                INY
                INX
                BRA     @ssr_compact_L
@ssr_compact_done

                ; --- Decrement count, rebuild limit ---
                DEC     _simHandlerCount
                LDA     _simHandlerCount
                ASL
                ASL
                STA     _simHandlerLimit

                ; --- Rebuild _simChanOwned = OR of remaining masks ---
                LDA     #$00
                STA     _simChanOwned
                LDX     #0
@ssr_owned_L    CPX     _simHandlerLimit
                BCS     @ssr_owned_done
                LDA     _simHandlerTbl,X
                ORA     _simChanOwned
                STA     _simChanOwned
                TXA
                CLC
                ADC     #4
                TAX
                BRA     @ssr_owned_L
@ssr_owned_done

                ; --- Last remove? WR9 = $00 ---
                LDA     _simHandlerCount
                BNE     @ssr_wr9_done
                PHP
                SEI
                LDAL    SCC_B_CMD               ; sync to reg 0
                LDA     #$09
                STAL    SCC_B_CMD
                LDA     #$00
                STAL    SCC_B_CMD
                PLP
@ssr_wr9_done

                REP     #$30
                MX      %00
                LDA     #0
                PLB
                SEC
                RTL

@ssr_err_noent  REP     #$30
                MX      %00
                LDA     #ESIM_NOENT
                PLB
                CLC
                RTL

;------------------------------------------------------------------------------
; _Sim_InstallGeneric - register a non-SCC "generic source" IRQ handler
; (Phase 0b).  Kernel-internal; called via JSR from the same (kernel) bank
; ($02 = assembly ORG).
;
; In:  MX %00.  A = 16-bit handler offset.  Y.lo = handler bank byte.
; Out: C=1 + A=0 on success; C=0 + A=ESIM_FULL if the registry is full.
;
; Appends {lo,mi,bank} to _simGenericTbl, bumps _simGenericCount, then writes
; _simGenericLimit = count*3 LAST — so a non-SCC IRQ firing mid-install sees
; either the old limit (new entry not yet walked) or the new one (entry already
; complete).  Touches no SCC/firmware state, so no SEI bracket is needed.
;------------------------------------------------------------------------------
_Sim_InstallGeneric MX  %00
                PHB
                PHK
                PLB                             ; DBR=kernel-bank for the registry statics
                STA     _simInArgOff            ; stash 16-bit handler offset
                SEP     #$30
                MX      %11
                TYA
                STA     _simInArgBank           ; handler bank byte
                ; --- capacity check ---
                LDA     _simGenericCount
                CMP     #SIM_GENERIC_MAX
                BCC     @sig_room
                REP     #$30
                MX      %00
                LDA     #ESIM_FULL
                PLB
                CLC
                RTS
@sig_room       ; X = count*3 (byte offset of the new entry)
                LDA     _simGenericCount
                STA     _simInArgMask           ; temp = count
                ASL                             ; count*2
                CLC
                ADC     _simInArgMask           ; + count = count*3
                TAX
                LDA     _simInArgOff            ; addr lo
                STA     _simGenericTbl,X
                LDA     _simInArgOff+1          ; addr mi
                STA     _simGenericTbl+1,X
                LDA     _simInArgBank           ; addr bank
                STA     _simGenericTbl+2,X
                ; --- bump count, then publish limit = count*3 (written LAST) ---
                INC     _simGenericCount
                LDA     _simGenericCount
                STA     _simInArgMask
                ASL
                CLC
                ADC     _simInArgMask           ; count*3
                STA     _simGenericLimit
                REP     #$30
                MX      %00
                LDA     #0
                PLB
                SEC
                RTS

;------------------------------------------------------------------------------
; _DetectAppleTalkPort - set _apTalkPort to indicate which serial port
; AppleTalk owns (if any).
;
; Under raw IIgs (no GS/OS loaded — FGX's normal configuration) AppleTalk
; is never active.  The Device Manager calls gno uses for detection
; (_DInfoGS / _DStatusGS) are GS/OS-only calls, dispatched via $E100B0,
; not via the regular Toolbox $E10000 vector.  Without GS/OS loaded
; there's no working detection mechanism — _apTalkPort is always 0.
;
; Earlier draft attempted to mirror gno's CheckPort via $E10000 with
; the GS/OS opcodes.  That dispatches them as regular Toolbox calls,
; which the dispatcher mishandles (PEA stack args + invalid tool#),
; corrupting the stack and producing wild RTS targets.  Manifested as
; an "insta-BRK" at $02:0241 before kernel banner.
;
; Detection (raw IIgs, no GS/OS): read the user's Control Panel slot-1 (printer
; port) setting from Battery RAM with ReadBParam (Misc Tool $0C03), paramRefNum
; $21 = "Slot 1 Internal/external" (Toolbox Ref Vol 1, Table 14-3).  That param
; is really a small enum, NOT a 0/1 internal/external flag: 0 = Printer Port
; (built-in serial), 1 = Your Card, **2 = AppleTalk**.  Value 2 means AppleTalk
; owns the printer port (Port 1 / SCC channel A / tty00).
;
; The $21=2 value was confirmed by a clean A/B Battery-RAM diff under MAME
; (deterministic BRAM): toggling Control Panel "Slot 1" between Printer Port and
; AppleTalk flips exactly $00 (Port 1 device) AND $21 (Slot 1) 0<->2 (+ the BRAM
; checksum).  We read $21.
;
; ReadBParam is a stateless ROM tool dispatched via $E10000 with NO TLStartUp —
; the exact mechanism _KCaptureBootTime uses one call earlier for ReadTimeHex
; ($0D03), so the toolbox is known-good here.  (The earlier GS/OS _DInfoGS/
; _DStatusGS draft crashed because GS/OS opcodes mis-dispatch through $E10000;
; a real Misc Tool call does not.)  AppleTalk on the IIgs only ever uses the
; printer port, so a positive detect always maps to chan A (port 1).
;
; Sets _apTalkPort to:
;   0 = none (slot 1 = Printer Port / Your Card, or no AppleTalk)
;   1 = chan A (slot 1 = AppleTalk -> printer port / tty00)
;   2 = chan B (modem port; not reachable via slot 1 — reserved)
;
; In:   MX %00.  DBR = kernel-bank ($02 = assembly ORG).
; Out:  _apTalkPort set.  MX %00 preserved.  ($E10000 preserves DBR/DP for the
;       caller, as relied on by _KCaptureBootTime.)
;------------------------------------------------------------------------------
_DetectAppleTalkPort ENT
                MX      %00
                PHP
                REP     #$30
                MX      %00

                SEP     #$20
                MX      %10
                STZ     _apTalkPort             ; default: no AppleTalk port
                REP     #$20
                MX      %00

                ; ReadBParam($21) -> A.lo = Slot 1 device (0=Printer,1=Card,2=ATalk).
                PEA     $0000                   ; space for result (theData)
                PEA     $0021                   ; paramRefNum = Slot 1 device
                LDX     #$0C03                  ; ReadBParam (Misc Tool $0C03)
                JSL     $E10000
                PLA                             ; theData (low byte significant)
                AND     #$00FF
                CMP     #2                      ; 2 = AppleTalk (clean A/B BRAM diff)
                BNE     @sap_none               ; Printer Port / Your Card / other

                ; Slot 1 = AppleTalk -> owns printer port (chan A / tty00).
                SEP     #$20
                MX      %10
                LDA     #1
                STA     _apTalkPort
                REP     #$20
                MX      %00
                LDX     #_simATalkA_msg
                JSL     SYS_KERNLOG
                PLP
                RTS

@sap_none       LDX     #_simATalkN_msg
                JSL     SYS_KERNLOG
                PLP
                RTS

;---- _DetectAppleTalkPort log strings ----
_simATalkN_msg  ASC     'sim: ATalk port = none',$0A,$00
_simATalkA_msg  ASC     'sim: ATalk port = printer (chan A/tty00)',$0A,$00

;==============================================================================
; END sim.s
;==============================================================================
