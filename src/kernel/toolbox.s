;==============================================================================
; toolbox.s - IIgs Toolbox bring-up + 60 Hz heartbeat task install (Phase A).
;
; Local EQU.  alloc_state.s defines the canonical KMEM_HEAP_FIRST_BANK but
; that file is PUT-included AFTER toolbox.s, so we need a local synonym
; here.  Must stay numerically identical to the canonical one (no automated
; check yet — keep these two values in sync by hand).
TBX_HEAP_FIRST_BANK EQU $07             ; first bank of FGX kernel heap.
                                        ; $07..$09 (heap) / $06 (FAT32 reservation)
                                        ; are the OLD fixed layout only — the
                                        ; rest-of-OS regions are now DYNAMIC
                                        ; (_restBaseBank + REST_*_OFF), capped by
                                        ; KMEM_MAX_ARENAS = 3.  See kernel.s.
;
; Public init routines, called in order from FGX_Entry:
;
;   Toolbox_GetOwnID   - _GetNewID (class $1000). Stores the returned userID
;                        in _kFgxUserID. Halts on failure. (TL/MT bring-up +
;                        bank pre-claim are now done by the stage-2 loader.)
;
;   Toolbox_InstallHB  - Installs _HBTickTask via _SetHeartBeat, enables the
;                        Mega-II VBL source ($00C041 |= $08), and unmasks
;                        CPU IRQs (CLI). After this returns, the firmware
;                        Heartbeat Interrupt Handler dispatches our task at
;                        every VBL.
;
; Plus one syscall entry (relocated from the now-retired src/kernel/irq.s):
;
;   _Sys_Ticks         - SYS_TICKS = 52 handler. Copies _kSystemTicks (4 B,
;                        atomic snapshot) to caller's buffer.
;
; Why this stack rather than a direct $E1/0031 IRQ install: firmware's
; Heartbeat Interrupt Handler is what makes our handler coexist with
; firmware's keyboard heartbeat task (which would otherwise drain $C010
; and starve Con_PollKey). See
; memory/reference_iigs_toolbox_bringup_from_raw_boot.md for the full
; surprise log — five non-obvious gotchas earned through this work:
;
;   1. _MMStartUp returns idErr=$0207 from raw boot (no app-launch
;      context); use _GetNewID instead. ddiigs uses the same pattern.
;   2. _SetHeartBeat does NOT auto-enable VBL despite the docs saying
;      it auto-installs the heartbeat interrupt handler. Application
;      must STAL #$08 -> $00C041.
;   3. CLI must come AFTER the caller's PLP, not before. Boot SEI'd I=1
;      gets restored by PLP and undoes a CLI placed first.
;   4. Heartbeat body uses RTL not RTI even though Toolbox Vol 1 p.662
;      says RTI. Empirically firmware calls via JSL (3-byte push) — RTI
;      pulls 4 and corrupts return.
;   5. Body must STAL $E0C047 (VBL ACK) or the dispatcher re-fires us
;      in a tight loop and the system freezes.
;==============================================================================

;------------------------------------------------------------------------------
; Toolbox_GetOwnID
;
; Allocate the kernel's userID via _GetNewID (class $1000 = application).
; Halts on failure with a console message (boot is not viable without it).
;
; Entry: M=0, X=0, native, IRQs masked.
; Exit:  C=1, M=0, X=0, _kFgxUserID populated (typically $1001 first time).
;
; The stage-2 loader now owns TL/MT bring-up and the FGX-bank claim (see
; src/boot/stage2.s KernelHandoff), so the kernel's first MM-aware code only
; needs its own userID — Toolbox_GetOwnID is that call.  Do NOT re-add a full
; TL/MT bring-up to main.s without first checking that the loader hasn't
; already done it (calling TLStartUp twice returns an error per Toolbox Ref
; Vol 1).
;------------------------------------------------------------------------------
Toolbox_GetOwnID ENT
                MX      %00
                PHP
                REP     #$30
                MX      %00
                PHA                             ; result placeholder
                PEA     $1000                   ; class $1000 (application)
                LDX     #$2003                  ; _GetNewID
                JSL     $E10000
                BCS     @tgo_fail
                PLA                             ; A = userID
                STA     _kFgxUserID
                PLP
                SEC
                RTS
@tgo_fail       STA     _kFgxToolErr
                PLA                             ; pop userID placeholder
                LDA     #_TBM_ID_Fail
                STA     _conStrPtr
                JSR     _PutStr
_kfp103         JSL     KFAR_CON_CR
                JMP     _Kern_Halt

;------------------------------------------------------------------------------
; Toolbox_PreClaim removed 2026-06-13: dead code (no caller). The loader
; (stage2.s LoaderPreClaim) does all bank claims now, and the kernel's heap
; arenas live inside the rest-of-OS handle (KFGX_REST_ANCHOR) rather than being
; self-NewHandle'd here.

