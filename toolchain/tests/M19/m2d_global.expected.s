                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from m2d_global.c
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
                STA     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                PHA
                LDA     #0
                ASL
                CLC
                ADC     1,S
                STA     1,S
                PLA
                TAX
                LDA:    m,X
                PHA
                LDA     #0
                STA     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                PHA
                LDA     #1
                ASL
                CLC
                ADC     1,S
                STA     1,S
                PLA
                TAX
                LDA:    m,X
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                PHA
                LDA     #0
                STA     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                PHA
                LDA     #2
                ASL
                CLC
                ADC     1,S
                STA     1,S
                PLA
                TAX
                LDA:    m,X
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                PHA
                LDA     #1
                STA     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                PHA
                LDA     #0
                ASL
                CLC
                ADC     1,S
                STA     1,S
                PLA
                TAX
                LDA:    m,X
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                PHA
                LDA     #1
                STA     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                PHA
                LDA     #1
                ASL
                CLC
                ADC     1,S
                STA     1,S
                PLA
                TAX
                LDA:    m,X
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                PHA
                LDA     #1
                STA     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                PHA
                LDA     #2
                ASL
                CLC
                ADC     1,S
                STA     1,S
                PLA
                TAX
                LDA:    m,X
                STA     _fcc_tmp_b
                PLA
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
main_FRAMESIZE   EQU     0
main_STKGUARD    EQU     0
                FGX2_RELOC_COUNT 2
