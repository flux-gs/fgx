                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from struct_partial_init.c
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
                LDA     _struct_partial_init_g+0
                TAX
                TXA
                CMP     #0
                BEQ     *+5
                BRL     _struct_partial_init_L1
                LDA     _struct_partial_init_g+2
                TAX
                TXA
                CMP     #0
                BEQ     *+5
                BRL     _struct_partial_init_L1
                LDA     #0
                BRL     _struct_partial_init_L2
_struct_partial_init_L1
                LDA     #1
_struct_partial_init_L2
                CMP     #0
                BNE     *+5
                BRL     _struct_partial_init_L0
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
_struct_partial_init_L0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #arr
                STA     _fcc_fpr0
                LDA     #0
                ASL
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                TAX
                TXA
                CMP     #1
                BEQ     *+5
                BRL     _struct_partial_init_L4
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #arr
                STA     _fcc_fpr0
                LDA     #0
                ASL
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDY     #2
                LDA     [_fcc_fpr0],Y
                TAX
                TXA
                CMP     #2
                BEQ     *+5
                BRL     _struct_partial_init_L4
                LDA     #0
                BRL     _struct_partial_init_L5
_struct_partial_init_L4
                LDA     #1
_struct_partial_init_L5
                CMP     #0
                BNE     *+5
                BRL     _struct_partial_init_L3
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
_struct_partial_init_L3
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #arr
                STA     _fcc_fpr0
                LDA     #1
                ASL
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                TAX
                TXA
                CMP     #3
                BEQ     *+5
                BRL     _struct_partial_init_L7
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #arr
                STA     _fcc_fpr0
                LDA     #1
                ASL
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDY     #2
                LDA     [_fcc_fpr0],Y
                TAX
                TXA
                CMP     #0
                BEQ     *+5
                BRL     _struct_partial_init_L7
                LDA     #0
                BRL     _struct_partial_init_L8
_struct_partial_init_L7
                LDA     #1
_struct_partial_init_L8
                CMP     #0
                BNE     *+5
                BRL     _struct_partial_init_L6
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
_struct_partial_init_L6
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
