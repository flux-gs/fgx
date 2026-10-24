                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from sprintf9.c
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
                LDA     #99
                PHA
                LDA     #88
                PHA
                LDA     #77
                PHA
                LDA     #66
                PHA
                LDA     #55
                PHA
                LDA     #44
                PHA
                LDA     #33
                PHA
                LDA     #22
                PHA
                LDA     #11
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_sprintf9_S0
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #buf
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL sprintf
                TSC
                CLC
                ADC     #26
                TCS
                LDA     #0
                TAX
                LDA:    buf,X
                AND     #$00FF
                TAX
                TXA
                CMP     #49
                BEQ     _sprintf9_L0
                LDA     #10
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_sprintf9_L0
                LDA     #2
                TAX
                LDA:    buf,X
                AND     #$00FF
                TAX
                TXA
                CMP     #46
                BEQ     _sprintf9_L1
                LDA     #11
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_sprintf9_L1
                LDA     #12
                TAX
                LDA:    buf,X
                AND     #$00FF
                TAX
                TXA
                CMP     #53
                BEQ     _sprintf9_L2
                LDA     #12
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_sprintf9_L2
                LDA     #24
                TAX
                LDA:    buf,X
                AND     #$00FF
                TAX
                TXA
                CMP     #57
                BEQ     _sprintf9_L3
                LDA     #13
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_sprintf9_L3
                LDA     #25
                TAX
                LDA:    buf,X
                AND     #$00FF
                TAX
                TXA
                CMP     #57
                BEQ     _sprintf9_L4
                LDA     #14
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_sprintf9_L4
                LDA     #26
                TAX
                LDA:    buf,X
                AND     #$00FF
                CMP     #0
                BEQ     _sprintf9_L5
                LDA     #15
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_sprintf9_L5
                LDA     #0
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
                FGX2_RELOC_COUNT 3
