                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from u_comp.c
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
                LDA     #36864
                STA     u
                TAX
                LDA     #2
                STA     _fcc_tmp_b
                TXA
                JSR     _fcc_divu16
                STA     u
                TAX
                TXA
                CMP     #18432
                BEQ     *+5
                BRL     _u_comp_L0
                LDA     _fcc_img0
                TAX
                TXA
                CLC
                ADC     #1
                STA     _fcc_img0
_u_comp_L0
                LDA     #36864
                STA     u
                TAX
                LDA     #4
                STA     _fcc_tmp_b
                TXA
                JSR     _fcc_shr16
                STA     u
                TAX
                TXA
                CMP     #2304
                BEQ     *+5
                BRL     _u_comp_L1
                LDA     _fcc_img0
                TAX
                TXA
                CLC
                ADC     #2
                STA     _fcc_img0
_u_comp_L1
                LDA     #65520
                STA     u
                TAX
                LDA     #7
                STA     _fcc_tmp_b
                TXA
                JSR     _fcc_modu16
                STA     u
                CMP     #0
                BEQ     *+5
                BRL     _u_comp_L2
                LDA     _fcc_img0
                TAX
                TXA
                CLC
                ADC     #4
                STA     _fcc_img0
_u_comp_L2
                LDA     _fcc_img0
                TAX
                TXA
                CMP     #7
                BEQ     *+5
                BRL     _u_comp_L3
                LDA     #42
                BRL     _u_comp_L4
_u_comp_L3
                LDA     _fcc_img0
_u_comp_L4
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
