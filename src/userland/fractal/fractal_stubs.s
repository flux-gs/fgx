;==============================================================================
; fractal_stubs.s - companion asm for fractal.c (SHR hardware access).
;
; These stubs do the SHR/SCB/palette writes with 24-bit STAL, as
; ntpplay_stubs.s drives the DOC. PUT into seg0 by the FGX2 build (src/userland/fractal/fractal_stubs.s is
; auto-staged as <name>_stubs.s). Each entry is JSL'd from C with DBR = seg1
; data bank, so `LDA: <cglobal>` reads the C globals; each returns RTL.
;
; Inputs/outputs travel through C globals (seg1), not stack args:
;   g_row[160]  current scanline, 4bpp packed (2 px/byte, hi nibble = left)
;   g_pal[32]   palette 0 contents (16 colors x 2 bytes)
;   g_off       int: dest byte offset into SHR for the current row (y*160)
;==============================================================================

; Write the bank-$01 SHR SHADOW SOURCE (as the FGX console does), not $E1
; directly. FGX keeps SHR shadowing ON, so bank-$01 $2000-$9FFF mirrors to the
; $E1 display page automatically -- and the console/harness both see bank $01,
; so a $01 write shows on the real display AND in the memory dump.
SHR_PIXELS      EQU     $012000             ; 32000 B, 160 bytes/scanline
SHR_SCBS        EQU     $019D00             ; 200 scanline control bytes
SHR_PAL0        EQU     $019E00             ; palette 0 (16 colors x 2 bytes)
EXIT_MARK       EQU     $00BF7F             ; harness exit-marker byte
SYS_SCREEN_CTL  EQU     101                 ; console screen claim

;------------------------------------------------------------------------------
; void scr_suspend(void) / scr_restore(void) - claim / release the screen so
; the console stops flushing its text over our SHR draw (SYS_SCREEN_CTL).
;------------------------------------------------------------------------------
                FGX2_EXPORT scr_suspend
scr_suspend     MX      %00
                LDA     #1
                JSL     SYS_TRAMP
                DFB     SYS_SCREEN_CTL
                RTL

                FGX2_EXPORT scr_restore
scr_restore     MX      %00
                LDA     #0
                JSL     SYS_TRAMP
                DFB     SYS_SCREEN_CTL
                RTL

;------------------------------------------------------------------------------
; void shr_done(void) - set the harness exit marker so the frame dump fires
; immediately (before the next cursor-blink console flush repaints us).
;------------------------------------------------------------------------------
                FGX2_EXPORT shr_done
shr_done        MX      %00
                SEP     #$20
                MX      %10
                LDA     #$01
                STAL    EXIT_MARK
                REP     #$30
                MX      %00
                RTL

;------------------------------------------------------------------------------
; void shr_go320(void) - set all 200 SCBs to $00 (320 mode, palette 0).
;------------------------------------------------------------------------------
                FGX2_EXPORT shr_go320
shr_go320       MX      %00
                SEP     #$20                ; 8-bit A
                MX      %10
                LDX     #0
@sg             LDA     #$00
                STAL    SHR_SCBS,X
                INX
                CPX     #200
                BCC     @sg
                REP     #$30
                MX      %00
                RTL

;------------------------------------------------------------------------------
; void shr_setpal(void) - copy g_pal[0..31] into hardware palette 0.
;------------------------------------------------------------------------------
                FGX2_EXPORT shr_setpal
shr_setpal      MX      %00
                SEP     #$20
                MX      %10
                LDX     #0
@sp             LDA:    g_pal,X             ; DBR = seg1
                STAL    SHR_PAL0,X
                INX
                CPX     #32
                BCC     @sp
                REP     #$30
                MX      %00
                RTL

;------------------------------------------------------------------------------
; void shr_setpaln(void) - copy g_pal[0..31] into hardware palette g_paln (0..15).
;   dest index X = g_paln*32 + i ; 16 palettes span SHR_PAL0..SHR_PAL0+511.
;------------------------------------------------------------------------------
                FGX2_EXPORT shr_setpaln
