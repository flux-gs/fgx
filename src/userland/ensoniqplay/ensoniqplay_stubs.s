;==============================================================================
; ensoniqplay_stubs.s - companion asm for ensoniqplay.c (Ensoniq 5503 DOC).
;
; PUT into seg0 by the FGX2 build (after ensoniqplay.s + seg1_layout.s), so the
; C seg1 globals resolve by bare name and are reached DBR-relative.  Every entry
; is JSL'd from C with DBR = data bank (seg1), so `LDA: <cglobal>` is a DBR-
; relative read into seg1; each returns RTL.  The DOC / GLU idioms (docwait,
; setreg, the bring-up sequence, the RAM autoinc blast) are lifted from the
; proven ntpplay engine (src/userland/ntpplay/ntpplay_stubs.s); the register-
; read double-tap follows libsoundGS's GetDOCReg.
;
; MILESTONE 1: PLACED playback only.  Upload a sample into DOC RAM once, program
; a single one-shot oscillator, poll its halt bit.  No sound IRQ (that is M2).
;==============================================================================

; DOC / sound GLU + syscalls not already EQU'd by seg0.link.s (SYS_TRAMP is).
SYS_TICKS       EQU     52
SYS_SOUND_CLAIM EQU     86
SYS_NANOSLEEP   EQU     83
SOUND_CTL       EQU     $E1C03C                     ; GLU control (bit7 busy)
SOUND_DATA      EQU     $E1C03D                     ; register / RAM data port
SOUND_ADRL      EQU     $E1C03E                     ; register# / RAM address low
SOUND_ADRH      EQU     $E1C03F                     ; RAM address high
IRQ_VOLUME      EQU     $E100CA                     ; system sound volume soft switch
IRQ_SOUNDDATA   EQU     $E100CC                     ; osc-int value the ROM saved for us
SND_INT_PTR     EQU     $E1002C                     ; firmware sound IRQ vector

; M2 streaming: two oscillators + a DOC-RAM double-buffer (mirrors ntpplay).
SAMPLE_OSC      EQU     0                           ; osc B: plays the 512 B buffer
TIMER_OSC       EQU     1                           ; osc A: silent timer, drives refills
BUF_BASE_PG     EQU     $FC                         ; double-buffer at $FC00 (512 B, 2 pages)
TIMER_WAVE_PG   EQU     $FF                         ; timer's 256 B scan wave at $FF00
STRM_SIZE_B     EQU     $09                         ; osc B size 1 (512 B) / res 1
STRM_SIZE_T     EQU     $00                         ; osc A size 0 (256 B) / res 0  (resshift locked)
STRM_A_CTL      EQU     $08                         ; free-run + interrupt enable (timer)
SAMPLE_OSC_R    EQU     1                           ; stereo: right voice (DOC channel 1)
STEREO_TIMER    EQU     2                           ; stereo: timer oscillator (osc 2)
BUF_R_PG        EQU     $FA                         ; stereo: right double-buffer at $FA00
STRM_R_CTL      EQU     $10                         ; free-run + DOC channel 1 (right)

; GLU control-register selectors (low nibble = master output volume $F):
CTL_RAM         EQU     $6F                         ; RAM access + autoinc + vol $F
CTL_REG_INC     EQU     $2F                         ; register access + autoinc + vol $F
CTL_REG         EQU     $0F                         ; register access, NO autoinc + vol $F

