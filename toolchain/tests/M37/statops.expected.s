                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from statops.c
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
                STA     1,S   ; fccstk d=0 b=1
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                INC
                INC
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_statops_S0
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL stat
                TAY
                TSC
                CLC
                ADC     #8
                TCS
                TYA
                BNE     _statops_L0
                LDA     1,S   ; fccstk d=0 b=1
                CLC
                ADC     #8
                STA     1,S   ; fccstk d=0 b=1
_statops_L0
                LDA     7,S   ; fccstk d=0 b=7
                AND     #61440
                TAX
                CMP     #32768
                BNE     _statops_L1
                LDA     1,S   ; fccstk d=0 b=1
                TAX
                CLC
                ADC     #8
                STA     1,S   ; fccstk d=0 b=1
_statops_L1
                LDA     19,S   ; fccstk d=0 b=19
                STA     _fcc_long_hi
                LDA     17,S   ; fccstk d=0 b=17
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #0
                JSR     _fcc_long_from_int
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_gts
                CMP     #0
                BEQ     _statops_L2
                LDA     1,S   ; fccstk d=0 b=1
                CLC
                ADC     #8
                STA     1,S   ; fccstk d=0 b=1
_statops_L2
                LDA     9,S   ; fccstk d=0 b=9
                TAX
                CMP     #1
                BNE     _statops_L3
                LDA     1,S   ; fccstk d=0 b=1
                TAX
                CLC
                ADC     #6
                STA     1,S   ; fccstk d=0 b=1
_statops_L3
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                INC
                INC
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_statops_S1
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL stat
                TAY
                TSC
                CLC
                ADC     #8
                TCS
                TYA
                CMP     #$FFFF
                BNE     _statops_L4
                LDA     1,S   ; fccstk d=0 b=1
                TAX
                CLC
                ADC     #6
                STA     1,S   ; fccstk d=0 b=1
_statops_L4
                LDA     #2
                PHA
                FGX2_FARCALL strerror
                TAY
                PLA
                TYA
                LDA     [_fcc_fpr0]
                AND     #$00FF
                TAX
                CMP     #78
                BNE     _statops_L5
                LDA     1,S   ; fccstk d=0 b=1
                TAX
                CLC
                ADC     #6
                STA     1,S   ; fccstk d=0 b=1
_statops_L5
                LDA     1,S   ; fccstk d=0 b=1
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
main_FRAMESIZE   EQU     54
main_STKGUARD    EQU     0
                FGX2_RELOC_COUNT 5
