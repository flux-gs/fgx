                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from arrpost.c
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
                LDA     #1
                STA     _fcc_img1
                LDA     #10
                STA     _fcc_img0
                LDA     #w
                PHA
                LDA     #1
                ASL
                CLC
                ADC     1,S
                TAY
                PLA
                TYA
                PHA
                LDA     #4
                TAY
                LDA     1,S
                TAX
                TYA
                STA:    $0000,X
                PLA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #w
                STA     _fcc_fpr0
                LDA     _fcc_img1
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                STA     _fcc_tmp_b
                INC
                STA     [_fcc_fpr0]
                LDA     #b
                PHA
                LDA     #2
                CLC
                ADC     1,S
                TAY
                PLA
                TYA
                PHA
                LDA     #9
                TAY
                LDA     1,S
                TAX
                TYA
                SEP     #$20
                MX      %10
                STA:    $0000,X
                REP     #$20
                MX      %00
                PLA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #b
                STA     _fcc_fpr0
                LDA     #2
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                AND     #$00FF
                STA     _fcc_tmp_b
                DEC
                SEP     #$20
                MX      %10
                STA     [_fcc_fpr0]
                REP     #$20
                MX      %00
                LDA     #1
                ASL
                TAX
                LDA:    w,X
                TAX
                LDA     #5
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BEQ     *+5
                BRL     _arrpost_L0
                LDA     _fcc_img0
                TAX
                LDA     #16
                STA     _fcc_tmp_b
                TXA
                CLC
                ADC     _fcc_tmp_b
                STA     _fcc_img0
_arrpost_L0
                LDA     #2
                TAX
                LDA:    b,X
                AND     #$00FF
                TAX
                LDA     #8
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BEQ     *+5
                BRL     _arrpost_L1
                LDA     _fcc_img0
                TAX
                LDA     #8
                STA     _fcc_tmp_b
                TXA
                CLC
                ADC     _fcc_tmp_b
                STA     _fcc_img0
_arrpost_L1
                LDA     _fcc_img1
                TAX
                LDA     #1
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BEQ     *+5
                BRL     _arrpost_L2
                LDA     _fcc_img0
                TAX
                LDA     #8
                STA     _fcc_tmp_b
                TXA
                CLC
                ADC     _fcc_tmp_b
                STA     _fcc_img0
_arrpost_L2
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
main_FRAMESIZE   EQU     4
main_STKGUARD    EQU     0
                FGX2_RELOC_COUNT 2
