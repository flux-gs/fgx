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
                CLC
                ADC     #1
                STA     gbefore
                LDA     #1
                STA     gv
_macro_for_step_L0
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     gv
                BEQ     _macro_for_step_L2
                LDA     gbody
                TAX
                SEC
                SBC     #3
                BVC     _macro_for_step_L3
                EOR     #$8000
_macro_for_step_L3
                BPL     _macro_for_step_L2
                LDA     gbody
                TAX
                CLC
                ADC     #1
                STA     gbody
_macro_for_step_L1
                LDA     gafter
                TAX
                CLC
                ADC     #1
                STA     gafter
                LDA     #1
                STA     gv
                BRA     _macro_for_step_L0
_macro_for_step_L2
                LDA     gbefore
                TAX
                CMP     #1
                BEQ     _macro_for_step_L4
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
_macro_for_step_L4
                LDA     gbody
                TAX
                CMP     #3
                BEQ     _macro_for_step_L5
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
_macro_for_step_L5
                LDA     gafter
                TAX
                CMP     #3
                BEQ     _macro_for_step_L6
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
_macro_for_step_L6
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
