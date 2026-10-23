                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from addrarrowdot.c
;---------------------------------------

                MX      %00
                FGX2_EXPORT _addrarrowdot_clear
_addrarrowdot_clear            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #_addrarrowdot_clear_FRAMESIZE
                DO      _addrarrowdot_clear_STKGUARD
                BCC     _addrarrowdot_clear_stkovf
                CMP     _fcc_stkfloor
                BCS     _addrarrowdot_clear_stkok
_addrarrowdot_clear_stkovf       JMP     _fcc_stkoflow
                FIN
_addrarrowdot_clear_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                LDA     #31354
                STA     gt+0
                LDA     #31611
                STA     gt+76
                LDA     #31868
                STA     gt+20
                LDA     #4112
                STA     gt+2
                LDA     #4113
                STA     gt+18
                LDA     #4114
                STA     gt+12
                LDA     #8224
                STA     gt+4
                LDA     #8225
                STA     gt+10
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0000
                STA     gt+6
                TAY
                LDA     _fcc_long_hi
                STA     gt+8
                TYA
                LDA     #0
                STA     _fcc_img0
_addrarrowdot_L0
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     _fcc_img0
                TAX
                TXA
                SEC
                SBC     #4
                BVC     _addrarrowdot_L3
                EOR     #$8000
_addrarrowdot_L3
                BMI     *+5
                BRL     _addrarrowdot_L2
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #gt
                CLC
                ADC     #14
                STA     _fcc_fpr0
                LDA     _fcc_img0
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     #48
                CLC
                ADC     _fcc_img0
                SEP     #$20
                MX      %10
                STA     [_fcc_fpr0]
                REP     #$20
                MX      %00
_addrarrowdot_L1
                INC     _fcc_img0
                BRL     _addrarrowdot_L0
_addrarrowdot_L2
                LDA     #0
                STA     _fcc_img0
_addrarrowdot_L4
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     _fcc_img0
                TAX
                TXA
                SEC
                SBC     #3
                BVC     _addrarrowdot_L7
                EOR     #$8000
_addrarrowdot_L7
                BMI     *+5
                BRL     _addrarrowdot_L6
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #gt
                CLC
                ADC     #22
                STA     _fcc_fpr0
                LDA     _fcc_img0
                STA     _fcc_tmp_b
                ASL
                ASL
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     #16448
                CLC
                ADC     _fcc_img0
                STA     [_fcc_fpr0]
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #gt
                CLC
                ADC     #22
                STA     _fcc_fpr0
                LDA     _fcc_img0
                STA     _fcc_tmp_b
                ASL
                ASL
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_fpr0
                CLC
                ADC     #16
                STA     _fcc_fpr0
                LDA     #16464
                CLC
                ADC     _fcc_img0
                STA     [_fcc_fpr0]
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #gt
                CLC
                ADC     #22
                STA     _fcc_fpr0
                LDA     _fcc_img0
                STA     _fcc_tmp_b
                ASL
                ASL
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_fpr0
                CLC
                ADC     #10
                STA     _fcc_fpr0
                LDA     #16480
                CLC
                ADC     _fcc_img0
                STA     [_fcc_fpr0]
_addrarrowdot_L5
                INC     _fcc_img0
                BRL     _addrarrowdot_L4
_addrarrowdot_L6
                LDA     #23130
                STA     gh+0
                LDA     #23387
                STA     gh+24
                LDA     #24672
                STA     gh+6
                LDA     #24673
                STA     gh+22
                LDA     #24674
                STA     gh+16
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #gt
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0
                STA     gh+2
                TAY
                LDA     _fcc_ptr+2
                STA     gh+4
                TYA
                LDA     #0
                TAY
                TSC
                CLC
                ADC     #_addrarrowdot_clear_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_addrarrowdot_clear_FRAMESIZE   EQU     2
_addrarrowdot_clear_STKGUARD    EQU     0
                FGX2_EXPORT main
main            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #main_FRAMESIZE
                DO      main_STKGUARD
                BCC     main_stkovf
                CMP     _fcc_stkfloor
                BCS     main_stkok
main_stkovf       JMP     _fcc_stkoflow
                FIN
main_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                LDA     #0
                STA     29,S   ; fccstk d=0 b=29
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #gt
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     3,S   ; fccstk d=0 b=3
                LDA     _fcc_fpr0
                STA     1,S   ; fccstk d=0 b=1
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #gh
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     7,S   ; fccstk d=0 b=7
                LDA     _fcc_fpr0
                STA     5,S   ; fccstk d=0 b=5
                FGX2_FARCALL _addrarrowdot_clear
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #0
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                PHA
                SEP     #$20
                MX      %10
                LDY     #2
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                CLC
                ADC     #4
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     11,S   ; fccstk d=0 b=11
                LDA     _fcc_fpr0
                STA     9,S   ; fccstk d=0 b=9
                LDA     11,S   ; fccstk d=0 b=11
                STA     _fcc_fpr0+2
                LDA     9,S   ; fccstk d=0 b=9
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     #gt
                INC
                INC
                INC
                INC
                STA     _fcc_fpr1
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BEQ     *+5
                BRL     _addrarrowdot_L9
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BEQ     *+5
                BRL     _addrarrowdot_L9
                LDA     #1
                BRL     _addrarrowdot_L10
_addrarrowdot_L9
                LDA     #0
