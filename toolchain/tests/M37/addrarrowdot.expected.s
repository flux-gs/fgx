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
                SEC
                SBC     #4
                BVC     _addrarrowdot_L3
                EOR     #$8000
_addrarrowdot_L3
                BPL     _addrarrowdot_L2
                LDA     _fcc_img0
                CLC
                ADC     #gt+14
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
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
                BRA     _addrarrowdot_L0
_addrarrowdot_L2
                LDA     #0
                STA     _fcc_img0
_addrarrowdot_L4
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     _fcc_img0
                TAX
                SEC
                SBC     #3
                BVC     _addrarrowdot_L7
                EOR     #$8000
_addrarrowdot_L7
                BMI     *+5
                BRL     _addrarrowdot_L6
                LDA     _fcc_img0
                STA     _fcc_tmp_b
                ASL
                ASL
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                CLC
                ADC     #gt+22
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #16448
                CLC
                ADC     _fcc_img0
                STA     [_fcc_fpr0]
                LDA     _fcc_img0
                STA     _fcc_tmp_b
                ASL
                ASL
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                CLC
                ADC     #gt+22
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0
                CLC
                ADC     #16
                STA     _fcc_fpr0
                LDA     #16464
                CLC
                ADC     _fcc_img0
                STA     [_fcc_fpr0]
                LDA     _fcc_img0
                STA     _fcc_tmp_b
                ASL
                ASL
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                CLC
                ADC     #gt+22
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0
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
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #gt
                STA     _fcc_fpr0
                PLA
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
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #gt
                STA     _fcc_fpr0
                PLA
                LDA     _fcc_fpr0+2
                STA     3,S   ; fccstk d=0 b=3
                LDA     _fcc_fpr0
                STA     1,S   ; fccstk d=0 b=1
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #gh
                STA     _fcc_fpr0
                PLA
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
                LDA     _fcc_fpr0
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     #gt+4
                STA     _fcc_fpr1
                PLA
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BNE     _addrarrowdot_L9
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _addrarrowdot_L9
                LDA     #1
                BRA     _addrarrowdot_L10
_addrarrowdot_L9
                LDA     #0
_addrarrowdot_L10
                CMP     #0
                BNE     *+5
                BRL     _addrarrowdot_L8
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
                LDX     #13124
                STX     _fcc_long_b_lo
                LDX     #4386
                STX     _fcc_long_b_hi
                JSR     _fcc_long_eq
                CMP     #0
                BEQ     _addrarrowdot_L11
                LDA     gt+4
                TAX
                CMP     #8224
                BNE     _addrarrowdot_L11
                LDA     gt+10
                TAX
                CMP     #8225
                BNE     _addrarrowdot_L11
                LDA     gt+2
                TAX
                CMP     #4112
                BNE     _addrarrowdot_L11
                LDA     gt+12
                TAX
                CMP     #4114
                BNE     _addrarrowdot_L11
                LDA     gt+18
                TAX
                CMP     #4113
                BNE     _addrarrowdot_L11
                LDA     gt+0
                TAX
                CMP     #31354
                BNE     _addrarrowdot_L11
                LDA     gt+20
                TAX
                CMP     #31868
                BNE     _addrarrowdot_L11
                LDA     gt+76
                TAX
                CMP     #31611
                BNE     _addrarrowdot_L11
                LDA     29,S   ; fccstk d=0 b=29
                TAX
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
                LDA     _fcc_fpr0
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     #gt+12
                STA     _fcc_fpr1
                PLA
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BNE     _addrarrowdot_L13
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _addrarrowdot_L13
                LDA     #1
                BRA     _addrarrowdot_L14
_addrarrowdot_L13
                LDA     #0
_addrarrowdot_L14
                CMP     #0
                BEQ     _addrarrowdot_L12
                LDA     #2989
                STA     [_fcc_fpr0]
                LDA     gt+12
                TAX
                CMP     #2989
                BNE     _addrarrowdot_L15
                LDA     gt+2
                TAX
                CMP     #4112
                BNE     _addrarrowdot_L15
                LDA     gt+18
                TAX
                CMP     #4113
                BNE     _addrarrowdot_L15
                LDA     gt+10
                TAX
                CMP     #8225
                BNE     _addrarrowdot_L15
                LDA     gt+14
                AND     #$00FF
                TAX
                CMP     #48
                BNE     _addrarrowdot_L15
                LDA     gt+20
                TAX
                CMP     #31868
                BNE     _addrarrowdot_L15
                LDA     29,S   ; fccstk d=0 b=29
                TAX
                CLC
                ADC     #4
                STA     29,S   ; fccstk d=0 b=29
