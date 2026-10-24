                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from m2d_row2.c
;---------------------------------------

                MX      %00
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
                LDA     #2
                STA     _fcc_img1
                LDA     #3
                STA     _fcc_img2
                LDA     #1
                STA     _fcc_img3
                LDA     #0
                STA     _fcc_img0
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #S3
                STA     _fcc_fpr0
                PLA
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0
                STA     H+0
                TAY
                LDA     _fcc_ptr+2
                STA     H+2
                TYA
                LDA     _fcc_img3
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
                ADC     #FA
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0
                INC
                INC
                STA     _fcc_fpr0
                LDA     _fcc_img1
                STA     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_img2
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     #101
                SEP     #$20
                MX      %10
                STA     [_fcc_fpr0]
                REP     #$20
                MX      %00
                LDA     _fcc_img3
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
                ADC     #FA
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
                ADC     #2
                STA     _fcc_fpr0
                LDA     _fcc_img1
                TAX
                LDA     #6
                STA     _fcc_tmp_b
                TXA
                JSR     _fcc_mul16
                CLC
                ADC     _fcc_img2
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                AND     #$00FF
                TAX
                CMP     #101
                BNE     _m2d_row2_L0
                LDA     _fcc_img0
                TAX
                CLC
                ADC     #1
                STA     _fcc_img0
_m2d_row2_L0
                SEP     #$20
                MX      %10
                LDA     pfa+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     pfa
                STA     _fcc_fpr0
                LDA     _fcc_img3
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
                ADC     _fcc_fpr0
                CLC
                ADC     #2
                STA     _fcc_fpr0
                LDA     _fcc_img1
                TAX
                LDA     #6
                STA     _fcc_tmp_b
                TXA
                JSR     _fcc_mul16
                CLC
                ADC     _fcc_img2
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                AND     #$00FF
                TAX
                CMP     #101
                BNE     _m2d_row2_L1
                LDA     _fcc_img0
                TAX
                CLC
                ADC     #2
                STA     _fcc_img0
_m2d_row2_L1
                LDA     #6
                TAX
                CMP     #6
                BNE     _m2d_row2_L3
                LDA     #6
                TAX
                CMP     #6
                BNE     _m2d_row2_L3
                LDA     #1
                BRA     _m2d_row2_L4
_m2d_row2_L3
                LDA     #0
_m2d_row2_L4
                CMP     #0
                BEQ     _m2d_row2_L2
                LDA     _fcc_img0
                TAX
                CLC
                ADC     #4
                STA     _fcc_img0
_m2d_row2_L2
                LDA     #1
                TAX
                CMP     #1
                BNE     _m2d_row2_L6
                LDA     #1
                TAX
                CMP     #1
                BNE     _m2d_row2_L6
                LDA     #1
                BRA     _m2d_row2_L7
_m2d_row2_L6
                LDA     #0
_m2d_row2_L7
                CMP     #0
                BEQ     _m2d_row2_L5
                LDA     _fcc_img0
                TAX
                CLC
                ADC     #8
                STA     _fcc_img0
_m2d_row2_L5
                LDA     #2
                CLC
                ADC     #S3
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_img1
                STA     _fcc_tmp_b
                ASL
                ASL
                CLC
                ADC     _fcc_tmp_b
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     _fcc_img2
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     #104
                SEP     #$20
                MX      %10
                STA     [_fcc_fpr0]
                LDA     ps3+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     ps3
                INC
                INC
                STA     _fcc_fpr0
                LDA     _fcc_img1
                STA     _fcc_tmp_b
                ASL
                ASL
                CLC
                ADC     _fcc_tmp_b
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     _fcc_img2
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                AND     #$00FF
                TAX
                CMP     #104
                BNE     _m2d_row2_L8
                LDA     _fcc_img0
                TAX
                CLC
                ADC     #16
                STA     _fcc_img0
_m2d_row2_L8
                SEP     #$20
                MX      %10
                LDA     ph+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     ph
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
                INC
                INC
                STA     _fcc_fpr0
                LDA     _fcc_img1
                STA     _fcc_tmp_b
                ASL
                ASL
                CLC
                ADC     _fcc_tmp_b
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     _fcc_img2
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                AND     #$00FF
                TAX
                CMP     #104
                BNE     _m2d_row2_L9
                LDA     _fcc_img0
                TAX
                CLC
                ADC     #32
                STA     _fcc_img0
_m2d_row2_L9
                LDA     _fcc_img1
                STA     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_img2
                CLC
                ADC     #F+2
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #122
                SEP     #$20
                MX      %10
                STA     [_fcc_fpr0]
                LDA     pf+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     pf
                INC
                INC
                STA     _fcc_fpr0
                LDA     _fcc_img1
                STA     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     _fcc_img2
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                AND     #$00FF
                TAX
                CMP     #122
                BNE     _m2d_row2_L10
                LDA     _fcc_img0
                TAX
                CLC
                ADC     #64
                STA     _fcc_img0
_m2d_row2_L10
                SEP     #$20
                MX      %10
                LDA     pf+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     pf
                INC
                INC
                STA     _fcc_fpr0
                LDA     _fcc_img1
                STA     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     _fcc_img5
                LDA     _fcc_fpr0
                STA     _fcc_img4
                LDA     _fcc_img5
                STA     _fcc_ptr+2
                LDA     _fcc_img4
                INC
                STA     _fcc_img4
                LDA     _fcc_img5
                STA     _fcc_fpr0+2
                LDA     _fcc_img4
                STA     _fcc_fpr0
                LDA     _fcc_img1
                STA     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                TAX
                INC
                CLC
                ADC     #F+2
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
                BNE     _m2d_row2_L12
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _m2d_row2_L12
                LDA     #1
                BRA     _m2d_row2_L13
_m2d_row2_L12
                LDA     #0
_m2d_row2_L13
                CMP     #0
                BEQ     _m2d_row2_L11
                LDA     _fcc_img0
                TAX
                CLC
                ADC     #128
                STA     _fcc_img0
_m2d_row2_L11
                LDA     _fcc_img0
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
main_FRAMESIZE   EQU     12
main_STKGUARD    EQU     0
                FGX2_RELOC_COUNT 2
