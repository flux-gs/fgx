                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from ternary_assoc.c
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
                STA     _fcc_img0
                TAX
                TXA
                CMP     #1
                BEQ     *+5
                BRL     _ternary_assoc_L0
                LDA     #10
                BRL     _ternary_assoc_L1
_ternary_assoc_L0
                LDA     _fcc_img0
                TAX
                TXA
                CMP     #2
                BEQ     *+5
                BRL     _ternary_assoc_L2
                LDA     #42
                BRL     _ternary_assoc_L3
_ternary_assoc_L2
                LDA     #99
_ternary_assoc_L3
_ternary_assoc_L1
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