_addrarrowdot_L15
_addrarrowdot_L12
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
                LDA     _fcc_fpr0
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     #gt+6
                STA     _fcc_fpr1
                PLA
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BNE     _addrarrowdot_L17
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _addrarrowdot_L17
                LDA     #1
                BRA     _addrarrowdot_L18
_addrarrowdot_L17
                LDA     #0
_addrarrowdot_L18
                CMP     #0
                BEQ     _addrarrowdot_L16
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
                LDX     #48879
                STX     _fcc_long_b_lo
                LDX     #32493
                STX     _fcc_long_b_hi
                JSR     _fcc_long_eq
                CMP     #0
                BEQ     _addrarrowdot_L19
                LDA     gt+4
                TAX
                CMP     #8224
                BNE     _addrarrowdot_L19
                LDA     gt+10
                TAX
                CMP     #8225
                BNE     _addrarrowdot_L19
                LDA     gt+12
                TAX
                CMP     #4114
                BNE     _addrarrowdot_L19
                LDA     29,S   ; fccstk d=0 b=29
                TAX
                CLC
                ADC     #4
                STA     29,S   ; fccstk d=0 b=29
_addrarrowdot_L19
_addrarrowdot_L16
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
                LDA     #2
                CLC
                ADC     #gt+14
                STA     _fcc_fpr1
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BNE     _addrarrowdot_L21
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _addrarrowdot_L21
                LDA     #1
                BRA     _addrarrowdot_L22
_addrarrowdot_L21
                LDA     #0
_addrarrowdot_L22
                CMP     #0
                BEQ     _addrarrowdot_L20
                LDA     #95
                SEP     #$20
                MX      %10
                STA     [_fcc_fpr0]
                REP     #$20
                MX      %00
                LDA     gt+16
                AND     #$00FF
                TAX
                CMP     #95
                BNE     _addrarrowdot_L23
                LDA     gt+15
                AND     #$00FF
                TAX
                CMP     #49
                BNE     _addrarrowdot_L23
                LDA     gt+17
                AND     #$00FF
                TAX
                CMP     #51
                BNE     _addrarrowdot_L23
                LDA     gt+12
                TAX
                CMP     #4114
                BNE     _addrarrowdot_L23
                LDA     gt+18
                TAX
                CMP     #4113
                BNE     _addrarrowdot_L23
                LDA     29,S   ; fccstk d=0 b=29
                TAX
                CLC
                ADC     #4
                STA     29,S   ; fccstk d=0 b=29
_addrarrowdot_L23
_addrarrowdot_L20
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
                LDA     _fcc_fpr0
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     #gt+50
                STA     _fcc_fpr1
                PLA
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BNE     _addrarrowdot_L25
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _addrarrowdot_L25
                LDA     #1
                BRA     _addrarrowdot_L26
_addrarrowdot_L25
                LDA     #0
_addrarrowdot_L26
                CMP     #0
                BEQ     _addrarrowdot_L24
                LDA     #3084
                STA     [_fcc_fpr0]
                LDA     gt+50
                TAX
                CMP     #3084
                BNE     _addrarrowdot_L27
                LDA     gt+32
                TAX
                CMP     #16480
                BNE     _addrarrowdot_L27
                LDA     gt+68
                TAX
                CMP     #16482
                BNE     _addrarrowdot_L27
                LDA     gt+40
                TAX
                CMP     #16449
                BNE     _addrarrowdot_L27
                LDA     gt+56
                TAX
                CMP     #16465
                BNE     _addrarrowdot_L27
                LDA     gt+38
                TAX
                CMP     #16464
                BNE     _addrarrowdot_L27
                LDA     gt+58
                TAX
                CMP     #16450
                BNE     _addrarrowdot_L27
                LDA     29,S   ; fccstk d=0 b=29
                TAX
                CLC
                ADC     #4
                STA     29,S   ; fccstk d=0 b=29
