                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from fprloop.c
;---------------------------------------

                MX      %00
                FGX2_EXPORT main
main            ENT
                PEI     _fcc_fb
                PEI     _fcc_img16
                TSC
                SEC
                SBC     #main_FRAMESIZE-2
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
                STA     7,S   ; fccstk d=0 b=7
                LDA     #2
                STA     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                ASL
                CLC
                ADC     #g1
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #77
                STA     [_fcc_fpr0]
                LDA     #3
                STA     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                ASL
                CLC
                ADC     #g1
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #78
                STA     [_fcc_fpr0]
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #g1
                STA     _fcc_fpr0
                PLA
                LDA     _fcc_fpr0+2
                STA     3,S   ; fccstk d=0 b=3
                LDA     _fcc_fpr0
                STA     1,S   ; fccstk d=0 b=1
                LDA     #0
                STA     _fcc_img16
_fprloop_L0
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     _fcc_img16
                TAX
                SEC
                SBC     #4
                BVC     _fprloop_L3
                EOR     #$8000
_fprloop_L3
                BMI     *+5
                BRL     _fprloop_L2
                LDA     #28
                PHA
                LDA     #0
                PHA
                LDA     7,S   ; fccstk d=4 b=3
                STA     _fcc_fpr0+2
                LDA     5,S   ; fccstk d=4 b=1
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL memset
                TSC
                CLC
                ADC     #8
                TCS
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDA     _fcc_img16
                TAX
                INC
                STA     [_fcc_fpr0]
                LDA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     #_fprloop_S0
                STA     _fcc_fpr1
                PEI     _fcc_fpr1+2
                PEI     _fcc_fpr1
                FGX2_FARCALL strdup
                TAY
                TSC
                CLC
                ADC     #4
                TCS
                TYA
                LDA     _fcc_fpr0
                STA     _fcc_fpr1
                LDA     _fcc_fpr0+2
                STA     _fcc_fpr1+2
                TAY
                PLA
                STA     _fcc_fpr0
                PLA
                STA     _fcc_fpr0+2
                TYA
                LDA     _fcc_fpr1
                LDY     #2
                STA     [_fcc_fpr0],Y
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr1+2
                LDY     #4
                STA     [_fcc_fpr0],Y
                REP     #$20
                MX      %00
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDY     #2
                LDA     [_fcc_fpr0],Y
                PHA
                INY
                INY
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                PLA
                STA     _fcc_fpr0
                LDA     #0
                STA     _fcc_fpr1
                STZ     _fcc_fpr1+2
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BNE     _fprloop_L5
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _fprloop_L5
                LDA     #1
                BRA     _fprloop_L6
_fprloop_L5
                LDA     #0
_fprloop_L6
                CMP     #0
                BEQ     _fprloop_L4
                LDA     #9
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-2
                TCS
                BRL     main_bandx
_fprloop_L4
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_ptr+2
                LDA     1,S   ; fccstk d=0 b=1
                CLC
                ADC     #28
                STA     1,S   ; fccstk d=0 b=1
                LDA     _fcc_img16
                TAX
                CMP     #1
                BNE     _fprloop_L7
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #g2
                STA     _fcc_fpr0
                PLA
                LDA     _fcc_fpr0+2
                STA     3,S   ; fccstk d=0 b=3
                LDA     _fcc_fpr0
                STA     1,S   ; fccstk d=0 b=1
_fprloop_L7
_fprloop_L1
                INC     _fcc_img16
                BRL     _fprloop_L0
_fprloop_L2
                LDA     #0
                STA     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                ASL
                CLC
                ADC     #g1
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     [_fcc_fpr0]
                CMP     #1
                BNE     _fprloop_L8
                LDA     7,S   ; fccstk d=0 b=7
                CLC
                ADC     #6
                STA     7,S   ; fccstk d=0 b=7
_fprloop_L8
                LDA     #1
                STA     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                ASL
                CLC
                ADC     #g1
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     [_fcc_fpr0]
                CMP     #2
                BNE     _fprloop_L9
                LDA     7,S   ; fccstk d=0 b=7
                CLC
                ADC     #6
                STA     7,S   ; fccstk d=0 b=7
_fprloop_L9
                LDA     #0
                STA     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                ASL
                CLC
                ADC     #g2
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     [_fcc_fpr0]
                CMP     #3
                BNE     _fprloop_L10
                LDA     7,S   ; fccstk d=0 b=7
                CLC
                ADC     #6
                STA     7,S   ; fccstk d=0 b=7
_fprloop_L10
                LDA     #1
                STA     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                ASL
                CLC
                ADC     #g2
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     [_fcc_fpr0]
                CMP     #4
                BNE     _fprloop_L11
                LDA     7,S   ; fccstk d=0 b=7
                CLC
                ADC     #6
                STA     7,S   ; fccstk d=0 b=7
_fprloop_L11
                LDA     #2
                STA     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                ASL
                CLC
                ADC     #g1
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     [_fcc_fpr0]
                CMP     #77
                BNE     _fprloop_L12
                LDA     7,S   ; fccstk d=0 b=7
                CLC
                ADC     #6
                STA     7,S   ; fccstk d=0 b=7
_fprloop_L12
                LDA     #3
                STA     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                ASL
                CLC
                ADC     #g1
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     [_fcc_fpr0]
                TAX
                CMP     #78
                BNE     _fprloop_L13
                LDA     7,S   ; fccstk d=0 b=7
                TAX
                CLC
                ADC     #6
                STA     7,S   ; fccstk d=0 b=7
_fprloop_L13
                LDA     #2
                STA     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                ASL
                CLC
                ADC     #g2
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     [_fcc_fpr0]
                BNE     _fprloop_L14
                LDA     7,S   ; fccstk d=0 b=7
                TAX
                CLC
                ADC     #6
                STA     7,S   ; fccstk d=0 b=7
_fprloop_L14
                LDA     7,S   ; fccstk d=0 b=7
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-2
                TCS
main_bandx
                PLA
                STA     _fcc_img16
                PLA
                STA     _fcc_fb
                TYA
                RTL
main_FRAMESIZE   EQU     10
main_STKGUARD    EQU     0
                FGX2_RELOC_COUNT 4
