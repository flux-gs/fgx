                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from continue_for.c
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
_continue_for_L0
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     _fcc_img0
                TAX
                SEC
                SBC     #10
                BVC     _continue_for_L3
                EOR     #$8000
_continue_for_L3
                BPL     _continue_for_L2
                LDA     _fcc_img0
                TAX
                LDX     #5
                STA     _fcc_tmp_b
                TXA
                SEC
                SBC     _fcc_tmp_b
                BVC     _continue_for_L5
                EOR     #$8000
_continue_for_L5
                BPL     _continue_for_L4
                BRA     _continue_for_L1
_continue_for_L4
                LDA     _fcc_img1
                TAX
                CLC
                ADC     #7
                STA     _fcc_img1
_continue_for_L1
                LDA     _fcc_img0
                TAX
                CLC
                ADC     #1
                STA     _fcc_img0
                BRA     _continue_for_L0
_continue_for_L2
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
