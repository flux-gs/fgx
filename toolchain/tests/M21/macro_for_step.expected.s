                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from macro_for_step.c
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
                STA     gbefore
                LDA     #0
                STA     gafter
                LDA     #0
                STA     gbody
                LDA     gbefore
                TAX
                LDA     #1
                STA     _fcc_tmp_b
                TXA
                CLC
                ADC     _fcc_tmp_b
                STA     gbefore
                LDA     #1
                STA     gv
_macro_for_step_L0
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     gv
                CMP     #0
                BNE     *+5
                BRL     _macro_for_step_L3
                LDA     gbody
                TAX
                LDA     #3
                STA     _fcc_tmp_b
                TXA
                SEC
                SBC     _fcc_tmp_b
                BVC     _macro_for_step_L5
                EOR     #$8000
_macro_for_step_L5
                BMI     *+5
                BRL     _macro_for_step_L3
                LDA     #1
                BRL     _macro_for_step_L4
_macro_for_step_L3
                LDA     #0
_macro_for_step_L4
                CMP     #0
                BNE     *+5
                BRL     _macro_for_step_L2
                LDA     gbody
                TAX
                LDA     #1
                STA     _fcc_tmp_b
                TXA
                CLC
                ADC     _fcc_tmp_b
                STA     gbody
_macro_for_step_L1
                LDA     gafter
                TAX
                LDA     #1
                STA     _fcc_tmp_b
                TXA
                CLC
                ADC     _fcc_tmp_b
                STA     gafter
                LDA     #1
                STA     gv
                BRL     _macro_for_step_L0
_macro_for_step_L2
                LDA     gbefore
                TAX
                LDA     #1
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BNE     *+5
                BRL     _macro_for_step_L6
                LDA     #1
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_macro_for_step_L6
                LDA     gbody
                TAX
                LDA     #3
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BNE     *+5
                BRL     _macro_for_step_L7
                LDA     #2
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_macro_for_step_L7
                LDA     gafter
                TAX
                LDA     #3
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BNE     *+5
                BRL     _macro_for_step_L8
                LDA     #3
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_macro_for_step_L8
                LDA     #42
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
main_FRAMESIZE   EQU     0
main_STKGUARD    EQU     0
                FGX2_RELOC_COUNT 2