_addrarrowdot_L10
                CMP     #0
                BNE     *+5
                BRL     _addrarrowdot_L8
                LDA     11,S   ; fccstk d=0 b=11
                STA     _fcc_fpr0+2
                LDA     9,S   ; fccstk d=0 b=9
                STA     _fcc_fpr0
                LDA     #$1122
                STA     _fcc_long_hi
                LDA     #$3344
                LDY     #2
                STA     [_fcc_fpr0],Y
                TAX
                LDA     _fcc_long_hi
                LDY     #4
                STA     [_fcc_fpr0],Y
                TXA
                LDA     gt+8
                STA     _fcc_long_hi
                LDA     gt+6
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$1122
                STA     _fcc_long_hi
                LDA     #$3344
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_eq
                CMP     #0
                BNE     *+5
                BRL     _addrarrowdot_L26
                LDA     gt+4
                TAX
                TXA
                CMP     #8224
                BEQ     *+5
                BRL     _addrarrowdot_L26
                LDA     #1
                BRL     _addrarrowdot_L27
_addrarrowdot_L26
                LDA     #0
_addrarrowdot_L27
                CMP     #0
                BNE     *+5
                BRL     _addrarrowdot_L24
                LDA     gt+10
                TAX
                TXA
                CMP     #8225
                BEQ     *+5
                BRL     _addrarrowdot_L24
                LDA     #1
                BRL     _addrarrowdot_L25
_addrarrowdot_L24
                LDA     #0
_addrarrowdot_L25
                CMP     #0
                BNE     *+5
                BRL     _addrarrowdot_L22
                LDA     gt+2
                TAX
                TXA
                CMP     #4112
                BEQ     *+5
                BRL     _addrarrowdot_L22
                LDA     #1
                BRL     _addrarrowdot_L23
_addrarrowdot_L22
                LDA     #0
_addrarrowdot_L23
                CMP     #0
                BNE     *+5
                BRL     _addrarrowdot_L20
                LDA     gt+12
                TAX
                TXA
                CMP     #4114
                BEQ     *+5
                BRL     _addrarrowdot_L20
                LDA     #1
                BRL     _addrarrowdot_L21
_addrarrowdot_L20
                LDA     #0
_addrarrowdot_L21
                CMP     #0
                BNE     *+5
                BRL     _addrarrowdot_L18
                LDA     gt+18
                TAX
                TXA
                CMP     #4113
                BEQ     *+5
                BRL     _addrarrowdot_L18
                LDA     #1
                BRL     _addrarrowdot_L19
_addrarrowdot_L18
                LDA     #0
_addrarrowdot_L19
                CMP     #0
                BNE     *+5
                BRL     _addrarrowdot_L16
                LDA     gt+0
                TAX
                TXA
                CMP     #31354
                BEQ     *+5
                BRL     _addrarrowdot_L16
                LDA     #1
                BRL     _addrarrowdot_L17
_addrarrowdot_L16
                LDA     #0
_addrarrowdot_L17
                CMP     #0
                BNE     *+5
                BRL     _addrarrowdot_L14
                LDA     gt+20
                TAX
                TXA
                CMP     #31868
                BEQ     *+5
                BRL     _addrarrowdot_L14
                LDA     #1
                BRL     _addrarrowdot_L15
_addrarrowdot_L14
                LDA     #0
_addrarrowdot_L15
                CMP     #0
                BNE     *+5
                BRL     _addrarrowdot_L12
                LDA     gt+76
                TAX
                TXA
                CMP     #31611
                BEQ     *+5
                BRL     _addrarrowdot_L12
                LDA     #1
                BRL     _addrarrowdot_L13
_addrarrowdot_L12
                LDA     #0
_addrarrowdot_L13
                CMP     #0
                BNE     *+5
                BRL     _addrarrowdot_L11
                LDA     29,S   ; fccstk d=0 b=29
                TAX
                TXA
                CLC
                ADC     #4
                STA     29,S   ; fccstk d=0 b=29
_addrarrowdot_L11
_addrarrowdot_L8
                FGX2_FARCALL _addrarrowdot_clear
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #0
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                PHA
                SEP     #$20
                MX      %10
                LDY     #2
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                CLC
                ADC     #12
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     19,S   ; fccstk d=0 b=19
                LDA     _fcc_fpr0
                STA     17,S   ; fccstk d=0 b=17
                LDA     19,S   ; fccstk d=0 b=19
                STA     _fcc_fpr0+2
                LDA     17,S   ; fccstk d=0 b=17
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     #gt
                CLC
                ADC     #10
                INC
                INC
                STA     _fcc_fpr1
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BEQ     *+5
                BRL     _addrarrowdot_L29
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BEQ     *+5
                BRL     _addrarrowdot_L29
                LDA     #1
                BRL     _addrarrowdot_L30
_addrarrowdot_L29
                LDA     #0
_addrarrowdot_L30
                CMP     #0
                BNE     *+5
                BRL     _addrarrowdot_L28
                LDA     19,S   ; fccstk d=0 b=19
                STA     _fcc_fpr0+2
                LDA     17,S   ; fccstk d=0 b=17
                STA     _fcc_fpr0
                LDA     #2989
                STA     [_fcc_fpr0]
                LDA     gt+12
                TAX
                TXA
                CMP     #2989
                BEQ     *+5
                BRL     _addrarrowdot_L40
                LDA     gt+2
                TAX
                TXA
                CMP     #4112
                BEQ     *+5
                BRL     _addrarrowdot_L40
                LDA     #1
                BRL     _addrarrowdot_L41
_addrarrowdot_L40
                LDA     #0
_addrarrowdot_L41
                CMP     #0
                BNE     *+5
                BRL     _addrarrowdot_L38
                LDA     gt+18
                TAX
                TXA
                CMP     #4113
                BEQ     *+5
                BRL     _addrarrowdot_L38
                LDA     #1
                BRL     _addrarrowdot_L39
_addrarrowdot_L38
                LDA     #0
_addrarrowdot_L39
                CMP     #0
                BNE     *+5
                BRL     _addrarrowdot_L36
                LDA     gt+10
                TAX
                TXA
                CMP     #8225
                BEQ     *+5
                BRL     _addrarrowdot_L36
                LDA     #1
                BRL     _addrarrowdot_L37
_addrarrowdot_L36
                LDA     #0