shr_setpaln     MX      %00
                LDA:    g_paln
                ASL     A
                ASL     A
                ASL     A
                ASL     A
                ASL     A                   ; A = g_paln * 32
                TAX                          ; X = dest base (16-bit)
                SEP     #$20                ; 8-bit A; X/Y stay 16-bit
                MX      %10
                LDY     #0
@spn            LDA:    g_pal,Y             ; DBR = seg1
                STAL    SHR_PAL0,X
                INX
                INY
                CPY     #32
                BCC     @spn
                REP     #$30
                MX      %00
                RTL

;------------------------------------------------------------------------------
; void shr_setscbs(void) - copy g_scb[0..199] into the 200 SHR SCB bytes
;   (per-scanline palette select; static 256-color mode).
;------------------------------------------------------------------------------
                FGX2_EXPORT shr_setscbs
shr_setscbs     MX      %00
                SEP     #$20
                MX      %10
                LDX     #0
@ssc            LDA:    g_scb,X             ; DBR = seg1
                STAL    SHR_SCBS,X
                INX
                CPX     #200
                BCC     @ssc
                REP     #$30
                MX      %00
                RTL

;------------------------------------------------------------------------------
; void shr_putrow(void) - copy g_row[0..159] to SHR_PIXELS + g_off.
;   X = SHR dest index (g_off .. g_off+159), Y = source index into g_row.
;------------------------------------------------------------------------------
                FGX2_EXPORT shr_putrow
shr_putrow      MX      %00
                LDX:    g_off               ; 16-bit dest offset (0..31840)
                SEP     #$20                ; 8-bit A; X/Y stay 16-bit
                MX      %10
                LDY     #0
@pr             LDA:    g_row,Y             ; DBR = seg1
                STAL    SHR_PIXELS,X
                INX
                INY
                CPY     #160
                BCC     @pr
                REP     #$30
                MX      %00
                RTL

;------------------------------------------------------------------------------
; void shr_getrow(void) - copy SHR_PIXELS + g_off into g_row[0..159] (reverse
; of shr_putrow; progressive render uses it to preserve already-final blocks
; on rows it only partially recomputes).
;------------------------------------------------------------------------------
                FGX2_EXPORT shr_getrow
shr_getrow      MX      %00
                LDX:    g_off               ; 16-bit src offset
                SEP     #$20                ; 8-bit A; X/Y stay 16-bit
                MX      %10
                LDY     #0
@gr             LDAL    SHR_PIXELS,X
                STA:    g_row,Y             ; DBR = seg1
                INX
                INY
                CPY     #160
                BCC     @gr
                REP     #$30
                MX      %00
                RTL

;------------------------------------------------------------------------------
; void shr_xorpix(void) - XOR one 4bpp pixel nibble in the SHR shadow
; (crosshair draw/erase; XOR twice restores). Inputs (C globals):
;   g_off  byte offset into SHR (y*160 + x/2)
;   g_msk  nibble mask: $F0 (even x, left pixel) or $0F (odd x)
;------------------------------------------------------------------------------
                FGX2_EXPORT shr_xorpix
shr_xorpix      MX      %00
                LDX:    g_off               ; 16-bit dest offset
                SEP     #$20                ; 8-bit A; X stays 16-bit
                MX      %10
                LDAL    SHR_PIXELS,X
                EOR:    g_msk               ; DBR = seg1 (low byte of int)
                STAL    SHR_PIXELS,X
                REP     #$30
                MX      %00
                RTL

;==============================================================================
; Quarter-square multiply engine (Plan A, Fable-reviewed). Q9 fixed point.
; g_qsq[n] = floor(n^2/4), n=0..7168 (mand_build). ab = T[|a+b|]-T[|a-b|] (exact
; for signed ints; parity proof). Squares: z^2 = T[|2z|] (single lookup, 2z even
; so floor is exact). The per-iteration component pre-check bounds |zr|,|zi|
; <= 2048 wherever a table is consulted: _sqz indexes g_qsq9 by |2z| <= 4096,
; and g_qsq's largest index is _qmul9's |u+v| <= 7168 (cubic). Only the table
; entries are 32-bit. mand_asm reads g_cr,g_ci (low 16 = signed Q9), g_maxit;
; returns escape count in A (capped 255). JSL/RTL, DBR = seg1.
;==============================================================================

