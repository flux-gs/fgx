                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from m2d_field.c
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
                LDA     #100
                STA     F+0
                LDA     #200
                STA     F+26
                LDA     #1
                SEP     #$20
                MX      %10
                STA     F+2
                REP     #$20
                MX      %00
                LDA     #2
                SEP     #$20
                MX      %10
                STA     F+25
                REP     #$20
                MX      %00
                LDA     #2
                STA     _fcc_img1
                STA     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
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
                LDA     _fcc_fpr0
                INC
                STA     _fcc_fpr0
                LDA     #4
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
                CLC
                ADC     #6
                INC
                INC
                STA     _fcc_fpr0
                LDA     #8
                SEP     #$20
                MX      %10
                STA     [_fcc_fpr0]
                LDA     pf+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     pf
                CLC
                ADC     #2
                STA     _fcc_fpr0
                LDA     #1
                TAX
                LDA     #6
                STA     _fcc_tmp_b
                TXA
                JSR     _fcc_mul16
                TAX
                INC
                INC
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                AND     #$00FF
                PHA
                LDA     F+2
                AND     #$00FF
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                PHA
                LDA     F+25
                AND     #$00FF
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                STA     _fcc_img0
                PHA
                SEP     #$20
                MX      %10
                LDA     pf+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     pf
                CLC
                ADC     #2
                STA     _fcc_fpr0
                LDA     _fcc_img1
                TAX
                LDA     #6
                STA     _fcc_tmp_b
                TXA
                JSR     _fcc_mul16
                TAX
                INC
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                AND     #$00FF
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                STA     _fcc_img0
                PHA
                LDA     F+25
                AND     #$00FF
                TAX
                CMP     #2
                BNE     _m2d_field_L0
                LDA     #16
                BRA     _m2d_field_L1
_m2d_field_L0
                LDA     #0
_m2d_field_L1
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                STA     _fcc_img0
                PHA
                LDA     F+15
                AND     #$00FF
                TAX
                CMP     #4
                BNE     _m2d_field_L2
                LDA     #32
                BRA     _m2d_field_L3
_m2d_field_L2
                LDA     #0
_m2d_field_L3
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                STA     _fcc_img0
                PHA
                LDA     #24
                TAX
                CMP     #24
                BNE     _m2d_field_L4
                LDA     #64
                BRA     _m2d_field_L5
_m2d_field_L4
                LDA     #0
_m2d_field_L5
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                STA     _fcc_img0
                PHA
                LDA     F+0
                TAX
                CMP     #100
                BNE     _m2d_field_L6
                LDA     F+26
                TAX
                CMP     #200
                BNE     _m2d_field_L6
                LDA     #128
                BRA     _m2d_field_L7
_m2d_field_L6
                LDA     #0
_m2d_field_L7
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                STA     _fcc_img0
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
main_FRAMESIZE   EQU     4
main_STKGUARD    EQU     0
                FGX2_RELOC_COUNT 2
