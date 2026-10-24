                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from fconv_store.c
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
                LDA     #1
                STA     3,S   ; fccstk d=0 b=3
                LDA     #16390
                STA     _fcc_q3
                LDA     #0
                STA     _fcc_q2
                LDA     #0
                STA     _fcc_long_hi
                LDA     #0
                FGX2_FARCALL _fcc_dtof
                STA     F
                TAY
                LDA     _fcc_long_hi
                STA     F+2
                TYA
                LDA     #16625
                STA     _fcc_q3
                LDA     #5896
                STA     _fcc_q2
                LDA     #0
                STA     _fcc_long_hi
                LDA     #0
                FGX2_FARCALL _fcc_dtof
                STA     FH
                TAY
                LDA     _fcc_long_hi
                STA     FH+2
                TYA
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #8
                STA     GP
                LDA     _fcc_fpr0+2
                STA     GP+2
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #4
                STA     _fcc_fpr0
                STA     PL
                LDA     _fcc_fpr0+2
                STA     PL+2
                LDA     F+2
                STA     _fcc_long_hi
                LDA     F
                JSR     _fcc_ftoi
                STA     GI
                TAX
                CMP     #2
                BNE     _fconv_store_L0
                LDA     1,S   ; fccstk d=0 b=1
                TAX
                CLC
                ADC     #1
                STA     1,S   ; fccstk d=0 b=1
_fconv_store_L0
                LDA     #GA
                PHA
                LDA     5,S   ; fccstk d=2 b=3
                ASL
                CLC
                ADC     1,S
                TAY
                PLA
                TYA
                PHA
                LDA     F+2
                STA     _fcc_long_hi
                LDA     F
                JSR     _fcc_ftoi
                TAY
                LDA     1,S
                TAX
                TYA
                STA:    $0000,X
                PLA
                LDA     #1
                ASL
                TAX
                LDA:    GA,X
                TAX
                CMP     #2
                BNE     _fconv_store_L1
                LDA     1,S   ; fccstk d=0 b=1
                TAX
                CLC
                ADC     #2
                STA     1,S   ; fccstk d=0 b=1
_fconv_store_L1
                SEP     #$20
                MX      %10
                LDA     GP+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     GP
                STA     _fcc_fpr0
                LDA     F+2
                STA     _fcc_long_hi
                LDA     F
                JSR     _fcc_ftoi
                LDY     #2
                STA     [_fcc_fpr0],Y
                LDA     FH+2
                STA     _fcc_long_hi
                LDA     FH
                JSR     _fcc_ftol
                STA     GS+4
                TAY
                LDA     _fcc_long_hi
                STA     GS+6
                TYA
                SEP     #$20
                MX      %10
                LDA     GP+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     GP
                STA     _fcc_fpr0
                LDY     #2
                LDA     [_fcc_fpr0],Y
                TAX
                CMP     #2
                BNE     _fconv_store_L3
                LDA     GS+6
                STA     _fcc_long_hi
                LDA     GS+4
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0001
                STA     _fcc_long_hi
                LDA     #$1170
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_eq
                CMP     #0
                BEQ     _fconv_store_L3
                LDA     #1
                BRA     _fconv_store_L4
_fconv_store_L3
                LDA     #0
_fconv_store_L4
                CMP     #0
                BEQ     _fconv_store_L2
                LDA     1,S   ; fccstk d=0 b=1
                TAX
                CLC
                ADC     #4
                STA     1,S   ; fccstk d=0 b=1
_fconv_store_L2
                LDA     #$0001
                STA     _fcc_long_hi
                LDA     #$1170
                STA     GL
                TAY
                LDA     _fcc_long_hi
                STA     GL+2
                TYA
                SEP     #$20
                MX      %10
                LDA     GP+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     GP
                STA     _fcc_fpr0
                LDA     GL+2
                STA     _fcc_long_hi
                LDA     GL
                JSR     _fcc_ltof
                LDY     #8
                STA     [_fcc_fpr0],Y
                TAX
                LDA     _fcc_long_hi
                LDY     #10
                STA     [_fcc_fpr0],Y
                TXA
                SEP     #$20
                MX      %10
                LDA     GP+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     GP
                STA     _fcc_fpr0
                LDY     #10
                LDA     [_fcc_fpr0],Y
                STA     _fcc_long_hi
                LDY     #8
                LDA     [_fcc_fpr0],Y
                JSR     _fcc_ftol
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0001
                STA     _fcc_long_hi
                LDA     #$1170
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_eq
                CMP     #0
                BEQ     _fconv_store_L5
                LDA     1,S   ; fccstk d=0 b=1
                TAX
                CLC
                ADC     #8
                STA     1,S   ; fccstk d=0 b=1
