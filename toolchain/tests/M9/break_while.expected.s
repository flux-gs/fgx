                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from break_while.c
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
                STA     _fcc_img1
                LDA     #0
                STA     _fcc_img0
_break_while_L0
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     _fcc_img0
                TAX
                TXA
                SEC
                SBC     #100
                BVC     _break_while_L2
                EOR     #$8000
_break_while_L2
                BPL     _break_while_L1
                LDA     _fcc_img0
                TAX
                TXA
                CMP     #6
                BNE     _break_while_L3
                BRA     _break_while_L1
_break_while_L3
                LDA     _fcc_img1
                TAX
                TXA
                CLC
                ADC     #7
                STA     _fcc_img1
                LDA     _fcc_img0
                TAX
                TXA
                CLC
                ADC     #1
                STA     _fcc_img0
                BRA     _break_while_L0
_break_while_L1
                LDA     _fcc_img1
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
