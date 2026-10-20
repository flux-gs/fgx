                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from sptrnull.c
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
                LDA     gp+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     gp
                STA     _fcc_fpr0
                LDA     #0
                STA     _fcc_fpr1
                STZ     _fcc_fpr1+2
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BEQ     *+5
                BRL     _sptrnull_L1
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BEQ     *+5
                BRL     _sptrnull_L1
                LDA     #0
                BRL     _sptrnull_L2
_sptrnull_L1
                LDA     #1
_sptrnull_L2
                CMP     #0
                BNE     *+5
                BRL     _sptrnull_L0
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
_sptrnull_L0
                SEP     #$20
                MX      %10
                LDA     gq+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     gq
                STA     _fcc_fpr0
                LDA     #0
                STA     _fcc_fpr1
                STZ     _fcc_fpr1+2
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BEQ     *+5
                BRL     _sptrnull_L4
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BEQ     *+5
                BRL     _sptrnull_L4
                LDA     #0
                BRL     _sptrnull_L5
_sptrnull_L4
                LDA     #1
_sptrnull_L5
                CMP     #0
                BNE     *+5
                BRL     _sptrnull_L3
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
_sptrnull_L3
                SEP     #$20
                MX      %10
                LDA     ip+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     ip
                STA     _fcc_fpr0
                LDA     #0
                STA     _fcc_fpr1
                STZ     _fcc_fpr1+2
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BEQ     *+5
                BRL     _sptrnull_L7
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BEQ     *+5
                BRL     _sptrnull_L7
                LDA     #0
                BRL     _sptrnull_L8
_sptrnull_L7
                LDA     #1
_sptrnull_L8
                CMP     #0
                BNE     *+5
                BRL     _sptrnull_L6
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
_sptrnull_L6
                SEP     #$20
                MX      %10
                LDA     cpp+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     cpp
                STA     _fcc_fpr0
                LDA     #0
                STA     _fcc_fpr1
                STZ     _fcc_fpr1+2
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BEQ     *+5
                BRL     _sptrnull_L10
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BEQ     *+5
                BRL     _sptrnull_L10
                LDA     #0
                BRL     _sptrnull_L11
_sptrnull_L10
                LDA     #1
_sptrnull_L11
                CMP     #0
                BNE     *+5
                BRL     _sptrnull_L9
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
_sptrnull_L9
                LDA     #0
                TAX
                LDA:    sentinel,X
                AND     #$00FF
                TAX
                LDA     #1
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BEQ     *+5
                BRL     _sptrnull_L13
                LDA     #3
                TAX
                LDA:    sentinel,X
                AND     #$00FF
                TAX
                LDA     #4
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BEQ     *+5
                BRL     _sptrnull_L13
                LDA     #0
                BRL     _sptrnull_L14
_sptrnull_L13
                LDA     #1
_sptrnull_L14
                CMP     #0
                BNE     *+5
                BRL     _sptrnull_L12
                LDA     #5
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_sptrnull_L12
                LDA     #42
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
main_FRAMESIZE   EQU     0
main_STKGUARD    EQU     0
                FGX2_RELOC_COUNT 2