; void mand_build(void) - fill g_qsq[0..7168] = floor(n^2/4), add-only:
;   sq=0; T[n]=sq>>2; sq+=odd(1,3,5,...).  g_qsq9 spans only n<=4096 (the
;   component pre-check bounds every _sqz index to |2z| <= 4096).
                FGX2_EXPORT mand_build
mand_build      MX      %00
                STZ     g_sq
                STZ     g_sq+2
                STZ     g_i9
                LDA     #1
                STA     g_odd
                LDX     #0                  ; byte offset (n*4)
                LDY     #0                  ; n
@mb             LDA     g_sq                ; g_qsq[n] = g_sq >> 2
                STA     g_tlo
                LDA     g_sq+2
                STA     g_thi
                LSR     g_thi
                ROR     g_tlo
                LSR     g_thi
                ROR     g_tlo
                LDA     g_tlo
                STA     g_qsq,X
                LDA     g_thi
                STA     g_qsq+2,X
                ; g_qsq9[n] = (g_sq>>2)>>9 = pre-shifted z^2; {g_thi,g_tlo}=g_sq>>2
                CPY     #4097               ; g_qsq9 only spans n <= 4096
                BCS     @mb_n9
                PHX
                LDX     #9
@mb9            LSR     g_thi
                ROR     g_tlo
                DEX
                BNE     @mb9
                LDX     g_i9
                LDA     g_tlo
                STA     g_qsq9,X
                INX
                INX
                STX     g_i9
                PLX
@mb_n9
                CLC                         ; g_sq += g_odd
                LDA     g_sq
                ADC     g_odd
                STA     g_sq
                LDA     g_sq+2
                ADC     #0
                STA     g_sq+2
                LDA     g_odd               ; g_odd += 2
                INC
                INC
                STA     g_odd
                INX
                INX
                INX
                INX
                INY
                CPY     #7169
                BCC     @mb
                RTL

; _absidx_load: A = signed value -> load g_qsq[|A|*4] into {g_thi,g_tlo}.
_absidx_load    BPL     @ai_p
                EOR     #$FFFF
                INC
@ai_p           ASL
                ASL                         ; |A|*4 (byte index)
                TAX
                LDA     g_qsq,X
                STA     g_tlo
                LDA     g_qsq+2,X
                STA     g_thi
                RTS

; _sqz: A = z (signed Q9) -> A = z^2 (Q9). ONE load of the pre-shifted table:
; z^2_raw = T[|2z|]>>9 = g_qsq9[|2z|] (16-bit entries -> byte index = |2z|*2).
_sqz            ASL                         ; 2z
                BPL     @sq_p
                EOR     #$FFFF
                INC
@sq_p           ASL                         ; |2z|*2 (16-bit table byte index)
                TAX
                LDA     g_qsq9,X
                RTS

; _crossz: -> A = 2*(zr*zi) Q9 signed, from g_zr,g_zi (the *2 is folded in).
_crossz         CLC
                LDA     g_zr
                ADC     g_zi                ; s = zr+zi
                JSR     _absidx_load        ; T[|s|]
                LDA     g_tlo
                STA     g_crlo
                LDA     g_thi
                STA     g_crhi
                SEC
                LDA     g_zr
                SBC     g_zi                ; d = zr-zi
                JSR     _absidx_load        ; T[|d|]
                SEC
                LDA     g_crlo
                SBC     g_tlo
                STA     g_tlo
                LDA     g_crhi
                SBC     g_thi
                STA     g_thi               ; {thi,tlo} = zr_raw*zi_raw (signed 32)
                ; 2*cross = (diff>>8 arith) & ~1  ==  ((diff>>9)<<1) bit-identical,
                ; no shift loop. |diff|<=~1M here (|z|<=2 pre-escape), fits 16-bit.
                LDA     g_tlo
                XBA
                AND     #$00FF              ; g_tlo >> 8
                STA     g_crlo
                LDA     g_thi
                XBA
                AND     #$FF00              ; (g_thi & $FF) << 8 (carries sign)
                ORA     g_crlo
                AND     #$FFFE              ; clear bit 0 (folds the *2 of >>9)
                RTS

