                MX      %00                 ; reset Merlin mode tracking
;==============================================================================
; sound.s - direct DOC (Ensoniq 5503) alert tone.
;
; The IIgs Toolbox Sound Manager path was a dead end for our "just play a
; beep" need — its _FFStartSound kept returning $0814 synthModeErr despite
; the parameter block matching the docs.  In practice, most IIgs software
; that just needs a tone (the examples corpus es5503/morse_gs etc.) talks
; to the DOC directly rather than going through the Sound Tool Set.
;
; Approach: at boot we configure oscillator 0 (frequency, volume, wave
; pointer, wave size) and upload a 256-byte square wave to DOC RAM page 0.
; Sound_Beep starts the oscillator free-running, burns ~80 ms in a delay
; loop, then halts it.
;
; DOC interface (always at bank $E0; FGX uses STAL to avoid DBR drift):
;   $E0C03C  SND_CTRL    bit 7 = busy (RO); bit 6 = 0 reg / 1 RAM;
;                        bit 5 = auto-increment
;   $E0C03D  SND_DATA    one-byte read/write at current SND_ADDR
;   $E0C03E  SND_ADDR    address-lo
;   $E0C03F  SND_ADDR+1  address-hi
;
; Per-oscillator register groups (offset = group_base + osc_num):
;   $00..$1F  freq lo
;   $20..$3F  freq hi
;   $40..$5F  volume
;   $60..$7F  wave data
;   $80..$9F  wave table pointer (DOC page)
;   $A0..$BF  control (channel<<4 | int<<3 | mode<<1 | halt)
;   $C0..$DF  wave size (bank | size3 | res3)
;
; Special registers:
;   $E0  osc interrupt status (read clears)
;   $E1  osc enable: write (active_osc_count - 1) * 2
;
; Owner: sound.s.  Init halts on no errors (direct DOC has no error path).
;==============================================================================

SND_CTRL        EQU     $E0C03C
SND_DATA        EQU     $E0C03D
SND_ADDR_LO     EQU     $E0C03E
SND_ADDR_HI     EQU     $E0C03F

;------------------------------------------------------------------------------
; _SoundWait - poll SND_CTRL bit 7 (busy) until clear.  M=1 entry/exit.
;------------------------------------------------------------------------------
_SoundWait      MX      %11
@sw_L           LDAL    SND_CTRL
                BMI     @sw_L
                RTS

;------------------------------------------------------------------------------
; _SoundDocMode - SND_CTRL → register-write + auto-increment.  M=1.
;------------------------------------------------------------------------------
_SoundDocMode   MX      %11
                JSR     _SoundWait
                LDAL    SND_CTRL
                AND     #%10111111              ; clear bit 6 → register mode
                ORA     #%00100000              ; set bit 5 → auto-incr
                STAL    SND_CTRL
                RTS

;------------------------------------------------------------------------------
; _SoundRamMode - SND_CTRL → RAM-write + auto-increment.  M=1.
;------------------------------------------------------------------------------
_SoundRamMode   MX      %11
                JSR     _SoundWait
                LDAL    SND_CTRL
                ORA     #%01100000              ; set bits 6 (RAM) + 5 (auto-incr)
                STAL    SND_CTRL
                RTS

;------------------------------------------------------------------------------
; _SoundSetAddr - point SND_ADDR at register A (DOC reg in low byte, 0 in hi).
; M=1.
;------------------------------------------------------------------------------
_SoundSetAddr   MX      %11
                STAL    SND_ADDR_LO
                LDA     #0
                STAL    SND_ADDR_HI
                RTS

;------------------------------------------------------------------------------
; Sound_Init - bring up DOC for the alert-tone oscillator.
;
; Entry: M=0, X=0 (kernel-boot convention).  Exit: same.
;------------------------------------------------------------------------------
Sound_Init      ENT
                MX      %00
                PHP
                PHB                             ; far bank: caller's DBR is the
                PHK                             ;   CORE bank; our own data (the
                PLB                             ;   _docVecSave block) is HERE
                SEP     #$30
                MX      %11

                ; --- Halt all 32 oscillators.
                JSR     _SoundDocMode
                LDA     #$A0                    ; control register, osc 0
                JSR     _SoundSetAddr
                LDA     #%00000001              ; free-run + halt
                LDX     #32
@si_haltL       STAL    SND_DATA
                DEX
                BNE     @si_haltL

                ; --- Zero all 32 oscillator volumes.
                JSR     _SoundDocMode
                LDA     #$40                    ; volume register, osc 0
                JSR     _SoundSetAddr
                LDA     #0
                LDX     #32
@si_volL        STAL    SND_DATA
                DEX
                BNE     @si_volL

                ; --- Drain the Oscillator Interrupt register ($E0).  Halting
                ;     clears every interrupt enable, but an oscillator that
                ;     reached the end of its wavetable before that left IRQ
                ;     asserted, and reading $E0 is what acknowledges it.  Bit 7
                ;     set means no oscillator is interrupting.  A read lags one
                ;     cycle, so the first is discarded (Hardware Reference
                ;     pp.106-107); auto-increment off keeps the address on $E0.
                ;     At most one read per oscillator, and one over.
                JSR     _SoundWait
                LDAL    SND_CTRL
                AND     #%10011111              ; DOC registers, no auto-incr
                STAL    SND_CTRL
                LDA     #$E0
                JSR     _SoundSetAddr
                JSR     _SoundWait
                LDAL    SND_DATA                ; the lagging read, discarded
                LDX     #33
