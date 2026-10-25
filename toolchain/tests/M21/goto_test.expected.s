                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from goto_test.c
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
                LDA     #0
                STA     _fcc_img1
                BRA     main_uL_inc_loop
main_uL_dec_block
                LDA     _fcc_img0
                TAX
                SEC
                SBC     #100
                STA     _fcc_img0
                BRA     main_uL_done
main_uL_inc_loop
                LDA     _fcc_img1
                TAX
                CMP     #7
                BNE     _goto_test_L0
                BRA     main_uL_done
_goto_test_L0
                LDA     _fcc_img0
                CLC
                ADC     #6
                STA     _fcc_img0
                LDA     _fcc_img1
                TAX
                CLC
                ADC     #1
                STA     _fcc_img1
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                BRA     main_uL_inc_loop
main_uL_done
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
