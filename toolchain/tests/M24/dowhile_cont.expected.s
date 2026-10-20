                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from dowhile_cont.c
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
_dowhile_cont_L0
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     _fcc_img0
                TAX
                LDA     #1
                STA     _fcc_tmp_b
                TXA
                CLC
                ADC     _fcc_tmp_b
                STA     _fcc_img0
                TAX
                LDA     #3
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BEQ     *+5
                BRL     _dowhile_cont_L3
                BRL     _dowhile_cont_L1
_dowhile_cont_L3
                LDA     _fcc_img1
                CLC
                ADC     _fcc_img0
                STA     _fcc_img1
_dowhile_cont_L1
                LDA     _fcc_img0
                TAX
                LDA     #5
                STA     _fcc_tmp_b
                TXA
                SEC
                SBC     _fcc_tmp_b
                BVC     _dowhile_cont_L4
                EOR     #$8000
_dowhile_cont_L4
                BMI     *+5
                BRL     _dowhile_cont_L2
                BRL     _dowhile_cont_L0
_dowhile_cont_L2
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
