                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from sar.c
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
                LDA     #$FFF0
                STA     si
                TAX
                LDA     #2
                STA     _fcc_tmp_b
                TXA
                JSR     _fcc_shrs16
                CMP     #$FFFC
                BNE     _sar_L0
                LDA     _fcc_img0
                TAX
                TXA
                CLC
                ADC     #1
                STA     _fcc_img0
_sar_L0
                LDA     #$FFFF
                STA     si
                TAX
                LDA     #1
                STA     _fcc_tmp_b
                TXA
                JSR     _fcc_shrs16
                CMP     #$FFFF
                BNE     _sar_L1
                LDA     _fcc_img0
                TAX
                TXA
                CLC
                ADC     #2
                STA     _fcc_img0
_sar_L1
                LDA     #32768
                STA     u
                LSR
                LSR
                LSR
                TAX
                TXA
                CMP     #4096
                BNE     _sar_L2
                LDA     _fcc_img0
                TAX
                TXA
                CLC
                ADC     #4
                STA     _fcc_img0
_sar_L2
                LDA     _fcc_img0
                TAX
                TXA
                CMP     #7
                BNE     _sar_L3
                LDA     #42
                BRA     _sar_L4
_sar_L3
                LDA     _fcc_img0
_sar_L4
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