_addrarrowdot_L27
_addrarrowdot_L24
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
                LDA     _fcc_fpr0
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     #gt+62
                STA     _fcc_fpr1
                PLA
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BNE     _addrarrowdot_L29
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _addrarrowdot_L29
                LDA     #1
                BRA     _addrarrowdot_L30
_addrarrowdot_L29
                LDA     #0
_addrarrowdot_L30
                CMP     #0
                BEQ     _addrarrowdot_L28
                LDA     #$0123
                STA     _fcc_long_hi
                LDA     #$FEDC
                STA     [_fcc_fpr0]
                TAX
                LDA     _fcc_long_hi
                LDY     #2
                STA     [_fcc_fpr0],Y
                TXA
                LDA     gt+64
                STA     _fcc_long_hi
                LDA     gt+62
                LDX     #65244
                STX     _fcc_long_b_lo
                LDX     #291
                STX     _fcc_long_b_hi
                JSR     _fcc_long_eq
                CMP     #0
                BEQ     _addrarrowdot_L31
                LDA     gt+68
                TAX
                CMP     #16482
                BNE     _addrarrowdot_L31
                LDA     gt+58
                TAX
                CMP     #16450
                BNE     _addrarrowdot_L31
                LDA     gt+56
                TAX
                CMP     #16465
                BNE     _addrarrowdot_L31
                LDA     29,S   ; fccstk d=0 b=29
                TAX
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
                LDA     _fcc_fpr0
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     #gt+20
                STA     _fcc_fpr1
                PLA
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BNE     _addrarrowdot_L33
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _addrarrowdot_L33
                LDA     #1
                BRA     _addrarrowdot_L34
_addrarrowdot_L33
                LDA     #0
_addrarrowdot_L34
                CMP     #0
                BEQ     _addrarrowdot_L32
                LDA     #3501
                STA     [_fcc_fpr0]
                LDA     gt+20
                TAX
                CMP     #3501
                BNE     _addrarrowdot_L35
                LDA     gt+0
                TAX
                CMP     #31354
                BNE     _addrarrowdot_L35
                LDA     gt+76
                TAX
                CMP     #31611
                BNE     _addrarrowdot_L35
                LDA     gt+18
                TAX
                CMP     #4113
                BNE     _addrarrowdot_L35
                LDA     gt+22
                TAX
                CMP     #16448
                BNE     _addrarrowdot_L35
                LDA     29,S   ; fccstk d=0 b=29
                TAX
                CLC
                ADC     #4
                STA     29,S   ; fccstk d=0 b=29
_addrarrowdot_L35
_addrarrowdot_L32
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
                LDA     _fcc_fpr0
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     #gt+12
                STA     _fcc_fpr1
                PLA
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BNE     _addrarrowdot_L37
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _addrarrowdot_L37
                LDA     #1
                BRA     _addrarrowdot_L38
_addrarrowdot_L37
                LDA     #0
_addrarrowdot_L38
                CMP     #0
                BEQ     _addrarrowdot_L36
                LDA     #3598
                STA     [_fcc_fpr0]
                LDA     gt+12
                TAX
                CMP     #3598
                BNE     _addrarrowdot_L39
                LDA     gt+2
                TAX
                CMP     #4112
                BNE     _addrarrowdot_L39
                LDA     gt+18
                TAX
                CMP     #4113
                BNE     _addrarrowdot_L39
                LDA     gt+20
                TAX
                CMP     #31868
                BNE     _addrarrowdot_L39
                LDA     29,S   ; fccstk d=0 b=29
                TAX
                CLC
                ADC     #4
                STA     29,S   ; fccstk d=0 b=29
_addrarrowdot_L39
_addrarrowdot_L36
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
                LDA     _fcc_fpr0
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     #gh+16
                STA     _fcc_fpr1
                PLA
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BNE     _addrarrowdot_L41
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _addrarrowdot_L41
                LDA     #1
                BRA     _addrarrowdot_L42
_addrarrowdot_L41
                LDA     #0