;------------------------------------------------------------------------------
; Toolbox_InstallHB
;
; Install our heartbeat task into firmware's queue, enable VBL, unmask IRQs.
; After this returns, the firmware Heartbeat Interrupt Handler is live and
; calls _HBTickTask's body at every VBL (~60 Hz).
;
; Entry: M=0, X=0, IRQs masked (kernel boot SEI).
; Exit:  C=1, M=0, X=0, IRQs UNMASKED.
;
; CRITICAL: The CLI here is positioned AFTER the PLP. The kernel boot SEI'd
; was captured by our PHP; PLP would restore I=1 and undo a CLI placed
; before it. PLP-then-CLI is mandatory for I=0 to persist across our RTS.
;------------------------------------------------------------------------------
Toolbox_InstallHB ENT
                MX      %00
                PHP
                REP     #$30
                MX      %00

                ; _SetHeartBeat ($1203) — takes Long pointer to HBTask.
                ; Reloc: register the LIVE kernel copy, not the baked $02 bank.
                ; The firmware heartbeat JSLs this node's body each VBL; under
                ; relocation the stale $02 copy reads divergent kernel statics
                ; (DBR=$02) and may never reach its VBL ACK (STAL $E0C047) ->
                ; VBL re-fires -> IRQ storm.  Push the running kernel bank (PHK).
                SEP     #$20
                MX      %10
                PHK
                PLA                             ; A.lo = running kernel bank
                REP     #$20
                MX      %00
                AND     #$00FF
                PHA                             ; bank (high word of long)
                LDA     #_HBTickTask
                PHA                             ; offset (low word)
                LDX     #$1203
                JSL     $E10000
                BCS     @hb_fail

                ; Enable Mega-II VBL source. Toolbox doesn't do this auto-
                ; matically despite docs hinting otherwise (surprise #2).
                SEP     #$20
                LDA     #$08                    ; INTEN bit 3 = VBL
                STAL    $00C041
                REP     #$20

                PLP                             ; restore caller flags
                CLI                             ; unmask IRQs (must be after PLP)
                SEC
                RTS

@hb_fail        STA     _kFgxToolErr
                LDA     #_TBM_HB_Fail
                STA     _conStrPtr
                JSR     _PutStr
_kfp104         JSL     KFAR_CON_CR
                JMP     _Kern_Halt

;==============================================================================
; _Sys_Ticks - SYS_TICKS = 52 handler. Atomic snapshot of _kSystemTicks.
;
; ABI: caller passes 4-byte buffer offset in A; bracketed with SEI/PLP-
; restoring-PHP so the heartbeat body can't update _kSystemTicks mid-copy.
;
; Relocated from the retired src/kernel/irq.s (which previously housed the
; failed direct-VBL install). The counter is now maintained by the
; heartbeat body below.
;==============================================================================
_Sys_Ticks      ENT
                MX      %00
                PHP
                SEI
                STA     _shTmp0
                STA     _libcTmp2
                SEP     #$20
                MX      %10
                LDA     _Sys_CallerBank
                STA     _libcTmp2+2
                LDY     #0
@st_L           LDA     _kSystemTicks,Y
                STA     [_libcTmp2]
                REP     #$20
                MX      %00
                INC     _libcTmp2
                SEP     #$20
                MX      %10
                INY
                CPY     #4
                BCC     @st_L
                REP     #$20
                MX      %00
                LDA     _shTmp0
                PLP
                SEC
                RTS

;==============================================================================
; _Hr_Stamp - hi-res timestamp from the Mega II video beam counter (Tech Note
; #39).  Resolution = one scan line ~63.7 us (260x finer than the 60 Hz tick).
;
; Returns:  A = linePos (0..261, the tick-aligned intra-frame scan line: 0 right
;               after the VBL/tick boundary V=$1C0, monotonic up to 261)
;           X = _kSystemTicks low 16 bits (the frame counter)
; The (X,A) pair is a consistent snapshot (SEI-bracketed vs the heartbeat).  A
; consumer forms a seamless 32-bit stamp as X*262 + A (each unit 63.7 us; the
; +262/frame makes linePos 261 -> next frame 0 a clean +1, no wrap gap).
;
; 9-bit vertical counter V ($FA..$1FF) = HW_VERTCNT (V bits 1..8) + HW_HORIZCNT
; bit 7 (V bit 0); read per TN #39: lda HORIZCNT / asl / lda VERTCNT / rol ->
; A = V low 8, C = V bit 8.  linePos = (V - $1C0) mod 262.
; MX %00 in/out.  Clobbers A/X/Y.
;==============================================================================
_Hr_Stamp       ENT
                MX      %00
                PHP
                SEI
                SEP     #$20
                MX      %10
                LDAL    HW_HORIZCNT             ; [V0][H6..H0]  (LDAL: bank $E0 is
                                                ;   NOT the DBR=live-kernel-bank, so
                                                ;   a plain LDA abs would read $xx:C02F
                                                ;   RAM and yield V=0 -> linePos=$FF46)
                ASL     A                       ; V0 -> carry
                LDAL    HW_VERTCNT             ; V bits 8..1 (high byte); LDAL: see above
                ROL     A                       ; A = V low 8 bits; C = V bit 8 (MSB)
                REP     #$20
                MX      %00
                AND     #$00FF                  ; A = V low byte (AND leaves C = V bit 8)
                BCC     @hrs_noV8
                ORA     #$0100                  ; V bit 8 set -> full V >= $100
@hrs_noV8       SEC
                SBC     #$01C0                  ; V - $1C0
                BCS     @hrs_line               ; V >= $1C0: linePos = V-$1C0 (0..63)
                CLC
                ADC     #262                    ; V < $1C0: + one frame (64..261)
@hrs_line       TAY                             ; Y = linePos
                LDA     _kSystemTicks           ; frame counter low 16 (atomic: SEI held)
                TAX                             ; X = ticks
                PLP
                TYA                             ; A = linePos
                RTS

;==============================================================================
; Heartbeat task struct + body.
;
; firmware queue node layout:
;     +0  HB_Link       (Long, firmware fills with next-task ptr)
;     +4  HB_TickCount  (Word, decremented each VBL; 0 = inactive)
;     +6  HB_Signature  (Word, must be byte-pattern $5A,$A5)
;     +8  body code     (firmware JSLs this on dispatch)
;
; Use HEX 5AA5 (not DW $5AA5) so Merlin emits the bytes in the high-byte-
; first order firmware checks for. DW would produce $A5,$5A and yield
; noSigTaskErr=$0304.
;
; Body discipline:
;   - Entry: native, hardware pushed PB+PCH+PCL — but the call is JSL not
;     interrupt, so we PHP at entry and PLP at exit, RTL not RTI.
;   - Reset HB_TickCount to 1 each fire (firmware decrements to 0 and
;     leaves it; without reset the task goes dormant after one fire).
;   - DO NOT touch shared DP scratch (_shTmp* / _libcTmp* / _fsTmp*); the
;     body fires asynchronously w.r.t. any in-flight kernel call.
;   - STAL $E0C047 (VBL ACK) is mandatory — without it the dispatcher
;     re-fires us in a tight loop and the system freezes.
;==============================================================================
_HBTickTask     DA      0,0                     ; HB_Link (firmware fills)
_HBTickCount    DW      1                       ; tickCount (fire every VBL)
                HEX     5AA5                    ; HB_Signature ($5A,$A5 byte order)
                ; Body starts here — firmware JSLs to _HBTickTask+8.
                MX      %11
                PHP
                REP     #$30
                MX      %00
                PHB
                PHK
                PLB                             ; DBR = kernel-bank (PHK = live; $02 = assembly ORG)

                LDA     #1                      ; reset count for next fire
                STA     _HBTickCount

                INC     _kSystemTicks           ; 16-bit INC of low word
                BNE     @hb_noHi
                INC     _kSystemTicks+2         ; 16-bit INC of high word
@hb_noHi
                LDA    |_kCpState               ; cp_time[cpstate]++
                ASL                             ;   (kern_clock.c:198)
                ASL
                TAX
                INC    |_cp_time,X
                BNE     @hb_cpDone
                INC    |_cp_time+2,X
@hb_cpDone
                LDA     _kTodFrac               ; the time of day, 32.32: Reno
                CLC                             ;   kern_clock.c:223 BUMPTIME
                ADC     _kTickFrac
                STA     _kTodFrac
                LDA     _kTodFrac+2
                ADC     _kTickFrac+2
                STA     _kTodFrac+2
                BCC     @hb_tod
                INC     _kTodSec
                BNE     @hb_tod
                INC     _kTodSec+2
@hb_tod
                ;------------------------------------------------------------
                ; apple/fgx#242: THE ISR-CONTEXT HALF OF _KcIrqProbe.
                ;
                ; `_KcIrqProbe' exercises KTTY_KC_ENTER_IRQ from TASK context,
                ; where the language card is banked in, and passed all twelve
                ; of its cases through increments 1, 2, 3 and 4b steps 1-3
                ; while the bracket could not reach its own stack from an
                ; actual interrupt.  A PROBE THAT CANNOT RUN IN THE CONTEXT
                ; UNDER TEST IS NOT COVERAGE FOR THAT CONTEXT, so this runs the
                ; bracket HERE, in the dispatch, once per boot.
                ;
                ; _hbLcCtl IS THE POSITIVE CONTROL AND MUST READ 0 -- the same
                ; store/read-back against LOW bank 0 (the $030A..$031F gap this
                ; body already writes at KFGX_YIELD_MIRROR).  Without it an
                ; inverted CMP or a block that never ran gives the identical
                ; all-FAIL answer.
                ;------------------------------------------------------------
                ;------------------------------------------------------------
                ; apple/fgx#242: THE ISR-CONTEXT HALF OF _KcIrqProbe.
                ;
                ; `_KcIrqProbe' exercises KTTY_KC_ENTER_IRQ from TASK context,
                ; where the language card is banked in, and passed all twelve
                ; of its cases through increments 1, 2, 3 and 4b steps 1-3
                ; while the bracket could not reach its own stack from an
                ; actual interrupt.  A PROBE THAT CANNOT RUN IN THE CONTEXT
                ; UNDER TEST IS NOT COVERAGE FOR THAT CONTEXT, so this runs the
                ; bracket HERE, in the dispatch.  `_KcIrqProbe' reads the
                ; counters and reports (case 13).
                ;
                ; TWO CONTROLS, BECAUSE ZERO IS AMBIGUOUS.  `_hbLcFail' = 0 is
                ; the answer we want AND what a heartbeat that died before
                ; writing anything leaves behind -- measured, and it read as a
                ; PASS under a mutation that kills the boot outright.  So
                ; `_hbLcRuns' counts COMPLETED brackets (the denominator) and
                ; `_hbLcCtl' is the same store/read-back against LOW bank 0,
                ; the $030A..$031F gap this body already writes at
                ; KFGX_YIELD_MIRROR (the CMP-sense control).
                ;
                ; BOUNDED: the first LC_PROBE_TICKS ticks and then one compare
                ; per VBL forever after.  The flip that follows exercises this
                ; bracket on every keystroke, which is the standing coverage;
                ; this is the boot-time witness that it can be entered at all.
                ;------------------------------------------------------------
                LDA     _hbLcTicks
                CMP     #LC_PROBE_TICKS
                BCC     @hb_lcRun
                BRL     @hb_lcSkip              ; BRL: the bracket below put the
@hb_lcRun       INC     _hbLcTicks              ;   landing point out of range
                SEP     #$20
                MX      %10
                LDAL    $E0C068                 ; STATEREG as the FIRMWARE left
                ORA     _hbLcState              ;   it, OR-ed over every tick
                STA     _hbLcState
                REP     #$20
                MX      %00
                LDA     #$C0DE
                STAL    $00030C                 ; POSITIVE CONTROL: low bank 0
                LDAL    $00030C
                CMP     #$C0DE
                BEQ     @hb_lcCtlOK
                INC     _hbLcCtl                ; MUST STAY 0
@hb_lcCtlOK     LDY     #0                      ; Y survives both macros; DBR is
                                                ;   the TTY bank inside, so the
                                                ;   kernel-bank counters cannot
                                                ;   be reached until after LEAVE
                KTTY_KC_ENTER_IRQ
                SEP     #$20
                MX      %10
                LDAL    $E0C068                 ; STATEREG *inside* the bracket
                STAL    $00030E                 ;   -- parked in low bank 0,
                REP     #$20                    ;   which always works
                MX      %00
                LDA     #$1234
                STAL    $00FCF0                 ; FGX_STK_KIRQ, the IRQ stack
                LDAL    $00FCF0
                CMP     #$1234
                BEQ     @hb_lcS1
                INY
@hb_lcS1        LDA     #$5678
                STAL    $00FA98                 ; FGX_DP_KERNELC_IRQ+$98, fcc's
                LDAL    $00FA98                 ;   first register
                CMP     #$5678
                BEQ     @hb_lcS2
                INY
@hb_lcS2        KTTY_KC_LEAVE_IRQ
                INC     _hbLcRuns               ; DENOMINATOR: brackets that came
                                                ;   back.  Unreached if LEAVE
                                                ;   pulled a return off ROM.
                TYA
                CLC
                ADC     _hbLcFail               ; 0 = the bracket reached its own
                STA     _hbLcFail               ;   context from the ISR, always
                SEP     #$20
                MX      %10
                LDAL    $E0C068
                ORA     _hbLcAfter              ; STATEREG after LEAVE
                STA     _hbLcAfter
                LDAL    $00030E
                ORA     _hbLcInside
                STA     _hbLcInside
                REP     #$20
                MX      %00
@hb_lcSkip
                ;------------------------------------------------------------
                ; P1 (preemption): quantum countdown.  Every QUANTUM_TICKS
                ; VBLs, ask whoever is running to yield at its next syscall
                ; boundary — the same flag + dispatcher hook as the F5
                ; kbd-yield; a keypress and quantum expiry are now the same
                ; resched request.  Model A: this never preempts kernel code;
                ; the dispatcher honors it between syscalls.
                ;------------------------------------------------------------
                DEC     _kQuantum
                BNE     @hb_qOK
                LDA     #QUANTUM_TICKS
                STA     _kQuantum
                LDA     #1
                STA     _kYieldReq
                STAL    KFGX_YIELD_MIRROR       ; P2': mirror for userland safepoints
@hb_qOK
                ;------------------------------------------------------------
                ; lbolt (apple/fgx#108 T3): once a second, MARK the wake.  It
                ; is not performed here, and that is BSD's own split rather
                ; than an FGX limitation.
                ;
                ; 2.11BSD's hardclock does not run its callouts either -- it
                ; sets `needsoft' and ends with
                ;     if (needsoft && BASEPRI(ps)) { _splsoftclock();
                ;                                    softclock(pc,ps); }
                ;                                    -- kern_clock.c:142
                ; because a callout may call wakeup(), which is not safe at
                ; clock priority.  schedcpu is one of those callouts and
                ; `wakeup((caddr_t)&lbolt)' is its first line (kern_synch.c:36).
                ;
                ; FGX HAS THE SAME CONSTRAINT FOR A DIFFERENT REASON: this
                ; heartbeat runs on the INTERRUPTED TASK'S direct page, so it
                ; cannot reach _schedTblPtr and cannot call _wakeup -- the same
                ; reason the keyboard wakeup lives in swtch's idle arm and not
                ; here.  So this marks and _Lbolt_Wake (sched.s) performs, at
                ; the two kernel-DP sites _Tty_DrainSigPend already uses.
                ;------------------------------------------------------------
                DEC     _kLboltTick
                BNE     @hb_lbOK
                LDA     #LBOLT_TICKS
                STA     _kLboltTick
                LDA     #1
                STA     _kLboltDue
@hb_lbOK
                ;------------------------------------------------------------
                ; Keyboard scan + ring enqueue.  Why here: the Mega II key
                ; latch ($C000) is one-deep.  If the foreground spends >16ms
                ; between Con_PollKey calls (typical during a full-screen
                ; scroll) the next strobe overwrites the unread one and we
                ; lose a keystroke.  The heartbeat drains $C000 every VBL
                ; into a 16-entry ring; Con_PollKey dequeues from there.
                ; Reads $E0C000 directly (NOT firmware KEYBOARD vector) so
                ; we don't fight with anyone else for the strobe-clear.
                ;
                ; Entry to this block: M=0, X=0, DBR=kernel-bank ($02 = assembly ORG).
                ;------------------------------------------------------------
                ; -- Test-only raw-key inject (vt100 keyboard net).  The ADB
                ; key latch ($E0C000) is not pokeable in MAME (a write there
                ; hits the 80STORE soft switch), so fgxdebug drops a
                ; pre-translation ADB byte in _kKbdInjectRaw and we run it
                ; through the SAME translation as a real strobe.  Encoding:
                ; low byte = 7-bit key, bit 8 = Ctrl-held, bit 9 = OPTION-held,
                ; 0 = no injection.  Inert in production.  Entry M=0, X=0.
                ;
                ; Bit 9 is slice D's addition and it is what makes alt-N
                ; TESTABLE AT ALL: injected keys bypass the live $C025 read, so
                ; without an Option bit in the encoding there is no way to drive
                ; a VC switch from the harness -- the phase would have shipped
                ; with no test rather than a weak one.
                ; TRIGGER ON THE KEY BYTE, NOT THE WHOLE WORD.  The harness
                ; cannot write 16 bits atomically, so for one instant the cell
                ; holds only half the injection.  Testing the whole word made
                ; EITHER write order wrong: key-first sampled a key with no
                ; modifier (alt-N arrived as a bare '2'), and modifier-first
                ; sampled a modifier with key 0 and consumed the cell before the
                ; key landed.  Gating on the LOW byte makes "a key is present"
                ; the trigger, so the plugin writes the modifier first and this
                ; sees a complete injection or nothing.
                LDA     _kKbdInjectRaw
                AND     #$00FF                  ; key byte present?
                BEQ     @hb_kbdScan
                LDA     _kKbdInjectRaw          ; full word: key + modifier bits
                STZ     _kKbdInjectRaw          ; consume (self-clearing)
                STZ     _kKbdOptHeld
                BIT     #$0200                  ; bit 9 = Option held
                BEQ     @hb_kbdInjNO
                PHA
                LDA     #1
                STA     _kKbdOptHeld
                PLA
@hb_kbdInjNO    LDX     #0                      ; X = Ctrl flag
                BIT     #$0100                  ; bit 8 = Ctrl held
                BEQ     @hb_kbdInjNC
                LDX     #1
@hb_kbdInjNC    AND     #$00FF                  ; A = 7-bit key byte
                BRA     @hb_kbdXlate
@hb_kbdScan
                SEP     #$20
                MX      %10
                LDAL    $E0C000                 ; bit 7 = strobe, bits 6-0 = ASCII
                BMI     @hb_kbdGot              ; key pending
                JMP     @hb_kbdEnd_M1           ; no key (far — vt100 block is long)
@hb_kbdGot
                AND     #$7F
                STAL    $E0C010                 ; clear strobe
                REP     #$20                    ; M=0 (X already 0)
                MX      %00
                AND     #$00FF                  ; clean hidden hi-byte of A
                ; -- Read Ctrl state into X (KEYMODREG $E0C025 bit 1; Firmware
                ; Ref p.298) so @hb_kbdXlate can disambiguate the collision.
                ; One read of KEYMODREG serves both modifiers: bit 1 = Ctrl,
                ; bit 6 = Option/Closed-Apple (Firmware Ref p.298).
                LDX     #0
                PHA                             ; key byte
                SEP     #$20
                MX      %10
                LDAL    $E0C025
                REP     #$20
                MX      %00
                AND     #$00FF                  ; A = modifier bits
                PHA
                AND     #$0040                  ; Option?
                BEQ     @hb_kbdNoOpt
                LDA     #1
@hb_kbdNoOpt    STA     _kKbdOptHeld            ; 1 when held, else 0
                PLA                             ; modifier bits again
                AND     #$0002                  ; Ctrl?
                BEQ     @hb_kbdScanNC
                LDX     #1
@hb_kbdScanNC   PLA                             ; A = key byte, X = Ctrl flag
@hb_kbdXlate
                ; -- Slice D: Option-1/2/3 REQUESTS a virtual console switch and
                ; is SWALLOWED (never enqueued -- a shell must not see a stray
                ; digit).  Only a request is posted; the switch itself repatches
                ; 97 bank operands and swaps ~110 B of console state, which must
                ; not happen in an ISR -- see _kVcSwitchReq in include/memmap.s.
                ; Option-1 selects VC 0 (the console), so the stored value is
                ; simply key-'0' and the drain's DEC recovers the index.
                ;
                ; OPTION ONLY, verified on hardware (2026-08-05): Ctrl-N
                ; does not reach here on a real IIgs keyboard, Option-N does.
                ; An earlier cut accepted either, which is worse than useless --
                ; it made a dead combination look supported and cost a debugging
                ; session driving the headless test with Ctrl.
                PHA
                LDA     _kKbdOptHeld            ; OPTION ONLY -- see below
                BEQ     @hb_kbdNotVc
                PLA
                PHA
                CMP     #$0031                  ; < '1'
                BCC     @hb_kbdNotVc
                CMP     #$0035                  ; > '4'
                BCS     @hb_kbdNotVc
                SEC
                SBC     #$0030                  ; '1'->1 .. '4'->4 (index+1)
                STA     _kVcSwitchReq
                PLA                             ; drop the key: swallowed
                BRL     @hb_kbdFull             ; skip the enqueue entirely
                                                ; (BRL: the vt100 block between
                                                ;  here and there is past BRA
                                                ;  range)
@hb_kbdNotVc    PLA
                ; -- vt100 translation.  IIgs Mega II latches Ctrl-H/J/K/U and
                ; Left/Down/Up/Right as the SAME byte ($08/$0A/$0B/$15).  Emit
                ; a real vt100 stream: naked arrow -> ESC [ D/B/A/C, Ctrl+letter
                ; -> the bare control code.  Everything else passes through.
                ; A = 7-bit key, X = Ctrl flag.
                CMP     #$0008
                BEQ     @hb_kbdAmbig
                CMP     #$000A
                BEQ     @hb_kbdAmbig
                CMP     #$000B
                BEQ     @hb_kbdAmbig
                CMP     #$0015
                BEQ     @hb_kbdAmbig
                BRL     @hb_kbdEnqueue          ; not ambiguous -> single enqueue
                                                ; BRL: T6 4b's emit helper sits
                                                ; between here and there
@hb_kbdAmbig
                CPX     #0
                BEQ     @hb_arrGo
                BRL     @hb_kbdEnqueue          ; Ctrl held -> bare control code
@hb_arrGo       ; naked arrow -> ESC [ <letter>
                CMP     #$0008
                BNE     @hb_arr1
                LDY     #$0044                  ; Left  -> 'D'
                BRA     @hb_arrEmit
@hb_arr1        CMP     #$000A
                BNE     @hb_arr2
                LDY     #$0042                  ; Down  -> 'B'
                BRA     @hb_arrEmit
@hb_arr2        CMP     #$000B
                BNE     @hb_arr3
                LDY     #$0041                  ; Up    -> 'A'
                BRA     @hb_arrEmit
@hb_arr3        LDY     #$0043                  ; Right -> 'C'  ($15)
@hb_arrEmit
                ; THE DISCIPLINE FIRST, AND ALL THREE BYTES, BEFORE the ring's
                ; space check below (T6 increment 4b).  Under feed-both the
                ; RING is the saturating side -- it is 16 entries and only a
                ; getkey consumer drains it -- so putting the emit behind that
                ; check would let a full ring silence the discipline, which is
                ; the queue a `read(2)' actually reads.
                LDA     #$001B                  ; ESC
                JSR     @hb_kbdEmit
                LDA     #$005B                  ; '['
                JSR     @hb_kbdEmit
                TYA                             ; the final letter
                JSR     @hb_kbdEmit
                LDA     _kTtyEmitRet            ; ring only as the fallback
                CMP     #$FFFF
                BEQ     @hb_arrRing
                BRL     @hb_kbdFull
@hb_arrRing
                ; Atomic 3-byte enqueue: a partial "ESC [" with the letter
                ; dropped = a lone ESC = "leave insert / bell" in vi.  Require
                ; count+3 <= KBD_RING_SZ up front, else drop the whole seq.
                LDA     _kKbdRingCount
                CLC
                ADC     #3
                CMP     #KBD_RING_SZ+1
                BCS     @hb_arrDrop
                LDA     #$001B                  ; ESC
                JSR     @hb_kbdRingPush
                LDA     #$005B                  ; '['
                JSR     @hb_kbdRingPush
                TYA                             ; final letter
                JSR     @hb_kbdRingPush
@hb_arrDrop     BRL     @hb_kbdFull             ; BRL: the per-tty ^C resolution
                                                ;   below pushed this past BRA
                                                ;   range, same as @hb_kbdNotVc
                ; @hb_kbdEmit: A.lo = the key byte -> the LINE DISCIPLINE,
                ; at arrival.
                ; PRESERVES X AND Y, because both callers have one live: the
                ; arrow path carries its final letter in Y across three calls,
                ; and the ordinary path's X is the ring cursor below.
                ;
                ; THIS IS 2.11BSD's `dzrint' -- bind the character to its line,
                ; then hand it to that line's `l_rint', before the discipline
                ; has any idea an interrupt happened.
                ;
                ; THE BIND IS RECOMPUTED HERE rather than hoisted, because the
                ; ARROW path never reached the old bind at all: it branches to
                ; `@hb_arrEmit' from the ambiguity test above, well before
                ; `@hb_kbdEnqueue'.  Three keystrokes that no fixture in the
                ; suite covers were reaching the ring and nothing else.
                ;
                ; THE BYTE RIDES IN Y ACROSS THE BRACKET.  KTTY_KC_ENTER_IRQ
                ; MOVES S to the interrupt stack, so anything pushed before it
                ; is unaddressable until LEAVE restores S; it destroys A and X
                ; and leaves Y alone (include/kernelc.s).  The plain `PHY/PHX'
                ; below are fine -- they are pulled after LEAVE has put the
                ; caller's stack back.
@hb_kbdEmit     PHY
                PHX
                PHA                             ; AND A: the ordinary caller
                                                ; falls straight into
                                                ; `@hb_kbdRing', which stores
                                                ; the byte FROM A.  Losing it
                                                ; here fed the discipline and
                                                ; left the ring empty -- the
                                                ; boot reached its prompt and
                                                ; then swallowed every
                                                ; keystroke, with `_kKbdRingCount'
                                                ; reading 0 in the dump.
                AND     #$00FF
                TAY                             ; Y.lo = c
                ; `_kTtyEmitRet' is SET FROM THE ANSWER at @hb_emGo below --
                ; `_Tty_IrqInput' answers $FFFF for "no tty bank" itself now, so
                ; the pre-seed and the second `_kTtyReady' test both went with
                ; the factoring.
                LDA     _kVcFocus               ; the console with the keyboard
                BEQ     @hb_emGo                ; VC0 -> tty[0]: index 0 already
                CMP     #1
                BNE     @hb_emV2
                TYA
                ORA     #$0300                  ; VC1 -> tty[3]
                TAY
                BRA     @hb_emGo
@hb_emV2        CMP     #VC_CARD
                BEQ     @hb_emV3
                TYA
                ORA     #$0400                  ; VC2 -> tty[4]
                TAY
                BRA     @hb_emGo
@hb_emV3        TYA
                ORA     #$0600                  ; VC3 -> tty[6], the card's
                TAY
@hb_emGo        JSR     _Tty_IrqInput           ; Y = (idx << 8) | c
                STA     _kTtyEmitRet            ; -1 = unbound line, else taken
@hb_emOut       PLA
                PLX
                PLY
                RTS

;==============================================================================
; _Tty_IrqInput - hand one ARRIVED character to the line discipline, from an
; interrupt.  2.11BSD's receive interrupt does this inline, and the line is the
; whole routine:
;
;     (*linesw[tp->t_line].l_rint)(c, tp);
;         -- dzrint, vendor/2.11BSD/usr/sys/pdpuba/dz.c:259 (dzrint at :209)
;
; THERE ARE TWO RECEIVE INTERRUPTS NOW, which is why this is a routine rather
; than the inline sequence it was.  The heartbeat feeds the keyboard; the SCC
; handler feeds /dev/tty01 (apple/fgx#108 T7).  ONE COPY OF THE BRACKET is the
; point: `KTTY_KC_ENTER_IRQ' resets S to the top of the interrupt stack, banks
; the language card in and hands it back (apple/fgx#242), and a second
; hand-written copy of that is a second place to get it wrong at interrupt time.
;
; NEITHER CALLER CAN INTERRUPT THE OTHER, and that was MEASURED rather than
; read: sampling the I flag at each handler's own entry gave 3,143 heartbeat
; entries and 360 `serial_isr' entries with I SET on every one of them, with a
; forced-mask positive control confirming the counters could report otherwise.
; That is the precondition `KTTY_KC_ENTER_IRQ's header states and does not
; enforce.
;
; `_kTtyReady' IS TESTED HERE, not by the callers.  A caller that has to
; remember a guard is a caller that will one day forget -- the same reasoning
; `kc_ttyinput' gives for setting `tty_irq' itself.
;
; In:  Y = (tty index << 8) | character.  MX %00.
; Out: A = $FFFF the discipline did not take it (no tty bank, or an unbound
;      line); 1 something was deferred; 0 taken with nothing marked.
;      X clobbered.
;==============================================================================
_Tty_IrqInput   MX      %00
                LDA     _kTtyReady              ; no tty bank -> nothing to feed
                BNE     @tii_go
                LDA     #$FFFF
                RTS
@tii_go         KTTY_KC_ENTER_IRQ
                TYA
                AND     #$00FF
                PHA                             ; arg2: c   (fcc reads its
                TYA                             ;   arguments RIGHT-TO-LEFT,
                XBA                             ;   so idx is pushed last)
                AND     #$00FF
                PHA                             ; arg1: idx
_ktp057         JSL     KTTY_KC_TTYINPUT        ; slot 38
                TAX
                PLA                             ; the caller pops its own two
                PLA
                KTTY_KC_LEAVE_IRQ
                ; ONLY 1 MEANS "SOMETHING WAS DEFERRED".  -1 is $FFFF for an
                ; unbound line and 0 is "nothing marked" -- arming the drain on
                ; anything else would arm it forever on the first key typed
                ; before the lines are bound.  Test, then set.
                CPX     #1
                BNE     @tii_out
                LDA     #1
                STA     _kTtyOutAny             ; a soft site will restart the
@tii_out        TXA
                RTS


@hb_kbdRingPush ; push A.lo into the ring (space pre-checked); uses X, keeps Y.
                LDX     _kKbdRingHead
                SEP     #$20
                MX      %10
                STA     _kKbdRing,X
                REP     #$20
                MX      %00
                INX
                CPX     #KBD_RING_SZ
                BCC     @hb_kpNoWrap
                LDX     #0
@hb_kpNoWrap    STX     _kKbdRingHead
                INC     _kKbdRingCount
                LDA     #1                      ; F5: a key arrived — ask the
                STAL    KFGX_YIELD_MIRROR       ; P2' userland-safepoint mirror
                STA     _kYieldReq              ;   running task to yield at its
                                                ;   next syscall boundary (the
                                                ;   swtch kbd-wake then runs the
                                                ;   blocked fg shell)
                RTS
@hb_kbdEnqueue  ; THE KEY GOES TO THE LINE DISCIPLINE, AT ARRIVAL, and then
                ; to the ring.  apple/fgx#108 T6 increment 4b.
                ;
                ; WHAT STOOD HERE, 165 lines of it: the VC->tty bind, a
                ; `_Tty_PgrpOf' gate, an `SG_RAW' gate, a hand-coded `^C'/`^Z'
                ; test that posted `_kTtySigPend' and BRANCHED PAST the ring,
                ; and the `_kTtyFlushPend' latch that stood in for the flush
                ; `ttyinput' would have done.  Every one of those is
                ; `ttyinput's own work -- it tests `t_intrc'/`t_suspc' against
                ; the line's OWN characters rather than a baked `$03'/`$1A'
                ; (settable through TIOCSETC/TIOCSLTC), it opens with the RAW
                ; arm so nothing is a signal character there, and it runs
                ; `if ((t_flags&NOFLSH)==0) ttyflush(tp, FREAD|FWRITE)' before
                ; it signals.  This is the same subsumption apple/fgx#57's
                ; hand-coded INTR/QUIT test took at increment 4a, from the
                ; other end of the same discipline.
                ;
                ; FEED BOTH (2026-08-26).  The fall-through to
                ; `@hb_kbdRing' is deliberate and is the whole of the ruling:
                ; SYS_GETKEY/SYS_POLLKEY stay a console primitive
                ; (apple/fgx#151), so the byte goes to the ring as well.  It
                ; also covers the boot window -- `Toolbox_InstallHB' arms this
                ; body long before `_TtyDevInit' binds the lines and
                ; `_Tty_Chars' seeds their characters, and `kc_ttyinput'
                ; answers -1 for an unbound line, so the ring is what catches a
                ; key typed in between.
                JSR     @hb_kbdEmit
                ; THE RING IS THE FALLBACK, NOT A SECOND COPY -- T6 4b.
                LDA     _kTtyEmitRet
                CMP     #$FFFF
                BEQ     @hb_kbdRing
                BRL     @hb_kbdFull

@hb_kbdRing     ; DROP THE OLDEST, NOT THE NEWEST, WHEN THE RING IS FULL.
                ; T6 increment 4b: until the flip, EVERY tty read drained this
                ; ring -- the pump's `_Tty_GetByte' was its consumer -- so it
                ; could not stay full.  With the pump gone only SYS_GETKEY
                ; drains it, and a session that never calls one leaves it
                ; saturated at KBD_RING_SZ with the FIRST sixteen keys of the
                ; boot in it.  Dropping the newest then makes the ring a
                ; permanent record of stale bytes and silently discards every
                ; key after the sixteenth; advancing the tail keeps it a window
                ; on the most recent sixteen, which is what a console primitive
                ; reading "the keyboard" means.
                LDX     _kKbdRingCount
                CPX     #KBD_RING_SZ
                BCC     @hb_kbdRingSp
                LDX     _kKbdRingTail           ; full: retire the oldest
                INX
                CPX     #KBD_RING_SZ
                BCC     @hb_kbdTNoWrap
                LDX     #0
@hb_kbdTNoWrap  STX     _kKbdRingTail
                DEC     _kKbdRingCount
@hb_kbdRingSp   LDX     _kKbdRingHead
                SEP     #$20
                MX      %10
                STA     _kKbdRing,X             ; A.lo = key byte (DBR=kernel-bank)
                REP     #$20
                MX      %00
                INX
                CPX     #KBD_RING_SZ
                BCC     @hb_kbdNoWrap
                LDX     #0
@hb_kbdNoWrap
                STX     _kKbdRingHead
                INC     _kKbdRingCount
@hb_kbdFull
                SEP     #$20
                MX      %10
@hb_kbdEnd_M1
                ; -- VBL ACK (entry M=1, X=0)
                STAL    $E0C047                 ; ACK VBL latch (mandatory)

                REP     #$20
                MX      %00

                ; vi-port slice 3: decrement every task's alarm tick
                ; counter; set SIGALRM pending on any that reach zero.
                ; O(16) per VBL — cheap.
                JSR     _Sys_AlarmTickAll

                PLB                             ; restore caller DBR
                PLP                             ; restore caller flags
                RTL                             ; pulls PB,PCH,PCL (3 bytes)

;==============================================================================
; Diagnostic strings — printed only on failure paths immediately before
; _Kern_Halt. None of these should fire on a working build.
;==============================================================================
_TBM_ID_Fail    ASC  "GetNewID FAIL",00
_TBM_HB_Fail    ASC  "SetHeartBeat FAIL",00

_kYieldReq      DS   2                  ; resched request (P1: kbd input OR
                                        ; quantum expiry — one mechanism): the
                                        ; heartbeat writes 1 (ring push M=8 low
                                        ; byte / quantum M=16; high byte stays
                                        ; 0 either way), the syscall dispatcher
                                        ; yields ONCE at the next boundary and
                                        ; clears it.  Inline static (KGlobals
                                        ; is at its ceiling).
_kQuantum       DA   QUANTUM_TICKS      ; P1 countdown to the next forced
                                        ; resched, in VBL ticks; BAKED initial
                                        ; value (DS-zero would first-DEC to
                                        ; $FFFF = an 18-minute first quantum)
_kLboltDue      DS   2                  ; lbolt wake is DUE: the heartbeat sets
                                        ; it, _Lbolt_Wake (sched.s) clears it
                                        ; and does the wakeup on kernel DP
_hbLcTicks      DS   2                  ; apple/fgx#242 ISR-context probe: ticks
                                        ;   that ENTERED it (bounded)
_hbLcRuns       DS   2                  ; brackets that CAME BACK -- the
                                        ;   denominator _hbLcFail needs
_hbLcState      DS   2                  ; STATEREG as the firmware left it ($08)
_hbLcCtl        DS   2                  ; positive control -- MUST read 0
_hbLcFail       DS   2                  ; store/read-backs failed INSIDE the
                                        ;   bracket -- MUST read 0
_hbLcAfter      DS   2                  ; STATEREG after LEAVE -- must match
                                        ;   _hbLcState
_hbLcInside     DS   2                  ; STATEREG sampled INSIDE the bracket
_kLboltTick     DA   LBOLT_TICKS        ; VBL countdown to the next lbolt wake.
                                        ; BAKED for the reason _kQuantum is --
                                        ; DS-zero first-DECs to $FFFF, which
                                        ; here would be an 18-minute first
                                        ; second and a tty writer wedged for it

;==============================================================================
; END toolbox.s
;==============================================================================