_addrarrowdot_L37
                CMP     #0
                BNE     *+5
                BRL     _addrarrowdot_L34
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #gt
                CLC
                ADC     #14
                STA     _fcc_fpr0
                LDA     #0
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                AND     #$00FF
                TAX
                TXA
                CMP     #48
                BEQ     *+5
                BRL     _addrarrowdot_L34
                LDA     #1
                BRL     _addrarrowdot_L35
_addrarrowdot_L34
                LDA     #0
_addrarrowdot_L35
                CMP     #0
                BNE     *+5
                BRL     _addrarrowdot_L32
                LDA     gt+20
                TAX
                TXA
                CMP     #31868
                BEQ     *+5
                BRL     _addrarrowdot_L32
                LDA     #1
                BRL     _addrarrowdot_L33
_addrarrowdot_L32
                LDA     #0
_addrarrowdot_L33
                CMP     #0
                BNE     *+5
                BRL     _addrarrowdot_L31
                LDA     29,S   ; fccstk d=0 b=29
                TAX
                TXA
                CLC
                ADC     #4
                STA     29,S   ; fccstk d=0 b=29
_addrarrowdot_L31
_addrarrowdot_L28
                FGX2_FARCALL _addrarrowdot_clear
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #0
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                PHA
                SEP     #$20
                MX      %10
                LDY     #2
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                CLC
                ADC     #6
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     15,S   ; fccstk d=0 b=15
                LDA     _fcc_fpr0
                STA     13,S   ; fccstk d=0 b=13
                LDA     15,S   ; fccstk d=0 b=15
                STA     _fcc_fpr0+2
                LDA     13,S   ; fccstk d=0 b=13
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     #gt
                INC
                INC
                CLC
                ADC     #4
                STA     _fcc_fpr1
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BEQ     *+5
                BRL     _addrarrowdot_L43
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BEQ     *+5
                BRL     _addrarrowdot_L43
                LDA     #1
                BRL     _addrarrowdot_L44
_addrarrowdot_L43
                LDA     #0
_addrarrowdot_L44
                CMP     #0
                BNE     *+5
                BRL     _addrarrowdot_L42
                LDA     15,S   ; fccstk d=0 b=15
                STA     _fcc_fpr0+2
                LDA     13,S   ; fccstk d=0 b=13
                STA     _fcc_fpr0
                LDA     #$7EED
                STA     _fcc_long_hi
                LDA     #$BEEF
                STA     [_fcc_fpr0]
                TAX
                LDA     _fcc_long_hi
                LDY     #2
                STA     [_fcc_fpr0],Y
                TXA
                LDA     gt+8
                STA     _fcc_long_hi
                LDA     gt+6
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$7EED
                STA     _fcc_long_hi
                LDA     #$BEEF
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_eq
                CMP     #0
                BNE     *+5
                BRL     _addrarrowdot_L50
                LDA     gt+4
                TAX
                TXA
                CMP     #8224
                BEQ     *+5
                BRL     _addrarrowdot_L50
                LDA     #1
                BRL     _addrarrowdot_L51
_addrarrowdot_L50
                LDA     #0
_addrarrowdot_L51
                CMP     #0
                BNE     *+5
                BRL     _addrarrowdot_L48
                LDA     gt+10
                TAX
                TXA
                CMP     #8225
                BEQ     *+5
                BRL     _addrarrowdot_L48
                LDA     #1
                BRL     _addrarrowdot_L49
_addrarrowdot_L48
                LDA     #0
_addrarrowdot_L49
                CMP     #0
                BNE     *+5
                BRL     _addrarrowdot_L46
                LDA     gt+12
                TAX
                TXA
                CMP     #4114
                BEQ     *+5
                BRL     _addrarrowdot_L46
                LDA     #1
                BRL     _addrarrowdot_L47
_addrarrowdot_L46
                LDA     #0
_addrarrowdot_L47
                CMP     #0
                BNE     *+5
                BRL     _addrarrowdot_L45
                LDA     29,S   ; fccstk d=0 b=29
                TAX
                TXA
                CLC
                ADC     #4
                STA     29,S   ; fccstk d=0 b=29
_addrarrowdot_L45
_addrarrowdot_L42
                FGX2_FARCALL _addrarrowdot_clear
                LDA     #2
                STA     27,S   ; fccstk d=0 b=27
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #0
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                PHA
                SEP     #$20
                MX      %10
                LDY     #2
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                CLC
                ADC     #14
                STA     _fcc_fpr0
                LDA     27,S   ; fccstk d=0 b=27
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     23,S   ; fccstk d=0 b=23
                LDA     _fcc_fpr0
                STA     21,S   ; fccstk d=0 b=21
                LDA     23,S   ; fccstk d=0 b=23
                STA     _fcc_fpr0+2
                LDA     21,S   ; fccstk d=0 b=21
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     #gt
                CLC
                ADC     #12
                INC
                INC
                STA     _fcc_fpr1
                LDA     #2
                CLC
                ADC     _fcc_fpr1
                STA     _fcc_fpr1
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BEQ     *+5
                BRL     _addrarrowdot_L53
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BEQ     *+5
                BRL     _addrarrowdot_L53
                LDA     #1
                BRL     _addrarrowdot_L54
_addrarrowdot_L53
                LDA     #0
_addrarrowdot_L54
                CMP     #0
                BNE     *+5
                BRL     _addrarrowdot_L52
                LDA     23,S   ; fccstk d=0 b=23
                STA     _fcc_fpr0+2
                LDA     21,S   ; fccstk d=0 b=21
                STA     _fcc_fpr0
                LDA     #95
                SEP     #$20
                MX      %10
                STA     [_fcc_fpr0]
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #gt
                CLC
                ADC     #14
                STA     _fcc_fpr0
                LDA     #2
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                AND     #$00FF
                TAX
                TXA
                CMP     #95
                BEQ     *+5
                BRL     _addrarrowdot_L62
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #gt
                CLC
                ADC     #14
                STA     _fcc_fpr0
                LDA     #1
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                AND     #$00FF
                TAX
                TXA
                CMP     #49
                BEQ     *+5
                BRL     _addrarrowdot_L62
                LDA     #1
                BRL     _addrarrowdot_L63
