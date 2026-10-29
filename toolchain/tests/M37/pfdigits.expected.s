                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from pfdigits.c
;---------------------------------------

                MX      %00
                FGX2_EXPORT same
same            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #same_FRAMESIZE
                DO      same_STKGUARD
                BCC     same_stkovf
                CMP     _fcc_stkfloor
                BCS     same_stkok
same_stkovf       JMP     _fcc_stkoflow
                FIN
same_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      8+same_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+same_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+same_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+same_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+same_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+same_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
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
                LDA     #b
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL strcmp
                PLY
                PLY
                PLY
                PLY
                TAX
                LDA     #0
                STA     _fcc_tmp_b
                TXA
                JSR     _fcc_eq16
                TAY
                TSC
                CLC
                ADC     #same_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
same_FRAMESIZE   EQU     0
same_STKGUARD    EQU     0
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
                LDA     #$8001
                TAX
                DEC
                PHA
                LDA     #65535
                PHA
                LDA     #9
                PHA
                LDA     #0
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_pfdigits_S0
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
                LDA     #b
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL sprintf
                TSC
                CLC
                ADC     #16
                TCS
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_pfdigits_S1
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL same
                PLY
                PLY
                CMP     #0
                BEQ     _pfdigits_L0
                LDA     1,S   ; fccstk d=0 b=1
                TAX
                CLC
                ADC     #6
                STA     1,S   ; fccstk d=0 b=1
_pfdigits_L0
                LDA     #$0009
                STA     _fcc_long_hi
                LDA     #$FFFF
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0001
                STA     _fcc_long_hi
                LDA     #$0000
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$FFFF
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_pfdigits_S2
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
                LDA     #b
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL sprintf
                TSC
                CLC
                ADC     #20
                TCS
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_pfdigits_S3
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL same
                PLY
                PLY
                CMP     #0
                BEQ     _pfdigits_L1
                LDA     1,S   ; fccstk d=0 b=1
                TAX
                CLC
                ADC     #6
                STA     1,S   ; fccstk d=0 b=1
_pfdigits_L1
                LDA     #$7FFF
                STA     _fcc_long_hi
                LDA     #$FFFF
                JSR     _fcc_long_neg
                LDX     #1
                STX     _fcc_long_b_lo
                LDX     #0
                STX     _fcc_long_b_hi
                JSR     _fcc_long_sub
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$FFFF
                STA     _fcc_long_hi
                LDA     #$FFFF
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_pfdigits_S4
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
                LDA     #b
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL sprintf
                TSC
                CLC
                ADC     #16
                TCS
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_pfdigits_S5
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL same
                PLY
                PLY
                CMP     #0
                BEQ     _pfdigits_L2
                LDA     1,S   ; fccstk d=0 b=1
                TAX
                CLC
                ADC     #6
                STA     1,S   ; fccstk d=0 b=1
_pfdigits_L2
                LDA     #0
                PHA
                LDA     #$0001
                STA     _fcc_long_hi
                LDA     #$0000
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #8
                PHA
                LDA     #8
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_pfdigits_S6
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
                LDA     #b
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL sprintf
                TSC
                CLC
                ADC     #18
                TCS
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_pfdigits_S7
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL same
                PLY
                PLY
                CMP     #0
                BEQ     _pfdigits_L3
                LDA     1,S   ; fccstk d=0 b=1
                TAX
                CLC
                ADC     #6
                STA     1,S   ; fccstk d=0 b=1
_pfdigits_L3
                LDA     #$FFFF
                STA     _fcc_long_hi
                LDA     #$FFFF
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0001
                STA     _fcc_long_hi
                LDA     #$2345
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #48879
                PHA
                LDA     #48879
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_pfdigits_S8
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
                LDA     #b
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL sprintf
                TSC
                CLC
                ADC     #20
                TCS
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_pfdigits_S9
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL same
                PLY
                PLY
                CMP     #0
                BEQ     _pfdigits_L4
                LDA     1,S   ; fccstk d=0 b=1
                TAX
                CLC
                ADC     #6
                STA     1,S   ; fccstk d=0 b=1
_pfdigits_L4
                LDA     #0
                PHA
                LDA     #7
                PHA
                LDA     #$0001
                STA     _fcc_long_hi
                LDA     #$86A0
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #42
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_pfdigits_S10
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
                LDA     #b
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL sprintf
                TSC
                CLC
                ADC     #18
                TCS
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_pfdigits_S11
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL same
                PLY
                PLY
                CMP     #0
                BEQ     _pfdigits_L5
                LDA     1,S   ; fccstk d=0 b=1
                TAX
                CLC
                ADC     #6
                STA     1,S   ; fccstk d=0 b=1
_pfdigits_L5
                LDA     #10
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_pfdigits_S13
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     #120
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_pfdigits_S12
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
                LDA     #b
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL sprintf
                TSC
                CLC
                ADC     #16
                TCS
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_pfdigits_S14
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL same
                PLY
                PLY
                CMP     #0
                BEQ     _pfdigits_L6
                LDA     1,S   ; fccstk d=0 b=1
                TAX
                CLC
                ADC     #6
                STA     1,S   ; fccstk d=0 b=1
_pfdigits_L6
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
main_FRAMESIZE   EQU     2
main_STKGUARD    EQU     0
                FGX2_RELOC_COUNT 18
