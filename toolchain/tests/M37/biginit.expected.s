                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from biginit.c
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
                LDA     #0
                ASL
                TAX
                LDA:    a,X
                TAX
                TXA
                CMP     #3
                BEQ     _biginit_L0
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
_biginit_L0
                LDA     #1
                ASL
                TAX
                LDA:    a,X
                TAX
                TXA
                CMP     #10
                BEQ     _biginit_L1
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
_biginit_L1
                LDA     #1099
                ASL
                TAX
                LDA:    a,X
                PHA
                LDA     #1099
                STA     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_tmp_b
                TAX
                TXA
                CLC
                ADC     #3
                TAX
                TXA
                AND     #127
                STA     _fcc_tmp_b
                PLA
                CMP     _fcc_tmp_b
                BEQ     _biginit_L2
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
_biginit_L2
                LDA     #1023
                ASL
                TAX
                LDA:    a,X
                PHA
                LDA     #1023
                STA     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_tmp_b
                TAX
                TXA
                CLC
                ADC     #3
                TAX
                TXA
                AND     #127
                STA     _fcc_tmp_b
                PLA
                CMP     _fcc_tmp_b
                BEQ     _biginit_L3
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
_biginit_L3
                LDA     #1024
                ASL
                TAX
                LDA:    a,X
                PHA
                LDA     #1024
                STA     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_tmp_b
                TAX
                TXA
                CLC
                ADC     #3
                TAX
                TXA
                AND     #127
                STA     _fcc_tmp_b
                PLA
                CMP     _fcc_tmp_b
                BEQ     _biginit_L4
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
_biginit_L4
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