; _intchk: C=1 -> (g_cr,g_ci) is inside the main cardioid or the period-2
; bulb, where the Q9 iteration would return maxit -- so mand_asm can skip the
; whole loop.  PROVEN value-preserving vs the Q9 iteration by fractal_ref
; --interior-diff: 0 mismatches at step-1 grid density up to maxit 256.
; Margins shrink the tests so q>>9 rounding and near-boundary iteration noise
; fall through to real iteration: cardioid +4096 Q18, bulb -512 Q18.
; Products via the quarter-square table: v^2 = T[|2v|] (exact since (2v)^2/4
; = v^2), u*v = T[|u+v|]-T[|u-v|].  The x/y window gates bound every table
; index <= ~1550 (table max 9728).  Clobbers A/X, g_t*/g_cr*/g_i*/g_a*.
;   bulb:     -640<=cr<=-384, y<=128, (cr+512)^2 + y^2 < 16384-512
;   cardioid: -390<=cr<=130, a=cr-128, q=((a^2+y^2)>>9),
;             q*(q+a) + 4096 < (y^2)>>2
_intchk         LDA     g_ci                ; y = |ci|
                BPL     @ic_yp
                EOR     #$FFFF
                INC
@ic_yp          STA     g_iy
                CMP     #359                ; y > 358: outside both regions
                BCC     @ic_y_ok
                BRL     @ic_no              ; (body > short-branch range)
@ic_y_ok        LDA     g_cr                ; ---- bulb x-window (unsigned trick)
                CLC
                ADC     #640                ; in-window -> 0..256
                CMP     #257
                BCS     @ic_card
                LDA     g_iy
                CMP     #129                ; bulb y-window
                BCS     @ic_card
                LDA     g_cr
                CLC
                ADC     #512                ; a, |a| <= 128
                ASL
                JSR     _absidx_load        ; {g_thi,g_tlo} = a^2 (Q18 exact)
                LDA     g_tlo
                STA     g_alo
                LDA     g_thi
                STA     g_ahi
                LDA     g_iy
                ASL
                JSR     _absidx_load        ; y^2
                CLC                         ; a^2 + y^2 (32-bit)
                LDA     g_tlo
                ADC     g_alo
                STA     g_tlo
                LDA     g_thi
                ADC     g_ahi
                BNE     @ic_card            ; >= 65536: not inside
                LDA     g_tlo
                CMP     #15872              ; < 16384-BULB_MARGIN -> inside
                BCS     @ic_card            ; not in the bulb: try the cardioid
                BRL     @ic_yes             ; (target > short-branch range)
@ic_card        LDA     g_cr                ; ---- cardioid x-window
                CLC
                ADC     #390                ; in-window -> 0..520
                CMP     #521
                BCC     @ic_x_ok
                BRL     @ic_no              ; (body > short-branch range)