_addrarrowdot_L62
                LDA     #0
_addrarrowdot_L63
                CMP     #0
                BNE     *+5
                BRL     _addrarrowdot_L60
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #gt
                CLC
                ADC     #14
                STA     _fcc_fpr0
                LDA     #3
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                AND     #$00FF
                TAX
                TXA
                CMP     #51
                BEQ     *+5
                BRL     _addrarrowdot_L60
                LDA     #1
                BRL     _addrarrowdot_L61
_addrarrowdot_L60
                LDA     #0
_addrarrowdot_L61
                CMP     #0
                BNE     *+5
                BRL     _addrarrowdot_L58
                LDA     gt+12
                TAX
                TXA
                CMP     #4114
                BEQ     *+5
                BRL     _addrarrowdot_L58
                LDA     #1
                BRL     _addrarrowdot_L59
_addrarrowdot_L58
                LDA     #0
_addrarrowdot_L59
                CMP     #0
                BNE     *+5
                BRL     _addrarrowdot_L56
                LDA     gt+18
                TAX
                TXA
                CMP     #4113
                BEQ     *+5
                BRL     _addrarrowdot_L56
                LDA     #1
                BRL     _addrarrowdot_L57
_addrarrowdot_L56
                LDA     #0
_addrarrowdot_L57
                CMP     #0
                BNE     *+5
                BRL     _addrarrowdot_L55
                LDA     29,S   ; fccstk d=0 b=29
                TAX
                TXA
                CLC
                ADC     #4
                STA     29,S   ; fccstk d=0 b=29
_addrarrowdot_L55
_addrarrowdot_L52
                FGX2_FARCALL _addrarrowdot_clear
                LDA     #1
                STA     25,S   ; fccstk d=0 b=25
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #0
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                PHA
                SEP     #$20
                MX      %10
                LDY     #2
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                CLC
                ADC     #22
                STA     _fcc_fpr0
                LDA     25,S   ; fccstk d=0 b=25
                STA     _fcc_tmp_b
                ASL
                ASL
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_fpr0
                CLC
                ADC     #10
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     19,S   ; fccstk d=0 b=19
                LDA     _fcc_fpr0
                STA     17,S   ; fccstk d=0 b=17
                LDA     19,S   ; fccstk d=0 b=19
                STA     _fcc_fpr0+2
                LDA     17,S   ; fccstk d=0 b=17
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     #gt
                CLC
                ADC     #22
                STA     _fcc_fpr1
                LDA     #1
                ASL
                ASL
                ASL
                INC
                ASL
                CLC
                ADC     _fcc_fpr1
                CLC
                ADC     #10
                STA     _fcc_fpr1
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BEQ     *+5
                BRL     _addrarrowdot_L65
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BEQ     *+5
                BRL     _addrarrowdot_L65
                LDA     #1
                BRL     _addrarrowdot_L66
_addrarrowdot_L65
                LDA     #0
_addrarrowdot_L66
                CMP     #0
                BNE     *+5
                BRL     _addrarrowdot_L64
                LDA     19,S   ; fccstk d=0 b=19
                STA     _fcc_fpr0+2
                LDA     17,S   ; fccstk d=0 b=17
                STA     _fcc_fpr0
                LDA     #3084
                STA     [_fcc_fpr0]
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #gt
                CLC
                ADC     #22
                STA     _fcc_fpr0
                LDA     #1
                ASL
                ASL
                ASL
                INC
                ASL
                CLC
                ADC     _fcc_fpr0
                CLC
                ADC     #10
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                TAX
                TXA
                CMP     #3084
                BEQ     *+5
                BRL     _addrarrowdot_L78
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #gt
                CLC
                ADC     #22
                STA     _fcc_fpr0
                LDA     #0
                ASL
                ASL
                ASL
                CLC
                ADC     #0
                ASL
                CLC
                ADC     _fcc_fpr0
                CLC
                ADC     #10
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                TAX
                TXA
                CMP     #16480
                BEQ     *+5
                BRL     _addrarrowdot_L78
                LDA     #1
                BRL     _addrarrowdot_L79
_addrarrowdot_L78
                LDA     #0
_addrarrowdot_L79
                CMP     #0
                BNE     *+5
                BRL     _addrarrowdot_L76
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #gt
                CLC
                ADC     #22
                STA     _fcc_fpr0
                LDA     #2
                ASL
                ASL
                ASL
                INC
                INC
                ASL
                CLC
                ADC     _fcc_fpr0
                CLC
                ADC     #10
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                TAX
                TXA
                CMP     #16482
                BEQ     *+5
                BRL     _addrarrowdot_L76
                LDA     #1
                BRL     _addrarrowdot_L77
_addrarrowdot_L76
                LDA     #0
_addrarrowdot_L77
                CMP     #0
                BNE     *+5
                BRL     _addrarrowdot_L74
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #gt
                CLC
                ADC     #22
                STA     _fcc_fpr0
                LDA     #1
                ASL
                ASL
                ASL
                INC
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                TAX
                TXA
                CMP     #16449
                BEQ     *+5
                BRL     _addrarrowdot_L74
                LDA     #1
                BRL     _addrarrowdot_L75
_addrarrowdot_L74
                LDA     #0
_addrarrowdot_L75
                CMP     #0
                BNE     *+5
                BRL     _addrarrowdot_L72
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #gt
                CLC
                ADC     #22
                STA     _fcc_fpr0
                LDA     #1
                ASL
                ASL
                ASL
                INC
                ASL
                CLC
                ADC     _fcc_fpr0
                CLC
                ADC     #16
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                TAX
                TXA
                CMP     #16465
                BEQ     *+5
                BRL     _addrarrowdot_L72
                LDA     #1
                BRL     _addrarrowdot_L73
