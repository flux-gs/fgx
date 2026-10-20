;==============================================================================
; log.s - FGX kernel log ring buffer.
;
; Public:
;   Kern_LogInit       One-time init (called before any logger).  Zeros
;                      _kernLogHead and _kernLogWrap.  The buffer itself
;                      is zero-filled by _KMem_ClearGlobals (see memmap.s).
;   Kern_LogStr        Append null-term string at _conStrPtr + $0A.
;   Kern_LogStrNoEOL   Append string without trailing newline.
;   Kern_LogStrLongNoEOL  Same, but reads via 24-bit _logSrcPtr (heap-aware).
;   Kern_LogHex8       Append 2 hex digits of A's low byte (no newline).
;   Kern_LogHex16      Append 4 hex digits of A (no newline).
;   Kern_LogEOL        Append $0A.
;
; Conventions:
;   - Every public entry is PHP/PLP wrapped; caller's M/X widths preserved.
;   - String pointer is a kernel-bank word in _conStrPtr (DP).  DBR = kernel-bank.
;   - Buffer wraps at KMEM_LOGBUF_SIZE (see memmap.s); sets _kernLogWrap once wrapped.
;==============================================================================

                MX      %00

;------------------------------------------------------------------------------
; Kern_LogInit - zero ring-buffer state words.  Buffer data already
; zero-filled by _KMem_ClearGlobals.
;------------------------------------------------------------------------------
Kern_LogInit    MX      %00
                PHP
                REP     #$30
                MX      %00
                LDA     #$0000
                STA    |_kernLogHead
                ; _kLogBufPtr = 0 until _AllocLogBuf runs (after Kmem_Init).
                ; While 0, _kernLogPutByte skips the ring (mirror-only), so the
                ; few pre-allocator boot logs can't corrupt low memory.  DP is
                ; FGX_DP_KERNEL here (set in FGX_Entry), so the DP store is safe.
                STZ     _kLogBufPtr
                SEP     #$20
                MX      %10
                LDA     #$00
                STA    |_kernLogWrap
                STZ     _kLogBufPtr+2           ; bank byte = 0 (the guard test)
                PLP
                RTS

