                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from pp_adv2.c
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
                TAX
                LDA     #1
                STA     _fcc_tmp_b
                TXA
                CLC
                ADC     _fcc_tmp_b
                TAX
                LDA     #1
                STA     _fcc_tmp_b
                TXA
                CLC
                ADC     _fcc_tmp_b
                TAX
                LDA     #1
                STA     _fcc_tmp_b
                TXA
                CLC
                ADC     _fcc_tmp_b
                STA     1,S   ; fccstk d=0 b=1
                LDA     #1
                TAX
                LDA     #1
                STA     _fcc_tmp_b
                TXA
                SEC
                SBC     _fcc_tmp_b
                STA     3,S   ; fccstk d=0 b=3
                LDA     #40
                TAX
                LDA     #1
                STA     _fcc_tmp_b
                TXA
                CLC
                ADC     _fcc_tmp_b
                STA     5,S   ; fccstk d=0 b=5
                LDA     1,S   ; fccstk d=0 b=1
                CLC
                ADC     3,S   ; fccstk d=0 b=3
                CLC
                ADC     5,S   ; fccstk d=0 b=5
                TAX
                LDA     #3
                STA     _fcc_tmp_b
                TXA
                SEC
                SBC     _fcc_tmp_b
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
main_FRAMESIZE   EQU     6
main_STKGUARD    EQU     0
                FGX2_RELOC_COUNT 2