_addrarrowdot_L72
                LDA     #0
_addrarrowdot_L73
                CMP     #0
                BNE     *+5
                BRL     _addrarrowdot_L70
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #gt
                CLC
                ADC     #22
                STA     _fcc_fpr0
                LDA     #0
                ASL
                ASL
                ASL
                CLC
                ADC     #0
                ASL
                CLC
                ADC     _fcc_fpr0
                CLC
                ADC     #16
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                TAX
                TXA
                CMP     #16464
                BEQ     *+5
                BRL     _addrarrowdot_L70
                LDA     #1
                BRL     _addrarrowdot_L71
_addrarrowdot_L70
                LDA     #0
_addrarrowdot_L71
                CMP     #0
                BNE     *+5
                BRL     _addrarrowdot_L68
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #gt
                CLC
                ADC     #22
                STA     _fcc_fpr0
                LDA     #2
                ASL
                ASL
                ASL
                INC
                INC
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                TAX
                TXA
                CMP     #16450
                BEQ     *+5
                BRL     _addrarrowdot_L68
                LDA     #1
                BRL     _addrarrowdot_L69
_addrarrowdot_L68
                LDA     #0
_addrarrowdot_L69
                CMP     #0
                BNE     *+5
                BRL     _addrarrowdot_L67
                LDA     29,S   ; fccstk d=0 b=29
                TAX
                TXA
                CLC
                ADC     #4
                STA     29,S   ; fccstk d=0 b=29
_addrarrowdot_L67
_addrarrowdot_L64
                FGX2_FARCALL _addrarrowdot_clear
                LDA     #2
                STA     25,S   ; fccstk d=0 b=25
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #0
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                PHA
                SEP     #$20
                MX      %10
                LDY     #2
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                CLC
                ADC     #22
                STA     _fcc_fpr0
                LDA     25,S   ; fccstk d=0 b=25
                STA     _fcc_tmp_b
                ASL
                ASL
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_fpr0
                CLC
                ADC     #4
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     15,S   ; fccstk d=0 b=15
                LDA     _fcc_fpr0
                STA     13,S   ; fccstk d=0 b=13
                LDA     15,S   ; fccstk d=0 b=15
                STA     _fcc_fpr0+2
                LDA     13,S   ; fccstk d=0 b=13
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     #gt
                CLC
                ADC     #22
                STA     _fcc_fpr1
                LDA     #2
                ASL
                ASL
                ASL
                INC
                INC
                ASL
                CLC
                ADC     _fcc_fpr1
                CLC
                ADC     #4
                STA     _fcc_fpr1
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BEQ     *+5
                BRL     _addrarrowdot_L81
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BEQ     *+5
                BRL     _addrarrowdot_L81
                LDA     #1
                BRL     _addrarrowdot_L82
_addrarrowdot_L81
                LDA     #0
_addrarrowdot_L82
                CMP     #0
                BNE     *+5
                BRL     _addrarrowdot_L80
                LDA     15,S   ; fccstk d=0 b=15
                STA     _fcc_fpr0+2
                LDA     13,S   ; fccstk d=0 b=13
                STA     _fcc_fpr0
                LDA     #$0123
                STA     _fcc_long_hi
                LDA     #$FEDC
                STA     [_fcc_fpr0]
                TAX
                LDA     _fcc_long_hi
                LDY     #2
                STA     [_fcc_fpr0],Y
                TXA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #gt
                CLC
                ADC     #22
                STA     _fcc_fpr0
                LDA     #2
                ASL
                ASL
                ASL
                INC
                INC
                ASL
                CLC
                ADC     _fcc_fpr0
                CLC
                ADC     #4
                STA     _fcc_fpr0
                LDY     #2
                LDA     [_fcc_fpr0],Y
                STA     _fcc_long_hi
                LDA     [_fcc_fpr0]
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0123
                STA     _fcc_long_hi
                LDA     #$FEDC
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_eq
                CMP     #0
                BNE     *+5
                BRL     _addrarrowdot_L88
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #gt
                CLC
                ADC     #22
                STA     _fcc_fpr0
                LDA     #2
                ASL
                ASL
                ASL
                INC
                INC
                ASL
                CLC
                ADC     _fcc_fpr0
                CLC
                ADC     #10
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                TAX
                TXA
                CMP     #16482
                BEQ     *+5
                BRL     _addrarrowdot_L88
                LDA     #1
                BRL     _addrarrowdot_L89
_addrarrowdot_L88
                LDA     #0
_addrarrowdot_L89
                CMP     #0
                BNE     *+5
                BRL     _addrarrowdot_L86
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #gt
                CLC
                ADC     #22
                STA     _fcc_fpr0
                LDA     #2
                ASL
                ASL
                ASL
                INC
                INC
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                TAX
                TXA
                CMP     #16450
                BEQ     *+5
                BRL     _addrarrowdot_L86
                LDA     #1
                BRL     _addrarrowdot_L87
_addrarrowdot_L86
                LDA     #0
_addrarrowdot_L87
                CMP     #0
                BNE     *+5
                BRL     _addrarrowdot_L84
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #gt
                CLC
                ADC     #22
                STA     _fcc_fpr0
                LDA     #1
                ASL
                ASL
                ASL
                INC
                ASL
                CLC
                ADC     _fcc_fpr0
                CLC
                ADC     #16
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                TAX
                TXA
                CMP     #16465
                BEQ     *+5
                BRL     _addrarrowdot_L84
                LDA     #1
                BRL     _addrarrowdot_L85
_addrarrowdot_L84
                LDA     #0