@ic_x_ok        LDA     g_cr
                SEC
                SBC     #128                ; a = cr - 1/4, [-518..2]
                STA     g_ia
                LDA     g_iy
                ASL
                JSR     _absidx_load        ; y^2 (<= 128164)
                LDA     g_tlo
                STA     g_alo               ; keep y^2 for the rhs
                LDA     g_thi
                STA     g_ahi
                LDA     g_ia
                ASL
                JSR     _absidx_load        ; a^2 (<= 268324)
                CLC                         ; q18 = a^2 + y^2 (<= ~396K)
                LDA     g_tlo
                ADC     g_alo
                STA     g_tlo
                LDA     g_thi
                ADC     g_ahi
                STA     g_thi
                LDA     g_tlo               ; q = q18 >> 9 (<= 774)
                XBA
                AND     #$00FF              ; g_tlo >> 8
                LSR                         ; g_tlo >> 9
                STA     g_iq
                LDA     g_thi
                ASL
                ASL
                ASL
                ASL
                ASL
                ASL
                ASL                         ; g_thi << 7
                ORA     g_iq
                STA     g_iq
                ASL                         ; 2q
                CLC
                ADC     g_ia                ; s = u+v = 2q+a (|s| <= ~1550)
                JSR     _absidx_load        ; T[|s|]
                LDA     g_tlo
                STA     g_crlo
                LDA     g_thi
                STA     g_crhi
                LDA     g_ia                ; d = u-v = -a -> T[|d|] = T[|a|]
                JSR     _absidx_load
                SEC                         ; lhs = q*(q+a) = T[|s|]-T[|a|]
                LDA     g_crlo
                SBC     g_tlo
                STA     g_crlo
                LDA     g_crhi
                SBC     g_thi
                STA     g_crhi
                LSR     g_ahi               ; rhs = y^2 >> 2 (<= 32041)
                ROR     g_alo
                LSR     g_ahi
                ROR     g_alo
                CLC                         ; lhs += CARD_MARGIN (4096)
                LDA     g_crlo
                ADC     #4096
                STA     g_crlo
                LDA     g_crhi
                ADC     #0
                STA     g_crhi
                SEC                         ; inside iff lhs - rhs < 0 (signed 32)
                LDA     g_crlo
                SBC     g_alo
                LDA     g_crhi
                SBC     g_ahi
                BMI     @ic_yes
@ic_no          CLC
                RTS
@ic_yes         SEC
                RTS

; _qmul9: A = (g_mu * g_mv) >> 9, signed Q9 multiply via the quarter-square
; table: u*v = T[|u+v|] - T[|u-v|] (exact 32-bit), then >>9 taken as
; (thi<<7)+(tlo>>9) -- exact because 65536/512 = 128, negatives included
; (16-bit wrap of thi<<7 is the correct low word). Callers bound |u|+|v|
; within the table. Clobbers X, g_tlo/g_thi/g_crlo/g_crhi.
_qmul9          CLC
                LDA     g_mu
                ADC     g_mv
                JSR     _absidx_load        ; T[|u+v|]
                LDA     g_tlo
                STA     g_crlo
                LDA     g_thi
                STA     g_crhi
                SEC
                LDA     g_mu
                SBC     g_mv
                JSR     _absidx_load        ; T[|u-v|]
                SEC
                LDA     g_crlo
                SBC     g_tlo
                STA     g_tlo
                LDA     g_crhi
                SBC     g_thi
                STA     g_thi               ; {g_thi,g_tlo} = u*v (signed 32)
                LDA     g_tlo
                XBA
                AND     #$00FF
                LSR                         ; tlo >> 9
                STA     g_tlo
                LDA     g_thi
                ASL
                ASL
                ASL
                ASL
                ASL
                ASL
                ASL                         ; thi << 7 (mod 2^16)
                CLC
                ADC     g_tlo               ; = (u*v) >> 9
                RTS

; int mand_asm(void) - escape count for the pixel, mode g_fmode:
;   0 mandel z^2+c   1 julia (c = g_jcr/g_jci, z0 = pixel)   2 tricorn
;   3 burning ship   4 cubic z^3+c.  Inputs g_cr/g_ci (low 16 = signed Q9),
;   g_maxit; returns escape count (capped 255).  One shared loop with small
;   mode branches; g_wcr/g_wci hold the iteration's c.
                FGX2_EXPORT mand_asm
mand_asm        MX      %00
                LDA     g_fmode
                CMP     #1
                BEQ     @m_jul
                LDA     g_cr                ; modes 0/2/3/4: c = the pixel
                STA     g_wcr
                LDA     g_ci
                STA     g_wci
                STZ     g_zr
                STZ     g_zi
                LDA     g_fmode
                BNE     @m_br0              ; interior shortcut: mandel only
                JSR     _intchk             ; cardioid/bulb
                BCC     @m_br0
                LDY     g_maxit             ; interior: same count the loop returns
                BRL     @done
@m_jul          LDA     g_jcr               ; julia: c fixed, z0 = the pixel
                STA     g_wcr
                LDA     g_jci
                STA     g_wci
                LDA     g_cr
                STA     g_zr
                LDA     g_ci
                STA     g_zi