@si_irqL        JSR     _SoundWait
                LDAL    SND_DATA
                BMI     @si_irqDone             ; bit 7: no IRQ pending
                DEX
                BNE     @si_irqL
@si_irqDone

                ; --- Enable 18 oscillators: per-oscillator sample rate
                ;     ≈ 44.7 kHz.  Matches morse_gs's pitch reference so the
                ;     freq-register values below behave the same as their
                ;     known-good beep tone.
                JSR     _SoundDocMode
                LDA     #$E1                    ; oscillator enable register
                JSR     _SoundSetAddr
                LDA     #17*2                   ; (active_count - 1) * 2
                STAL    SND_DATA

                ; --- osc 0 + osc 1 frequency = $0800.  Auto-increment lets us
                ;     write both bytes per register group in one mode setup.
                JSR     _SoundDocMode
                LDA     #$00                    ; freq lo, oscs 0+1
                JSR     _SoundSetAddr
                LDA     #$00                    ; lo of $0800
                STAL    SND_DATA                ; osc 0 freq lo
                STAL    SND_DATA                ; osc 1 freq lo

                JSR     _SoundDocMode
                LDA     #$20                    ; freq hi, oscs 0+1
                JSR     _SoundSetAddr
                LDA     #$08                    ; hi of $0800
                STAL    SND_DATA                ; osc 0 freq hi
                STAL    SND_DATA                ; osc 1 freq hi

                ; --- osc 0 + osc 1 volume = $C0.
                JSR     _SoundDocMode
                LDA     #$40
                JSR     _SoundSetAddr
                LDA     #$C0
                STAL    SND_DATA                ; osc 0
                STAL    SND_DATA                ; osc 1

                ; --- osc 0 + osc 1 wave table pointer = DOC RAM page $00.
                JSR     _SoundDocMode
                LDA     #$80
                JSR     _SoundSetAddr
                LDA     #$00
                STAL    SND_DATA                ; osc 0
                STAL    SND_DATA                ; osc 1

                ; --- osc 0 + osc 1 wave size = $00 (256-B table, min res).
                JSR     _SoundDocMode
                LDA     #$C0
                JSR     _SoundSetAddr
                LDA     #$00
                STAL    SND_DATA                ; osc 0
                STAL    SND_DATA                ; osc 1

                ; --- Upload the 256-byte square wave to DOC RAM page 0.
                JSR     _SoundRamMode
                LDA     #0
                JSR     _SoundSetAddr           ; SND_ADDR = $0000
                ; 16-bit X for table index.
                REP     #$10
                MX      %10
                LDX     #0
@si_waveL       LDA     SoundBeepWave,X
                STAL    SND_DATA
                INX
                CPX     #256
                BCC     @si_waveL
                SEP     #$10
                MX      %11

                ; Snapshot the firmware sound-IRQ vector ($E1002C, a 4-byte JML)
                ; so Sound_StopDoc can restore it when a DOC-owning task is killed
                ; (its handler lived in a now-freed user bank).
                LDAL    $E1002C
                STA     _docVecSave
                LDAL    $E1002D
                STA     _docVecSave+1
                LDAL    $E1002E
                STA     _docVecSave+2
                LDAL    $E1002F
                STA     _docVecSave+3

                PLB                             ; restore caller's DBR (pushed
                PLP                             ;   AFTER P, so it pulls FIRST)
                SEC                             ; after PLP: SEC is the return value
                RTL

;------------------------------------------------------------------------------
; Sound_StopDoc - silence the DOC: halt all 32 oscillators, zero their volumes,
; and restore the firmware sound-IRQ vector.  Called from _Exit_Core when the
; DOC-owning task (SYS_SOUND_CLAIM) terminates, so a player's audio stops on
; kill/exit but keeps running when backgrounded or stopped.  MX %00 in/out.
;------------------------------------------------------------------------------
Sound_StopDoc   ENT
                MX      %00
                PHP
                PHB                             ; far bank: caller's DBR is the
                PHK                             ;   CORE bank; our own data (the
                PLB                             ;   _docVecSave block) is HERE
                SEP     #$30
                MX      %11
                ; halt all 32 oscillators (control regs $A0..$BF; bit 0 = halt)
                JSR     _SoundDocMode
                LDA     #$A0
                JSR     _SoundSetAddr
                LDX     #32
@ssd_halt       LDA     #%00000001              ; halted (channel 0)
                STAL    SND_DATA                ; auto-increments to next osc
                DEX
                BNE     @ssd_halt
                ; zero all 32 oscillator volumes ($40..$5F)
                JSR     _SoundDocMode
                LDA     #$40
                JSR     _SoundSetAddr
                LDX     #32