;------------------------------------------------------------------------------
; void eng_sound_claim(void) - claim the DOC so the kernel runs Sound_StopDoc if
; we are killed (SIGKILL can't run our teardown); audio keeps playing when bg'd.
;------------------------------------------------------------------------------
                FGX2_EXPORT eng_sound_claim
eng_sound_claim MX      %00
                JSL     SYS_TRAMP
                DFB     SYS_SOUND_CLAIM
                RTL

;------------------------------------------------------------------------------
; void eng_doc_bringup(void) - master vol on, halt all 32 oscs, zero all vols,
; drain any latched osc IRQ, enable 32 oscillators.  Verbatim from ntpplay's
; eng_doc_bringup (proven in MAME); the drain is harmless with no IRQs armed.
;------------------------------------------------------------------------------
                FGX2_EXPORT eng_doc_bringup
eng_doc_bringup MX      %00
                SEP     #$20
                MX      %10
                LDA     #$0F
                STAL    IRQ_VOLUME
                JSR     docwait
                LDA     #$20                        ; register access, auto-increment
                STAL    SOUND_CTL
                JSR     docwait
                LDA     #$A0                        ; ctl regs $A0..$BF <- $01 (halt)
                STAL    SOUND_ADRL
                JSR     docwait
                LDA     #$00
                STAL    SOUND_ADRH
                LDX     #32
                LDA     #$01
@bu_halt        JSR     docwait
                STAL    SOUND_DATA
                DEX
                BNE     @bu_halt
                JSR     docwait
                LDA     #$40                        ; vol regs $40..$5F <- $00
                STAL    SOUND_ADRL
                LDX     #32
                LDA     #$00
@bu_zvol        JSR     docwait
                STAL    SOUND_DATA
                DEX
                BNE     @bu_zvol
                JSR     docwait                     ; drain latched osc IRQ
                LDA     #$E0
                STAL    SOUND_ADRL
@bu_drain       JSR     docwait
                LDAL    SOUND_DATA
                BPL     @bu_drain
                JSR     docwait                     ; enable 32 oscs: $E1 <- $3E
                LDA     #$E1
                STAL    SOUND_ADRL
                JSR     docwait
                LDA     #$3E
                STAL    SOUND_DATA
                REP     #$30
                MX      %00
                RTL

;------------------------------------------------------------------------------
; void eng_doc_ram_addr(void) - select DOC RAM access (auto-increment), address
; = snd_page<<8.  Call once before the chunk writes for a placed sample.
;------------------------------------------------------------------------------
                FGX2_EXPORT eng_doc_ram_addr
eng_doc_ram_addr MX     %00
                SEP     #$20
                MX      %10
                JSR     docwait
                LDA     #CTL_RAM
                STAL    SOUND_CTL
                JSR     docwait
                LDA     #$00
                STAL    SOUND_ADRL                  ; address low = 0
                JSR     docwait
                LDA:    snd_page
                STAL    SOUND_ADRH                  ; address high = page
                REP     #$30
                MX      %00
                RTL

;------------------------------------------------------------------------------
; void eng_doc_write_chunk(void) - write snd_buf[0..snd_chunk-1] to DOC RAM
; (auto-increment).  Clamps interior $00 -> $01 so the sample carries no false
; one-shot end marker (libsoundGS PutDOCRAM does the same).  Assumes RAM-access
; mode is already selected (eng_doc_ram_addr).
;------------------------------------------------------------------------------
                FGX2_EXPORT eng_doc_write_chunk
eng_doc_write_chunk MX  %00
                SEP     #$20
                MX      %10
                LDX     #0
@wc             JSR     docwait
                LDA:    snd_buf,X
                BNE     @wc_nz
                LDA     #$01                        ; clamp $00 -> $01 (inaudible)
@wc_nz          STAL    SOUND_DATA
                INX
                CPX:    snd_chunk
                BCC     @wc
                REP     #$30
                MX      %00
                RTL

;------------------------------------------------------------------------------
; void eng_doc_stopper(void) - write one $00 byte to DOC RAM (the one-shot end
; marker).  Assumes RAM autoinc still selected: it lands right after the sample.
;------------------------------------------------------------------------------
                FGX2_EXPORT eng_doc_stopper
eng_doc_stopper MX      %00
                SEP     #$20
                MX      %10
                JSR     docwait
                LDA     #$00
                STAL    SOUND_DATA
                REP     #$30
                MX      %00
                RTL

;------------------------------------------------------------------------------
; void eng_osc_start(void) - program oscillator 0 for a placed one-shot sample
; and start it.  Inputs (C globals): snd_freq (16-bit), snd_page (wavetable
; start page), snd_size (size/resolution reg), snd_vol, snd_ctl (start control).
;------------------------------------------------------------------------------
                FGX2_EXPORT eng_osc_start
eng_osc_start   MX      %00
                SEP     #$20
                MX      %10
                JSR     docwait
                LDA     #CTL_REG_INC                ; register access (setreg re-addresses)
                STAL    SOUND_CTL
                LDX     #$A0                        ; halt osc 0 first (clean start)
                LDA     #$01
                JSR     setreg
                LDX     #$00                        ; freq low
                LDA:    snd_freq
                JSR     setreg
                LDX     #$20                        ; freq high
                LDA:    snd_freq+1
                JSR     setreg
                LDX     #$80                        ; wavetable pointer (start page)
                LDA:    snd_page
                JSR     setreg
                LDX     #$C0                        ; wavetable size / resolution
                LDA:    snd_size
                JSR     setreg
                LDX     #$40                        ; volume
                LDA:    snd_vol
                JSR     setreg
                LDX     #$A0                        ; control: start (one-shot, playing)
                LDA:    snd_ctl
                JSR     setreg
                REP     #$30
                MX      %00
                RTL

;------------------------------------------------------------------------------
; void eng_osc_start_r(void) - like eng_osc_start but oscillator 1 (the right
; channel of a placed stereo pair).  Same input globals; snd_ctl carries the
; DOC channel-1 bits, snd_page the right sample's wavetable page.
;------------------------------------------------------------------------------
                FGX2_EXPORT eng_osc_start_r
eng_osc_start_r MX      %00
                SEP     #$20
                MX      %10
                JSR     docwait
                LDA     #CTL_REG_INC
                STAL    SOUND_CTL
                LDX     #$A1                        ; halt osc 1 first
                LDA     #$01
                JSR     setreg
                LDX     #$01                        ; freq low
                LDA:    snd_freq
                JSR     setreg
                LDX     #$21                        ; freq high
                LDA:    snd_freq+1
                JSR     setreg
                LDX     #$81                        ; wavetable pointer
                LDA:    snd_page
                JSR     setreg
                LDX     #$C1                        ; size / resolution
                LDA:    snd_size
                JSR     setreg
                LDX     #$41                        ; volume
                LDA:    snd_vol
                JSR     setreg
                LDX     #$A1                        ; control: start
                LDA:    snd_ctl
                JSR     setreg
                REP     #$30
                MX      %00
                RTL

;------------------------------------------------------------------------------
; int eng_osc_halted(void) - return 1 if oscillator 0's control register halt
; bit (bit 0) is set, else 0.  Register read uses NO autoinc so the ES5503
; double-read (first is stale) re-reads the SAME register, not the next one.
;------------------------------------------------------------------------------
                FGX2_EXPORT eng_osc_halted
eng_osc_halted  MX      %00
                SEP     #$20
                MX      %10
                JSR     docwait
                LDA     #CTL_REG                    ; register access, NO autoinc
                STAL    SOUND_CTL
                JSR     docwait
                LDA     #$A0                        ; osc 0 control register
                STAL    SOUND_ADRL
                JSR     docwait
                LDAL    SOUND_DATA                  ; first read is stale
                JSR     docwait
                LDAL    SOUND_DATA                  ; second read = control value
                AND     #$01                        ; halt bit
                REP     #$30
                MX      %00
                AND     #$00FF                      ; clean 16-bit 0 / 1 for C
                RTL

;------------------------------------------------------------------------------
; int eng_osc_halted_r(void) - 1 if oscillator 1 (right) has halted.
;------------------------------------------------------------------------------
                FGX2_EXPORT eng_osc_halted_r
eng_osc_halted_r MX     %00
                SEP     #$20
                MX      %10
                JSR     docwait
                LDA     #CTL_REG
                STAL    SOUND_CTL
                JSR     docwait
                LDA     #$A1                        ; osc 1 control register
                STAL    SOUND_ADRL
                JSR     docwait
                LDAL    SOUND_DATA                  ; first read is stale
                JSR     docwait
                LDAL    SOUND_DATA                  ; second read = control value
                AND     #$01
                REP     #$30
                MX      %00
                AND     #$00FF
                RTL

;------------------------------------------------------------------------------
; void eng_doc_halt(void) - halt all 32 oscs + zero all vols (foreground
; teardown).  Same as the bring-up's halt/zero prologue.
;------------------------------------------------------------------------------
                FGX2_EXPORT eng_doc_halt
eng_doc_halt    MX      %00
                SEP     #$20
                MX      %10
                JSR     docwait
                LDA     #$20                        ; register access, auto-increment
                STAL    SOUND_CTL
                JSR     docwait
                LDA     #$A0                        ; ctl regs $A0..$BF <- $01 (halt)
                STAL    SOUND_ADRL
                JSR     docwait
                LDA     #$00
                STAL    SOUND_ADRH
                LDX     #32
                LDA     #$01
@dh_halt        JSR     docwait
                STAL    SOUND_DATA
                DEX
                BNE     @dh_halt
                JSR     docwait
                LDA     #$40                        ; vol regs $40..$5F <- $00
                STAL    SOUND_ADRL
                LDX     #32
                LDA     #$00
@dh_zvol        JSR     docwait
                STAL    SOUND_DATA
                DEX
                BNE     @dh_zvol
                REP     #$30
                MX      %00
                RTL

;------------------------------------------------------------------------------
; int eng_ticks(void) - low 16 bits of the 60 Hz _kSystemTicks counter.
; SYS_TICKS copies the 4-byte counter into the caller buffer at A's offset.
;------------------------------------------------------------------------------
                FGX2_EXPORT eng_ticks
eng_ticks       MX      %00
                LDA     #snd_tbuf                   ; seg1 offset of the 4-byte buffer
                JSL     SYS_TRAMP
                DFB     SYS_TICKS
                LDA:    snd_tbuf                    ; low 16 bits
                RTL

;------------------------------------------------------------------------------
; void eng_sleep1(void) - block for one 60 Hz tick (SYS_NANOSLEEP, A = ticks).
;------------------------------------------------------------------------------
                FGX2_EXPORT eng_sleep1
eng_sleep1      MX      %00
                LDA     #1
                JSL     SYS_TRAMP
                DFB     SYS_NANOSLEEP
                RTL

;==============================================================================
; M2 STREAMING ENGINE.  A PCM larger than the 32 KB wavetable is held resident
; in an mm_alloc'd pool (loaded by C via a far-pointer store) and streamed to a
; 512 B DOC-RAM double-buffer under the sound IRQ.  Oscillator B (SAMPLE_OSC)
; free-runs the 512 B buffer; oscillator A (TIMER_OSC) free-runs a 256 B wave at
; the SAME resshift, so it wraps -- and raises a sound IRQ -- once per 256
; sample bytes B plays, i.e. each time B finishes a half.  interrupt_stream
; refills the just-finished half from the pool.  At pool end it plays out the
; buffered tail (drain), halts both oscs, and sets snd_done for the C loop.
; The IRQ path adapts ntpplay_stubs.s: eng_dbank / irq_handler / ih_dispatch /
; strm_copy are its idioms; the linear one-shot + drain logic is ensoniq's.
;
; ABI to C (all seg1 globals): snd_pool_base/ptr/end (24-bit, unsigned long),
; snd_freq, snd_vol, snd_base_pg, snd_pg_off, snd_dst_pg, snd_cnt, snd_drain,
; snd_done, old_vec[2].
;==============================================================================

; eng_dbank - the one datum this engine owns in seg0 (code): the saved data
; bank, read by irq_handler before DBR is set (a seg1 global can't be reached
; first).  Not in the execution path (preceded by RTL).
eng_dbank       DFB     $00

;------------------------------------------------------------------------------
; void eng_stream_prime(void) - upload the timer wave, prime the 512 B buffer
; from the pool, program osc B (sample) + osc A (timer), install the $E1002C
; sound-IRQ vector, claim the DOC, and arm the timer (IE) LAST.  Inputs: the
; pool globals set by C, snd_freq, snd_vol.  DBR = seg1 in.
;------------------------------------------------------------------------------
                FGX2_EXPORT eng_stream_prime
eng_stream_prime MX     %00
                ; --- save DBR -> eng_dbank so irq_handler can restore it ---
                SEP     #$20
                MX      %10
                PHB
                PLA                                  ; A.lo = data bank
                PHK
                PLB                                  ; DBR = code (reach eng_dbank)
                STA:    eng_dbank
                PHA
                PLB                                  ; DBR = data (restored)
                REP     #$30
                MX      %00
                LDA     #TIMER_OSC                   ; mono: timer is oscillator 1
                STA:    snd_timer_osc
                ; --- save the old firmware sound vector ---
                LDAL    SND_INT_PTR
                STA:    old_vec
                LDAL    SND_INT_PTR+2
                STA:    old_vec+2
                ; --- upload a 256 B (non-$00) scan wave to the timer page ---
                SEP     #$20
                MX      %10
                JSR     docwait
                LDA     #$6F                         ; RAM access + autoinc + vol $F
                STAL    SOUND_CTL
                JSR     docwait
                LDA     #$00
                STAL    SOUND_ADRL
                JSR     docwait
                LDA     #TIMER_WAVE_PG
                STAL    SOUND_ADRH
                LDX     #256
                LDA     #$FF                         ; timer is silent; content only must be non-$00
@ep_tw          STAL    SOUND_DATA
                DEX
                BNE     @ep_tw
                REP     #$30
                MX      %00
                ; --- prime the double-buffer: 512 B pool -> BUF_BASE_PG ---
                LDA     #BUF_BASE_PG
                STA:    snd_dst_pg
                LDA     #512
                STA:    snd_cnt
                SEP     #$20
                MX      %10
                JSR     strm_copy                   ; fills $FC00..$FDFF, advances snd_pool_ptr
                ; --- program osc B (sample): freq, vol, waveptr, size, then run ---
                JSR     docwait
                LDA     #$2F                         ; register access + autoinc + vol $F
                STAL    SOUND_CTL
                LDX     #$A0+SAMPLE_OSC              ; halt B first (clean start)
                LDA     #$01
                JSR     setreg
                LDX     #$00+SAMPLE_OSC             ; freq lo
                LDA:    snd_freq
                JSR     setreg
                LDX     #$20+SAMPLE_OSC             ; freq hi
                LDA:    snd_freq+1
                JSR     setreg
                LDX     #$80+SAMPLE_OSC             ; wavetable ptr = buffer base
                LDA     #BUF_BASE_PG
                JSR     setreg
                LDX     #$C0+SAMPLE_OSC             ; size 1 (512 B) / res 1
                LDA     #STRM_SIZE_B
                JSR     setreg
                LDX     #$40+SAMPLE_OSC             ; volume
                LDA:    snd_vol
                JSR     setreg
                ; --- program osc A (timer): freq (same), vol 0, timer wave, size 0 ---
                LDX     #$A0+TIMER_OSC              ; halt A first
                LDA     #$01
                JSR     setreg
                LDX     #$00+TIMER_OSC
                LDA:    snd_freq
                JSR     setreg
                LDX     #$20+TIMER_OSC
                LDA:    snd_freq+1
                JSR     setreg
                LDX     #$40+TIMER_OSC             ; volume 0 (inaudible)
                LDA     #$00
                JSR     setreg
                LDX     #$80+TIMER_OSC            ; wavetable ptr = timer page
                LDA     #TIMER_WAVE_PG
                JSR     setreg
                LDX     #$C0+TIMER_OSC            ; size 0 (256 B) / res 0
                LDA     #STRM_SIZE_T
                JSR     setreg
                ; --- start osc B (free-run, channel 0), then install the vector ---
                LDX     #$A0+SAMPLE_OSC
                LDA     #$00
                JSR     setreg
                LDA     #$5C                        ; $E1002C <- JML irq_handler
                STAL    SND_INT_PTR
                REP     #$20                        ; the address as ONE word, so
                MX      %00                         ;   an offset relocation can
                LDA     #irq_handler                ;   move it with the code
                STAL    SND_INT_PTR+1
                SEP     #$20
                MX      %10
                PHK                                 ; real run bank (not ^irq_handler)
                PLA
                STAL    SND_INT_PTR+3
                ; --- ARM the timer LAST: free-run + IE ---
                JSR     docwait
                LDA     #$2F
                STAL    SOUND_CTL
                LDX     #$A0+TIMER_OSC
                LDA     #STRM_A_CTL
                JSR     setreg
                REP     #$30
                MX      %00
                ; --- claim the DOC (kernel silences it on kill) ---
                JSL     SYS_TRAMP
                DFB     SYS_SOUND_CLAIM
                RTL

;------------------------------------------------------------------------------
; void eng_stream_prime_stereo(void) - two sample voices + one timer.  osc 0 =
; left (DOC channel 0, buffer $FC00), osc 1 = right (channel 1, buffer $FA00),
; osc 2 = silent timer (IE).  Primes both 512 B buffers from snd_pool_ptr (left)
; and snd_pool_ptr_r (right).  Refill of both is driven from interrupt_stream.
;------------------------------------------------------------------------------
                FGX2_EXPORT eng_stream_prime_stereo
eng_stream_prime_stereo MX %00
                SEP     #$20
                MX      %10
                PHB
                PLA
                PHK
                PLB
                STA:    eng_dbank
                PHA
                PLB
                REP     #$30
                MX      %00
                LDA     #STEREO_TIMER               ; timer is oscillator 2
                STA:    snd_timer_osc
                LDA     #1
                STA:    snd_stereo
                LDAL    SND_INT_PTR
                STA:    old_vec
                LDAL    SND_INT_PTR+2
                STA:    old_vec+2
                ; --- upload the 256 B timer scan wave to $FF ---
                SEP     #$20
                MX      %10
                JSR     docwait
                LDA     #$6F
                STAL    SOUND_CTL
                JSR     docwait
                LDA     #$00
                STAL    SOUND_ADRL
                JSR     docwait
                LDA     #TIMER_WAVE_PG
                STAL    SOUND_ADRH
                LDX     #256
                LDA     #$FF
@eps_tw         STAL    SOUND_DATA
                DEX
                BNE     @eps_tw
                REP     #$30
                MX      %00
                ; --- prime left buffer (512 B -> $FC00) ---
                LDA     #BUF_BASE_PG
                STA:    snd_dst_pg
                LDA     #512
                STA:    snd_cnt
                SEP     #$20
                MX      %10
                JSR     strm_copy
                ; --- prime right buffer (512 B -> $FA00) ---
                REP     #$30
                MX      %00
                LDA     #BUF_R_PG
                STA:    snd_dst_pg_r
                LDA     #512
                STA:    snd_cnt
                SEP     #$20
                MX      %10
                JSR     strm_copy_r
                ; --- program osc 0 (left, channel 0) ---
                JSR     docwait
                LDA     #$2F
                STAL    SOUND_CTL
                LDX     #$A0
                LDA     #$01
                JSR     setreg
                LDX     #$00
                LDA:    snd_freq
                JSR     setreg
                LDX     #$20
                LDA:    snd_freq+1
                JSR     setreg
                LDX     #$80
                LDA     #BUF_BASE_PG
                JSR     setreg
                LDX     #$C0
                LDA     #STRM_SIZE_B
                JSR     setreg
                LDX     #$40
                LDA:    snd_vol
                JSR     setreg
                ; --- program osc 1 (right, channel 1) ---
                LDX     #$A1
                LDA     #$01
                JSR     setreg
                LDX     #$01
                LDA:    snd_freq
                JSR     setreg
                LDX     #$21
                LDA:    snd_freq+1
                JSR     setreg
                LDX     #$81
                LDA     #BUF_R_PG
                JSR     setreg
                LDX     #$C1
                LDA     #STRM_SIZE_B
                JSR     setreg
                LDX     #$41
                LDA:    snd_vol
                JSR     setreg
                ; --- program osc 2 (timer, silent) ---
                LDX     #$A2
                LDA     #$01
                JSR     setreg
                LDX     #$02
                LDA:    snd_freq
                JSR     setreg
                LDX     #$22
                LDA:    snd_freq+1
                JSR     setreg
                LDX     #$42
                LDA     #$00
                JSR     setreg
                LDX     #$82
                LDA     #TIMER_WAVE_PG
                JSR     setreg
                LDX     #$C2
                LDA     #STRM_SIZE_T
                JSR     setreg
                ; --- start osc 0 (free-run, ch0) and osc 1 (free-run, ch1) ---
                LDX     #$A0
                LDA     #$00
                JSR     setreg
                LDX     #$A1
                LDA     #STRM_R_CTL
                JSR     setreg
                ; --- install the $E1002C vector ---
                LDA     #$5C
                STAL    SND_INT_PTR
                REP     #$20                        ; the address as ONE word, so
                MX      %00                         ;   an offset relocation can
                LDA     #irq_handler                ;   move it with the code
                STAL    SND_INT_PTR+1
                SEP     #$20
                MX      %10
                PHK
                PLA
                STAL    SND_INT_PTR+3
                ; --- ARM the timer (osc 2) LAST: free-run + IE ---
                JSR     docwait
                LDA     #$2F
                STAL    SOUND_CTL
                LDX     #$A2
                LDA     #STRM_A_CTL
                JSR     setreg
                REP     #$30
                MX      %00
                JSL     SYS_TRAMP
                DFB     SYS_SOUND_CLAIM
                RTL

;------------------------------------------------------------------------------
; void eng_stream_stop(void) - teardown: SEI, halt all 32 oscs, drain $E0, then
; restore the firmware vector, CLI.  (Adapts ntpplay irq_uninstall.)  DBR=seg1.
;------------------------------------------------------------------------------
                FGX2_EXPORT eng_stream_stop
eng_stream_stop MX      %00
                SEI
                SEP     #$20
                MX      %10
                JSR     docwait                      ; halt all: ctl $A0..$BF <- $01
                LDA     #$20                         ; register access, auto-increment
                STAL    SOUND_CTL
                JSR     docwait
                LDA     #$A0
                STAL    SOUND_ADRL
                JSR     docwait
                LDA     #$00
                STAL    SOUND_ADRH
                LDX     #32
                LDA     #$01
@es_halt        JSR     docwait
                STAL    SOUND_DATA
                DEX
                BNE     @es_halt
                JSR     docwait                      ; drain $E0: ack any latched osc IRQ
                LDA     #$00                         ; register access, no auto-increment
                STAL    SOUND_CTL
                LDY     #40                          ; safety cap (>= 32 oscs)
@es_drain       JSR     docwait
                LDA     #$E0
                STAL    SOUND_ADRL
                JSR     docwait
                LDAL    SOUND_DATA                   ; dummy read (GLU one-behind pipeline)
                JSR     docwait
                LDA     #$00                         ; commit the $E0 read
                STAL    SOUND_ADRL
                JSR     docwait
                LDAL    SOUND_DATA                   ; A = $E0 (reading acks the osc)
                BMI     @es_draindone                ; bit7=1 -> none pending
                DEY
                BNE     @es_drain
@es_draindone   REP     #$30
                MX      %00
                LDA:    old_vec                      ; restore vector (safe: oscs halted)
                STAL    SND_INT_PTR
                LDA:    old_vec+2
                STAL    SND_INT_PTR+2
                CLI
                RTL

;------------------------------------------------------------------------------
; irq_handler - the $E1002C sound-IRQ handler (JML'd from the firmware via the
; SIM non-SCC chain).  Restores DBR=seg1 from eng_dbank, dispatches the osc the
; ROM handed us at IRQ_SOUNDDATA, then drains $E0 for any others.  (ntpplay.)
;------------------------------------------------------------------------------
irq_handler     MX      %11
                PHB
                PHD
                PHK
                PLB                                  ; DBR = code bank (reach eng_dbank)
                CLC
                XCE                                  ; force native
                SEP     #$30
                MX      %11
                LDA:    eng_dbank                    ; saved data bank (DBR=code now)
                PHA
                PLB                                  ; DBR = data bank (seg1 reachable)
                LDAL    IRQ_SOUNDDATA
                JSR     ih_dispatch
@ih_next        MX      %11
@ih_w0          LDAL    SOUND_CTL
                BMI     @ih_w0
                LDA     #$00                         ; register mode, no auto-inc
                STAL    SOUND_CTL
@ih_w1          LDAL    SOUND_CTL
                BMI     @ih_w1
                LDA     #$E0
                STAL    SOUND_ADRL
@ih_w2          LDAL    SOUND_CTL
                BMI     @ih_w2
                LDAL    SOUND_DATA                   ; dummy (pipeline delay)
@ih_w3          LDAL    SOUND_CTL
                BMI     @ih_w3
                LDA     #$00                         ; re-set addr (commit the read)
                STAL    SOUND_ADRL
@ih_w4          LDAL    SOUND_CTL
                BMI     @ih_w4
                LDAL    SOUND_DATA                   ; A = $E0 (reading acks the osc)
                BMI     @ih_done                     ; bit7=1 -> none left
                JSR     ih_dispatch
                BRA     @ih_next
@ih_done        MX      %11
                PLD
                PLB
                CLC
                RTL

;------------------------------------------------------------------------------
; ih_dispatch - A = an osc-interrupt value; if it is TIMER_OSC, refill.  Other
; oscs (none IE-armed here) are already acked -> ignore.  Caller MX %11.
;------------------------------------------------------------------------------
ih_dispatch     MX      %11
                AND     #$3E                         ; bits 5..1 = osc number
                LSR
                CMP:    snd_timer_osc
                BNE     @id_done
                REP     #$30
                MX      %00
                JSR     interrupt_stream
                SEP     #$30
                MX      %11
@id_done        RTS

;------------------------------------------------------------------------------
; interrupt_stream - refill the half osc B just finished (snd_base_pg +
; snd_pg_off), advancing the pool pointer.  At pool end, play out the buffered
; tail as silence for two halves (drain), then halt both oscs and set snd_done.
; Caller MX %00.
;------------------------------------------------------------------------------
interrupt_stream MX     %00
                CLC
                LDA     #BUF_BASE_PG
                ADC:    snd_pg_off
                STA:    snd_dst_pg                   ; refill target page
                LDA:    snd_drain
                BNE     @is_drain
                LDA:    snd_ring
                BEQ     @is_linear
                JSR     ring_refill                 ; stdin ring: refill / underrun / end
                BRA     @is_toggle
@is_linear      ; --- linear pool (M2): copy 256 B of real data ---
                LDA     #256
                STA:    snd_cnt
                SEP     #$20
                MX      %10
                JSR     strm_copy                   ; L half -> snd_dst_pg, advances snd_pool_ptr
                REP     #$30
                MX      %00
                LDA:    snd_stereo                   ; stereo: refill the right half too
                BEQ     @is_endchk
                JSR     stereo_refill_r
@is_endchk      ; reached the pool end? (24-bit unsigned compare, left channel)
                LDA:    snd_pool_ptr+2
                CMP:    snd_pool_end+2
                BCC     @is_toggle
                BNE     @is_setdrain
                LDA:    snd_pool_ptr
                CMP:    snd_pool_end
                BCC     @is_toggle
@is_setdrain    LDA     #2                           ; two more halves buffered -> drain
                STA:    snd_drain
                BRA     @is_toggle
@is_drain       ; --- draining: fill this half with silence, count down ---
                LDA     #256
                STA:    snd_cnt
                SEP     #$20
                MX      %10
                JSR     strm_fill_silence            ; L half silence (snd_dst_pg)
                REP     #$30
                MX      %00
                LDA:    snd_stereo                   ; stereo: R half silence too
                BEQ     @is_drdec
                JSR     stereo_silence_r
@is_drdec       LDA:    snd_drain
                DEC
                STA:    snd_drain
                BNE     @is_toggle
                ; drain complete: halt both oscs, tell the C loop
                SEP     #$20
                MX      %10
                JSR     stream_halt_oscs
                REP     #$30
                MX      %00
                LDA     #1
                STA:    snd_done
                RTS
@is_toggle      LDA:    snd_pg_off                   ; other half next time
                EOR     #1
                STA:    snd_pg_off
                RTS

;------------------------------------------------------------------------------
; ring_refill - stdin ring consumer (M4).  Copy one 256 B ring page (page
; ring_rd_pg at snd_ring_base) into the DOC half snd_dst_pg and advance rd; if
; the ring is empty, either play silence (producer behind -> underrun) or, once
; the foreground has flagged EOF, silence + arm the drain.  Sets snd_drain for
; interrupt_stream's @is_drain path to halt.  Caller MX %00; does not toggle.
;------------------------------------------------------------------------------
ring_refill     MX      %00
                LDA:    ring_rd_pg
                CMP:    ring_wr_pg
                BNE     @rr_data                     ; ring not empty
                LDA:    snd_input_done
                BNE     @rr_end
                ; --- underrun: play silence, keep rd (producer may catch up) ---
                LDA     #256
                STA:    snd_cnt
                SEP     #$20
                MX      %10
                JSR     strm_fill_silence
                REP     #$30
                MX      %00
                LDA:    snd_underruns
                INC
                STA:    snd_underruns
                RTS
@rr_end         ; --- EOF + empty: silence this half and arm the drain ---
                LDA     #256
                STA:    snd_cnt
                SEP     #$20
                MX      %10
                JSR     strm_fill_silence
                REP     #$30
                MX      %00
                LDA     #2
                STA:    snd_drain
                RTS
@rr_data        ; --- snd_pool_ptr = snd_ring_base + (ring_rd_pg << 8), copy, rd++ ---
                LDA:    ring_rd_pg
                AND     #$00FF
                XBA                                  ; << 8
                CLC
                ADC:    snd_ring_base
                STA:    snd_pool_ptr
                LDA:    snd_ring_base+2
                ADC     #0
                STA:    snd_pool_ptr+2
                LDA     #256
                STA:    snd_cnt
                SEP     #$20
                MX      %10
                JSR     strm_copy                   ; ring page -> DOC half
                REP     #$30
                MX      %00
                LDA:    ring_rd_pg                   ; rd = (rd + 1) & $FF
                INC
                AND     #$00FF
                STA:    ring_rd_pg
                RTS

;------------------------------------------------------------------------------
; stream_halt_oscs - halt osc A + osc B (ctl bit0).  Caller MX %10.
;------------------------------------------------------------------------------
stream_halt_oscs MX     %10
                JSR     docwait
                LDA     #$2F                         ; register access + vol $F
                STAL    SOUND_CTL
                LDX     #$A0                         ; halt oscs 0,1,2 (L, R, timer)
                LDA     #$01
                JSR     setreg
                LDX     #$A1
                LDA     #$01
                JSR     setreg
                LDX     #$A2
                LDA     #$01
                JSR     setreg
                RTS

;------------------------------------------------------------------------------
; stereo_refill_r - refill the right half (BUF_R_PG + snd_pg_off) from
; snd_pool_ptr_r.  Caller MX %00.
;------------------------------------------------------------------------------
stereo_refill_r MX      %00
                CLC
                LDA     #BUF_R_PG
                ADC:    snd_pg_off
                STA:    snd_dst_pg_r
                LDA     #256
                STA:    snd_cnt
                SEP     #$20
                MX      %10
                JSR     strm_copy_r
                REP     #$30
                MX      %00
                RTS

;------------------------------------------------------------------------------
; stereo_silence_r - fill the right half with silence.  Caller MX %00.
;------------------------------------------------------------------------------
stereo_silence_r MX     %00
                CLC
                LDA     #BUF_R_PG
                ADC:    snd_pg_off
                STA:    snd_dst_pg
                LDA     #256
                STA:    snd_cnt
                SEP     #$20
                MX      %10
                JSR     strm_fill_silence
                REP     #$30
                MX      %00
                RTS

;------------------------------------------------------------------------------
; strm_copy - copy snd_cnt bytes from the pool (snd_pool_ptr, 24-bit, may span
; banks) to DOC RAM from page snd_dst_pg, then advance snd_pool_ptr.  The source
; operand is self-patched (SMC): read the seg1 pointer, flip DBR->seg0 to patch
; the LDAL operand, flip back.  Caller MX %10.  (Adapts ntpplay strm_copy.)
;------------------------------------------------------------------------------
strm_copy       MX      %10
                JSR     docwait
                LDA     #$6F                         ; RAM access + autoinc
                STAL    SOUND_CTL
                JSR     docwait
                LDA     #$00
                STAL    SOUND_ADRL
                JSR     docwait
                LDA:    snd_dst_pg                   ; high byte of DOC address = page
                STAL    SOUND_ADRH
                REP     #$20                         ; patch source operand from snd_pool_ptr
                MX      %00
                LDA:    snd_pool_ptr
                LDX:    snd_pool_ptr+2
                PHB
                PHK
                PLB                                  ; DBR = seg0 (operand lives in code)
                STA:    @sc_src+1
                SEP     #$20
                MX      %10
                TXA
                STA:    @sc_src+3
                PLB                                  ; DBR = seg1
                LDX     #0
@sc_loop        MX      %10
@sc_src         LDAL    $000000,X                    ; [snd_pool_ptr + X], self-patched (24-bit)
                STAL    SOUND_DATA                   ; DOC RAM write (autoincrements)
                INX
                CPX:    snd_cnt
                BCC     @sc_loop
                REP     #$30                         ; snd_pool_ptr += snd_cnt
                MX      %00
                CLC
                LDA:    snd_pool_ptr
                ADC:    snd_cnt
                STA:    snd_pool_ptr
                LDA:    snd_pool_ptr+2
                ADC     #0
                STA:    snd_pool_ptr+2
                SEP     #$20
                MX      %10
                RTS

;------------------------------------------------------------------------------
; strm_copy_r - like strm_copy but the RIGHT channel: source snd_pool_ptr_r,
; dest page snd_dst_pg_r.  Caller MX %10.
;------------------------------------------------------------------------------
strm_copy_r     MX      %10
                JSR     docwait
                LDA     #$6F
                STAL    SOUND_CTL
                JSR     docwait
                LDA     #$00
                STAL    SOUND_ADRL
                JSR     docwait
                LDA:    snd_dst_pg_r
                STAL    SOUND_ADRH
                REP     #$20
                MX      %00
                LDA:    snd_pool_ptr_r
                LDX:    snd_pool_ptr_r+2
                PHB
                PHK
                PLB
                STA:    @scr_src+1
                SEP     #$20
                MX      %10
                TXA
                STA:    @scr_src+3
                PLB
                LDX     #0
@scr_loop       MX      %10
@scr_src        LDAL    $000000,X
                STAL    SOUND_DATA
                INX
                CPX:    snd_cnt
                BCC     @scr_loop
                REP     #$30
                MX      %00
                CLC
                LDA:    snd_pool_ptr_r
                ADC:    snd_cnt
                STA:    snd_pool_ptr_r
                LDA:    snd_pool_ptr_r+2
                ADC     #0
                STA:    snd_pool_ptr_r+2
                SEP     #$20
                MX      %10
                RTS

;------------------------------------------------------------------------------
; strm_fill_silence - write snd_cnt bytes of $80 (silence) to DOC RAM from page
; snd_dst_pg.  Caller MX %10.
;------------------------------------------------------------------------------
strm_fill_silence MX    %10
                JSR     docwait
                LDA     #$6F                         ; RAM access + autoinc
                STAL    SOUND_CTL
                JSR     docwait
                LDA     #$00
                STAL    SOUND_ADRL
                JSR     docwait
                LDA:    snd_dst_pg
                STAL    SOUND_ADRH
                LDX     #0
                LDA     #$80
@sf_loop        STAL    SOUND_DATA
                INX
                CPX:    snd_cnt
                BCC     @sf_loop
                RTS

;------------------------------------------------------------------------------
; void eng_ring_write(void) - copy snd_buf[0..255] into ring page ring_wr_pg (at
; snd_ring_base + ring_wr_pg<<8) via a self-patched 24-bit store (crosses banks).
; The foreground producer helper (DBR = seg1 in); far faster than a C per-byte
; far store, which the stdin producer cannot afford at the play rate.
;------------------------------------------------------------------------------
                FGX2_EXPORT eng_ring_write
eng_ring_write  MX      %00
                ; compute the 24-bit dest = snd_ring_base + ring_wr_pg<<8 into
                ; registers WHILE DBR = seg1 (snd_ring_base is a seg1 global);
                ; only then flip DBR to seg0 to patch the store operand.
                LDA:    ring_wr_pg
                AND     #$00FF
                XBA                                  ; << 8
                CLC
                ADC:    snd_ring_base                ; A = dest lo/mid (carry on overflow)
                TAY                                  ; Y = dest lo/mid
                LDA:    snd_ring_base+2
                ADC     #0                           ; + carry -> bank word
                TAX                                  ; X.lo = dest bank
                PHB
                PHK
                PLB                                  ; DBR = seg0 (patch operand)
                TYA
                STA:    @rw_dst+1                    ; lo/mid
                SEP     #$20
                MX      %10
                TXA
                STA:    @rw_dst+3                    ; bank
                PLB                                  ; DBR = seg1
                LDX     #0
@rw_loop        MX      %10
                LDA:    snd_buf,X
@rw_dst         STAL    $000000,X                    ; [dest + X], self-patched (24-bit)
                INX
                CPX     #256
                BCC     @rw_loop
                REP     #$30
                MX      %00
                RTL

;------------------------------------------------------------------------------
; docwait - busy-wait until the GLU is not busy (bit7 of $C03C clear). Preserves
; A. Caller MX %10. (From ntpplay_stubs.s / doctone.s.)
;------------------------------------------------------------------------------
docwait         MX      %10
                PHA
@dw             LDAL    SOUND_CTL
                BMI     @dw
                PLA
                RTS

;------------------------------------------------------------------------------
; setreg - write DOC register: X.lo = reg#, A.lo = value. Caller MX %10,
; register-access mode already selected. (From ntpplay_stubs.s / doctone.s.)
;------------------------------------------------------------------------------
setreg          MX      %10
                PHA
                JSR     docwait
                TXA
                STAL    SOUND_ADRL
                PLA
                PHA
                JSR     docwait
                PLA
                STAL    SOUND_DATA
                RTS