_fconv_store_L5
                LDA     #3
                STA     GI
                LDA     GI
                JSR     _fcc_long_from_int
                FGX2_FARCALL _fcc_dfroml
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #16376
                STA     _fcc_q3
                LDA     #0
                STA     _fcc_q2
                LDA     #0
                STA     _fcc_long_hi
                LDA     #0
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                LDX     _fcc_q2
                STX     _fcc_qb2
                LDX     _fcc_q3
                STX     _fcc_qb3
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                PLA
                STA     _fcc_q2
                PLA
                STA     _fcc_q3
                TYA
                FGX2_FARCALL _fcc_dmul
                FGX2_FARCALL _fcc_dtol
                STA     GI
                TAX
                CMP     #4
                BNE     _fconv_store_L6
                LDA     1,S   ; fccstk d=0 b=1
                TAX
                CLC
                ADC     #16
                STA     1,S   ; fccstk d=0 b=1
_fconv_store_L6
                LDA     #$0001
                STA     _fcc_long_hi
                LDA     #$86A1
                STA     GS+4
                TAY
                LDA     _fcc_long_hi
                STA     GS+6
                TYA
                LDA     GS+6
                STA     _fcc_long_hi
                LDA     GS+4
                FGX2_FARCALL _fcc_dfroml
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #16376
                STA     _fcc_q3
                LDA     #0
                STA     _fcc_q2
                LDA     #0
                STA     _fcc_long_hi
                LDA     #0
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                LDX     _fcc_q2
                STX     _fcc_qb2
                LDX     _fcc_q3
                STX     _fcc_qb3
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                PLA
                STA     _fcc_q2
                PLA
                STA     _fcc_q3
                TYA
                FGX2_FARCALL _fcc_dmul
                FGX2_FARCALL _fcc_dtol
                STA     GS+4
                TAY
                LDA     _fcc_long_hi
                STA     GS+6
                TYA
                LDA     GS+6
                STA     _fcc_long_hi
                LDA     GS+4
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0002
                STA     _fcc_long_hi
                LDA     #$49F1
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_eq
                CMP     #0
                BEQ     _fconv_store_L7
                LDA     1,S   ; fccstk d=0 b=1
                TAX
                CLC
                ADC     #32
                STA     1,S   ; fccstk d=0 b=1
_fconv_store_L7
                LDA     #$0001
                STA     _fcc_long_hi
                LDA     #$1170
                STA     5,S   ; fccstk d=0 b=5
                TAY
                LDA     _fcc_long_hi
                STA     7,S   ; fccstk d=0 b=7
                TYA
                SEP     #$20
                MX      %10
                LDA     PL+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     PL
                STA     _fcc_fpr0
                LDY     #2
                LDA     [_fcc_fpr0],Y
                STA     _fcc_long_hi
                LDA     [_fcc_fpr0]
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0001
                STA     _fcc_long_hi
                LDA     #$1170
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_add
                STA     [_fcc_fpr0]
                TAX
                LDA     _fcc_long_hi
                LDY     #2
                STA     [_fcc_fpr0],Y
                TXA
                LDA     7,S   ; fccstk d=0 b=7
                STA     _fcc_long_hi
                LDA     5,S   ; fccstk d=0 b=5
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0002
                STA     _fcc_long_hi
                LDA     #$22E0
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_eq
                CMP     #0
                BEQ     _fconv_store_L8
                LDA     1,S   ; fccstk d=0 b=1
                TAX
                CLC
                ADC     #64
                STA     1,S   ; fccstk d=0 b=1
_fconv_store_L8
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0003
                STA     5,S   ; fccstk d=0 b=5
                TAY
                LDA     _fcc_long_hi
                STA     7,S   ; fccstk d=0 b=7
                TYA
                SEP     #$20
                MX      %10
                LDA     PL+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     PL
                STA     _fcc_fpr0
                LDA     F+2
                STA     _fcc_long_hi
                LDA     F
                JSR     _fcc_ftol
                STA     [_fcc_fpr0]
                TAX
                LDA     _fcc_long_hi
                LDY     #2
                STA     [_fcc_fpr0],Y
                TXA
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0002
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_eq
                CMP     #0
                BEQ     _fconv_store_L9
                LDA     1,S   ; fccstk d=0 b=1
                TAX
                CLC
                ADC     #128
                STA     1,S   ; fccstk d=0 b=1
_fconv_store_L9
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
main_FRAMESIZE   EQU     20
main_STKGUARD    EQU     0
                FGX2_RELOC_COUNT 10
