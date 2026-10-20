                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from sizeof_deref.c
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
                LDA     #1
                TAX
                LDA     #1
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BNE     *+5
                BRL     _sizeof_deref_L0
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
_sizeof_deref_L0
                LDA     #1
                PHA
                LDA     #1
                STA     _fcc_tmp_b
                PLA
                CMP     _fcc_tmp_b
                BNE     *+5
                BRL     _sizeof_deref_L1
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
_sizeof_deref_L1
                LDA     #4
                PHA
                LDA     #4
                STA     _fcc_tmp_b
                PLA
                CMP     _fcc_tmp_b
                BNE     *+5
                BRL     _sizeof_deref_L2
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
_sizeof_deref_L2
                LDA     #4
                PHA
                LDA     #4
                STA     _fcc_tmp_b
                PLA
                CMP     _fcc_tmp_b
                BNE     *+5
                BRL     _sizeof_deref_L3
                LDA     #4
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_sizeof_deref_L3
                LDA     #16
                PHA
                LDA     #16
                STA     _fcc_tmp_b
                PLA
                CMP     _fcc_tmp_b
                BNE     *+5
                BRL     _sizeof_deref_L4
                LDA     #5
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_sizeof_deref_L4
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
