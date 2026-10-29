                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from miscops.c
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
                STA     7,S   ; fccstk d=0 b=7
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_miscops_S0
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL atoi
                PLY
                PLY
                CMP     #$FFD6
                BNE     _miscops_L0
                LDA     7,S   ; fccstk d=0 b=7
                TAX
                CLC
                ADC     #6
                STA     7,S   ; fccstk d=0 b=7
_miscops_L0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_miscops_S1
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL atol
                PLY
                PLY
                LDX     #34464
                STX     _fcc_long_b_lo
                LDX     #1
                STX     _fcc_long_b_hi
                JSR     _fcc_long_eq
                CMP     #0
                BEQ     _miscops_L1
                LDA     7,S   ; fccstk d=0 b=7
                TAX
                CLC
                ADC     #6
                STA     7,S   ; fccstk d=0 b=7
_miscops_L1
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_miscops_S2
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL getenv
                PLY
                PLY
                LDA     #0
                STA     _fcc_fpr1
                STZ     _fcc_fpr1+2
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BNE     _miscops_L3
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _miscops_L3
                LDA     #1
                BRA     _miscops_L4
_miscops_L3
                LDA     #0
_miscops_L4
                CMP     #0
                BEQ     _miscops_L2
                LDA     7,S   ; fccstk d=0 b=7
                TAX
                CLC
                ADC     #6
                STA     7,S   ; fccstk d=0 b=7
_miscops_L2
                LDA     #9
                PHA
                LDA     #30000
                PHA
                FGX2_FARCALL kill
                PLY
                PLY
                CMP     #$FFFF
                BNE     _miscops_L5
                LDA     7,S   ; fccstk d=0 b=7
                TAX
                CLC
                ADC     #6
                STA     7,S   ; fccstk d=0 b=7
_miscops_L5
                LDA     #1
                PHA
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #0
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     #$FFFF
                PHA
                FGX2_FARCALL waitpid
                PLY
                PLY
                PLY
                PLY
                CMP     #$FFFF
                BNE     _miscops_L6
                LDA     7,S   ; fccstk d=0 b=7
                TAX
                CLC
                ADC     #6
                STA     7,S   ; fccstk d=0 b=7
_miscops_L6
                FGX2_FARCALL ticks
                STA     3,S   ; fccstk d=0 b=3
                LDA     #0
                PHA
                LDA     #128
                PHA
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #8
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL getfsstat
                PLY
                PLY
                PLY
                PLY
                TAX
                SEC
                SBC     #1
                BVC     _miscops_L8
                EOR     #$8000
_miscops_L8
                BMI     _miscops_L7
                LDA     7,S   ; fccstk d=0 b=7
                TAX
                CLC
                ADC     #6
                STA     7,S   ; fccstk d=0 b=7
_miscops_L7
                FGX2_FARCALL ticks
                STA     5,S   ; fccstk d=0 b=5
                SEC
                SBC     3,S   ; fccstk d=0 b=3
                BMI     _miscops_L9
                LDA     7,S   ; fccstk d=0 b=7
                TAX
                CLC
                ADC     #6
                STA     7,S   ; fccstk d=0 b=7
_miscops_L9
                LDA     7,S   ; fccstk d=0 b=7
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
main_FRAMESIZE   EQU     136
main_STKGUARD    EQU     1
                FGX2_RELOC_COUNT 10
