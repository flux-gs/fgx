                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from long_global_inc.c
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
                LDA     #40
                JSR     _fcc_long_from_int
                STA     g_n
                TAY
                LDA     _fcc_long_hi
                STA     g_n+2
                TYA
                LDA     g_n+2
                STA     _fcc_long_hi
                LDA     g_n
                CLC
                ADC     #1
                STA     g_n
                LDA     _fcc_long_hi
                ADC     #0
                STA     g_n+2
                STA     _fcc_long_hi
                LDA     g_n
                SEC
                SBC     #1
                STA     g_n
                LDA     _fcc_long_hi
                SBC     #0
                STA     g_n+2
                STA     _fcc_long_hi
                LDA     g_n
                CLC
                ADC     #1
                STA     g_n
                LDA     _fcc_long_hi
                ADC     #0
                STA     g_n+2
                LDA     #0
                STA     _fcc_img0
_long_global_inc_L0
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     _fcc_img0
                TAX
                LDA     #1
                STA     _fcc_tmp_b
                TXA
                SEC
                SBC     _fcc_tmp_b
                BVC     _long_global_inc_L3
                EOR     #$8000
_long_global_inc_L3
                BMI     *+5
                BRL     _long_global_inc_L2
                LDA     g_n+2
                STA     _fcc_long_hi
                LDA     g_n
                CLC
                ADC     #1
                STA     g_n
                LDA     _fcc_long_hi
                ADC     #0
                STA     g_n+2
_long_global_inc_L1
                LDA     _fcc_img0
                TAX
                LDA     #1
                STA     _fcc_tmp_b
                TXA
                CLC
                ADC     _fcc_tmp_b
                STA     _fcc_img0
                BRL     _long_global_inc_L0
_long_global_inc_L2
                LDA     g_n+2
                STA     _fcc_long_hi
                LDA     g_n
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
