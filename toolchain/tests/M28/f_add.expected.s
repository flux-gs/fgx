                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from f_add.c
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
                LDA     #16376
                STA     _fcc_q3
                LDA     #0
                STA     _fcc_q2
                LDA     #0
                STA     _fcc_long_hi
                LDA     #0
                FGX2_FARCALL _fcc_dtof
                STA     1,S   ; fccstk d=0 b=1
                TAY
                LDA     _fcc_long_hi
                STA     3,S   ; fccstk d=0 b=3
                TYA
                LDA     #16384
                STA     _fcc_q3
                LDA     #0
                STA     _fcc_q2
                LDA     #0
                STA     _fcc_long_hi
                LDA     #0
                FGX2_FARCALL _fcc_dtof
                STA     5,S   ; fccstk d=0 b=5
                TAY
                LDA     _fcc_long_hi
                STA     7,S   ; fccstk d=0 b=7
                TYA
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_long_hi
                LDA     1,S   ; fccstk d=0 b=1
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     11,S   ; fccstk d=4 b=7
                STA     _fcc_long_hi
                LDA     9,S   ; fccstk d=4 b=5
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_fadd
                JSR     _fcc_ftoi
                TAX
                TXA
                CMP     #3
                BNE     *+5
                BRL     _f_add_L0
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
_f_add_L0
                LDA     #16404
                STA     _fcc_q3
                LDA     #0
                STA     _fcc_q2
                LDA     #0
                STA     _fcc_long_hi
                LDA     #0
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #16392
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
                FGX2_FARCALL _fcc_dsub
                FGX2_FARCALL _fcc_dtol
                TAX
                TXA
                CMP     #2
                BNE     *+5
                BRL     _f_add_L1
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
_f_add_L1
                LDA     #16388
                STA     _fcc_q3
                LDA     #0
                STA     _fcc_q2
                LDA     #0
                STA     _fcc_long_hi
                LDA     #0
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
                FGX2_FARCALL _fcc_dadd
                FGX2_FARCALL _fcc_dtol
                TAX
                TXA
                CMP     #5
                BNE     *+5
                BRL     _f_add_L2
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
_f_add_L2
                LDA     #16420
                STA     _fcc_q3
                LDA     #0
                STA     _fcc_q2
                LDA     #0
                STA     _fcc_long_hi
                LDA     #0
                FGX2_FARCALL _fcc_dtof
                STA     1,S   ; fccstk d=0 b=1
                TAY
                LDA     _fcc_long_hi
                STA     3,S   ; fccstk d=0 b=3
                TYA
                LDA     #16352
                STA     _fcc_q3
                LDA     #0
                STA     _fcc_q2
                LDA     #0
                STA     _fcc_long_hi
                LDA     #0
                FGX2_FARCALL _fcc_dtof
                STA     5,S   ; fccstk d=0 b=5
                TAY
                LDA     _fcc_long_hi
                STA     7,S   ; fccstk d=0 b=7
                TYA
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_long_hi
                LDA     1,S   ; fccstk d=0 b=1
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     11,S   ; fccstk d=4 b=7
                STA     _fcc_long_hi
                LDA     9,S   ; fccstk d=4 b=5
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_fsub
                JSR     _fcc_ftoi
                TAX
                TXA
                CMP     #9
                BNE     *+5
                BRL     _f_add_L3
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
_f_add_L3
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_long_hi
                LDA     1,S   ; fccstk d=0 b=1
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #32
                JSR     _fcc_itof
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_fadd
                JSR     _fcc_ftoi
                TAX
                TXA
                CMP     #42
                BNE     *+5
                BRL     _f_add_L4
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
_f_add_L4
                LDA     #16392
                STA     _fcc_q3
                LDA     #0
                STA     _fcc_q2
                LDA     #0
                STA     _fcc_long_hi
                LDA     #0
                FGX2_FARCALL _fcc_dtof
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
                LDA     #16392
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
                FGX2_FARCALL _fcc_dsub
                FGX2_FARCALL _fcc_dtol
                TAX
                TXA
                CMP     #0
                BNE     *+5
                BRL     _f_add_L5
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
_f_add_L5
                LDA     #16384
                STA     _fcc_q3
                LDA     #0
                STA     _fcc_q2
                LDA     #0
                STA     _fcc_long_hi
                LDA     #0
                FGX2_FARCALL _fcc_dtof
                STA     1,S   ; fccstk d=0 b=1
                TAY
                LDA     _fcc_long_hi
                STA     3,S   ; fccstk d=0 b=3
                TYA
                LDA     #16452
                STA     _fcc_q3
                LDA     #0
                STA     _fcc_q2
                LDA     #0
                STA     _fcc_long_hi
                LDA     #0
                FGX2_FARCALL _fcc_dtof
                STA     5,S   ; fccstk d=0 b=5
                TAY
                LDA     _fcc_long_hi
                STA     7,S   ; fccstk d=0 b=7
                TYA
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_long_hi
                LDA     1,S   ; fccstk d=0 b=1
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     11,S   ; fccstk d=4 b=7
                STA     _fcc_long_hi
                LDA     9,S   ; fccstk d=4 b=5
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_fadd
                JSR     _fcc_ftoi
                TAX
                TXA
                CMP     #42
                BEQ     *+5
                BRL     _f_add_L6
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
_f_add_L6
                LDA     #7
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
main_FRAMESIZE   EQU     8
main_STKGUARD    EQU     0
                FGX2_RELOC_COUNT 16
