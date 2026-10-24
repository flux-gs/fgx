                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from ternary_balance.c
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
                STA     9,S   ; fccstk d=0 b=9
                LDA     one
                CMP     #0
                BEQ     _ternary_balance_L0
                LDA     f+2
                STA     _fcc_long_hi
                LDA     f
                BRA     _ternary_balance_L1
_ternary_balance_L0
                LDA     #1
                JSR     _fcc_itof
_ternary_balance_L1
                STA     1,S   ; fccstk d=0 b=1
                TAY
                LDA     _fcc_long_hi
                STA     3,S   ; fccstk d=0 b=3
                TYA
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_long_hi
                LDA     1,S   ; fccstk d=0 b=1
                FGX2_FARCALL _fcc_dfromf
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #16388
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
                FGX2_FARCALL _fcc_dcmp
                BEQ     *+7
                LDA     #0
                BRA     *+5
                LDA     #1
                BEQ     _ternary_balance_L2
                LDA     9,S   ; fccstk d=0 b=9
                TAX
                CLC
                ADC     #10
                STA     9,S   ; fccstk d=0 b=9
_ternary_balance_L2
                LDA     one
                CMP     #0
                BEQ     _ternary_balance_L3
                LDA     #1
                JSR     _fcc_itof
                BRA     _ternary_balance_L4
_ternary_balance_L3
                LDA     f+2
                STA     _fcc_long_hi
                LDA     f
_ternary_balance_L4
                STA     1,S   ; fccstk d=0 b=1
                TAY
                LDA     _fcc_long_hi
                STA     3,S   ; fccstk d=0 b=3
                TYA
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_long_hi
                LDA     1,S   ; fccstk d=0 b=1
                FGX2_FARCALL _fcc_dfromf
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #16368
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
                FGX2_FARCALL _fcc_dcmp
                BEQ     *+7
                LDA     #0
                BRA     *+5
                LDA     #1
                BEQ     _ternary_balance_L5
                LDA     9,S   ; fccstk d=0 b=9
                TAX
                CLC
                ADC     #10
                STA     9,S   ; fccstk d=0 b=9
_ternary_balance_L5
                LDA     one
                CMP     #0
                BEQ     _ternary_balance_L6
                LDA     big+2
                STA     _fcc_long_hi
                LDA     big
                BRA     _ternary_balance_L7
_ternary_balance_L6
                LDA     #1
                JSR     _fcc_long_from_int
_ternary_balance_L7
                STA     5,S   ; fccstk d=0 b=5
                TAY
                LDA     _fcc_long_hi
                STA     7,S   ; fccstk d=0 b=7
                TYA
                LDA     7,S   ; fccstk d=0 b=7
                STA     _fcc_long_hi
                LDA     5,S   ; fccstk d=0 b=5
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
                BEQ     _ternary_balance_L8
                LDA     9,S   ; fccstk d=0 b=9
                TAX
                CLC
                ADC     #11
                STA     9,S   ; fccstk d=0 b=9
_ternary_balance_L8
                LDA     one
                CMP     #0
                BEQ     _ternary_balance_L9
                LDA     #1
                JSR     _fcc_long_from_int
                BRA     _ternary_balance_L10
_ternary_balance_L9
                LDA     big+2
                STA     _fcc_long_hi
                LDA     big
_ternary_balance_L10
                STA     5,S   ; fccstk d=0 b=5
                TAY
                LDA     _fcc_long_hi
                STA     7,S   ; fccstk d=0 b=7
                TYA
                LDA     7,S   ; fccstk d=0 b=7
                STA     _fcc_long_hi
                LDA     5,S   ; fccstk d=0 b=5
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #1
                JSR     _fcc_long_from_int
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
                BEQ     _ternary_balance_L11
                LDA     9,S   ; fccstk d=0 b=9
                TAX
                CLC
                ADC     #11
                STA     9,S   ; fccstk d=0 b=9
_ternary_balance_L11
                LDA     9,S   ; fccstk d=0 b=9
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
main_FRAMESIZE   EQU     10
main_STKGUARD    EQU     0
                FGX2_RELOC_COUNT 6