@m_br0          LDA     g_zr                ; Brent: checkpoint = z0
                STA     g_pzr
                LDA     g_zi
                STA     g_pzi
                STZ     g_bdst
                LDA     #1
                STA     g_bpow
                LDY     #0
@it             LDA     g_zr                ; component pre-check: |zr|>4.0 or
                BPL     @m_p1               ; |zi|>4.0 escapes NOW -- equivalent
                EOR     #$FFFF              ; to the sum test (one square alone
                INC                         ; exceeds ESC) and it bounds the
@m_p1           CMP     #2049               ; cubic transients for 16-bit math.
                BCS     @m_esc              ; Mirrored by PRECHK in fractal_ref.
                LDA     g_zi
                BPL     @m_p2
                EOR     #$FFFF
                INC
@m_p2           CMP     #2049
                BCS     @m_esc
                LDA     g_fmode             ; Burning Ship: z <- (|zr|,|zi|)
                CMP     #3
                BNE     @m_sq
                LDA     g_zr
                BPL     @m_ab1
                EOR     #$FFFF
                INC
                STA     g_zr
@m_ab1          LDA     g_zi
                BPL     @m_sq
                EOR     #$FFFF
                INC
                STA     g_zi
@m_sq           LDA     g_zr
                JSR     _sqz
                STA     g_zr2
                LDA     g_zi
                JSR     _sqz
                STA     g_zi2
                CLC
                LDA     g_zr2
                ADC     g_zi2
                CMP     #2049               ; sum > 2048 (=4.0 Q9) -> escape
                BCC     @m_upd
@m_esc          STA     g_esum              ; |z|^2 (or component) at escape:
                BRL     @done               ; 2 fractional-count bits for smooth color
@m_upd          LDA     g_fmode
                CMP     #4
                BEQ     @m_cub
                JSR     _crossz             ; A = 2*zr*zi (Q9); _crossz folds the *2
                LDX     g_fmode             ; tricorn: conj -> negate the cross
                CPX     #2
                BNE     @m_ncr
                EOR     #$FFFF
                INC
@m_ncr          CLC
                ADC     g_wci               ; + ci
                STA     g_newzi
                SEC
                LDA     g_zr2
                SBC     g_zi2
                CLC
                ADC     g_wcr               ; nzr = zr2 - zi2 + cr
                STA     g_zr
                LDA     g_newzi
                STA     g_zi
                BRA     @m_brent
@m_cub          CLC                         ; cubic: zi' = zi*(3*zr2-zi2)>>9 + ci
                LDA     g_zr2
                ADC     g_zr2
                CLC
                ADC     g_zr2               ; 3*zr2 (<= 6144)
                SEC
                SBC     g_zi2
                STA     g_mv
                LDA     g_zi
                STA     g_mu
                JSR     _qmul9
                CLC
                ADC     g_wci
                STA     g_newzi
                SEC                         ; zr' = zr*(zr2-3*zi2)>>9 + cr
                LDA     g_zr2
                SBC     g_zi2
                SEC
                SBC     g_zi2
                SEC
                SBC     g_zi2               ; zr2 - 3*zi2
                STA     g_mv
                LDA     g_zr
                STA     g_mu
                JSR     _qmul9
                CLC
                ADC     g_wcr
                STA     g_zr
                LDA     g_newzi
                STA     g_zi
@m_brent
                ; Brent periodicity: the Q9 map is deterministic, so an EXACT
                ; state repeat means the orbit cycles forever -> same count as
                ; iterating to maxit.  Exact by construction (no margins).
                ; dist++ each iter; when dist==power, move the checkpoint to
                ; the current z and double power (checks orbits of any period).
                LDA     g_zr
                CMP     g_pzr
                BNE     @b_go
                LDA     g_zi
                CMP     g_pzi
                BEQ     @b_cyc              ; exact cycle: interior
@b_go           LDA     g_bdst
                INC
                STA     g_bdst
                CMP     g_bpow
                BNE     @b_nx
                LDA     g_zr                ; checkpoint = z, power *= 2
                STA     g_pzr
                LDA     g_zi
                STA     g_pzi
                STZ     g_bdst
                ASL     g_bpow