_addrarrowdot_L85
                CMP     #0
                BNE     *+5
                BRL     _addrarrowdot_L83
                LDA     29,S   ; fccstk d=0 b=29
                TAX
                TXA
                CLC
                ADC     #4
                STA     29,S   ; fccstk d=0 b=29
_addrarrowdot_L83
_addrarrowdot_L80
                FGX2_FARCALL _addrarrowdot_clear
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #4
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                PHA
                SEP     #$20
                MX      %10
                LDY     #2
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                LDY     #2
                LDA     [_fcc_fpr0],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #4
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                CLC
                ADC     #20
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     19,S   ; fccstk d=0 b=19
                LDA     _fcc_fpr0
                STA     17,S   ; fccstk d=0 b=17
                LDA     19,S   ; fccstk d=0 b=19
                STA     _fcc_fpr0+2
                LDA     17,S   ; fccstk d=0 b=17
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     #gt
                CLC
                ADC     #20
                STA     _fcc_fpr1
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BEQ     *+5
                BRL     _addrarrowdot_L91
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BEQ     *+5
                BRL     _addrarrowdot_L91
                LDA     #1
                BRL     _addrarrowdot_L92
_addrarrowdot_L91
                LDA     #0
_addrarrowdot_L92
                CMP     #0
                BNE     *+5
                BRL     _addrarrowdot_L90
                LDA     19,S   ; fccstk d=0 b=19
                STA     _fcc_fpr0+2
                LDA     17,S   ; fccstk d=0 b=17
                STA     _fcc_fpr0
                LDA     #3501
                STA     [_fcc_fpr0]
                LDA     gt+20
                TAX
                TXA
                CMP     #3501
                BEQ     *+5
                BRL     _addrarrowdot_L100
                LDA     gt+0
                TAX
                TXA
                CMP     #31354
                BEQ     *+5
                BRL     _addrarrowdot_L100
                LDA     #1
                BRL     _addrarrowdot_L101
_addrarrowdot_L100
                LDA     #0
_addrarrowdot_L101
                CMP     #0
                BNE     *+5
                BRL     _addrarrowdot_L98
                LDA     gt+76
                TAX
                TXA
                CMP     #31611
                BEQ     *+5
                BRL     _addrarrowdot_L98
                LDA     #1
                BRL     _addrarrowdot_L99
_addrarrowdot_L98
                LDA     #0
_addrarrowdot_L99
                CMP     #0
                BNE     *+5
                BRL     _addrarrowdot_L96
                LDA     gt+18
                TAX
                TXA
                CMP     #4113
                BEQ     *+5
                BRL     _addrarrowdot_L96
                LDA     #1
                BRL     _addrarrowdot_L97
_addrarrowdot_L96
                LDA     #0
_addrarrowdot_L97
                CMP     #0
                BNE     *+5
                BRL     _addrarrowdot_L94
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #gt
                CLC
                ADC     #22
                STA     _fcc_fpr0
                LDA     #0
                ASL
                ASL
                ASL
                CLC
                ADC     #0
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                TAX
                TXA
                CMP     #16448
                BEQ     *+5
                BRL     _addrarrowdot_L94
                LDA     #1
                BRL     _addrarrowdot_L95
_addrarrowdot_L94
                LDA     #0
_addrarrowdot_L95
                CMP     #0
                BNE     *+5
                BRL     _addrarrowdot_L93
                LDA     29,S   ; fccstk d=0 b=29
                TAX
                TXA
                CLC
                ADC     #4
                STA     29,S   ; fccstk d=0 b=29
_addrarrowdot_L93
_addrarrowdot_L90
                FGX2_FARCALL _addrarrowdot_clear
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #4
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                PHA
                SEP     #$20
                MX      %10
                LDY     #2
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                LDY     #2
                LDA     [_fcc_fpr0],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #4
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                CLC
                ADC     #12
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     19,S   ; fccstk d=0 b=19
                LDA     _fcc_fpr0
                STA     17,S   ; fccstk d=0 b=17
                LDA     19,S   ; fccstk d=0 b=19
                STA     _fcc_fpr0+2
                LDA     17,S   ; fccstk d=0 b=17
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     #gt
                CLC
                ADC     #10
                INC
                INC
                STA     _fcc_fpr1
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BEQ     *+5
                BRL     _addrarrowdot_L103
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BEQ     *+5
                BRL     _addrarrowdot_L103
                LDA     #1
                BRL     _addrarrowdot_L104
_addrarrowdot_L103
                LDA     #0
_addrarrowdot_L104
                CMP     #0
                BNE     *+5
                BRL     _addrarrowdot_L102
                LDA     19,S   ; fccstk d=0 b=19
                STA     _fcc_fpr0+2
                LDA     17,S   ; fccstk d=0 b=17
                STA     _fcc_fpr0
                LDA     #3598
                STA     [_fcc_fpr0]
                LDA     gt+12
                TAX
                TXA
                CMP     #3598
                BEQ     *+5
                BRL     _addrarrowdot_L110
                LDA     gt+2
                TAX
                TXA
                CMP     #4112
                BEQ     *+5
                BRL     _addrarrowdot_L110
                LDA     #1
                BRL     _addrarrowdot_L111
_addrarrowdot_L110
                LDA     #0
_addrarrowdot_L111
                CMP     #0
                BNE     *+5
                BRL     _addrarrowdot_L108
                LDA     gt+18
                TAX
                TXA
                CMP     #4113
                BEQ     *+5
                BRL     _addrarrowdot_L108
                LDA     #1
                BRL     _addrarrowdot_L109
_addrarrowdot_L108
                LDA     #0
_addrarrowdot_L109
                CMP     #0
                BNE     *+5
                BRL     _addrarrowdot_L106
                LDA     gt+20
                TAX
                TXA
                CMP     #31868
                BEQ     *+5
                BRL     _addrarrowdot_L106
                LDA     #1
                BRL     _addrarrowdot_L107
