                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from callchain_stmt.c
;---------------------------------------

                MX      %00
                FGX2_EXPORT lookup
lookup            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #lookup_FRAMESIZE
                DO      lookup_STKGUARD
                BCC     lookup_stkovf
                CMP     _fcc_stkfloor
                BCS     lookup_stkok
lookup_stkovf       JMP     _fcc_stkoflow
                FIN
lookup_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                LDA     calls
                INC
                STA     calls
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #root
                STA     _fcc_fpr0
                PLA
                TAY
                TSC
                CLC
                ADC     #lookup_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
lookup_FRAMESIZE   EQU     0
lookup_STKGUARD    EQU     0
                FGX2_EXPORT ivec
ivec            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #ivec_FRAMESIZE
                DO      ivec_STKGUARD
                BCC     ivec_stkovf
                CMP     _fcc_stkfloor
                BCS     ivec_stkok
ivec_stkovf       JMP     _fcc_stkoflow
                FIN
ivec_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                LDA     calls
                INC
                STA     calls
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #vec
                STA     _fcc_fpr0
                PLA
                TAY
                TSC
                CLC
                ADC     #ivec_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
ivec_FRAMESIZE   EQU     0
ivec_STKGUARD    EQU     0
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
                STA     root+8
                LDA     #0
                STA     calls
                LDA     #1
                PHA
                FGX2_FARCALL lookup
                TAY
                PLA
                TYA
                LDA     _fcc_fpr0
                CLC
                ADC     #8
                STA     _fcc_fpr0
                LDA     #4
                STA     [_fcc_fpr0]
                LDA     root+8
                TAX
                CMP     #4
                BEQ     _callchain_stmt_L0
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
_callchain_stmt_L0
                LDA     #1
                PHA
                FGX2_FARCALL lookup
                TAY
                PLA
                TYA
                LDA     _fcc_fpr0
                CLC
                ADC     #8
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                TAX
                ORA     #16
                STA     [_fcc_fpr0]
                LDA     root+8
                TAX
                CMP     #20
                BEQ     _callchain_stmt_L1
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
_callchain_stmt_L1
                LDA     #1
                PHA
                FGX2_FARCALL lookup
                TAY
                PLA
                TYA
                LDA     _fcc_fpr0
                CLC
                ADC     #8
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                TAX
                ORA     #8
                STA     [_fcc_fpr0]
                LDA     root+8
                TAX
                CMP     #28
                BEQ     _callchain_stmt_L2
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
_callchain_stmt_L2
                FGX2_FARCALL ivec
                LDA     #2
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     #5
                STA     [_fcc_fpr0]
                LDA     #2
                ASL
                TAX
                LDA:    vec,X
                TAX
                CMP     #5
                BEQ     _callchain_stmt_L3
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
_callchain_stmt_L3
                FGX2_FARCALL ivec
                LDA     _fcc_fpr0
                CLC
                ADC     #4
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                TAX
                CLC
                ADC     #3
                STA     [_fcc_fpr0]
                LDA     #2
                ASL
                TAX
                LDA:    vec,X
                TAX
                CMP     #8
                BEQ     _callchain_stmt_L4
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
_callchain_stmt_L4
                LDA     calls
                TAX
                CMP     #5
                BEQ     _callchain_stmt_L5
                LDA     #6
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_callchain_stmt_L5
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
                FGX2_RELOC_COUNT 9
