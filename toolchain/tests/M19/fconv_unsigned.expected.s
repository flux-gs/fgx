                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from fconv_unsigned.c
;---------------------------------------

                MX      %00
                FGX2_EXPORT ret_u
ret_u            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #ret_u_FRAMESIZE
                DO      ret_u_STKGUARD
                BCC     ret_u_stkovf
                CMP     _fcc_stkfloor
                BCS     ret_u_stkok
ret_u_stkovf       JMP     _fcc_stkoflow
                FIN
ret_u_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                LDA     U
                JSR     _fcc_utof
                TAY
                TSC
                CLC
                ADC     #ret_u_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
ret_u_FRAMESIZE   EQU     0
ret_u_STKGUARD    EQU     0
                FGX2_EXPORT arg_f
arg_f            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #arg_f_FRAMESIZE
                DO      arg_f_STKGUARD
                BCC     arg_f_stkovf
                CMP     _fcc_stkfloor
                BCS     arg_f_stkok
arg_f_stkovf       JMP     _fcc_stkoflow
                FIN
arg_f_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      8+arg_f_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+arg_f_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+arg_f_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_long_hi
                DO      6+arg_f_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+arg_f_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+arg_f_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                TAY
                TSC
                CLC
                ADC     #arg_f_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
arg_f_FRAMESIZE   EQU     0
arg_f_STKGUARD    EQU     0
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
                LDA     #$9C40
                STA     U
                LDA     #$B2D0
                STA     _fcc_long_hi
                LDA     #$5E00
                STA     UL
                TAY
                LDA     _fcc_long_hi
                STA     UL+2
                TYA
                LDA     U
                JSR     _fcc_utof
                STA     3,S   ; fccstk d=0 b=3
                TAY
                LDA     _fcc_long_hi
                STA     5,S   ; fccstk d=0 b=5
                TYA
                LDA     5,S   ; fccstk d=0 b=5
                STA     _fcc_long_hi
                LDA     3,S   ; fccstk d=0 b=3
                JSR     _fcc_ftol
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$9C40
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
                BEQ     _fconv_unsigned_L0
                LDA     1,S   ; fccstk d=0 b=1
                TAX
                CLC
                ADC     #1
                STA     1,S   ; fccstk d=0 b=1
_fconv_unsigned_L0
                LDA     U
                JSR     _fcc_utof
                JSR     _fcc_ftol
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$9C40
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
                BEQ     _fconv_unsigned_L1
                LDA     1,S   ; fccstk d=0 b=1
                CLC
                ADC     #2
                STA     1,S   ; fccstk d=0 b=1
_fconv_unsigned_L1
                LDA     U
                LDX     #0
                STX     _fcc_long_hi
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
                LDA     #16352
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
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$9C40
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
                BEQ     _fconv_unsigned_L2
                LDA     1,S   ; fccstk d=0 b=1
                TAX
                CLC
                ADC     #4
                STA     1,S   ; fccstk d=0 b=1
_fconv_unsigned_L2
                FGX2_FARCALL ret_u
                JSR     _fcc_ftol
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$9C40
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
                BEQ     _fconv_unsigned_L3
                LDA     1,S   ; fccstk d=0 b=1
                TAX
                CLC
                ADC     #8
                STA     1,S   ; fccstk d=0 b=1
_fconv_unsigned_L3
                LDA     UL+2
                STA     _fcc_long_hi
                LDA     UL
                JSR     _fcc_ultof
                STA     3,S   ; fccstk d=0 b=3
                TAY
                LDA     _fcc_long_hi
                STA     5,S   ; fccstk d=0 b=5
                TYA
                LDA     5,S   ; fccstk d=0 b=5
                STA     _fcc_long_hi
                LDA     3,S   ; fccstk d=0 b=3
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
                LDA     #16869
                STA     _fcc_q3
                LDA     #39759
                STA     _fcc_q2
                LDA     #40960
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
                CMP     #1
                BEQ     *+7
                LDA     #0
                BRA     *+5
                LDA     #1
                CMP     #0
                BEQ     _fconv_unsigned_L4
                LDA     5,S   ; fccstk d=0 b=5
                STA     _fcc_long_hi
                LDA     3,S   ; fccstk d=0 b=3
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
                LDA     #16871
                STA     _fcc_q3
                LDA     #6343
                STA     _fcc_q2
                LDA     #57344
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
                BMI     *+7
                LDA     #0
                BRA     *+5
                LDA     #1
                CMP     #0
                BEQ     _fconv_unsigned_L4
                LDA     1,S   ; fccstk d=0 b=1
                TAX
                CLC
                ADC     #16
                STA     1,S   ; fccstk d=0 b=1
_fconv_unsigned_L4
                LDA     #16611
                STA     _fcc_q3
                LDA     #34816
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
                LDA     F+2
                STA     _fcc_long_hi
                LDA     F
                JSR     _fcc_ftoi
                STA     7,S   ; fccstk d=0 b=7
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$9C40
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                LDX     #0
                STX     _fcc_long_hi
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     _fcc_long_b_lo
                LDX     _fcc_long_b_hi
                STX     _fcc_long_hi
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
                BEQ     _fconv_unsigned_L5
                LDA     1,S   ; fccstk d=0 b=1
                TAX
                CLC
                ADC     #32
                STA     1,S   ; fccstk d=0 b=1
_fconv_unsigned_L5
                LDA     #16870
                STA     _fcc_q3
                LDA     #23051
                STA     _fcc_q2
                LDA     #49152
                STA     _fcc_long_hi
                LDA     #0
                FGX2_FARCALL _fcc_dtof
                STA     F
                TAY
                LDA     _fcc_long_hi
                STA     F+2
                TYA
                LDA     F+2
                STA     _fcc_long_hi
                LDA     F
                JSR     _fcc_ftol
                STA     9,S   ; fccstk d=0 b=9
                TAY
                LDA     _fcc_long_hi
                STA     11,S   ; fccstk d=0 b=11
                TYA
                LDA     11,S   ; fccstk d=0 b=11
                STA     _fcc_long_hi
                LDA     9,S   ; fccstk d=0 b=9
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$B2D0
                STA     _fcc_long_hi
                LDA     #$5E00
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
                BEQ     _fconv_unsigned_L6
                LDA     1,S   ; fccstk d=0 b=1
                TAX
                CLC
                ADC     #64
                STA     1,S   ; fccstk d=0 b=1
_fconv_unsigned_L6
                LDA     U
                JSR     _fcc_utof
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                FGX2_FARCALL arg_f
                TAY
                TSC
                CLC
                ADC     #4
                TCS
                TYA
                JSR     _fcc_ftol
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$9C40
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
                BEQ     _fconv_unsigned_L7
                LDA     1,S   ; fccstk d=0 b=1
                TAX
                CLC
                ADC     #128
                STA     1,S   ; fccstk d=0 b=1
_fconv_unsigned_L7
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
main_FRAMESIZE   EQU     12
main_STKGUARD    EQU     0
                FGX2_RELOC_COUNT 15