;------------------------------------------------------------------------------
; _kernLogPutByte - append A (8-bit) to ring buffer.  Advances
; _kernLogHead; sets _kernLogWrap on wrap past KMEM_LOGBUF_SIZE.
;
; Input:  A = byte to append (M=1 expected).
; Preserves: X, Y, DBR.  Clobbers: A, flags.
;
; DBR discipline: the ring-write path uses abs (DBR-relative) addressing
; for _kernLogHead/_kernLogWrap, and Con_PutChar (mirror) also reads
; CON_VT_STATE via DBR-relative abs.  Module callers (hello, prodos)
; enter SYS_KERNLOG after PHK/PLB with DBR=module_bank — without the
; PHB/PHK/PLB wrap below, head reads/writes hit the wrong bank, so
; module log bytes overwrite ring offset 0 every time the module logs
; (because $module_bank:EE97 is fresh-zero).  PHB+PHK+PLB establishes
; DBR=kernel-bank for the entire routine; PLB at exit restores caller's DBR.
;------------------------------------------------------------------------------
; Ring buffer now lives in the heap (Kmalloc'd, _kLogBufPtr long-ptr).  The
; write uses [_kLogBufPtr],Y, so the head index moved from X to Y; caller's
; X AND Y are both preserved (Kern_LogStr's loop index is Y).  If _kLogBufPtr
; is still 0 (pre-_AllocLogBuf boot), the ring write is skipped (mirror only).
; DP must be FGX_DP_KERNEL (it always is at log call sites — boot keeps it,
; the dispatcher restores it before module SYS_KERNLOG).
_kernLogPutByte MX      %10
                PHB                             ; save caller DBR
                PHK                             ; push PB (live kernel bank; $02 = assembly ORG)
                PLB                             ; DBR = kernel-bank
                PHX                             ; preserve caller X
                PHY                             ; preserve caller Y
                PHA                             ; save byte (1,S) across ring + mirror
                REP     #$10
                MX      %10
                LDA     _kLogBufPtr+2           ; ring allocated? (bank byte, dp)
                BEQ     @klp_skipring           ; 0 -> pre-alloc boot; mirror only
                LDY     _kernLogHead            ; head -> Y (abs, DBR=kernel-bank)
                LDA     1,S                     ; reload byte (guard test clobbered A)
                STA     [_kLogBufPtr],Y         ; append to heap ring buffer
                INY
                CPY     #KMEM_LOGBUF_SIZE       ; wrap at ring-buffer size
                BCC     @klp_headok
                LDY     #0
                LDA     #$01
                STA    |_kernLogWrap
@klp_headok     STY     _kernLogHead

@klp_skipring   ; Mirror to live console if enabled.  ONLCR: a log LF ($0A)
                ; emits CR+LF so the true-VT console advances to col 0 of the
                ; next row (the dmesg ring buffer itself stays LF-native).
                LDA    |_kernLogMirror
                BEQ     @klp_noMirror
                PLA                             ; A = byte (M=1, 1 B from stack)
                CMP     #$0A
                BNE     @klp_emit               ; non-LF → emit verbatim
                ; LF: emit CR first, then fall through to emit the LF.
                REP     #$20
                MX      %00
                LDA     #$000D
_kfp105         JSL     KFAR_CON_PUTCHAR        ; clobbers X/Y (restored at exit)
                LDA     #$000A
                BRA     @klp_emit2
@klp_emit       ; Con_PutChar wants MX %00 + A.lo = char.  It clobbers X/Y;
                ; the entry PHX/PHY + exit PLY/PLX cover that.  DBR is kernel-bank
                ; from the entry PHB/PHK/PLB, so CON_VT_STATE access works.
                REP     #$20
                MX      %00
                AND     #$00FF
@klp_emit2
_kfp200         JSL     KFAR_CON_PUTCHAR
                SEP     #$20
                MX      %10
                PLY                             ; restore caller's Y
                PLX                             ; restore caller's X
                PLB                             ; restore caller DBR
                RTS

@klp_noMirror   PLA                             ; discard saved byte
                PLY                             ; restore caller's Y
                PLX                             ; restore caller's X
                PLB                             ; restore caller DBR
                RTS

;------------------------------------------------------------------------------
; Kern_LogStr - append null-term string + $0A.
;
; Input:  _conStrPtr (DP word) = ptr to string in the kernel bank.
; Preserves caller M/X widths.  Clobbers A, Y.
;------------------------------------------------------------------------------
Kern_LogStr     ENT                     ; cross-segment: blkcache.s probe logs
                MX      %00
                PHP
                REP     #$30
                MX      %00
                SEP     #$20
                MX      %10
                LDY     #0
@kls_L          LDA     (_conStrPtr),Y
                BEQ     @kls_done
                JSR     _kernLogPutByte
                INY
                BRA     @kls_L
@kls_done       MX      %10
                LDA     #$0A                    ; trailing newline (per docstring)
                JSR     _kernLogPutByte
                PLP
                RTS

;------------------------------------------------------------------------------
; Kern_LogStrNoEOL - append null-term string (no newline).  Use to
; compose "prefix: $XX" lines: LogStrNoEOL + LogHex8/16 + LogEOL.
;------------------------------------------------------------------------------
Kern_LogStrNoEOL ENT             ; cross-segment: block.s's boot-drive line
                                MX      %00
                PHP
                REP     #$30
                MX      %00
                SEP     #$20
                MX      %10
                LDY     #0
@klsn_L         LDA     (_conStrPtr),Y
                BEQ     @klsn_done
                JSR     _kernLogPutByte
                INY
                BRA     @klsn_L
@klsn_done      MX      %10
                PLP
                RTS

;------------------------------------------------------------------------------
; Kern_LogStrLongNoEOL - append null-term string read via 24-bit ptr.
;
; Input:  _logSrcPtr (DP, 3 bytes) = full long pointer to string.  Used when
;         the source string lives outside the kernel bank (e.g. heap
;         allocations in bank $05+).
;------------------------------------------------------------------------------
Kern_LogStrLongNoEOL MX %00
                PHP
                REP     #$30
                MX      %00
                SEP     #$20
                MX      %10
                LDY     #0
@klsl_L         LDA     [_logSrcPtr],Y
                BEQ     @klsl_done
                JSR     _kernLogPutByte
                INY
                BRA     @klsl_L
@klsl_done      MX      %10
                PLP
                RTS

;------------------------------------------------------------------------------
; Kern_LogEOL - append $0A.
;------------------------------------------------------------------------------
Kern_LogEOL
                MX      %00
                PHP
                SEP     #$20
                MX      %10
                LDA     #$0A
                JSR     _kernLogPutByte
                PLP
                RTS

;------------------------------------------------------------------------------
; Kern_LogHex8 - append 2 hex digits of A's low byte.
; Caller: M=0 or M=1 both OK; routine sets M=1 internally.
;------------------------------------------------------------------------------
Kern_LogHex8
                MX      %00
                PHP
                SEP     #$20
                MX      %10
                PHA
                LSR
                LSR
                LSR
                LSR
                JSR     _hexNibble
                PLA
                AND     #$0F
                JSR     _hexNibble
                PLP
                RTS

;------------------------------------------------------------------------------
; Kern_LogHex16 - append 4 hex digits of A.  Caller is at M=0.
;------------------------------------------------------------------------------
Kern_LogHex16
                MX      %00
                PHP
                REP     #$20
                MX      %00
                PHA                             ; save 16-bit
                XBA                             ; swap bytes: high now in low
                SEP     #$20
                MX      %10
                PHA
                LSR
                LSR
                LSR
                LSR
                JSR     _hexNibble
                PLA
                AND     #$0F
                JSR     _hexNibble
                REP     #$20
                MX      %00
                PLA                             ; restore full 16-bit value
                SEP     #$20
                MX      %10
                PHA
                LSR
                LSR
                LSR
                LSR
                JSR     _hexNibble
                PLA
                AND     #$0F
                JSR     _hexNibble
                PLP
                RTS

;------------------------------------------------------------------------------
; Kern_LogDec16 - append A (16-bit unsigned) as decimal, no leading zeros.
; Kern_LogDec32 - the same for X:A (X = high word), which is what a SmartPort
; block count needs: it is three bytes (Firmware Reference p.123).
; Caller at M=0.  Power-of-10 trial subtraction, at most nine per place.
;
; Scratch: _klogDecVal (running LOW word), _klogDecLead (leading-zero flag);
; the running HIGH word lives on the stack for the call.
;------------------------------------------------------------------------------
Kern_LogDec16 ENT             ; cross-segment: block.s's boot-drive line
                MX      %00
                LDX     #0                      ; high word 0
Kern_LogDec32 ENT
                MX      %00
                PHP
                REP     #$30
                MX      %00
                STA    |_klogDecVal
                PHX                             ; running high word, at 1,S
                SEP     #$20
                MX      %10
                STZ     _klogDecLead            ; 0 = still suppressing leading zeros
                REP     #$30
                MX      %00
                LDX     #0                      ; power-table byte index, by 4
@kd_pow         LDY     #0                      ; digit counter for this place
@kd_sub         LDA     _klogDecVal             ; value - power, 32 bits
                SEC
                SBC     _klogPow10,X
                PHA                             ; low word of the difference
                LDA     3,S                     ; running high word
                SBC     _klogPow10+2,X
                BCC     @kd_under               ; value < power: this place is done
                STA     3,S
                PLA
                STA    |_klogDecVal
                INY                             ; Y = quotient digit
                BRA     @kd_sub
@kd_under       PLA                             ; drop the difference
@kd_emit        ; Y = digit for this place (0..9).  Emit if nonzero or
                ; leading-zero suppression already broken.
                TYA
                AND     #$00FF
                BNE     @kd_doEmit
                SEP     #$20
                MX      %10
                LDA     _klogDecLead
                BNE     @kd_doEmit8             ; lead broken → emit even a 0
                REP     #$30
                MX      %00
                BRA     @kd_next
@kd_doEmit      SEP     #$20
                MX      %10
@kd_doEmit8     LDA     #1
                STA     _klogDecLead
                TYA                             ; digit (low byte)
                CLC
                ADC     #'0'
                JSR     _kernLogPutByte
                REP     #$30
                MX      %00
@kd_next        INX
                INX
                INX
                INX
                CPX     #36                     ; 9 powers (10^9 .. 10)
                BCC     @kd_pow
                ; Units digit: _klogDecVal is now 0..9.  Always emit.
                SEP     #$20
                MX      %10
                LDA    |_klogDecVal
                CLC
                ADC     #'0'
                JSR     _kernLogPutByte
                REP     #$30
                MX      %00
                PLX                             ; drop the running high word
                PLP
                RTS
_klogPow10      ADRL    1000000000,100000000,10000000,1000000
                ADRL    100000,10000,1000,100,10

;------------------------------------------------------------------------------
; _hexNibble - convert A (0..15) to ASCII and append.
;------------------------------------------------------------------------------
_hexNibble      MX      %10
                CMP     #10
                BCC     @hn_digit
                CLC
                ADC     #$07                    ; 'A'-10-'0' = $41-10-$30 = 7
@hn_digit       MX      %10
                CLC
                ADC     #'0'
                JMP     _kernLogPutByte

;==============================================================================
; Kern_LogReplay - stream what is already in the ring to the console.
;
; _BootScreen is what sets _kernLogMirror, and it runs at main.s:438.  Fs_Init
; runs at main.s:307 and Dev_Init at :304, so EVERYTHING they log reaches the
; ring and nothing else:
;
;   fs: /VOL on sNdM          the BOOT volume's own mount -- the one line that
;                             says what the machine actually booted from
;   bus N: slot M entry=$..   every SmartPort controller past the boot bus
;   dev NN: sMdU blk=$....    every unit on them
;   INODEPROBE / BLKPROBE     the boot self-tests' verdicts
;
; dmesg(1) can fetch them AFTER boot -- but only from a shell, and a boot that
; dies before init has none.  That is the apple/fgx#111 case exactly: the
; visible screen is a strict SUFFIX of the log, the part it drops is precisely
; the device inventory, and the failure was diagnosed from a photograph that
; could not show it.  Reconstructing the topology from source cost two wrong
; conclusions.
;
; Emits ring[0..head), or ring[head..SIZE)+ring[0..head) once it has wrapped,
; straight through KFAR_CON_PUTCHAR -- NOT through _kernLogPutByte, which would
; append the replay to the ring it is reading.  Same ONLCR the mirror applies.
;
; Caller: _BootScreen, after CON_INIT and before _kernLogMirror is set.
; Preserves caller M/X widths and DBR.
;==============================================================================
Kern_LogReplay  ENT
                MX      %00
                PHP
                PHB
                PHK
                PLB                             ; DBR = kernel bank
                REP     #$30
                MX      %00
                SEP     #$20
                MX      %10
                LDA     _kLogBufPtr+2           ; ring allocated? (bank byte)
                BNE     @klr_have               ; pre-_AllocLogBuf: nothing to say
                JMP     @klr_done               ;   (the filter put the tail out
@klr_have       MX      %10                            ;    of a branch's reach)
                LDA    |_kernLogWrap
                REP     #$30
                MX      %00
                AND     #$00FF
                BEQ     @klr_linear
                LDX     #KMEM_LOGBUF_SIZE       ; wrapped: the whole ring...
                LDY     _kernLogHead            ; ...oldest byte is at the head
                BRA     @klr_loop
@klr_linear     LDX     _kernLogHead            ; else just [0..head)
                LDY     #0
@klr_loop       MX      %00
                CPX     #0
                BEQ     @klr_done
                SEP     #$20
                MX      %10
                LDA     [_kLogBufPtr],Y
                REP     #$20
                MX      %00
                AND     #$00FF
                PHX                             ; CON_PUTCHAR clobbers X/Y
                PHY
                CMP     #$000A
                BNE     @klr_emit
                LDA     #$000D                  ; ONLCR, exactly as the mirror does
_kfp360         JSL     KFAR_CON_PUTCHAR
                LDA     #$000A
@klr_emit       MX      %00
_kfp361         JSL     KFAR_CON_PUTCHAR
                PLY
                PLX
                INY
                CPY     #KMEM_LOGBUF_SIZE
                BCC     @klr_next
                LDY     #0                      ; wrap the read cursor
@klr_next       DEX
                BRA     @klr_loop
@klr_done       MX      %00
                PLB
                PLP
                RTS

;==============================================================================
; END log.s
;==============================================================================