@b_nx           INY
                CPY     g_maxit
                BCS     @done               ; iterated out (body > BCC range)
                BRL     @it
@b_cyc          LDY     g_maxit             ; cycle: return maxit, like the loop
@done           TYA
                CMP     #256
                BCC     @cap
                LDA     #255
@cap            RTL

;==============================================================================
; 3200-color scanline engine (userland side). GFX_PALTAB = $01A000 (256
; per-line palettes x 32 B, bank $01). gfx_pset copies g_pal[32] to
; GFX_PALTAB[g_palv*32]; scr_arm/scr_disarm start/stop the kernel engine.
;==============================================================================
GFX_PALTAB      EQU     $01A000

                FGX2_EXPORT gfx_pset
gfx_pset        MX      %00
                LDA:    g_palv
                ASL
                ASL
                ASL
                ASL
                ASL                         ; g_palv * 32
                TAX
                SEP     #$20
                MX      %10
                LDY     #0
@gp             LDA:    g_pal,Y             ; DBR = seg1
                STAL    GFX_PALTAB,X
                INX
                INY
                CPY     #32
                BCC     @gp
                REP     #$30
                MX      %00
                RTL

                FGX2_EXPORT scr_arm
scr_arm         MX      %00
                LDA     #2
                JSL     SYS_TRAMP
                DFB     SYS_SCREEN_CTL
                RTL

                FGX2_EXPORT scr_disarm
scr_disarm      MX      %00
                LDA     #3
                JSL     SYS_TRAMP
                DFB     SYS_SCREEN_CTL
                RTL

;==============================================================================
; 3200-color BEAM-POLL path (userland, no kernel IRQ). rd_vcnt reads the VGC
; vertical counter; pal_load copies GFX_PALTAB[g_palline] into hw palette 0.
; The tool busy-polls rd_vcnt and calls pal_load on each line change -- FGX's
; design guidance ("poll the beam, don't count scanline interrupts").
;==============================================================================
                FGX2_EXPORT rd_vcnt
rd_vcnt         MX      %00
                LDAL    $E0C02E             ; VGC vertical count (V1..V8 low byte)
                AND     #$00FF
                RTL

                FGX2_EXPORT pal_load
pal_load        MX      %00
                PHB                         ; save DBR (seg1) -- MVN clobbers it
                LDA:    g_palline
                ASL
                ASL
                ASL
                ASL
                ASL                         ; g_palline * 32
                CLC
                ADC     #$A000              ; src = GFX_PALTAB + line*32 (bank $01)
                TAX
                LDY     #$9E00              ; dst = $01:9E00 (hw palette 0)
                LDA     #31                 ; count-1
                MVN     $01,$01
                PLB                         ; restore DBR = seg1
                RTL

; int rd_vbl(void) - RDVBL ($C019): bit 7 = vertical blanking. Returns full byte.
                FGX2_EXPORT rd_vbl
rd_vbl          MX      %00
                LDAL    $E0C019
                AND     #$00FF
                RTL

; ---- flicker-free 3200 display helpers (Convert 3200 technique) ----
; irq_off/irq_on bracket the beam-poll with SEI/CLI so no IRQ jitters the
; per-scanline palette timing. kbd_poll reads the hardware keyboard ($C000)
; directly so a keypress still exits while interrupts are masked.
                FGX2_EXPORT irq_off
irq_off         MX      %00
                SEI
                RTL

                FGX2_EXPORT irq_on
irq_on          MX      %00
                CLI
                RTL

; int kbd_poll(void) - 1 if a key is waiting (and clears the strobe), else -1.
                FGX2_EXPORT kbd_poll
kbd_poll        MX      %00
                SEP     #$20
                MX      %10
                LDAL    $E0C000             ; keyboard data + strobe (bit 7)
                BMI     @kp_key
                REP     #$30
                MX      %00
                LDA     #$FFFF              ; -1 = no key
                RTL
@kp_key         LDAL    $E0C010             ; clear the keyboard strobe
                REP     #$30
                MX      %00
                LDA     #1
                RTL
