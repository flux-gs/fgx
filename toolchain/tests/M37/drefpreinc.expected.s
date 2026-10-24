                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from drefpreinc.c
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
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #buf
                STA     _fcc_fpr0
                PLA
                LDA     _fcc_fpr0
                STA     rp
                LDA     _fcc_fpr0+2
                STA     rp+2
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #rp
                STA     _fcc_fpr0
                PLA
                LDA     _fcc_fpr0
                STA     pp
                LDA     _fcc_fpr0+2
                STA     pp+2
                SEP     #$20
                MX      %10
                LDA     pp+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     pp
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                LDA     pp+2
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     pp
                STA     _fcc_fpr1
                LDA     [_fcc_fpr1]
                PHA
                SEP     #$20
                MX      %10
                LDY     #2
                LDA     [_fcc_fpr1],Y
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr1
                LDA     #1
                CLC
                ADC     _fcc_fpr1
                STA     _fcc_fpr1
                STA     [_fcc_fpr0]
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr1+2
                LDY     #2
                STA     [_fcc_fpr0],Y
                REP     #$20
                MX      %00
                LDA     _fcc_fpr1
                STA     _fcc_fpr0
                LDA     _fcc_fpr1+2
                STA     _fcc_fpr0+2
                LDA     [_fcc_fpr0]
                AND     #$00FF
                STA     _fcc_img0
                AND     #$00FF
                TAX
                CMP     #66
                BEQ     _drefpreinc_L0
                LDA     #1
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_drefpreinc_L0
                SEP     #$20
                MX      %10
                LDA     rp+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     rp
                STA     _fcc_fpr0
                LDA     #1
                CLC
                ADC     #buf
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
                BNE     _drefpreinc_L2
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _drefpreinc_L2
                LDA     #0
                BRA     _drefpreinc_L3
_drefpreinc_L2
                LDA     #1
_drefpreinc_L3
                CMP     #0
                BEQ     _drefpreinc_L1
                LDA     #2
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_drefpreinc_L1
                SEP     #$20
                MX      %10
                LDA     pp+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     pp
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                LDA     pp+2
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     pp
                STA     _fcc_fpr1
                LDA     [_fcc_fpr1]
                PHA
                SEP     #$20
                MX      %10
                LDY     #2
                LDA     [_fcc_fpr1],Y
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                PLA
                DEC
                STA     _fcc_fpr1
                STA     [_fcc_fpr0]
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr1+2
                LDY     #2
                STA     [_fcc_fpr0],Y
                REP     #$20
                MX      %00
                LDA     _fcc_fpr1
                STA     _fcc_fpr0
                LDA     _fcc_fpr1+2
                STA     _fcc_fpr0+2
                LDA     [_fcc_fpr0]
                AND     #$00FF
                STA     _fcc_img0
                AND     #$00FF
                TAX
                CMP     #65
                BEQ     _drefpreinc_L4
                LDA     #3
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_drefpreinc_L4
                SEP     #$20
                MX      %10
                LDA     rp+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     rp
                STA     _fcc_fpr0
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     #buf
                STA     _fcc_fpr1
                PLA
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BNE     _drefpreinc_L6
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _drefpreinc_L6
                LDA     #0
                BRA     _drefpreinc_L7
_drefpreinc_L6
                LDA     #1
_drefpreinc_L7
                CMP     #0
                BEQ     _drefpreinc_L5
                LDA     #4
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_drefpreinc_L5
                LDA     _fcc_img0
                AND     #$00FF
                TAX
                SEC
                SBC     #65
                TAX
                CLC
                ADC     #42
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
main_FRAMESIZE   EQU     2
main_STKGUARD    EQU     0
                FGX2_RELOC_COUNT 2