_addrarrowdot_L106
                LDA     #0
_addrarrowdot_L107
                CMP     #0
                BNE     *+5
                BRL     _addrarrowdot_L105
                LDA     29,S   ; fccstk d=0 b=29
                TAX
                TXA
                CLC
                ADC     #4
                STA     29,S   ; fccstk d=0 b=29
_addrarrowdot_L105
_addrarrowdot_L102
                FGX2_FARCALL _addrarrowdot_clear
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #4
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                PHA
                SEP     #$20
                MX      %10
                LDY     #2
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                CLC
                ADC     #16
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     19,S   ; fccstk d=0 b=19
                LDA     _fcc_fpr0
                STA     17,S   ; fccstk d=0 b=17
                LDA     19,S   ; fccstk d=0 b=19
                STA     _fcc_fpr0+2
                LDA     17,S   ; fccstk d=0 b=17
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     #gh
                CLC
                ADC     #10
                CLC
                ADC     #6
                STA     _fcc_fpr1
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BEQ     *+5
                BRL     _addrarrowdot_L113
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BEQ     *+5
                BRL     _addrarrowdot_L113
                LDA     #1
                BRL     _addrarrowdot_L114
_addrarrowdot_L113
                LDA     #0
_addrarrowdot_L114
                CMP     #0
                BNE     *+5
                BRL     _addrarrowdot_L112
                LDA     19,S   ; fccstk d=0 b=19
                STA     _fcc_fpr0+2
                LDA     17,S   ; fccstk d=0 b=17
                STA     _fcc_fpr0
                LDA     #3855
                STA     [_fcc_fpr0]
                LDA     gh+16
                TAX
                TXA
                CMP     #3855
                BEQ     *+5
                BRL     _addrarrowdot_L124
                LDA     gh+6
                TAX
                TXA
                CMP     #24672
                BEQ     *+5
                BRL     _addrarrowdot_L124
                LDA     #1
                BRL     _addrarrowdot_L125
_addrarrowdot_L124
                LDA     #0
_addrarrowdot_L125
                CMP     #0
                BNE     *+5
                BRL     _addrarrowdot_L122
                LDA     gh+22
                TAX
                TXA
                CMP     #24673
                BEQ     *+5
                BRL     _addrarrowdot_L122
                LDA     #1
                BRL     _addrarrowdot_L123
_addrarrowdot_L122
                LDA     #0
_addrarrowdot_L123
                CMP     #0
                BNE     *+5
                BRL     _addrarrowdot_L120
                LDA     gh+0
                TAX
                TXA
                CMP     #23130
                BEQ     *+5
                BRL     _addrarrowdot_L120
                LDA     #1
                BRL     _addrarrowdot_L121
_addrarrowdot_L120
                LDA     #0
_addrarrowdot_L121
                CMP     #0
                BNE     *+5
                BRL     _addrarrowdot_L118
                LDA     gh+24
                TAX
                TXA
                CMP     #23387
                BEQ     *+5
                BRL     _addrarrowdot_L118
                LDA     #1
                BRL     _addrarrowdot_L119
_addrarrowdot_L118
                LDA     #0
_addrarrowdot_L119
                CMP     #0
                BNE     *+5
                BRL     _addrarrowdot_L116
                LDA     gh+4
                STA     _fcc_fpr0+2
                LDA     gh+2
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     #gt
                STA     _fcc_fpr1
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BEQ     *+5
                BRL     _addrarrowdot_L126
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BEQ     *+5
                BRL     _addrarrowdot_L126
                LDA     #1
                BRL     _addrarrowdot_L127
_addrarrowdot_L126
                LDA     #0
_addrarrowdot_L127
                CMP     #0
                BNE     *+5
                BRL     _addrarrowdot_L116
                LDA     #1
                BRL     _addrarrowdot_L117
_addrarrowdot_L116
                LDA     #0
_addrarrowdot_L117
                CMP     #0
                BNE     *+5
                BRL     _addrarrowdot_L115
                LDA     29,S   ; fccstk d=0 b=29
                TAX
                TXA
                CLC
                ADC     #4
                STA     29,S   ; fccstk d=0 b=29
_addrarrowdot_L115
_addrarrowdot_L112
                FGX2_FARCALL _addrarrowdot_clear
                LDA     #2
                STA     25,S   ; fccstk d=0 b=25
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #gt
                CLC
                ADC     #22
                STA     _fcc_fpr0
                LDA     25,S   ; fccstk d=0 b=25
                STA     _fcc_tmp_b
                ASL
                ASL
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_fpr0
                CLC
                ADC     #10
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     19,S   ; fccstk d=0 b=19
                LDA     _fcc_fpr0
                STA     17,S   ; fccstk d=0 b=17
                LDA     19,S   ; fccstk d=0 b=19
                STA     _fcc_fpr0+2
                LDA     17,S   ; fccstk d=0 b=17
                STA     _fcc_fpr0
                LDA     #6682
                STA     [_fcc_fpr0]
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #gt
                CLC
                ADC     #22
                STA     _fcc_fpr0
                LDA     #2
                ASL
                ASL
                ASL
                INC
                INC
                ASL
                CLC
                ADC     _fcc_fpr0
                CLC
                ADC     #10
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                TAX
                TXA
                CMP     #6682
                BEQ     *+5
                BRL     _addrarrowdot_L137
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #gt
                CLC
                ADC     #22
                STA     _fcc_fpr0
                LDA     #1
                ASL
                ASL
                ASL
                INC
                ASL
                CLC
                ADC     _fcc_fpr0
                CLC
                ADC     #10
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                TAX
                TXA
                CMP     #16481
                BEQ     *+5
                BRL     _addrarrowdot_L137
                LDA     #1
                BRL     _addrarrowdot_L138
_addrarrowdot_L137
                LDA     #0