_addrarrowdot_L42
                CMP     #0
                BEQ     _addrarrowdot_L40
                LDA     #3855
                STA     [_fcc_fpr0]
                LDA     gh+16
                TAX
                CMP     #3855
                BNE     _addrarrowdot_L43
                LDA     gh+6
                TAX
                CMP     #24672
                BNE     _addrarrowdot_L43
                LDA     gh+22
                TAX
                CMP     #24673
                BNE     _addrarrowdot_L43
                LDA     gh+0
                TAX
                CMP     #23130
                BNE     _addrarrowdot_L43
                LDA     gh+24
                TAX
                CMP     #23387
                BNE     _addrarrowdot_L43
                LDA     gh+4
                STA     _fcc_fpr0+2
                LDA     gh+2
                STA     _fcc_fpr0
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     #gt
                STA     _fcc_fpr1
                PLA
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BNE     _addrarrowdot_L44
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _addrarrowdot_L44
                LDA     #1
                BRA     _addrarrowdot_L45
_addrarrowdot_L44
                LDA     #0
_addrarrowdot_L45
                CMP     #0
                BEQ     _addrarrowdot_L43
                LDA     29,S   ; fccstk d=0 b=29
                TAX
                CLC
                ADC     #4
                STA     29,S   ; fccstk d=0 b=29
_addrarrowdot_L43
_addrarrowdot_L40
                FGX2_FARCALL _addrarrowdot_clear
                LDA     #2
                STA     25,S   ; fccstk d=0 b=25
                STA     _fcc_tmp_b
                ASL
                ASL
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                CLC
                ADC     #gt+22
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0
                CLC
                ADC     #10
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     19,S   ; fccstk d=0 b=19
                LDA     _fcc_fpr0
                STA     17,S   ; fccstk d=0 b=17
                LDA     #6682
                STA     [_fcc_fpr0]
                LDA     gt+68
                TAX
                CMP     #6682
                BNE     _addrarrowdot_L46
                LDA     gt+50
                TAX
                CMP     #16481
                BNE     _addrarrowdot_L46
                LDA     gt+32
                TAX
                CMP     #16480
                BNE     _addrarrowdot_L46
                LDA     gt+58
                TAX
                CMP     #16450
                BNE     _addrarrowdot_L46
                LDA     gt+74
                TAX
                CMP     #16466
                BNE     _addrarrowdot_L46
                LDA     gt+56
                TAX
                CMP     #16465
                BNE     _addrarrowdot_L46
                LDA     29,S   ; fccstk d=0 b=29
                TAX
                CLC
                ADC     #3
                STA     29,S   ; fccstk d=0 b=29
_addrarrowdot_L46
                FGX2_FARCALL _addrarrowdot_clear
                SEP     #$20
                MX      %10
                LDA     gh+4
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     gh+2
                CLC
                ADC     #20
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     19,S   ; fccstk d=0 b=19
                LDA     _fcc_fpr0
                STA     17,S   ; fccstk d=0 b=17
                LDA     _fcc_fpr0
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     #gt+20
                STA     _fcc_fpr1
                PLA
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BNE     _addrarrowdot_L48
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _addrarrowdot_L48
                LDA     #1
                BRA     _addrarrowdot_L49
_addrarrowdot_L48
                LDA     #0
_addrarrowdot_L49
                CMP     #0
                BEQ     _addrarrowdot_L47
                LDA     #6939
                STA     [_fcc_fpr0]
                LDA     gt+20
                TAX
                CMP     #6939
                BNE     _addrarrowdot_L50
                LDA     gt+0
                TAX
                CMP     #31354
                BNE     _addrarrowdot_L50
                LDA     gt+76
                TAX
                CMP     #31611
                BNE     _addrarrowdot_L50
                LDA     gt+18
                TAX
                CMP     #4113
                BNE     _addrarrowdot_L50
                LDA     gh+0
                TAX
                CMP     #23130
                BNE     _addrarrowdot_L50
                LDA     29,S   ; fccstk d=0 b=29
                TAX
                CLC
                ADC     #3
                STA     29,S   ; fccstk d=0 b=29
_addrarrowdot_L50
_addrarrowdot_L47
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
