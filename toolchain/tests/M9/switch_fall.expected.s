                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from switch_fall.c
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
                STA     _fcc_img0
                LDA     #1
                STA     3,S   ; fccstk d=0 b=3
                CMP     #1
                BNE     *+5
                BRL     _switch_fall_L1
                CMP     #2
                BNE     *+5
                BRL     _switch_fall_L2
                CMP     #3
                BNE     *+5
                BRL     _switch_fall_L3
                CMP     #4
                BNE     *+5
                BRL     _switch_fall_L4
                BRL     _switch_fall_L0
_switch_fall_L1
                LDA     _fcc_img0
                TAX
                TXA
                CLC
                ADC     #14
                STA     _fcc_img0
_switch_fall_L2
                LDA     _fcc_img0
                TAX
                TXA
                CLC
                ADC     #14
                STA     _fcc_img0
_switch_fall_L3
                LDA     _fcc_img0
                TAX
                TXA
                CLC
                ADC     #14
                STA     _fcc_img0
                BRL     _switch_fall_L0
_switch_fall_L4
                LDA     #999
                STA     _fcc_img0
_switch_fall_L0
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
