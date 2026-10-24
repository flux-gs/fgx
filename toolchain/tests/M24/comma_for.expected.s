                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from comma_for.c
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
                STA     _fcc_img2
                LDA     #0
                STA     _fcc_img0
                LDA     #10
                STA     _fcc_img1
_comma_for_L0
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     _fcc_img0
                TAX
                LDA     _fcc_img1
                STA     _fcc_tmp_b
                TXA
                SEC
                SBC     _fcc_tmp_b
                BVC     _comma_for_L3
                EOR     #$8000
_comma_for_L3
                BPL     _comma_for_L2
                LDA     _fcc_img2
                TAX
                TXA
                CLC
                ADC     #1
                STA     _fcc_img2
_comma_for_L1
                LDA     _fcc_img0
                TAX
                TXA
                INC
                STA     _fcc_img0
                LDA     _fcc_img1
                TAX
                TXA
                SEC
                SBC     #1
                STA     _fcc_img1
                BRA     _comma_for_L0
_comma_for_L2
                LDA     _fcc_img2
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
