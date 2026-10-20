;==============================================================================
; ntpplay_stubs.s - companion asm for ntpplay (H3 final).  PUT into seg0 by the
; FGX2 build (after ntpplay.s + seg1_layout.s), so C's seg1 globals resolve by
; bare name and are reached DBR-relative.  Every entry here is called via
; FGX2_FARCALL (JSL) from C with DBR = data bank, so `LDA: <cglobal>` is a
; DBR-relative read into seg1; returns in A; ends RTL.  The tracker engine +
; sound-IRQ handler land here in increment 3 (see the C-framework plan doc).
;
; INCREMENTS SO FAR: 1 = eng_ping (seg1 bridge proof); 1.5 = mini-irqtick (the
; async-IRQ / DBR two-step mechanism, proven before the big engine port).
;==============================================================================

; DOC / sound GLU + syscalls not already EQU'd by seg0.link.s (SYS_TRAMP is).
SYS_MM_ALLOC    EQU     68
SYS_MM_FREE     EQU     69
SYS_SOUND_CLAIM EQU     86
SOUND_CTL       EQU     $E1C03C
SOUND_DATA      EQU     $E1C03D
SOUND_ADRL      EQU     $E1C03E
SOUND_ADRH      EQU     $E1C03F
IRQ_VOLUME      EQU     $E100CA
IRQ_SOUNDDATA   EQU     $E100CC                     ; OIR value the ROM saved for sound handlers
SND_INT_PTR     EQU     $E1002C                     ; firmware sound IRQ vector
TIMER_OSC       EQU     31                          ; osc dedicated to the ~50 Hz tick
REF_FREQ        EQU     249
TIMER_PAGE      EQU     $FF
; syscalls the engine control path uses
SYS_TICKS       EQU     52
SYS_POLLKEY     EQU     66
; (SYS_YIELD EQU comes from fcc_runtime.s since the loop-safepoints
;  toolchain — a local copy is a merlin duplicate-equivalence error.)
; engine geometry / job / streaming constants (mirror ntpplay.s)
MAX_INS         EQU     32
MAX_TRACKS      EQU     16
NUM_OSC         EQU     32
SPEED           EQU     6
MAX_FT_PTR      EQU     3574                        ; max valid freq_finetune byte offset
LOOP_SONG       EQU     0
JOB_NONE        EQU     0
JOB_TICK        EQU     2
JOB_STREAM      EQU     6
STREAM_BUF_TOP  EQU     $FC
STRM_A_CTL      EQU     $08
STRM_A_SIZE     EQU     $00
STRM_B_SIZE     EQU     $09

;==============================================================================
; increment 2 - load-path hardware helpers, C-called (DBR = data bank = seg1).
; The DOC / Memory-Manager bit-banging that the C load path (ntpplay.c) drives.
; Each helper reads/writes the seg1 C globals by bare name and returns RTL.
;
; SMC bracket: helpers that self-patch an absolute-long operand (handle deref,
; the cross-bank copies) run with DBR = seg1, but the operand they patch lives
; in seg0 code.  So they first read the seg1 pointer into registers, flip
; DBR -> seg0 to patch the code operand, then flip DBR back to seg1 before the
; patched instruction runs (the FGX1 originals could `STA: @site+1` directly
; only because DBR = code = data in the single-bank model).
;==============================================================================

;------------------------------------------------------------------------------
; docwait / setreg are defined by the engine (below); the load helpers reuse them.
;------------------------------------------------------------------------------
;------------------------------------------------------------------------------
; void eng_doc_bringup(void) - master vol on, halt all 32 oscs, zero all vols,
; drain latched osc IRQ, enable 31 oscillators.  (asm main @doDocUp.)
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
                JSR     docwait                  ; drain latched osc IRQ
                LDA     #$E0
                STAL    SOUND_ADRL
@bu_drain       JSR     docwait
                LDAL    SOUND_DATA
                BPL     @bu_drain
                JSR     docwait                  ; enable 31 oscs: $E1 <- $3E
                LDA     #$E1
                STAL    SOUND_ADRL
                JSR     docwait
                LDA     #$3E
                STAL    SOUND_DATA
                REP     #$30
                MX      %00
                RTL

