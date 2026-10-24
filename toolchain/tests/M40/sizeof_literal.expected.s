                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from sizeof_literal.c
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
                LDA     #2
                CMP     #2
                BNE     _sizeof_literal_L1
                LDA     #2
                CMP     #2
                BEQ     _sizeof_literal_L0
_sizeof_literal_L1
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
_sizeof_literal_L0
                LDA     #4
                CMP     #4
                BNE     _sizeof_literal_L3
                LDA     #4
                CMP     #4
                BEQ     _sizeof_literal_L2
_sizeof_literal_L3
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
_sizeof_literal_L2
                LDA     #2
                CMP     #2
                BNE     _sizeof_literal_L5
                LDA     #2
                CMP     #2
                BEQ     _sizeof_literal_L4
_sizeof_literal_L5
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
_sizeof_literal_L4
                LDA     #8
                CMP     #8
                BNE     _sizeof_literal_L7
                LDA     #4
                CMP     #4
                BEQ     _sizeof_literal_L6
_sizeof_literal_L7
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
_sizeof_literal_L6
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