_addrarrowdot_L138
                CMP     #0
                BNE     *+5
                BRL     _addrarrowdot_L135
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #gt
                CLC
                ADC     #22
                STA     _fcc_fpr0
                LDA     #0
                ASL
                ASL
                ASL
                CLC
                ADC     #0
                ASL
                CLC
                ADC     _fcc_fpr0
                CLC
                ADC     #10
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                TAX
                TXA
                CMP     #16480
                BEQ     *+5
                BRL     _addrarrowdot_L135
                LDA     #1
                BRL     _addrarrowdot_L136
_addrarrowdot_L135
                LDA     #0
_addrarrowdot_L136
                CMP     #0
                BNE     *+5
                BRL     _addrarrowdot_L133
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #gt
                CLC
                ADC     #22
                STA     _fcc_fpr0
                LDA     #2
                ASL
                ASL
                ASL
                INC
                INC
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                TAX
                TXA
                CMP     #16450
                BEQ     *+5
                BRL     _addrarrowdot_L133
                LDA     #1
                BRL     _addrarrowdot_L134
_addrarrowdot_L133
                LDA     #0
_addrarrowdot_L134
                CMP     #0
                BNE     *+5
                BRL     _addrarrowdot_L131
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #gt
                CLC
                ADC     #22
                STA     _fcc_fpr0
                LDA     #2
                ASL
                ASL
                ASL
                INC
                INC
                ASL
                CLC
                ADC     _fcc_fpr0
                CLC
                ADC     #16
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                TAX
                TXA
                CMP     #16466
                BEQ     *+5
                BRL     _addrarrowdot_L131
                LDA     #1
                BRL     _addrarrowdot_L132
_addrarrowdot_L131
                LDA     #0
_addrarrowdot_L132
                CMP     #0
                BNE     *+5
                BRL     _addrarrowdot_L129
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #gt
                CLC
                ADC     #22
                STA     _fcc_fpr0
                LDA     #1
                ASL
                ASL
                ASL
                INC
                ASL
                CLC
                ADC     _fcc_fpr0
                CLC
                ADC     #16
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                TAX
                TXA
                CMP     #16465
                BEQ     *+5
                BRL     _addrarrowdot_L129
                LDA     #1
                BRL     _addrarrowdot_L130
_addrarrowdot_L129
                LDA     #0
_addrarrowdot_L130
                CMP     #0
                BNE     *+5
                BRL     _addrarrowdot_L128
                LDA     29,S   ; fccstk d=0 b=29
                TAX
                TXA
                CLC
                ADC     #3
                STA     29,S   ; fccstk d=0 b=29
_addrarrowdot_L128
                FGX2_FARCALL _addrarrowdot_clear
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #gh
                STA     _fcc_fpr0
                LDY     #2
                LDA     [_fcc_fpr0],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #4
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                CLC
                ADC     #20
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     19,S   ; fccstk d=0 b=19
                LDA     _fcc_fpr0
                STA     17,S   ; fccstk d=0 b=17
                LDA     19,S   ; fccstk d=0 b=19
                STA     _fcc_fpr0+2
                LDA     17,S   ; fccstk d=0 b=17
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     #gt
                CLC
                ADC     #20
                STA     _fcc_fpr1
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BEQ     *+5
                BRL     _addrarrowdot_L140
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BEQ     *+5
                BRL     _addrarrowdot_L140
                LDA     #1
                BRL     _addrarrowdot_L141
_addrarrowdot_L140
                LDA     #0
_addrarrowdot_L141
                CMP     #0
                BNE     *+5
                BRL     _addrarrowdot_L139
                LDA     19,S   ; fccstk d=0 b=19
                STA     _fcc_fpr0+2
                LDA     17,S   ; fccstk d=0 b=17
                STA     _fcc_fpr0
                LDA     #6939
                STA     [_fcc_fpr0]
                LDA     gt+20
                TAX
                TXA
                CMP     #6939
                BEQ     *+5
                BRL     _addrarrowdot_L149
                LDA     gt+0
                TAX
                TXA
                CMP     #31354
                BEQ     *+5
                BRL     _addrarrowdot_L149
                LDA     #1
                BRL     _addrarrowdot_L150
_addrarrowdot_L149
                LDA     #0
_addrarrowdot_L150
                CMP     #0
                BNE     *+5
                BRL     _addrarrowdot_L147
                LDA     gt+76
                TAX
                TXA
                CMP     #31611
                BEQ     *+5
                BRL     _addrarrowdot_L147
                LDA     #1
                BRL     _addrarrowdot_L148
_addrarrowdot_L147
                LDA     #0
_addrarrowdot_L148
                CMP     #0
                BNE     *+5
                BRL     _addrarrowdot_L145
                LDA     gt+18
                TAX
                TXA
                CMP     #4113
                BEQ     *+5
                BRL     _addrarrowdot_L145
                LDA     #1
                BRL     _addrarrowdot_L146
_addrarrowdot_L145
                LDA     #0
_addrarrowdot_L146
                CMP     #0
                BNE     *+5
                BRL     _addrarrowdot_L143
                LDA     gh+0
                TAX
                TXA
                CMP     #23130
                BEQ     *+5
                BRL     _addrarrowdot_L143
                LDA     #1
                BRL     _addrarrowdot_L144
_addrarrowdot_L143
                LDA     #0
_addrarrowdot_L144
                CMP     #0
                BNE     *+5
                BRL     _addrarrowdot_L142
                LDA     29,S   ; fccstk d=0 b=29
                TAX
                TXA
                CLC
                ADC     #3
                STA     29,S   ; fccstk d=0 b=29
_addrarrowdot_L142
_addrarrowdot_L139
                LDA     29,S   ; fccstk d=0 b=29
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
main_FRAMESIZE   EQU     30
main_STKGUARD    EQU     0
                FGX2_RELOC_COUNT 14