;------------------------------------------------------------------------------
; void eng_doc_addr(void) - select DOC RAM access (auto-increment), address =
; up_write<<8 (the instrument's DOC page).  Called once per placed instrument
; before its chunk writes.  (asm main @up_setDoc select portion.)
;------------------------------------------------------------------------------
                FGX2_EXPORT eng_doc_addr
eng_doc_addr    MX      %00
                SEP     #$20
                MX      %10
                JSR     docwait
                LDA     #$6F                        ; RAM access, auto-increment
                STAL    SOUND_CTL
                JSR     docwait
                LDA     #$00
                STAL    SOUND_ADRL
                JSR     docwait
                LDA:    up_write                    ; page (low byte)
                STAL    SOUND_ADRH
                REP     #$30
                MX      %00
                RTL

;------------------------------------------------------------------------------
; void eng_doc_write_chunk(void) - write upbuf[0..chunk-1] verbatim to DOC RAM
; (auto-increment); keeps $00 stoppers.  (asm main @up_wb.)
;------------------------------------------------------------------------------
                FGX2_EXPORT eng_doc_write_chunk
eng_doc_write_chunk MX  %00
                SEP     #$20
                MX      %10
                LDX     #0
@dwc            JSR     docwait
                LDA:    upbuf,X
                STAL    SOUND_DATA
                INX
                CPX:    chunk
                BCC     @dwc
                REP     #$30
                MX      %00
                RTL

;------------------------------------------------------------------------------
; int eng_res_alloc(void) - SYS_MM_ALLOC(mm_size); on success store the handle
; and deref it to res_base (24-bit block base), return 1.  On failure return 0.
;------------------------------------------------------------------------------
                FGX2_EXPORT eng_res_alloc
eng_res_alloc   MX      %00
                LDA:    mm_size
                LDX:    mm_size+2
                JSL     SYS_TRAMP
                DFB     SYS_MM_ALLOC
                BCS     @ra_ok
                LDA     #0
                RTL
@ra_ok          STY:    mm_handle                   ; handle: Y=offset, A.lo=bank
                SEP     #$20
                MX      %10
                STA:    mm_handle+2
                REP     #$30
                MX      %00
                ; deref handle -> res_base: patch the LDAL operands (SMC bracket)
                LDA:    mm_handle                   ; lo16 (seg1 read, DBR=seg1)
                LDX:    mm_handle+2                 ; bank (byte2)
                PHB
                PHK
                PLB                                 ; DBR = seg0 (patch code)
                STA:    @ra_dA+1
                CLC
                ADC     #2
                STA:    @ra_dB+1
                SEP     #$20
                MX      %10
                TXA
                STA:    @ra_dA+3
                STA:    @ra_dB+3
                REP     #$30
                MX      %00
                PLB                                 ; DBR = seg1
@ra_dA          LDAL    $000000                     ; master ptr lo16 = base offset
                STA:    res_base
                SEP     #$20
                MX      %10
@ra_dB          LDAL    $000000                     ; master ptr byte2 = base bank
                STA:    res_base+2
                REP     #$30
                MX      %00
                LDA     #1
                RTL

;------------------------------------------------------------------------------
; void eng_res_free(void) - SYS_MM_FREE(mm_handle) (resident-load failure path).
;------------------------------------------------------------------------------
                FGX2_EXPORT eng_res_free
eng_res_free    MX      %00
                SEP     #$20
                MX      %10
                LDA:    mm_handle+2
                REP     #$30
                MX      %00
                LDX:    mm_handle
                JSL     SYS_TRAMP
                DFB     SYS_MM_FREE
                RTL

;------------------------------------------------------------------------------
; void eng_pool_free(void) - SYS_MM_FREE(pool_handle) (song-end teardown).
;------------------------------------------------------------------------------
                FGX2_EXPORT eng_pool_free
eng_pool_free   MX      %00
                SEP     #$20
                MX      %10
                LDA:    pool_handle+2
                REP     #$30
                MX      %00
                LDX:    pool_handle
                JSL     SYS_TRAMP
                DFB     SYS_MM_FREE
                RTL

;------------------------------------------------------------------------------
; void eng_doc_halt(void) - halt all 32 oscillators + zero all volumes (song-end
; teardown for the foreground non-resident path; the IRQ path halts in uninstall).
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
; int eng_pool_alloc(void) - SYS_MM_ALLOC(pool_size); store the handle + deref
; to pool_base (24-bit), return 1.  On failure return 0.  (sibling of res_alloc)
;------------------------------------------------------------------------------
                FGX2_EXPORT eng_pool_alloc
eng_pool_alloc  MX      %00
                LDA:    pool_size
                LDX:    pool_size+2
                JSL     SYS_TRAMP
                DFB     SYS_MM_ALLOC
                BCS     @pa_ok
                LDA     #0
                RTL
@pa_ok          STY:    pool_handle
                SEP     #$20
                MX      %10
                STA:    pool_handle+2
                REP     #$30
                MX      %00
                LDA:    pool_handle
                LDX:    pool_handle+2
                PHB
                PHK
                PLB                                 ; DBR = seg0
                STA:    @pa_dA+1
                CLC
                ADC     #2
                STA:    @pa_dB+1
                SEP     #$20
                MX      %10
                TXA
                STA:    @pa_dA+3
                STA:    @pa_dB+3
                REP     #$30
                MX      %00
                PLB                                 ; DBR = seg1
@pa_dA          LDAL    $000000
                STA:    pool_base
                SEP     #$20
                MX      %10
@pa_dB          LDAL    $000000
                STA:    pool_base+2
                REP     #$30
                MX      %00
                LDA     #1
                RTL

;------------------------------------------------------------------------------
; void eng_pat_to_res(void) - copy pattbuf[0..patstep-1] (seg1) to [res_dst], a
; 24-bit resident-block address.  (FGX1 pat_to_res, with the SMC bracket.)
;------------------------------------------------------------------------------
                FGX2_EXPORT eng_pat_to_res
eng_pat_to_res  MX      %00
                LDA:    res_dst
                LDX:    res_dst+2
                PHB
                PHK
                PLB                                 ; DBR = seg0 (patch STAL operand)
                STA:    @p2r_st+1
                SEP     #$20
                MX      %10
                TXA
                STA:    @p2r_st+3
                PLB                                 ; DBR = seg1 (stay MX %10 = 8-bit byte copy)
                LDX     #0
@p2r_loop       LDA:    pattbuf,X                   ; src byte (seg1, DBR-relative)
@p2r_st         STAL    $000000,X                   ; [res_dst + X], operand patched
                INX
                CPX:    patstep
                BCC     @p2r_loop
                REP     #$30
                MX      %00
                RTL

;------------------------------------------------------------------------------
; void eng_pool_write_chunk(void) - copy upbuf[0..chunk-1] (seg1) to [pool_wr],
; a 24-bit stream-pool address; then pool_wr += chunk (24-bit).  (FGX1
; upbuf_to_pool, with the SMC bracket.)
;------------------------------------------------------------------------------
                FGX2_EXPORT eng_pool_write_chunk
eng_pool_write_chunk MX %00
                LDA:    pool_wr
                LDX:    pool_wr+2
                PHB
                PHK
                PLB                                 ; DBR = seg0
                STA:    @u2p_st+1
                SEP     #$20
                MX      %10
                TXA
                STA:    @u2p_st+3
                PLB                                 ; DBR = seg1 (stay MX %10 = 8-bit byte copy)
                LDX     #0
@u2p_loop       LDA:    upbuf,X
@u2p_st         STAL    $000000,X                   ; [pool_wr + X], operand patched
                INX
                CPX:    chunk
                BCC     @u2p_loop
                REP     #$30
                MX      %00
                CLC                                 ; pool_wr += chunk (24-bit)
                LDA:    pool_wr
                ADC:    chunk
                STA:    pool_wr
                LDA:    pool_wr+2
                ADC     #0
                STA:    pool_wr+2
                RTL

;==============================================================================
; increment 3 - the tracker engine (ported from ntpplay.s), C-called.
;
; The engine runs with DBR = data bank (seg1): the C control loop calls the
; eng_* wrappers below with DBR=seg1, and irq_handler restores DBR=seg1 from
; the seg0 eng_dbank cell.  So every `LDA: <cglobal>` is a DBR-relative seg1
; read.  Routines reachable from BOTH C and the IRQ path (do_one_tick,
; load_pattern) stay RTS internally; these thin wrappers add the C entry
; (JSL in, RTL out).  Engine data lives entirely in C globals (seg1).
;==============================================================================

; eng_dbank - the ONE datum the engine owns in seg0: the saved data bank, read
; by irq_handler before DBR is set (a seg1 global can't be reached first).
eng_dbank       DFB     $00

                FGX2_EXPORT eng_do_one_tick
eng_do_one_tick JSR     do_one_tick                 ; one engine tick (foreground -c path)
                RTL

                FGX2_EXPORT eng_load_pattern
eng_load_pattern JSR    load_pattern                ; C=1 ok -> return 1, else 0
                LDA     #0
                BCC     @elp0
                LDA     #1
@elp0           RTL

                FGX2_EXPORT eng_irq_install
eng_irq_install JSR     irq_install
                RTL

                FGX2_EXPORT eng_irq_uninstall
eng_irq_uninstall JSR   irq_uninstall
                RTL

                FGX2_EXPORT eng_poll_keyboard
eng_poll_keyboard JSR   poll_keyboard               ; sets g_abort / adjusts master_vol
                RTL

                FGX2_EXPORT eng_wait_tick
eng_wait_tick   JSR     wait_one_tick               ; foreground pacing (no-op under -c)
                RTL

; eng_wait_irq - sleep until the next sound IRQ, yield to the scheduler, and
; return the engine tick count (for the -Q autoquit check in C).
                FGX2_EXPORT eng_wait_irq
eng_wait_irq    MX      %00
                WAI
                JSR     yield_cpu
                LDA:    irq_ticks
                RTL

; eng_inspect_run - -i audition mode (dev aid).  Not yet ported to the C
; framework; -i currently no-ops.  (No automated test covers it.)
                FGX2_EXPORT eng_inspect_run
eng_inspect_run RTL

do_row_tick0    MX      %00
                STZ:    trkidx2
@trackLoop      MX      %00
                LDA:    trkidx2
                CMP:    ntracks
                BCC     @trackBody
                RTS                                 ; all tracks done -> tick-0 complete
@trackBody      MX      %00
                ; noteoff = patptr + trkidx2*4
                LDA:    trkidx2
                ASL
                ASL
                CLC
                ADC:    patptr
                TAX
                LDA:    pattbuf,X                   ; note_index | (instrument<<8)
                PHA
                AND     #$00FF
                STA:    noteidx
                PLA
                XBA
                AND     #$00FF
                STA:    insnum
                LDA:    pattbuf+2,X                 ; eff | val<<8 (X still = noteoff)
                STA:    effval_tmp
                ; per-track index (trkidx2*2): store effect+value, persist instrument
                LDA:    trkidx2
                ASL
                TAX                                 ; X = trkidx2*2
                LDA:    effval_tmp
                AND     #$000F
                STA:    curr_eff,X                  ; MOD effect number 0..15
                LDA:    effval_tmp
                XBA
                AND     #$00FF
                STA:    curr_val,X                  ; MOD effect value 0..255
                LDA:    insnum
                BEQ     @tNoUpd
                STA:    last_ins,X
@tNoUpd         LDA:    noteidx                     ; 0 note -> sustain, skip track
                BNE     @tgA
                BRL     @tNext
@tgA            LDA:    last_ins,X                  ; no instrument set yet -> skip
                BNE     @tgB
                BRL     @tNext
@tgB            ; cur_ins = last_ins[trkidx2] - 1
                LDA:    last_ins,X
                DEC
                STA:    cur_ins
                CMP     #MAX_INS                    ; defensive bound
                BCC     @tgPorta
                BRL     @tNext
@tgPorta        ; $03/$05 porta WITH a note: note is the slide TARGET, do not retrigger
                LDA:    curr_eff,X                  ; X = trk*2
                CMP     #$03
                BEQ     @tgPortaDo
                CMP     #$05
                BNE     @tgC
@tgPortaDo
                LDA:    cur_ins                     ; target finetune = this instrument's
                ASL
                TAX                                 ; X = cur_ins*2
                LDA:    ins_finetune,X
                STA:    cur_finetune
                LDA:    noteidx                     ; target = note_to_ptr(note)
                JSR     note_to_ptr
                STA:    nf_ptr
                LDA:    trkidx2
                ASL
                TAX                                 ; X = trk*2
                LDA:    nf_ptr
                STA:    slide_target,X
                BRL     @tNext                      ; suppress trigger; se_porta arms the slide
@tgC            LDA:    cur_ins
                ASL
                TAX                                 ; X = cur_ins*2
                ; LOOPHEADER (type 2) -> retarget to paired loop body (next instr)
                LDA:    ins_type,X
                AND     #$03
                CMP     #$02
                BNE     @tInsSel
                LDA:    cur_ins
                INC
                STA:    cur_ins
                CMP     #MAX_INS
                BCC     @tgD
                BRL     @tNext
@tgD            LDA:    cur_ins
                ASL
                TAX
@tInsSel        LDA:    ins_docptr,X                ; doc_ptr 0 = streamed (not in DOC RAM)
                AND     #$00FF
                BNE     @tPlaced                    ; placed -> normal voice
                ; --- v1a.3c streamed: stream it if its sample data is in the pool ---
                LDA:    pool_ok
                BNE     @tStreamed
                BRL     @tNext                      ; no pool -> skip this voice (silent)
@tStreamed      ; collision guard: skip streaming if this track's 2-page DOC stream
                ;   buffer would overlap the uploaded sample pages (big modules)
                LDA:    trkidx2
                ASL
                TAX
                LDA:    strm_base_pg,X
                AND     #$00FF
                CMP:    max_doc_page
                BCC     @tStrSkip                   ; base < max uploaded page -> overlap
                BEQ     @tStrSkip                   ; base == max uploaded page -> overlap
                LDA     #1
                STA:    strm_active
                STZ:    cur_docptr                  ; (overridden to the stream buffer below)
                BRA     @tPlayBody
@tStrSkip       BRL     @tNext                      ; buffer collides with samples -> silent
@tPlaced        STA:    cur_docptr                  ; placed: doc_ptr (DOC page)
                STZ:    strm_active
@tPlayBody      LDA:    ins_finetune,X
                STA:    cur_finetune
                LDA:    ins_type,X
                STA:    cur_type
                LDA:    ins_docsize,X
                STA:    cur_docsize
                LDA:    ins_vol,X                   ; X=cur_ins*2; MOD vol 0..64
                AND     #$00FF
                CMP     #65                         ; defensive clamp to 64
                BCC     @tModVolOK
                LDA     #64
@tModVolOK      STA:    cur_modvol                  ; unscaled MOD vol (per-track persist)
                ASL                                 ; -> DOC scale (x4, clamp 255)
                ASL
                CMP     #$0100
                BCC     @tVolOK
                LDA     #$00FF
@tVolOK         STA:    cur_vol                     ; scaled DOC vol (trigger_voice uses this)
                ; voice oscillator + stereo channel from this track
                LDA:    trkidx2
                ASL
                TAX                                 ; X = trkidx2*2
                LDA:    cur_modvol                  ; persist unscaled vol for effects
                STA:    curr_vol,X
                ; trk_nosc[t] = swap-pair ? 2 : 1  (mirror trigger_voice mode dispatch)
                LDA:    cur_type
                AND     #$0001
                BEQ     @tNs1                       ; even type -> one-shot, 1 osc
                LDA:    cur_type
                AND     #$0004
                BNE     @tNs1                       ; optimal-size loop -> free-run, 1 osc
                LDA     #2
                BRA     @tNsSet
@tNs1           LDA     #1
@tNsSet         STA:    trk_nosc,X
                LDA:    track_osc,X
                STA:    cur_osc
                LDA:    track_chan,X
                STA:    cur_chan
                ; freq: pitch index -> per-channel curr_ptr (for slides) -> freq
                LDA:    noteidx
                JSR     note_to_ptr
                STA:    nf_ptr
                LDA:    trkidx2                     ; X = trk*2 (note_to_ptr clobbered X)
                ASL
                TAX
                LDA:    nf_ptr
                STA:    curr_ptr,X                  ; per-channel pitch index
                LDA:    nf_ptr
                JSR     ptr_to_freq
                STA:    curfreq
                ; --- v1a.3c: streamed -> osc B wavetable = this track's stream buffer,
                ;     2 oscs (timer + sample); trigger_stream does the rest ---
                LDA:    strm_active
                BEQ     @tHaveTrig
                LDA:    trkidx2
                ASL
                TAX
                LDA:    strm_base_pg,X
                STA:    cur_docptr
                LDA     #2
                STA:    trk_nosc,X
@tHaveTrig      ; trigger the voice (MX %10, register-access mode)
                LDA:    g_check                     ; check mode: skip DOC, keep count
                BNE     @tSkipDoc
                SEP     #$20
                MX      %10
                JSR     docwait
                LDA:    master_vol                  ; register access + autoinc + System Volume
                ORA     #$20
                STAL    SOUND_CTL
                LDA:    strm_active                 ; streamed -> stream setup, else normal voice
                BEQ     @tDoVoice
                JSR     trigger_stream
                BRA     @tTrigDone
@tDoVoice       JSR     trigger_voice
@tTrigDone      REP     #$20
                MX      %00
@tSkipDoc       MX      %00
                LDA:    trigcnt                     ; count triggered notes (diagnostic)
                INC
                STA:    trigcnt
@tNext          MX      %00
                LDA:    trkidx2                     ; setup effect (every track, even note-less)
                ASL
                TAY                                 ; Y = trkidx2*2
                JSR     setup_effect_track
                LDA:    trkidx2
                INC
                STA:    trkidx2
                BRL     @trackLoop
poll_keyboard   MX      %00
                LDA     #0
                JSL     SYS_TRAMP
                DFB     SYS_POLLKEY                  ; C=1 + A=key, or C=0 (no key)
                BCC     @pk_nokey                   ; no key this poll
                AND     #$00FF
                ; -- vt100 arrow decode.  Arrows arrive as ESC [ C/D (right/
                ; left) — the kernel heartbeat enqueues the 3 bytes atomically,
                ; so consecutive polls drain ESC, '[', letter in order.  ESC is
                ; also the quit key, so we defer the quit decision one poll: if
                ; a '[' follows the ESC it's an arrow, else (any other key, or
                ; no key next poll) the ESC was a bare quit.
                LDX:    g_esc_state
                BNE     @pk_inseq
                ; state 0: a fresh key.
                CMP     #$1B                        ; ESC -> maybe arrow / quit
                BEQ     @pk_escStart
                CMP     #$71                        ; 'q'
                BEQ     @pk_abort
                CMP     #$51                        ; 'Q'
                BEQ     @pk_abort
                CMP     #$03                        ; Ctrl-C
                BEQ     @pk_abort
                BRA     @pk_done                    ; any other key -> ignore
@pk_escStart    LDA     #1
                STA:    g_esc_state
                BRA     @pk_done
@pk_inseq       CPX     #1
                BNE     @pk_seq2
                ; state 1: expect '[' — else the ESC was a real quit.
                CMP     #$5B                        ; '['
                BEQ     @pk_gotBracket
                STZ:    g_esc_state
                BRA     @pk_abort
@pk_gotBracket  LDA     #2
                STA:    g_esc_state
                BRA     @pk_done
@pk_seq2        ; state 2: final letter.  Sequence consumed either way.
                STZ:    g_esc_state
                CMP     #$43                        ; 'C' right arrow -> vol up
                BEQ     @pk_volUp
                CMP     #$44                        ; 'D' left arrow  -> vol down
                BEQ     @pk_volDn
                BRA     @pk_done                    ; other arrow (A/B) -> ignore
@pk_nokey       ; no key: a pending ESC (state 1) with nothing following was a
                ; bare quit (a real arrow's '[' is already queued by now).
                LDX:    g_esc_state
                CPX     #1
                BNE     @pk_done
                STZ:    g_esc_state
                ; fall through to abort
@pk_abort       LDA     #1
                STA:    g_abort
                RTS
@pk_volDn       LDA:    master_vol
                BEQ     @pk_volSet                   ; already 0
                DEC
                STA:    master_vol
                BRA     @pk_volSet
@pk_volUp       LDA:    master_vol
                CMP     #$0F
                BCS     @pk_volSet                   ; already 15 (max)
                INC
                STA:    master_vol
@pk_volSet      SEI                                  ; DOC single-owner: mask the sound IRQ
                SEP     #$20                         ; while the foreground writes the GLU
                MX      %10
                JSR     docwait
                LDA:    master_vol
                ORA     #$20                         ; register access + System Volume
                STAL    SOUND_CTL
                REP     #$20
                MX      %00
                CLI
@pk_done        RTS
do_row_continue MX      %00
                STZ:    trkidx2
@drc_loop       MX      %00
                LDA:    trkidx2
                CMP:    ntracks
                BCS     @drc_done
                JSR     handle_effects_track
                LDA:    trkidx2
                INC
                STA:    trkidx2
                BRA     @drc_loop
@drc_done       RTS
advance_row     MX      %00
                LDA:    pend_jump
                BEQ     @ar_normal
                CMP     #2
                BEQ     @ar_posjump
                CMP     #4
                BEQ     @ar_break
                BRA     @ar_done                     ; pend_jump==6 -> stop
@ar_posjump     STZ:    pend_jump
                LDA:    pend_jump_param
                STA:    songpos                      ; jump to order position, row 0
                STZ:    start_row
                BRA     @ar_loadpat
@ar_break       STZ:    pend_jump
                LDA:    songpos                      ; break -> next pattern at start_row
                INC
                STA:    songpos
                CMP:    norder
                BCS     @ar_done                     ; past end -> stop
                LDA:    pend_jump_param
                STA:    start_row
                BRA     @ar_loadpat
@ar_normal      LDA:    patptr                       ; advance to next row
                CLC
                ADC:    rowstep
                STA:    patptr
                LDA:    row
                INC
                STA:    row
                CMP     #64
                BCC     @ar_samepat                  ; row < 64 -> next row, same pattern
                LDA:    songpos                      ; row wrapped -> next order entry
                INC
                STA:    songpos
                CMP:    norder
                BCC     @ar_loadpat
                LDA     #LOOP_SONG                   ; end of order table
                BEQ     @ar_done
                STZ:    songpos                      ; LOOP_SONG: restart the song
@ar_loadpat     JSR     load_pattern
                BCC     @ar_done                     ; read fail -> done
@ar_samepat     STZ:    g_done
                RTS
@ar_done        LDA     #1
                STA:    g_done
                RTS
do_one_tick     MX      %00
                LDA:    irq_ticks                    ; engine ticks, for -Q's autoquit
                INC
                STA:    irq_ticks
                LDA:    ttick
                BNE     @dot_cont
                JSR     do_row_tick0                 ; tick 0
                LDA     #1
                STA:    ttick
                STZ:    g_done
                RTS
@dot_cont       JSR     do_row_continue              ; ticks 1..speed-1
                LDA:    ttick
                INC
                STA:    ttick
                CMP:    speed
                BCC     @dot_nd                      ; still within the row
                STZ:    ttick                        ; row finished -> advance
                JSR     advance_row                  ; sets g_done
                RTS
@dot_nd         STZ:    g_done
                RTS
irq_install     MX      %00
                ; --- save the data bank to the seg0 eng_dbank cell so irq_handler can
                ;     restore DBR=seg1 before touching any C global (chicken-and-egg:
                ;     the saved bank itself can't live in seg1).  DBR=seg1 in/out. ---
                SEP     #$20
                MX      %10
                PHB
                PLA                                  ; A.lo = data bank (current DBR)
                PHK
                PLB                                  ; DBR = code (reach eng_dbank)
                STA:    eng_dbank
                PHA
                PLB                                  ; DBR = data (restored)
                REP     #$30
                MX      %00
                ; --- v1a.3b: init the per-osc job table (all NONE, timer osc = tick).
                ;     v1a.3c sets JOB_STREAM on a voice's osc when streaming starts. ---
                SEP     #$20
                MX      %10
                LDX     #NUM_OSC-1
@ii_jzero       STZ:    osc_job_tbl,X
                DEX
                BPL     @ii_jzero
                LDA     #JOB_TICK
                STA:    osc_job_tbl+TIMER_OSC
                REP     #$30
                MX      %00
                LDAL    SND_INT_PTR                  ; save old vector
                STA:    old_vec
                LDAL    SND_INT_PTR+2
                STA:    old_vec+2
                SEP     #$20
                MX      %10
                JSR     docwait                      ; upload dummy wave -> TIMER_PAGE
                LDA     #$6F                         ; RAM + autoinc + vol $F
                STAL    SOUND_CTL
                JSR     docwait
                LDA     #$00
                STAL    SOUND_ADRL
                JSR     docwait
                LDA     #TIMER_PAGE
                STAL    SOUND_ADRH
                LDX     #128
                LDA     #$FF
@ii_whi         JSR     docwait
                STAL    SOUND_DATA
                DEX
                BNE     @ii_whi
                LDX     #128
                LDA     #$01
@ii_wlo         JSR     docwait
                STAL    SOUND_DATA
                DEX
                BNE     @ii_wlo
                JSR     docwait                      ; register-access mode for setreg
                LDA     #$2F
                STAL    SOUND_CTL
                LDX     #$00+TIMER_OSC               ; freq lo
                LDA     #REF_FREQ
                JSR     setreg
                LDX     #$20+TIMER_OSC               ; freq hi
                LDA     #$00
                JSR     setreg
                LDX     #$40+TIMER_OSC               ; volume = 0 (inaudible)
                LDA     #$00
                JSR     setreg
                LDX     #$80+TIMER_OSC               ; wavetable ptr = TIMER_PAGE
                LDA     #TIMER_PAGE
                JSR     setreg
                LDX     #$C0+TIMER_OSC               ; size 256 / res 0
                LDA     #$00
                JSR     setreg
                LDA     #$5C                         ; install $E1002C = JML irq_handler
                STAL    SND_INT_PTR
                REP     #$20                        ; the address as ONE word, so
                MX      %00                         ;   an offset relocation can
                LDA     #irq_handler                ;   move it with the code
                STAL    SND_INT_PTR+1
                SEP     #$20
                MX      %10
                PHK                                  ; REAL run bank, not ^irq_handler
                PLA
                STAL    SND_INT_PTR+3
                LDX     #$A0+TIMER_OSC               ; ARM last: ctrl $08 = free-run + IE
                LDA     #$08
                JSR     setreg
                REP     #$30
                MX      %00
                ; Claim the DOC so the kernel runs Sound_StopDoc if we're killed
                ; (SIGKILL/SIGTERM can't run our irq_uninstall) -- audio stops on
                ; kill but keeps playing when backgrounded.
                JSL     SYS_TRAMP
                DFB     SYS_SOUND_CLAIM
                RTS
irq_handler     MX      %11
                PHB
                PHD
                PHK
                PLB                                  ; DBR = code bank (reach seg0 eng_dbank)
                CLC
                XCE                                  ; force native
                SEP     #$30                         ; 8-bit
                MX      %11
                LDA:    eng_dbank                    ; saved data bank (seg0; DBR=code now)
                PHA
                PLB                                  ; DBR = data bank (seg1 globals reachable)
                ; --- The ROM sound IRQ handler read (and ACKed) the $E0 oscillator-
                ;     interrupt register and saved its value at IRQ_SOUNDDATA
                ;     (bits 5-1 = osc#) before JSLing IRQ.SOUND.  Read it from there,
                ;     as NinjaTrackerPlus and Apple's own sound handlers do: A holds
                ;     it only when nothing is chained in front of this handler, and a
                ;     CDA such as DocVue wraps the vector.  Dispatch that osc's job. ---
                LDAL    IRQ_SOUNDDATA
                JSR     ih_dispatch                  ; A = osc-interrupt value
@ih_next        MX      %11
                ; --- drain $E0 for any OTHER still-pending oscs (the ROM ACKed only
                ;     the one it passed in A); each $E0 read ACKs the osc it returns.
                ;     GLU pipeline-delay dance. ---
@ih_w0          LDAL    SOUND_CTL
                BMI     @ih_w0
                LDA     #$00                         ; register mode, no auto-inc
                STAL    SOUND_CTL
@ih_w1          LDAL    SOUND_CTL
                BMI     @ih_w1
                LDA     #$E0                         ; osc-interrupt register
                STAL    SOUND_ADRL
@ih_w2          LDAL    SOUND_CTL
                BMI     @ih_w2
                LDAL    SOUND_DATA                   ; dummy read (pipeline delay)
@ih_w3          LDAL    SOUND_CTL
                BMI     @ih_w3
                LDA     #$00                         ; re-set addr (commit the $E0 read)
                STAL    SOUND_ADRL
@ih_w4          LDAL    SOUND_CTL
                BMI     @ih_w4
                LDAL    SOUND_DATA                   ; A = $E0 (reading ACKs the osc)
                BMI     @ih_done                     ; bit7=1 -> none left -> done
                JSR     ih_dispatch                  ; A = osc-interrupt value -> dispatch
                BRA     @ih_next
@ih_done        MX      %11
                PLD
                PLB
                CLC
                RTL
ih_dispatch     MX      %11
                AND     #$3E
                LSR
                STA:    irq_osc                      ; stash osc# for the stream job
                TAX
                LDA:    osc_job_tbl,X
                CMP     #JOB_TICK
                BNE     @id_stream
                REP     #$30                         ; tick job (osc 31): run the engine
                MX      %00
                JSR     do_one_tick
                SEP     #$30
                MX      %11
                RTS
@id_stream      CMP     #JOB_STREAM
                BNE     @id_done                     ; NONE/unknown -> already acked, ignore
                REP     #$30                         ; stream job: refill the voice (v1a.3c)
                MX      %00
                JSR     interrupt_stream
                SEP     #$30
                MX      %11
@id_done        RTS
interrupt_stream MX     %00
                LDA:    irq_osc                     ; X = the IRQ'ing timer osc#
                AND     #$00FF
                TAX
                SEP     #$20
                MX      %10
                LDA:    osc_strm_trk,X              ; -> owning track*2
                REP     #$30
                MX      %00
                AND     #$00FF
                TAY                                 ; Y = track*2
                ; --- refill target page = strm_base_pg[Y] + strm_pg_off[Y] ---
                SEP     #$20
                MX      %10
                CLC
                LDA:    strm_base_pg,Y
                ADC:    strm_pg_off,Y
                STA:    strm_dst_pg
                REP     #$30
                MX      %00
                LDA     #256
                STA:    strm_cnt
                SEP     #$20
                MX      %10
                JSR     strm_copy                   ; refill 256 B, advance strm_ptr[Y]
                ; --- reached the end of the instrument's sample data? ---
                REP     #$30
                MX      %00
                LDA:    strm_ptr_hi,Y
                CMP:    strm_end_hi,Y
                BCC     @is_more
                BNE     @is_end
                LDA:    strm_ptr_lo,Y
                CMP:    strm_end_lo,Y
                BCC     @is_more
@is_end         ; --- end of sample: looped -> loop back by rep_len + keep going;
                ;     not looped -> halt (one-shot) ---
                LDA:    strm_looped,Y
                AND     #$00FF
                BEQ     @is_halt
                SEC                                 ; strm_ptr[Y] -= strm_replen[Y]
                LDA:    strm_ptr_lo,Y
                SBC:    strm_replen_lo,Y
                STA:    strm_ptr_lo,Y
                LDA:    strm_ptr_hi,Y
                SBC:    strm_replen_hi,Y
                STA:    strm_ptr_hi,Y
                BRA     @is_more                    ; continue streaming (toggle page)
@is_halt        ; --- one-shot end: clear the job + halt the timer osc ---
                LDA:    irq_osc
                AND     #$00FF
                TAX
                SEP     #$20
                MX      %10
                STZ:    osc_job_tbl,X               ; stop future refills
                JSR     docwait                     ; register access for the halt
                LDA:    master_vol
                ORA     #$20
                STAL    SOUND_CTL
                TXA                                 ; ctl reg $A0+osc <- $01 (halt)
                CLC
                ADC     #$A0
                TAX
                LDA     #$01
                JSR     setreg
                REP     #$30
                MX      %00
                RTS
@is_more        ; --- toggle to the other buffer page for the next refill ---
                SEP     #$20
                MX      %10
                LDA:    strm_pg_off,Y
                EOR     #1
                STA:    strm_pg_off,Y
                REP     #$30
                MX      %00
                RTS
irq_uninstall   MX      %00
                SEI
                SEP     #$20
                MX      %10
                JSR     docwait                      ; halt all oscs: ctl $A0..$BF <- $01
                LDA     #$20                         ;   ($01 clears run + IE on each)
                STAL    SOUND_CTL                    ; register access, auto-increment
                JSR     docwait
                LDA     #$A0
                STAL    SOUND_ADRL
                JSR     docwait
                LDA     #$00
                STAL    SOUND_ADRH
                LDX     #32
                LDA     #$01
@iu_halt        JSR     docwait
                STAL    SOUND_DATA
                DEX
                BNE     @iu_halt
                JSR     docwait                      ; drain $E0: ack any latched osc IRQ
                LDA     #$00                         ; register access, no auto-increment
                STAL    SOUND_CTL
                LDY     #40                          ; safety cap (>= 32 oscs; can't hang)
@iu_drain       JSR     docwait
                LDA     #$E0                         ; osc-interrupt register
                STAL    SOUND_ADRL
                JSR     docwait
                LDAL    SOUND_DATA                   ; dummy read (GLU one-behind pipeline)
                JSR     docwait
                LDA     #$00                         ; commit the $E0 read
                STAL    SOUND_ADRL
                JSR     docwait
                LDAL    SOUND_DATA                   ; A = $E0 (reading acks the osc)
                BMI     @iu_drainDone                ; bit7=1 -> none pending -> done
                DEY
                BNE     @iu_drain                    ; else ack next osc (capped)
@iu_drainDone   REP     #$30
                MX      %00
                LDA:    old_vec                      ; restore old vector (now safe: no osc
                STAL    SND_INT_PTR                   ;   running, no IRQ pending)
                LDA:    old_vec+2
                STAL    SND_INT_PTR+2
                CLI
                RTS
wait_one_tick   MX      %00
                LDA:    g_check
                BEQ     @wt_go
                RTS
@wt_go          LDA     #tbuf
                JSL     SYS_TRAMP
                DFB     SYS_TICKS
                LDA:    tbuf
                STA:    tstart
@wt_wait        MX      %00
                WAI
                JSR     yield_cpu                   ; bg: hand the fg shell the CPU between ticks
                LDA     #tbuf
                JSL     SYS_TRAMP
                DFB     SYS_TICKS
                LDA:    tbuf
                SEC
                SBC:    tstart
                CMP     #1
                BCC     @wt_wait
                RTS
yield_cpu       MX      %00
                JSL     SYS_TRAMP
                DFB     SYS_YIELD
                RTS
handle_effects_track MX  %00
                LDA:    trkidx2
                ASL
                TAY                                 ; Y = track*2
                ; --- volume slide ($0A) ---
                LDA:    vol_delta,Y
                BEQ     @he_cut
                CLC
                ADC:    curr_vol,Y                  ; signed add (vol_delta is signed)
                BPL     @he_hi                      ; >=0 -> check high clamp
                LDA     #0                          ; underflow -> clamp 0
@he_hi          CMP     #65
                BCC     @he_nvok
                LDA     #64                         ; overshoot -> clamp 64
@he_nvok        STA:    curr_vol,Y
                JSR     write_vol_check
@he_cut         ; --- note-cut ($0E Cx) ---
                LDA:    note_cut,Y
                BEQ     @he_pitch
                DEC
                STA:    note_cut,Y
                BNE     @he_pitch                   ; not yet
                LDA     #0                          ; reached 0 -> cut to silence
                STA:    curr_vol,Y
                JSR     write_vol_check
@he_pitch       ; --- pitch ($01 up / $02 down / $03 porta): bend curr_ptr, reprogram freq ---
                LDA:    curr_eff,Y                  ; dispatch via inverted BNE+BRL (handlers far)
                CMP     #$01
                BNE     @hp_c2
                BRL     @he_slideup
@hp_c2          CMP     #$02
                BNE     @hp_c3
                BRL     @he_slidedown
@hp_c3          CMP     #$03
                BNE     @hp_c0
                BRL     @he_porta
@hp_c0          CMP     #$00
                BNE     @hp_c4
                BRL     @he_arp
@hp_c4          CMP     #$04
                BNE     @hp_c5
                BRL     @he_vibrato
@hp_c5          CMP     #$05
                BNE     @hp_c6
                BRL     @he_porta                   ; 05: porta continue (+ volslide via vol_delta)
@hp_c6          CMP     #$06
                BNE     @hp_none
                BRL     @he_vibrato                 ; 06: vibrato continue (+ volslide via vol_delta)
@hp_none        BRL     @he_done
@he_vibrato     ; offset = sine_tbl[voff+pos]; freq = ptr_to_freq(curr_ptr + offset)
                LDA:    vibrato_voff,Y
                CLC
                ADC:    vibrato_pos,Y
                TAX
                LDA:    sine_tbl,X                  ; signed pitch offset
                CLC
                ADC:    curr_ptr,Y                  ; modulated pitch index
                BPL     @hv_nonneg
                LDA     #0                          ; clamp low
@hv_nonneg      CMP     #MAX_FT_PTR+1
                BCC     @hv_inrange
                LDA     #MAX_FT_PTR                 ; clamp high
@hv_inrange     JSR     ptr_to_freq
                STA:    wf_freq
                JSR     write_freq_check
                LDA:    vibrato_pos,Y               ; advance phase, wrap at 128
                CLC
                ADC:    vibrato_rate,Y
                CMP     #128
                BCC     @hv_setpos
                AND     #127
@hv_setpos      STA:    vibrato_pos,Y
                BRL     @he_done
@he_slideup     LDA:    curr_ptr,Y
                CLC
                ADC:    slide_delta,Y
                CMP     #MAX_FT_PTR+1               ; clamp high
                BCC     @he_su_ok
                LDA     #MAX_FT_PTR
@he_su_ok       STA:    curr_ptr,Y
                BRA     @he_pwrite
@he_slidedown   LDA:    curr_ptr,Y
                SEC
                SBC:    slide_delta,Y
                BCS     @he_sd_ok                   ; no underflow
                LDA     #0                          ; clamp to 0
@he_sd_ok       STA:    curr_ptr,Y
                BRA     @he_pwrite
@he_porta       ; slide curr_ptr toward slide_target, clamp at the target
                LDA:    curr_ptr,Y
                CMP:    slide_target,Y
                BEQ     @he_done                    ; already there
                BCS     @he_porta_dn                ; curr > target -> slide down
                CLC                                 ; curr < target -> slide up
                ADC:    slide_delta,Y
                CMP:    slide_target,Y
                BCC     @he_porta_set               ; still below target
                LDA:    slide_target,Y              ; reached/overshot -> clamp to target
                BRA     @he_porta_set
@he_porta_dn    SEC
                SBC:    slide_delta,Y
                CMP:    slide_target,Y
                BCS     @he_porta_set               ; still at/above target
                LDA:    slide_target,Y              ; overshot below -> clamp to target
@he_porta_set   STA:    curr_ptr,Y
                BRA     @he_pwrite
@he_arp         LDA:    arp_phase,Y                 ; cycle base/note2/note3 each tick
                BEQ     @he_done                    ; inactive
                CMP     #3
                BCC     @he_arp_inc                 ; phase < 3 -> +1
                LDA     #1                          ; phase 3 -> wrap to 1
                BRA     @he_arp_setph
@he_arp_inc     INC
@he_arp_setph   STA:    arp_phase,Y
                CMP     #1
                BNE     @he_arp_c2
                LDA:    arp_ptr1,Y
                BRA     @he_arp_set
@he_arp_c2      CMP     #2
                BNE     @he_arp_p3
                LDA:    arp_ptr2,Y
                BRA     @he_arp_set
@he_arp_p3      LDA:    arp_ptr3,Y
@he_arp_set     STA:    curr_ptr,Y
@he_pwrite      LDA:    curr_ptr,Y
                JSR     ptr_to_freq
                STA:    wf_freq
                JSR     write_freq_check
@he_done        RTS

;------------------------------------------------------------------------------
; setup_effect_track - tick-0 effect setup for track Y/2. Y = track*2. Dispatches
; curr_eff[Y] to the note-lifecycle setups. MX %00. Preserves Y. CMP-chain
; dispatch (jump table deferred to E5.3 per spec). Bodies filled in Task 6.
;------------------------------------------------------------------------------
setup_effect_track MX   %00
                LDA     #0
                STA:    vol_delta,Y                 ; slide re-arms only if $0A this row
                LDA:    curr_eff,Y
                CMP     #$0C
                BEQ     @d_setvol
                CMP     #$0A
                BEQ     @d_volslide
                CMP     #$0E
                BEQ     @d_ext
                CMP     #$0F
                BEQ     @d_setspeed
                CMP     #$0B
                BEQ     @d_posjump
                CMP     #$0D
                BEQ     @d_break
                CMP     #$01
                BEQ     @d_slideup
                CMP     #$02
                BEQ     @d_slidedown
                CMP     #$03
                BEQ     @d_porta
                CMP     #$00
                BEQ     @d_arp                      ; effect 0: arpeggio if val!=0, else off
                CMP     #$04
                BEQ     @d_vibrato
                CMP     #$05
                BEQ     @d_combo5
                CMP     #$06
                BEQ     @d_combo6
                RTS                                 ; other effects ignored
@d_setvol       JMP     se_setvol                   ; JMP (absolute) -> body-growth safe
@d_volslide     JMP     se_volslide
@d_ext          JMP     se_ext
@d_setspeed     JMP     se_setspeed
@d_posjump      JMP     se_posjump
@d_break        JMP     se_break
@d_slideup      JMP     se_slideup
@d_slidedown    JMP     se_slidedown
@d_porta        JMP     se_porta
@d_arp          JMP     se_arp
@d_vibrato      JMP     se_vibrato
@d_combo5       JMP     se_combo5
@d_combo6       JMP     se_combo6

;------------------------------------------------------------------------------
; se_setvol - $0C set-volume. curr_vol[Y]=min(val,64); write; count. Y=track*2.
;------------------------------------------------------------------------------
se_setvol       MX      %00
                LDA:    curr_val,Y
                AND     #$00FF
                CMP     #65
                BCC     @sv_ok
                LDA     #64
@sv_ok          STA:    curr_vol,Y
                LDA:    d_setv                      ; count set-volume dispatch
                INC
                STA:    d_setv
                LDA:    curr_vol,Y                  ; re-load to test 0 (avoid stale flags)
                BNE     @sv_write
                LDA:    d_vz                        ; value 0 -> also count vz
                INC
                STA:    d_vz
@sv_write       JSR     write_vol_check
                RTS

;------------------------------------------------------------------------------
; se_volslide - $0A. vol_delta[Y] = (val>>4) ? +(val>>4) : -(val&0F). Y=track*2.
;------------------------------------------------------------------------------
se_volslide     MX      %00
                LDA:    d_vsl
                INC
                STA:    d_vsl
                JMP     arm_volslide                ; tail-call (shared with combos 05/06)

;------------------------------------------------------------------------------
; arm_volslide - vol_delta[Y] = (val>>4) ? +(val>>4) : -(val&0F). Y=track*2.
; Shared by $0A and the $05/$06 combos. RTS to caller.
;------------------------------------------------------------------------------
arm_volslide    MX      %00
                LDA:    curr_val,Y
                AND     #$00F0                      ; high nibble
                BEQ     @av_down
                LSR
                LSR
                LSR
                LSR
                STA:    vol_delta,Y                 ; +hi (up)
                RTS
@av_down        LDA:    curr_val,Y
                AND     #$000F                      ; low nibble
                EOR     #$FFFF                      ; two's-complement negate (16-bit)
                INC
                STA:    vol_delta,Y                 ; -lo (down)
                RTS

;------------------------------------------------------------------------------
; se_combo5 ($05 porta+volslide) / se_combo6 ($06 vibrato+volslide) - arm the
; volume slide; the pitch part continues with its prior state (porta target set
; by the trigger gate; vibrato rate/depth from a prior $04). Counts d_c5/d_c6.
;------------------------------------------------------------------------------
se_combo5       MX      %00
                LDA:    d_c5
                INC
                STA:    d_c5
                JMP     arm_volslide
se_combo6       MX      %00
                LDA:    d_c6
                INC
                STA:    d_c6
                JMP     arm_volslide

;------------------------------------------------------------------------------
; se_ext - $0E extended: sub=val>>4, n=val&0F. C note-cut, A/B fine-vol, D delay.
;------------------------------------------------------------------------------
se_ext          MX      %00
                LDA:    curr_val,Y
                AND     #$00F0
                LSR
                LSR
                LSR
                LSR
                STA:    se_sub
                LDA:    curr_val,Y
                AND     #$000F
                STA:    se_n
                LDA:    se_sub
                CMP     #$0C
                BEQ     @ext_cut
                CMP     #$0A
                BEQ     @ext_fvu
                CMP     #$0B
                BEQ     @ext_fvd
                CMP     #$0D
                BEQ     @ext_ndl
                RTS                                 ; other E-subeffects: later slices
@ext_cut        LDA:    se_n                        ; note-cut after n sub-ticks
                STA:    note_cut,Y
                LDA:    d_cut                       ; count $0E Cx dispatch (matches ntpdump)
                INC
                STA:    d_cut
                RTS
@ext_fvu        LDA:    curr_vol,Y                  ; fine vol up: +n clamp 64
                CLC
                ADC:    se_n
                CMP     #65
                BCC     @fvu_ok
                LDA     #64
@fvu_ok         STA:    curr_vol,Y
                JSR     write_vol_check
                RTS
@ext_fvd        LDA:    curr_vol,Y                  ; fine vol down: -n clamp 0
                SEC
                SBC:    se_n
                BPL     @fvd_ok
                LDA     #0
@fvd_ok         STA:    curr_vol,Y
                JSR     write_vol_check
                RTS
@ext_ndl        LDA:    se_n                        ; note-delay: trigger after n sub-ticks
                STA:    note_delay,Y
                LDA:    d_ndl
                INC
                STA:    d_ndl
                RTS

;------------------------------------------------------------------------------
; write_vol_check - select register access + write_vol for track Y/2. No-op
; under g_check (no DOC). MX %00 in/out. Preserves Y.
;------------------------------------------------------------------------------
write_vol_check MX      %00
                LDA:    g_check
                BEQ     @wvc_go
                RTS
@wvc_go         SEP     #$20
                MX      %10
                JSR     docwait
                LDA:    master_vol
                ORA     #$20                        ; register access + System Volume
                STAL    SOUND_CTL
                JSR     write_vol                   ; Y still = track*2
                REP     #$20
                MX      %00
                RTS

;------------------------------------------------------------------------------
; se_setspeed - $0F. val<$20 -> speed (ticks/row); val>=$20 -> BPM (deferred to
; the IRQ timer / Initiative II; foreground keeps current speed). val 0 ignored.
; Counts every $0F dispatch in d_spd. (Reference setup_setspeed :2797.)
;------------------------------------------------------------------------------
;------------------------------------------------------------------------------
; write_freq - write osc freq regs ($00+osc lo, $20+osc hi) for track Y/2 from
; the 16-bit value in wf_freq; both osc if swap pair. Caller MX %10, register
; access selected. Reuses setosc (voc = osc). Clobbers A,X. Preserves Y.
;------------------------------------------------------------------------------
write_freq      MX      %10
                PHY
                LDA:    track_osc,Y                 ; osc A = base
                STA:    voc
                JSR     @wf_one
                LDA:    trk_nosc,Y
                CMP     #2
                BNE     @wf_done
                LDA:    voc                         ; osc B = base+1
                INC
                STA:    voc
                JSR     @wf_one
@wf_done        PLY
                RTS
@wf_one         LDX     #$00                        ; freq-lo reg ($00+voc)
                LDA:    wf_freq
                JSR     setosc
                LDX     #$20                        ; freq-hi reg ($20+voc)
                LDA:    wf_freq+1
                JSR     setosc
                RTS

;------------------------------------------------------------------------------
; write_freq_check - select register access + write_freq for track Y/2 (freq in
; wf_freq). No-op under g_check. MX %00 in/out. Preserves Y.
;------------------------------------------------------------------------------
write_freq_check MX     %00
                LDA:    g_check
                BEQ     @wfc_go
                RTS
@wfc_go         SEP     #$20
                MX      %10
                JSR     docwait
                LDA:    master_vol
                ORA     #$20                        ; register access + System Volume
                STAL    SOUND_CTL
                JSR     write_freq                  ; Y=track*2, freq in wf_freq
                REP     #$20
                MX      %00
                RTS

;------------------------------------------------------------------------------
; se_slideup ($01) / se_slidedown ($02) - arm pitch slide: slide_delta[Y]=val*2
; (freq_finetune is word-indexed). Counts d_su/d_sd. Reference setup_slide_*:2601.
;------------------------------------------------------------------------------
se_slideup      MX      %00
                LDA:    d_su
                INC
                STA:    d_su
                LDA:    curr_val,Y
                AND     #$00FF
                ASL                                 ; *2
                STA:    slide_delta,Y
                RTS
se_slidedown    MX      %00
                LDA:    d_sd
                INC
                STA:    d_sd
                LDA:    curr_val,Y
                AND     #$00FF
                ASL
                STA:    slide_delta,Y
                RTS

;------------------------------------------------------------------------------
; se_porta - $03 tone-portamento setup. Arms slide_delta=val*2 (val 0 keeps the
; previous slide speed). Target ptr is set by the trigger gate when a note is
; present; note-less rows just continue the slide. Counts d_porta.
;------------------------------------------------------------------------------
se_porta        MX      %00
                LDA:    d_porta
                INC
                STA:    d_porta
                LDA:    curr_val,Y
                AND     #$00FF
                BEQ     @sesp_done                    ; 0 -> keep previous slide speed
                ASL                                 ; *2
                STA:    slide_delta,Y
@sesp_done        RTS

;------------------------------------------------------------------------------
; se_arp - $00 arpeggio. val!=0: cache 3 freq-table ptrs (base, +hi semis,
; +lo semis) and activate; val 0: deactivate. Needs a note this row (uses the
; trigger's cur_finetune). Counts d_arp. Freq-only (no per-tick retrigger).
;------------------------------------------------------------------------------
se_arp          MX      %00
                LDA:    curr_val,Y
                AND     #$00FF
                BNE     @arp_on
                LDA     #0
                STA:    arp_phase,Y                 ; val 0 -> arpeggio off
                RTS
@arp_on         LDA:    d_arp
                INC
                STA:    d_arp
                LDA:    noteidx
                BNE     @arp_compute
                LDA     #0
                STA:    arp_phase,Y                 ; no note this row -> can't arpeggiate
                RTS
@arp_compute    LDA:    noteidx                     ; ptr1 = base note
                JSR     note_to_ptr
                STA:    arp_ptr1,Y
                LDA:    curr_val,Y                  ; ptr2 = base + hi-nibble semitones
                AND     #$00F0
                LSR
                LSR
                LSR
                LSR
                CLC
                ADC:    noteidx
                JSR     note_to_ptr
                STA:    arp_ptr2,Y
                LDA:    curr_val,Y                  ; ptr3 = base + lo-nibble semitones
                AND     #$000F
                CLC
                ADC:    noteidx
                JSR     note_to_ptr
                STA:    arp_ptr3,Y
                LDA     #1
                STA:    arp_phase,Y                 ; active; tick 0 already played the base
                RTS

;------------------------------------------------------------------------------
; se_vibrato - $04 vibrato. rate=(hi>>3=hi*2); depth -> vibrato_voff=depth*128
; (sine_tbl block); reset phase. x/y 0 keep previous. Counts d_vib. Reference
; setup_vibrato :2645.
;------------------------------------------------------------------------------
se_vibrato      MX      %00
                LDA:    d_vib
                INC
                STA:    d_vib
                LDA:    curr_val,Y
                AND     #$00F0                       ; rate nibble
                BEQ     @sv_depth
                LSR
                LSR
                LSR                                  ; hi*2 (rate)
                STA:    vibrato_rate,Y
@sv_depth       LDA:    curr_val,Y
                AND     #$000F                       ; depth nibble
                BEQ     @sv_pos                      ; 0 -> keep previous depth block
                XBA                                  ; depth<<8
                LSR                                  ; depth*128 (sine_tbl block offset)
                STA:    vibrato_voff,Y
@sv_pos         LDA     #0
                STA:    vibrato_pos,Y                ; reset phase
                RTS

se_setspeed     MX      %00
                LDA:    d_spd
                INC
                STA:    d_spd
                LDA:    curr_val,Y
                AND     #$00FF
                BEQ     @ss_done                    ; 0 -> ignore (no stop)
                CMP     #$20
                BCS     @ss_done                    ; >=$20 -> BPM, deferred
                STA:    speed                       ; 1..$1F ticks per row
@ss_done        RTS

;------------------------------------------------------------------------------
; se_posjump - $0B position jump. pend_jump=2, param=val&$7F. Applied at end of
; the current row (song loop). Counts d_pj. (Reference setup_positionjump :2759.)
;------------------------------------------------------------------------------
se_posjump      MX      %00
                LDA:    d_pj
                INC
                STA:    d_pj
                LDA:    curr_val,Y
                AND     #$007F                      ; legal 0..127
                STA:    pend_jump_param
                LDA     #2
                STA:    pend_jump
                RTS

;------------------------------------------------------------------------------
; se_break - $0D pattern break. pend_jump=4, param = decoded start row in the
; NEXT pattern (Dxy -> hi*10+lo, ProTracker decimal), clamped 0..63. Counts d_br.
; (Reference setup_patternbreak :2771.)
;------------------------------------------------------------------------------
se_break        MX      %00
                LDA:    d_br
                INC
                STA:    d_br
                LDA:    curr_val,Y                  ; hi*10 = (hi*16)>>1 + (hi*16)>>3
                AND     #$00F0                      ; hi*16
                LSR                                 ; hi*8
                STA:    sb_tmp
                LSR
                LSR                                 ; hi*2
                CLC
                ADC:    sb_tmp                      ; hi*2 + hi*8 = hi*10
                STA:    sb_tmp
                LDA:    curr_val,Y
                AND     #$000F                      ; lo
                CLC
                ADC:    sb_tmp                      ; hi*10 + lo
                CMP     #64
                BCC     @br_ok
                LDA     #0                          ; out of range -> row 0
@br_ok          STA:    pend_jump_param
                LDA     #4
                STA:    pend_jump
                RTS

;------------------------------------------------------------------------------
; note_to_freq - A.lo = 1-based note index; returns A = 16-bit DOC freq word for
; the current note's finetune (cur_finetune).  Chains note_to_ptr -> ptr_to_freq.
;------------------------------------------------------------------------------
note_to_freq    MX      %00
                JSR     note_to_ptr
                ; fall through into ptr_to_freq
;------------------------------------------------------------------------------
; ptr_to_freq - A = freq-table byte offset (curr_ptr); returns A = 16-bit DOC freq.
; Used by pitch effects after they bend curr_ptr. MX %00. Clobbers X.
;------------------------------------------------------------------------------
ptr_to_freq     MX      %00
                TAX
                LDA:    freq_finetune,X
                RTS
;------------------------------------------------------------------------------
; note_to_ptr - A = 1-based note index; returns A = freq-table byte offset for the
; current finetune (cur_finetune). The index slid by 01/02/03. MX %00. Clobbers X.
;------------------------------------------------------------------------------
note_to_ptr     MX      %00
                AND     #$00FF
                ASL                                 ; note * 2 (word index)
                STA:    nf_tmp
                LDA:    cur_finetune
                AND     #$000F
                ASL                                 ; finetune * 2 (word index into offset table)
                TAX
                LDA:    note_freq_ptrs_offset,X     ; byte offset of this finetune's block
                CLC
                ADC:    nf_tmp                      ; + note*2
                TAX
                LDA:    note_freq_ptrs,X            ; -> byte offset into freq_finetune (curr_ptr)
                RTS

;------------------------------------------------------------------------------
; load_pattern - load the pattern at the current songpos and set up its row
; cursor.  cur_pat = orderbuf[songpos]; read_pattern; row = start_row; patptr =
; start_row*rowstep; consume start_row.  Prints "pat NN" (foreground only).
; Returns C=1 on success, C=0 if read_pattern failed (caller ends the song).
; MX %00.  Clobbers A,X,Y.
;------------------------------------------------------------------------------
load_pattern    MX      %00
                LDX:    songpos
                LDA:    orderbuf,X
                AND     #$00FF
                STA:    cur_pat
                JSR     read_pattern
                BCC     @lp_fail
@lp_norow       LDA:    start_row
                STA:    row
                STZ:    patptr
                LDA:    start_row
                BEQ     @lp_rowset
                TAX                                 ; X = start_row (row count)
@lp_patmul      LDA:    patptr
                CLC
                ADC:    rowstep
                STA:    patptr
                DEX
                BNE     @lp_patmul
@lp_rowset      STZ:    start_row                   ; consume (default 0 next pattern)
                SEC
                RTS
@lp_fail        CLC
                RTS

;------------------------------------------------------------------------------
; read_pattern - read pattern number cur_pat into pattbuf. MX %00.
;   patoff = patbase + cur_pat*patstep ; raw lseek (lsfd) ; fread patstep bytes.
;   Returns C=1 on success, C=0 on lseek/short-read (caller treats as song end).
;   Reuses patbase/patstep/lsfd established during the parse. Clobbers A,X,Y.
;------------------------------------------------------------------------------
read_pattern    MX      %00
                LDA:    res_ok
                BNE     @rp_resident                ; resident: copy from the MM block
                CLC                                 ; no resident block -> song ends (the disk
                RTS                                 ;   fallback is retired; load path is C)

;------------------------------------------------------------------------------
; read_pattern (resident path): src = res_base + cur_pat*patstep; copy patstep
; bytes into pattbuf via res_to_pat (cross-bank safe).  No disk I/O.
;------------------------------------------------------------------------------
@rp_resident    LDA:    res_base
                STA:    patoff
                LDA:    res_base+2
                STA:    patoff+2
                LDA:    cur_pat
                AND     #$00FF
                STA:    patcount
                BEQ     @rp_rcpy
@rp_rmul        CLC
                LDA:    patoff
                ADC:    patstep
                STA:    patoff
                LDA:    patoff+2
                ADC     #0
                STA:    patoff+2
                LDA:    patcount
                DEC
                STA:    patcount
                BNE     @rp_rmul
@rp_rcpy        JSR     res_to_pat                  ; [patoff] -> pattbuf (patstep B)
                SEC
                RTS

;------------------------------------------------------------------------------
; res_to_pat / pat_to_res - copy patstep bytes between pattbuf (this bank, DBR)
; and a 24-bit address in the resident MM block.  The block may span banks, so
; long-indexed (,X) addressing carries into the bank.  The 24-bit resident
; address rides in patoff (res_to_pat source) / res_dst (pat_to_res dest); each
; helper self-patches its own LDAL/STAL operand.  MX %00 in; clobbers A,X.
;------------------------------------------------------------------------------
res_to_pat      MX      %00
                LDA:    patoff                      ; read the 24-bit src (seg1) into regs,
                LDX:    patoff+2                    ;   then flip DBR->seg0 to patch the operand
                PHB
                PHK
                PLB                                 ; DBR = seg0 (LDAL operand lives in code)
                STA:    @r2p_ld+1
                SEP     #$20
                MX      %10
                TXA
                STA:    @r2p_ld+3
                PLB                                 ; DBR = seg1 (stay MX %10 = 8-bit byte copy)
                LDX     #0
@r2p_loop
@r2p_ld         LDAL    $000000,X                   ; [patoff + X] byte, operand self-patched
                STA:    pattbuf,X
                INX
                CPX:    patstep
                BCC     @r2p_loop
                REP     #$30
                MX      %00
                RTS
setosc          MX      %10
                PHA                                 ; save value
                TXA                                 ; A = offset (X.lo)
                CLC
                ADC:    voc                         ; + voice oscillator
                TAX                                 ; X.lo = register number
                PLA                                 ; A = value
                JMP     setreg                      ; tail call (setreg RTS returns to caller)

;------------------------------------------------------------------------------
; write_vol - rewrite the DOC volume register(s) for track Y/2 from curr_vol[Y].
; Caller MX %10, register-access mode selected. Y = track index*2. Scales the
; per-track MOD volume 0..64 -> DOC 0..255 (x4, clamp 255) and writes vol reg
; $40+track_osc[Y]; if trk_nosc[Y]=2 (swap pair) also $40+track_osc[Y]+1. Used by
; effects to reshape a sounding voice. Clobbers A,X. Preserves Y.
;------------------------------------------------------------------------------
write_vol       MX      %10
                PHY
                REP     #$20                        ; scale in 16-bit
                MX      %00
                LDA:    curr_vol,Y
                AND     #$00FF
                ASL                                 ; x4
                ASL
                CMP     #$0100
                BCC     @wv_ok
                LDA     #$00FF
@wv_ok          MX      %00
                STA:    wv_scaled
                ; --- streaming voice? vol -> osc B (sample); osc A (timer) stays
                ;     muted.  Placed voice: osc A (+ osc B if a swap pair). ---
                LDA:    track_osc,Y
                AND     #$00FF
                TAX                                 ; X = osc A#
                SEP     #$20
                MX      %10
                LDA:    osc_job_tbl,X
                CMP     #JOB_STREAM
                BNE     @wv_placed
                REP     #$20                        ; streaming: write osc B only
                MX      %00
                LDA:    track_osc,Y
                INC
                STA:    voc
                SEP     #$20
                MX      %10
                LDX     #$40
                LDA:    wv_scaled
                JSR     setosc
                BRA     @wv_done
@wv_placed      MX      %10
                REP     #$20
                MX      %00
                LDA:    track_osc,Y                 ; placed: osc A volume
                STA:    voc
                SEP     #$20
                MX      %10
                LDX     #$40
                LDA:    wv_scaled
                JSR     setosc
                LDA:    trk_nosc,Y                  ; swap pair -> osc B vol too
                CMP     #2
                BNE     @wv_done
                LDA:    voc
                INC
                STA:    voc
                LDX     #$40
                LDA:    wv_scaled
                JSR     setosc
@wv_done        MX      %10
                PLY
                RTS

;------------------------------------------------------------------------------
; trigger_voice - start a note on the current track's oscillator(s).
; Caller: MX %10, register-access mode selected. Inputs (data cells): cur_osc
; (base oscillator), cur_chan (channel bits <<4), curfreq, cur_type, cur_docptr,
; cur_docsize, cur_vol. Mode mirrors NTP+ generate_osc_settings:
;   SINGLE (type&3==0) ............ one-shot, 1 osc (ctl $02)
;   looped+optimal (type&4) ....... free-run,  1 osc (ctl $00)
;   looped non-optimal ............ swap pair (osc base=$06 / base+1=$07)
; All control bytes OR in cur_chan for stereo. Clobbers A,X.
;------------------------------------------------------------------------------
trigger_voice   MX      %10
                ; v1a.3c: a PLACED voice clears any stale stream job on its osc(s)
                ; (this track may have streamed a previous note).
                REP     #$30
                MX      %00
                LDA:    cur_osc
                AND     #$00FF
                TAX
                SEP     #$20
                MX      %10
                STZ:    osc_job_tbl,X               ; clear osc A's job
                REP     #$30
                MX      %00
                LDA:    trkidx2
                ASL
                TAX
                LDA:    trk_nosc,X                  ; swap pair -> clear osc A+1 too
                CMP     #2
                BNE     @tv_jobDone
                LDA:    cur_osc
                INC
                AND     #$00FF
                TAX
                SEP     #$20
                MX      %10
                STZ:    osc_job_tbl,X
                REP     #$30
                MX      %00
@tv_jobDone     SEP     #$20
                MX      %10
                ; ---- program oscillator A (base) ----
                LDA:    cur_osc
                STA:    voc
                LDX     #$A0                        ; halt A first (clean retrigger)
                LDA     #$01
                JSR     setosc
                LDX     #$00                        ; freq low
                LDA:    curfreq
                JSR     setosc
                LDX     #$20                        ; freq high
                LDA:    curfreq+1
                JSR     setosc
                LDX     #$80                        ; wavetable pointer (page)
                LDA:    cur_docptr
                JSR     setosc
                LDX     #$C0                        ; wavetable size/resolution
                LDA:    cur_docsize
                JSR     setosc
                LDX     #$40                        ; volume
                LDA:    cur_vol
                JSR     setosc
                ; ---- mode dispatch ----
                LDA:    cur_type
                AND     #$01                        ; odd type (1 looped / 3 loop) = loop
                BEQ     @tvOneShot
                LDA:    cur_type
                AND     #$04                        ; optimal-size loop?
                BNE     @tvFreeRun
                ; ---- swap pair: program osc B (base+1) then swap control bytes ----
                LDA:    cur_osc
                INC
                STA:    voc                         ; voc = base+1
                LDX     #$A0                        ; halt B first
                LDA     #$01
                JSR     setosc
                LDX     #$00
                LDA:    curfreq
                JSR     setosc
                LDX     #$20
                LDA:    curfreq+1
                JSR     setosc
                LDX     #$80
                LDA:    cur_docptr
                JSR     setosc
                LDX     #$C0
                LDA:    cur_docsize
                JSR     setosc
                LDX     #$40
                LDA:    cur_vol
                JSR     setosc
                LDX     #$A0                        ; B ctl = swap, armed ($07) | chan
                LDA     #$07
                ORA:    cur_chan
                JSR     setosc
                LDA:    cur_osc                     ; back to osc A
                STA:    voc
                LDX     #$A0                        ; A ctl = swap, running ($06) | chan
                LDA     #$06
                ORA:    cur_chan
                JSR     setosc
                RTS
@tvFreeRun      ; free-run, 1 osc (optimal-size loop wraps cleanly)
                LDX     #$A0
                LDA     #$00                        ; mode 00 (free-run), running
                ORA:    cur_chan
                JSR     setosc
                RTS
@tvOneShot      ; one-shot, 1 osc (SINGLE, or unresolved LOOPHEADER)
                LDX     #$A0
                LDA     #$02                        ; mode 01 (one-shot), running
                ORA:    cur_chan
                JSR     setosc
                RTS

;------------------------------------------------------------------------------
; trigger_stream - start a streamed note (v1a.3c).  Streamed voice = timer osc A
; (cur_osc; plays the $FF wave 256B/res0, free-run+IE -> drives refills, vol 0) +
; sample osc B (cur_osc+1; plays the 2-page stream buffer 512B/res1, free-run).
; Seeds the pool read pointer, fills both buffer pages, programs both oscs, flags
; osc A JOB_STREAM.  Inputs: cur_ins, trkidx2, cur_osc, curfreq, cur_vol,
; cur_chan, cur_docptr(=stream buf base).  Caller MX %10, register-access mode.
;------------------------------------------------------------------------------
trigger_stream  MX      %10
                ; --- seed strm_ptr[trk]=pool_base+ins_pooloff[ins]; strm_end=+ins_len ---
                REP     #$30
                MX      %00
                LDA:    cur_ins
                ASL
                TAX                                 ; X = cur_ins*2
                LDA:    trkidx2
                ASL
                TAY                                 ; Y = trk*2
                CLC
                LDA:    pool_base
                ADC:    ins_pooloff_lo,X
                STA:    strm_ptr_lo,Y
                LDA:    pool_base+2
                AND     #$00FF
                ADC:    ins_pooloff_hi,X
                STA:    strm_ptr_hi,Y
                LDA:    ins_rep_len_lo,X            ; loop length + looped flag
                STA:    strm_replen_lo,Y
                LDA:    ins_rep_len_hi,X
                STA:    strm_replen_hi,Y
                LDA:    ins_type,X
                AND     #$0001
                STA:    strm_looped,Y              ; (STA preserves Z from the AND)
                ; --- strm_end: looped -> strm_ptr + rep_ptr + rep_len, so the loop-back
                ;     by rep_len in interrupt_stream lands on the file's loop start
                ;     (rep_ptr); one-shot -> strm_ptr + total length.  Mirrors NTP+
                ;     setup_instrument_ptrs (was unconditionally total length: looped
                ;     samples looped the wrong region + a post-loop tail -> distortion). ---
                BEQ     @tsEndOne
                CLC                                 ; looped: end = strm_ptr + rep_ptr
                LDA:    strm_ptr_lo,Y
                ADC:    ins_rep_ptr_lo,X
                STA:    strm_end_lo,Y
                LDA:    strm_ptr_hi,Y
                ADC:    ins_rep_ptr_hi,X
                STA:    strm_end_hi,Y
                CLC                                 ;            + rep_len
                LDA:    strm_end_lo,Y
                ADC:    ins_rep_len_lo,X
                STA:    strm_end_lo,Y
                LDA:    strm_end_hi,Y
                ADC:    ins_rep_len_hi,X
                STA:    strm_end_hi,Y
                BRA     @tsEndDone
@tsEndOne       CLC                                 ; one-shot: end = strm_ptr + total len
                LDA:    strm_ptr_lo,Y
                ADC:    ins_len_lo,X
                STA:    strm_end_lo,Y
                LDA:    strm_ptr_hi,Y
                ADC:    ins_len_hi,X
                STA:    strm_end_hi,Y
@tsEndDone      MX      %00
                LDA     #0                          ; (STZ abs,Y not a valid mode)
                STA:    strm_pg_off,Y
                ; --- fill both buffer pages (512 B) from the pool ---
                LDA:    strm_base_pg,Y
                STA:    strm_dst_pg
                LDA     #512
                STA:    strm_cnt
                SEP     #$20                        ; MX %10 (8-bit A, 16-bit X/Y)
                MX      %10
                JSR     strm_copy                   ; fills 2 pages, advances strm_ptr[Y]
                JSR     docwait                     ; re-select register access (strm_copy left RAM)
                LDA:    master_vol
                ORA     #$20
                STAL    SOUND_CTL
                ; --- program osc A (timer): $FF wave, 256B/res0, free-run+IE, vol 0 ---
                LDA:    cur_osc
                STA:    voc
                LDX     #$A0
                LDA     #$01                        ; halt A first
                JSR     setosc
                LDX     #$00
                LDA:    curfreq
                JSR     setosc
                LDX     #$20
                LDA:    curfreq+1
                JSR     setosc
                LDX     #$80
                LDA     #TIMER_PAGE                 ; wavetable = $FF (timer wave)
                JSR     setosc
                LDX     #$C0
                LDA     #STRM_A_SIZE
                JSR     setosc
                LDX     #$40
                LDA     #$00                        ; timer is silent
                JSR     setosc
                ; --- program osc B (sample): stream buffer, 512B/res1, free-run, vol ---
                LDA:    cur_osc
                INC
                STA:    voc                         ; voc = osc B = base+1
                LDX     #$A0
                LDA     #$01                        ; halt B first
                JSR     setosc
                LDX     #$00
                LDA:    curfreq
                JSR     setosc
                LDX     #$20
                LDA:    curfreq+1
                JSR     setosc
                LDX     #$80
                LDA:    cur_docptr                  ; wavetable = stream buffer base page
                JSR     setosc
                LDX     #$C0
                LDA     #STRM_B_SIZE
                JSR     setosc
                LDX     #$40
                LDA:    cur_vol
                JSR     setosc
                ; --- start both (B first, free-run + chan; then A, free-run + IE) ---
                LDX     #$A0
                LDA     #$00                        ; B ctl = free-run (mode 00) | chan
                ORA:    cur_chan
                JSR     setosc
                LDA:    cur_osc
                STA:    voc                         ; back to osc A
                LDX     #$A0
                LDA     #STRM_A_CTL                 ; A ctl = $08 free-run + IE
                JSR     setosc
                ; --- flag osc A as the JOB_STREAM IRQ source for this track ---
                REP     #$30
                MX      %00
                LDA:    cur_osc
                AND     #$00FF
                TAX                                 ; X = osc A#
                SEP     #$20
                MX      %10
                LDA     #JOB_STREAM
                STA:    osc_job_tbl,X
                LDA:    trkidx2
                ASL
                STA:    osc_strm_trk,X              ; osc A -> trk*2
                REP     #$30                        ; osc B carries no job
                MX      %00
                LDA:    cur_osc
                INC
                AND     #$00FF
                TAX
                SEP     #$20
                MX      %10
                STZ:    osc_job_tbl,X
                RTS

;------------------------------------------------------------------------------
; strm_copy - copy strm_cnt bytes (256 or 512) from the pool (strm_ptr[Y], 24-bit;
; may span banks) to DOC RAM from page strm_dst_pg, then advance strm_ptr[Y].
; Y = track*2.  Caller MX %10 (16-bit X/Y).  Leaves DOC in RAM-access mode.
;------------------------------------------------------------------------------
strm_copy       MX      %10
                JSR     docwait
                LDA     #$6F                        ; RAM access + autoinc
                STAL    SOUND_CTL
                JSR     docwait
                LDA     #$00
                STAL    SOUND_ADRL
                JSR     docwait
                LDA:    strm_dst_pg                 ; high byte of the DOC address = page
                STAL    SOUND_ADRH
                REP     #$20                        ; self-patch source operand from strm_ptr[Y]
                MX      %00
                LDA:    strm_ptr_lo,Y               ; read the 24-bit pool src into regs, then
                LDX:    strm_ptr_hi,Y               ;   flip DBR->seg0 to patch the LDAL operand
                PHB
                PHK
                PLB                                 ; DBR = seg0 (operand lives in code)
                STA:    @stc_src+1
                SEP     #$20
                MX      %10
                TXA
                STA:    @stc_src+3
                PLB                                 ; DBR = seg1
                LDX     #0
@stc_loop       MX      %10
@stc_src        LDAL    $000000,X                   ; [strm_ptr + X], operand self-patched
                STAL    SOUND_DATA                  ; DOC RAM write (autoincrements)
                INX
                CPX:    strm_cnt
                BCC     @stc_loop
                REP     #$30                        ; strm_ptr[Y] += strm_cnt
                MX      %00
                CLC
                LDA:    strm_ptr_lo,Y
                ADC:    strm_cnt
                STA:    strm_ptr_lo,Y
                LDA:    strm_ptr_hi,Y
                ADC     #0
                STA:    strm_ptr_hi,Y
                SEP     #$20
                MX      %10
                RTS

;------------------------------------------------------------------------------
; docwait - busy-wait until GLU not busy (bit7 of $C03C clear). Preserves A.
; Caller MX %10. (Copied from doctone.s.)
;------------------------------------------------------------------------------
docwait         MX      %10
                PHA
@dw             LDAL    SOUND_CTL
                BMI     @dw
                PLA
                RTS

;------------------------------------------------------------------------------
; setreg - write DOC register: X.lo = reg#, A.lo = value. Caller MX %10,
; register access mode already selected. (Copied from doctone.s.)
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

;------------------------------------------------------------------------------