@ssd_vol        LDA     #$00
                STAL    SND_DATA
                DEX
                BNE     @ssd_vol
                ; restore the firmware sound-IRQ vector (de-risk a stray IRQ into
                ; the killed player's freed bank)
                LDA     _docVecSave
                STAL    $E1002C
                LDA     _docVecSave+1
                STAL    $E1002D
                LDA     _docVecSave+2
                STAL    $E1002E
                LDA     _docVecSave+3
                STAL    $E1002F
                PLB                             ; restore caller's DBR (pushed
                PLP                             ;   AFTER P, so it pulls FIRST)
                RTL

;------------------------------------------------------------------------------
; Sound_Beep - start osc 0 free-running, delay ~80 ms, halt.
;
; Caller MX any.  Wraps with PHP/PLP so flag state is preserved.
;------------------------------------------------------------------------------
; TWO ENTRY POINTS, and the split is load-bearing.  Sound_Beep is an export-table
; target (far.s slot 3, `JMP Sound_Beep`), reached by JSL from the core kernel,
; so it must end in RTL.  But it also has FAR-BANK callers now that the sound
; driver lives over here -- Far_BootChime and the VT bell -- and those reach it
; with a plain JSR, which pushes two bytes where RTL pulls three.  That is not a
; crash at the call; it is a wild return one level up, so it looks like the
; CALLER broke.  It cost a whole boot-hang investigation: the chime "worked"
; (the beep sounds) and boot simply never continued past it.
;
; Same shape as the kernel's MOD_JT *Impl targets and far_shims.s: RTS body,
; RTL wrapper.  Same-bank callers JSR the impl; cross-bank callers JSL the
; wrapper.
Sound_Beep      ENT
                MX      %00
                JSR     _Sound_BeepImpl
                RTL

_Sound_BeepImpl MX      %00
                PHP
                PHB                             ; far bank: caller's DBR is the
                PHK                             ;   CORE bank; our own data (the
                PLB                             ;   _docVecSave block) is HERE
                SEP     #$30
                MX      %11

                ; Start osc 0 (channel 0 = left) and osc 1 (channel 1 = right)
                ; together so the beep is centered in the stereo field.
                ;   bit 7..4 = channel (0 = L, 1 = R)
                ;   bit 3    = interrupt enable
                ;   bit 2..1 = mode (00 = free-run)
                ;   bit 0    = halt
                JSR     _SoundDocMode
                LDA     #$A0
                JSR     _SoundSetAddr
                LDA     #%00000000              ; channel 0, free-run, running
                STAL    SND_DATA                ; osc 0 → left
                LDA     #%00010000              ; channel 1, free-run, running
                STAL    SND_DATA                ; osc 1 → right

                ; Burn ~80 ms.  Inner DEY/BNE ≈ 5 cyc; LDY=$FF ≈ 1280 cyc.
                ; LDX=$80 → 128 × 1280 ≈ 164 k cyc ≈ 58 ms @ 2.8 MHz.
                LDX     #$80
@sbp_o          LDY     #$FF
@sbp_i          DEY
                BNE     @sbp_i
                DEX
                BNE     @sbp_o

                ; Halt both oscillators.
                JSR     _SoundDocMode
                LDA     #$A0
                JSR     _SoundSetAddr
                LDA     #%00000001              ; channel 0, halted
                STAL    SND_DATA                ; osc 0
                LDA     #%00010001              ; channel 1, halted
                STAL    SND_DATA                ; osc 1

                PLB                             ; restore caller's DBR (pushed
                PLP                             ;   AFTER P, so it pulls FIRST)
                RTS                             ; RTS: the RTL is on the wrapper


;==============================================================================
; Static data — alert-tone waveform (single page).
;==============================================================================

; 256-byte square wave: 128 bytes of $E0 then 128 bytes of $20.  $80 is the
; DOC's silent center; swing ±$60 ≈ 75 % amplitude.  Vol Setting ($C0) +
; wave amplitude jointly determine perceived loudness.  Bytes deliberately
; avoid $00 — on the DOC, a $00 sample byte is "end of sample" in some
; modes and would cause spurious halts in free-run mode.
SoundBeepWave   DS      128,$E0
                DS      128,$20

;==============================================================================
; END sound.s
;==============================================================================

;------------------------------------------------------------------------------
; Far-bank statics.  These live HERE rather than in the core kernel's memmap.s
; because only this driver touches them, so they stay DBR-relative (far.s entries
; do PHK/PLB) and need no cross-bank patching.
;
; PLACED AFTER ALL CODE, deliberately.  A `DS` in a code segment reserves bytes
; exactly where it sits: an earlier draft put this between Sound_Init's `MX %00`
; and its `PHP`, which planted four zero bytes in the entry point and executed
; them as BRK.  Boot hung with the console still repainting, which looked like a
; cross-bank call failure and was nothing of the kind.
;------------------------------------------------------------------------------
_docVecSave     DS      4               ; boot snapshot of the firmware sound-IRQ
                                        ; vector ($E1002C); Sound_StopDoc restores
                                        ; it so a killed player's freed-bank
                                        ; handler can't fire.
