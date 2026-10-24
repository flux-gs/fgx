                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from ppbodylong.c
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
_ppbodylong_L0
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     #1
                TAX
                INC
                INC
                STA     _fcc_img0
                LDA     #3
                TAX
                CLC
                ADC     #4
                STA     _fcc_img1
                LDA     #5
                TAX
                CLC
                ADC     #6
                STA     _fcc_img2
                LDA     _fcc_img0
                STA     _fcc_img3
                LDA     _fcc_img1
                STA     _fcc_img4
                LDA     _fcc_img2
                STA     _fcc_img5
                LDA     _fcc_img3
                CLC
                ADC     _fcc_img4
                CLC
                ADC     _fcc_img5
                TAX
                INC
                TAX
                DEC
                TAX
                INC
                INC
                TAX
                DEC
                DEC
                TAX
                CLC
                ADC     #3
                TAX
                SEC
                SBC     #3
                STA     acc
_ppbodylong_L1
                LDA     #0
                CMP     #0
                BEQ     _ppbodylong_L2
                BRA     _ppbodylong_L0
_ppbodylong_L2
                LDA     acc
                TAX
                CLC
                ADC     #21
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
