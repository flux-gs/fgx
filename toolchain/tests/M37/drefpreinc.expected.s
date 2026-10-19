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
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #buf
                STA     rp
                LDA     _fcc_fpr0+2
                STA     rp+2
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #rp
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
                LDA     #66
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BNE     *+5
                BRL     _drefpreinc_L0
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
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     #buf
                STA     _fcc_fpr1
                LDA     #1
                CLC
                ADC     _fcc_fpr1
                STA     _fcc_fpr1
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BEQ     *+5
                BRL     _drefpreinc_L2
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BEQ     *+5
                BRL     _drefpreinc_L2
                LDA     #0
                BRL     _drefpreinc_L3
_drefpreinc_L2
                LDA     #1
_drefpreinc_L3
                CMP     #0
                BNE     *+5
                BRL     _drefpreinc_L1
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
                STA     _fcc_fpr1
                LDA     #1
                STA     _fcc_tmp_b
                LDA     _fcc_fpr1
                SEC
                SBC     _fcc_tmp_b
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
                LDA     #65
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BNE     *+5
                BRL     _drefpreinc_L4
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
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     #buf
                STA     _fcc_fpr1
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BEQ     *+5
                BRL     _drefpreinc_L6
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BEQ     *+5
                BRL     _drefpreinc_L6
                LDA     #0
                BRL     _drefpreinc_L7
_drefpreinc_L6
                LDA     #1
_drefpreinc_L7
                CMP     #0
                BNE     *+5
                BRL     _drefpreinc_L5
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
                LDA     #65
                STA     _fcc_tmp_b
                TXA
                SEC
                SBC     _fcc_tmp_b
                TAX
                LDA     #42
                STA     _fcc_tmp_b
                TXA
                CLC
                ADC     _fcc_tmp_b
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
