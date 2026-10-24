                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from ldouble_arith.c
;---------------------------------------

                MX      %00
                FGX2_EXPORT _ldouble_arith_is
_ldouble_arith_is            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #_ldouble_arith_is_FRAMESIZE
                DO      _ldouble_arith_is_STKGUARD
                BCC     _ldouble_arith_is_stkovf
                CMP     _fcc_stkfloor
                BCS     _ldouble_arith_is_stkok
_ldouble_arith_is_stkovf       JMP     _fcc_stkoflow
                FIN
_ldouble_arith_is_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      8+_ldouble_arith_is_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_ldouble_arith_is_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_ldouble_arith_is_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+_ldouble_arith_is_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_ldouble_arith_is_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_ldouble_arith_is_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     3,S   ; fccstk d=0 b=3
                LDA     _fcc_fpr0
                STA     1,S   ; fccstk d=0 b=1
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_ptr+2
                LDA     1,S   ; fccstk d=0 b=1
                PHA
                LDA     #0
                ASL
                ASL
                CLC
                ADC     1,S
                STA     _fcc_ptr
                PLA
                LDA     [_fcc_ptr]
                STA     _fcc_long_b_lo
                LDA     _fcc_ptr
                INC
                INC
                STA     _fcc_ptr
                LDA     [_fcc_ptr]
                STA     _fcc_long_hi
                LDA     _fcc_long_b_lo
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                DO      20+_ldouble_arith_is_FRAMESIZE/256
                TSC
                CLC
                ADC     #20+_ldouble_arith_is_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     20+_ldouble_arith_is_FRAMESIZE,S   ; fccstk d=4 b=16 fs
                FIN
                STA     _fcc_long_hi
                DO      18+_ldouble_arith_is_FRAMESIZE/256
                TSC
                CLC
                ADC     #18+_ldouble_arith_is_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     18+_ldouble_arith_is_FRAMESIZE,S   ; fccstk d=4 b=14 fs
                FIN
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
                BNE     *+5
                BRL     _ldouble_arith_L0
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_ptr+2
                LDA     1,S   ; fccstk d=0 b=1
                PHA
                LDA     #1
                ASL
                ASL
                CLC
                ADC     1,S
                STA     _fcc_ptr
                PLA
                LDA     [_fcc_ptr]
                STA     _fcc_long_b_lo
                LDA     _fcc_ptr
                INC
                INC
                STA     _fcc_ptr
                LDA     [_fcc_ptr]
                STA     _fcc_long_hi
                LDA     _fcc_long_b_lo
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                DO      16+_ldouble_arith_is_FRAMESIZE/256
                TSC
                CLC
                ADC     #16+_ldouble_arith_is_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     16+_ldouble_arith_is_FRAMESIZE,S   ; fccstk d=4 b=12 fs
                FIN
                STA     _fcc_long_hi
                DO      14+_ldouble_arith_is_FRAMESIZE/256
                TSC
                CLC
                ADC     #14+_ldouble_arith_is_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     14+_ldouble_arith_is_FRAMESIZE,S   ; fccstk d=4 b=10 fs
                FIN
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
                BNE     *+5
                BRL     _ldouble_arith_L0
                LDA     #1
                BRL     _ldouble_arith_L1
_ldouble_arith_L0
                LDA     #0
_ldouble_arith_L1
                TAY
                TSC
                CLC
                ADC     #_ldouble_arith_is_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_ldouble_arith_is_FRAMESIZE   EQU     4
_ldouble_arith_is_STKGUARD    EQU     0
                FGX2_EXPORT _ldouble_arith_put
_ldouble_arith_put            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #_ldouble_arith_put_FRAMESIZE
                DO      _ldouble_arith_put_STKGUARD
                BCC     _ldouble_arith_put_stkovf
                CMP     _fcc_stkfloor
                BCS     _ldouble_arith_put_stkok
_ldouble_arith_put_stkovf       JMP     _fcc_stkoflow
                FIN
_ldouble_arith_put_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      8+_ldouble_arith_put_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_ldouble_arith_put_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_ldouble_arith_put_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+_ldouble_arith_put_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_ldouble_arith_put_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_ldouble_arith_put_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     3,S   ; fccstk d=0 b=3
                LDA     _fcc_fpr0
                STA     1,S   ; fccstk d=0 b=1
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_ptr+2
                LDA     1,S   ; fccstk d=0 b=1
                PHA
                LDA     #0
                ASL
                ASL
                CLC
                ADC     1,S
                TAY
                PLA
                TYA
                TAY
                LDA     _fcc_ptr+2
                PHA
                TYA
                PHA
                DO      20+_ldouble_arith_put_FRAMESIZE/256
                TSC
                CLC
                ADC     #20+_ldouble_arith_put_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     20+_ldouble_arith_put_FRAMESIZE,S   ; fccstk d=4 b=16 fs
                FIN
                STA     _fcc_long_hi
                DO      18+_ldouble_arith_put_FRAMESIZE/256
                TSC
                CLC
                ADC     #18+_ldouble_arith_put_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     18+_ldouble_arith_put_FRAMESIZE,S   ; fccstk d=4 b=14 fs
                FIN
                STA     _fcc_tmp_b
                LDA     1,S
                STA     _fcc_ptr
                LDA     3,S
                STA     _fcc_ptr+2
                LDA     _fcc_tmp_b
                STA     [_fcc_ptr]
                LDA     _fcc_long_hi
                LDY     #2
                STA     [_fcc_ptr],Y
                PLA
                PLA
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_ptr+2
                LDA     1,S   ; fccstk d=0 b=1
                PHA
                LDA     #1
                ASL
                ASL
                CLC
                ADC     1,S
                TAY
                PLA
                TYA
                TAY
                LDA     _fcc_ptr+2
                PHA
                TYA
                PHA
                DO      16+_ldouble_arith_put_FRAMESIZE/256
                TSC
                CLC
                ADC     #16+_ldouble_arith_put_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     16+_ldouble_arith_put_FRAMESIZE,S   ; fccstk d=4 b=12 fs
                FIN
                STA     _fcc_long_hi
                DO      14+_ldouble_arith_put_FRAMESIZE/256
                TSC
                CLC
                ADC     #14+_ldouble_arith_put_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     14+_ldouble_arith_put_FRAMESIZE,S   ; fccstk d=4 b=10 fs
                FIN
                STA     _fcc_tmp_b
                LDA     1,S
                STA     _fcc_ptr
                LDA     3,S
                STA     _fcc_ptr+2
                LDA     _fcc_tmp_b
                STA     [_fcc_ptr]
                LDA     _fcc_long_hi
                LDY     #2
                STA     [_fcc_ptr],Y
                PLA
                PLA
                TAY
                TSC
                CLC
                ADC     #_ldouble_arith_put_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_ldouble_arith_put_FRAMESIZE   EQU     4
_ldouble_arith_put_STKGUARD    EQU     0
                FGX2_EXPORT _ldouble_arith_trunc3
_ldouble_arith_trunc3            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #_ldouble_arith_trunc3_FRAMESIZE
                DO      _ldouble_arith_trunc3_STKGUARD
                BCC     _ldouble_arith_trunc3_stkovf
                CMP     _fcc_stkfloor
                BCS     _ldouble_arith_trunc3_stkok
_ldouble_arith_trunc3_stkovf       JMP     _fcc_stkoflow
                FIN
_ldouble_arith_trunc3_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      6+_ldouble_arith_trunc3_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_ldouble_arith_trunc3_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_ldouble_arith_trunc3_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                TAY
                TSC
                CLC
                ADC     #_ldouble_arith_trunc3_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_ldouble_arith_trunc3_FRAMESIZE   EQU     0
_ldouble_arith_trunc3_STKGUARD    EQU     0
                FGX2_EXPORT _ldouble_arith_half
_ldouble_arith_half            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #_ldouble_arith_half_FRAMESIZE
                DO      _ldouble_arith_half_STKGUARD
                BCC     _ldouble_arith_half_stkovf
                CMP     _fcc_stkfloor
                BCS     _ldouble_arith_half_stkok
_ldouble_arith_half_stkovf       JMP     _fcc_stkoflow
                FIN
_ldouble_arith_half_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      12+_ldouble_arith_half_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+_ldouble_arith_half_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+_ldouble_arith_half_FRAMESIZE,S   ; fccstk d=0 b=12 fs
                FIN
                STA     _fcc_q3
                DO      10+_ldouble_arith_half_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+_ldouble_arith_half_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+_ldouble_arith_half_FRAMESIZE,S   ; fccstk d=0 b=10 fs
                FIN
                STA     _fcc_q2
                DO      8+_ldouble_arith_half_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_ldouble_arith_half_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_ldouble_arith_half_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_long_hi
                DO      6+_ldouble_arith_half_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_ldouble_arith_half_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_ldouble_arith_half_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #2
                JSR     _fcc_long_from_int
                FGX2_FARCALL _fcc_dfroml
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
                FGX2_FARCALL _fcc_ddiv
                TAY
                TSC
                CLC
                ADC     #_ldouble_arith_half_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_ldouble_arith_half_FRAMESIZE   EQU     0
_ldouble_arith_half_STKGUARD    EQU     0
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
                LDA     #$9C40
                STA     45,S   ; fccstk d=0 b=45
                LDA     #$B2D0
                STA     _fcc_long_hi
                LDA     #$5E00
                STA     47,S   ; fccstk d=0 b=47
                TAY
                LDA     _fcc_long_hi
                STA     49,S   ; fccstk d=0 b=49
                TYA
                LDA     #$0001
                STA     _fcc_long_hi
                LDA     #$1170
                STA     51,S   ; fccstk d=0 b=51
                TAY
                LDA     _fcc_long_hi
                STA     53,S   ; fccstk d=0 b=53
                TYA
                LDA     #1
                JSR     _fcc_long_from_int
                FGX2_FARCALL _fcc_dfroml
                STA     1,S   ; fccstk d=0 b=1
                TAY
                LDA     _fcc_long_hi
                STA     3,S   ; fccstk d=0 b=3
                LDA     _fcc_q2
                STA     5,S   ; fccstk d=0 b=5
                LDA     _fcc_q3
                STA     7,S   ; fccstk d=0 b=7
                TYA
                LDA     #3
                JSR     _fcc_long_from_int
                FGX2_FARCALL _fcc_dfroml
                STA     9,S   ; fccstk d=0 b=9
                TAY
                LDA     _fcc_long_hi
                STA     11,S   ; fccstk d=0 b=11
                LDA     _fcc_q2
                STA     13,S   ; fccstk d=0 b=13
                LDA     _fcc_q3
                STA     15,S   ; fccstk d=0 b=15
                TYA
                LDA     7,S   ; fccstk d=0 b=7
                STA     _fcc_q3
                LDA     5,S   ; fccstk d=0 b=5
                STA     _fcc_q2
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_long_hi
                LDA     1,S   ; fccstk d=0 b=1
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     23,S   ; fccstk d=8 b=15
                STA     _fcc_q3
                LDA     21,S   ; fccstk d=8 b=13
                STA     _fcc_q2
                LDA     19,S   ; fccstk d=8 b=11
                STA     _fcc_long_hi
                LDA     17,S   ; fccstk d=8 b=9
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
                FGX2_FARCALL _fcc_ddiv
                STA     17,S   ; fccstk d=0 b=17
                TAY
                LDA     _fcc_long_hi
                STA     19,S   ; fccstk d=0 b=19
                LDA     _fcc_q2
                STA     21,S   ; fccstk d=0 b=21
                LDA     _fcc_q3
                STA     23,S   ; fccstk d=0 b=23
                TYA
                LDA     #$5555
                STA     _fcc_long_hi
                LDA     #$5555
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$3FD5
                STA     _fcc_long_hi
                LDA     #$5555
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #16
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _ldouble_arith_is
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                CMP     #0
                BEQ     _ldouble_arith_L3
                LDA     #0
                BRA     _ldouble_arith_L4
_ldouble_arith_L3
                LDA     #1
_ldouble_arith_L4
                CMP     #0
                BNE     *+5
                BRL     _ldouble_arith_L2
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
_ldouble_arith_L2
                LDA     23,S   ; fccstk d=0 b=23
                STA     _fcc_q3
                LDA     21,S   ; fccstk d=0 b=21
                STA     _fcc_q2
                LDA     19,S   ; fccstk d=0 b=19
                STA     _fcc_long_hi
                LDA     17,S   ; fccstk d=0 b=17
                TAY
                LDA     _fcc_q3
                EOR     #$8000
                STA     _fcc_q3
                TYA
                STA     17,S   ; fccstk d=0 b=17
                TAY
                LDA     _fcc_long_hi
                STA     19,S   ; fccstk d=0 b=19
                LDA     _fcc_q2
                STA     21,S   ; fccstk d=0 b=21
                LDA     _fcc_q3
                STA     23,S   ; fccstk d=0 b=23
                TYA
                LDA     #$5555
                STA     _fcc_long_hi
                LDA     #$5555
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$BFD5
                STA     _fcc_long_hi
                LDA     #$5555
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #16
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _ldouble_arith_is
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                CMP     #0
                BEQ     _ldouble_arith_L6
                LDA     #0
                BRA     _ldouble_arith_L7
_ldouble_arith_L6
                LDA     #1
_ldouble_arith_L7
                CMP     #0
                BNE     *+5
                BRL     _ldouble_arith_L5
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
_ldouble_arith_L5
                LDA     #7
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
                LDA     15,S   ; fccstk d=8 b=7
                STA     _fcc_q3
                LDA     13,S   ; fccstk d=8 b=5
                STA     _fcc_q2
                LDA     11,S   ; fccstk d=8 b=3
                STA     _fcc_long_hi
                LDA     9,S   ; fccstk d=8 b=1
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     31,S   ; fccstk d=16 b=15
                STA     _fcc_q3
                LDA     29,S   ; fccstk d=16 b=13
                STA     _fcc_q2
                LDA     27,S   ; fccstk d=16 b=11
                STA     _fcc_long_hi
                LDA     25,S   ; fccstk d=16 b=9
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
                FGX2_FARCALL _fcc_ddiv
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
                STA     17,S   ; fccstk d=0 b=17
                TAY
                LDA     _fcc_long_hi
                STA     19,S   ; fccstk d=0 b=19
                LDA     _fcc_q2
                STA     21,S   ; fccstk d=0 b=21
                LDA     _fcc_q3
                STA     23,S   ; fccstk d=0 b=23
                TYA
                LDA     #$AAAA
                STA     _fcc_long_hi
                LDA     #$AAAA
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$4002
                STA     _fcc_long_hi
                LDA     #$AAAA
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #16
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _ldouble_arith_is
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                CMP     #0
                BEQ     _ldouble_arith_L9
                LDA     #0
                BRA     _ldouble_arith_L10
_ldouble_arith_L9
                LDA     #1
_ldouble_arith_L10
                CMP     #0
                BNE     *+5
                BRL     _ldouble_arith_L8
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
_ldouble_arith_L8
                LDA     7,S   ; fccstk d=0 b=7
                STA     _fcc_q3
                LDA     5,S   ; fccstk d=0 b=5
                STA     _fcc_q2
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_long_hi
                LDA     1,S   ; fccstk d=0 b=1
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     23,S   ; fccstk d=8 b=15
                STA     _fcc_q3
                LDA     21,S   ; fccstk d=8 b=13
                STA     _fcc_q2
                LDA     19,S   ; fccstk d=8 b=11
                STA     _fcc_long_hi
                LDA     17,S   ; fccstk d=8 b=9
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
                FGX2_FARCALL _fcc_ddiv
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #2
                JSR     _fcc_long_from_int
                FGX2_FARCALL _fcc_dfroml
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
                STA     17,S   ; fccstk d=0 b=17
                TAY
                LDA     _fcc_long_hi
                STA     19,S   ; fccstk d=0 b=19
                LDA     _fcc_q2
                STA     21,S   ; fccstk d=0 b=21
                LDA     _fcc_q3
                STA     23,S   ; fccstk d=0 b=23
                TYA
                LDA     #$AAAA
                STA     _fcc_long_hi
                LDA     #$AAAB
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$4002
                STA     _fcc_long_hi
                LDA     #$AAAA
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #16
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _ldouble_arith_is
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                CMP     #0
                BEQ     _ldouble_arith_L12
                LDA     #0
                BRA     _ldouble_arith_L13
_ldouble_arith_L12
                LDA     #1
_ldouble_arith_L13
                CMP     #0
                BNE     *+5
                BRL     _ldouble_arith_L11
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
_ldouble_arith_L11
                LDA     45,S   ; fccstk d=0 b=45
                LDX     #0
                STX     _fcc_long_hi
                FGX2_FARCALL _fcc_dfroml
                STA     17,S   ; fccstk d=0 b=17
                TAY
                LDA     _fcc_long_hi
                STA     19,S   ; fccstk d=0 b=19
                LDA     _fcc_q2
                STA     21,S   ; fccstk d=0 b=21
                LDA     _fcc_q3
                STA     23,S   ; fccstk d=0 b=23
                TYA
                LDA     23,S   ; fccstk d=0 b=23
                STA     _fcc_q3
                LDA     21,S   ; fccstk d=0 b=21
                STA     _fcc_q2
                LDA     19,S   ; fccstk d=0 b=19
                STA     _fcc_long_hi
                LDA     17,S   ; fccstk d=0 b=17
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #7
                JSR     _fcc_long_from_int
                FGX2_FARCALL _fcc_dfroml
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
                FGX2_FARCALL _fcc_ddiv
                STA     17,S   ; fccstk d=0 b=17
                TAY
                LDA     _fcc_long_hi
                STA     19,S   ; fccstk d=0 b=19
                LDA     _fcc_q2
                STA     21,S   ; fccstk d=0 b=21
                LDA     _fcc_q3
                STA     23,S   ; fccstk d=0 b=23
                TYA
                LDA     #$2492
                STA     _fcc_long_hi
                LDA     #$4925
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$40B6
                STA     _fcc_long_hi
                LDA     #$5249
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #16
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _ldouble_arith_is
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                CMP     #0
                BEQ     _ldouble_arith_L15
                LDA     #0
                BRA     _ldouble_arith_L16
_ldouble_arith_L15
                LDA     #1
_ldouble_arith_L16
                CMP     #0
                BNE     *+5
                BRL     _ldouble_arith_L14
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
_ldouble_arith_L14
                LDA     53,S   ; fccstk d=0 b=53
                STA     _fcc_long_hi
                LDA     51,S   ; fccstk d=0 b=51
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$FFFD
                JSR     _fcc_long_from_int
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_mul
                FGX2_FARCALL _fcc_dfroml
                STA     17,S   ; fccstk d=0 b=17
                TAY
                LDA     _fcc_long_hi
                STA     19,S   ; fccstk d=0 b=19
                LDA     _fcc_q2
                STA     21,S   ; fccstk d=0 b=21
                LDA     _fcc_q3
                STA     23,S   ; fccstk d=0 b=23
                TYA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0000
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$C109
                STA     _fcc_long_hi
                LDA     #$A280
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #16
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _ldouble_arith_is
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                CMP     #0
                BEQ     _ldouble_arith_L18
                LDA     #0
                BRA     _ldouble_arith_L19
_ldouble_arith_L18
                LDA     #1
_ldouble_arith_L19
                CMP     #0
                BNE     *+5
                BRL     _ldouble_arith_L17
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
_ldouble_arith_L17
                LDA     49,S   ; fccstk d=0 b=49
                STA     _fcc_long_hi
                LDA     47,S   ; fccstk d=0 b=47
                FGX2_FARCALL _fcc_dfromul
                STA     17,S   ; fccstk d=0 b=17
                TAY
                LDA     _fcc_long_hi
                STA     19,S   ; fccstk d=0 b=19
                LDA     _fcc_q2
                STA     21,S   ; fccstk d=0 b=21
                LDA     _fcc_q3
                STA     23,S   ; fccstk d=0 b=23
                TYA
                LDA     #$C000
                STA     _fcc_long_hi
                LDA     #$0000
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$41E6
                STA     _fcc_long_hi
                LDA     #$5A0B
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #16
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _ldouble_arith_is
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                CMP     #0
                BEQ     _ldouble_arith_L21
                LDA     #0
                BRA     _ldouble_arith_L22
_ldouble_arith_L21
                LDA     #1
_ldouble_arith_L22
                CMP     #0
                BNE     *+5
                BRL     _ldouble_arith_L20
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
_ldouble_arith_L20
                LDA     23,S   ; fccstk d=0 b=23
                STA     _fcc_q3
                LDA     21,S   ; fccstk d=0 b=21
                STA     _fcc_q2
                LDA     19,S   ; fccstk d=0 b=19
                STA     _fcc_long_hi
                LDA     17,S   ; fccstk d=0 b=17
                FGX2_FARCALL _fcc_dtol
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
                JSR     _fcc_long_ne
                CMP     #0
                BNE     *+5
                BRL     _ldouble_arith_L23
                LDA     #8
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_ldouble_arith_L23
                LDA     #16880
                STA     _fcc_q3
                LDA     #0
                STA     _fcc_q2
                LDA     #0
                STA     _fcc_long_hi
                LDA     #0
                STA     17,S   ; fccstk d=0 b=17
                TAY
                LDA     _fcc_long_hi
                STA     19,S   ; fccstk d=0 b=19
                LDA     _fcc_q2
                STA     21,S   ; fccstk d=0 b=21
                LDA     _fcc_q3
                STA     23,S   ; fccstk d=0 b=23
                TYA
                LDA     23,S   ; fccstk d=0 b=23
                STA     _fcc_q3
                LDA     21,S   ; fccstk d=0 b=21
                STA     _fcc_q2
                LDA     19,S   ; fccstk d=0 b=19
                STA     _fcc_long_hi
                LDA     17,S   ; fccstk d=0 b=17
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0020
                STA     _fcc_long_hi
                LDA     #$0000
                FGX2_FARCALL _fcc_dfroml
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
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #1
                JSR     _fcc_long_from_int
                FGX2_FARCALL _fcc_dfroml
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
                STA     17,S   ; fccstk d=0 b=17
                TAY
                LDA     _fcc_long_hi
                STA     19,S   ; fccstk d=0 b=19
                LDA     _fcc_q2
                STA     21,S   ; fccstk d=0 b=21
                LDA     _fcc_q3
                STA     23,S   ; fccstk d=0 b=23
                TYA
                LDA     #$FFFF
                STA     _fcc_long_hi
                LDA     #$FFFF
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$433F
                STA     _fcc_long_hi
                LDA     #$FFFF
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #16
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _ldouble_arith_is
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                CMP     #0
                BEQ     _ldouble_arith_L25
                LDA     #0
                BRA     _ldouble_arith_L26
_ldouble_arith_L25
                LDA     #1
_ldouble_arith_L26
                CMP     #0
                BNE     *+5
                BRL     _ldouble_arith_L24
                LDA     #9
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_ldouble_arith_L24
                LDA     23,S   ; fccstk d=0 b=23
                STA     _fcc_q3
                LDA     21,S   ; fccstk d=0 b=21
                STA     _fcc_q2
                LDA     19,S   ; fccstk d=0 b=19
                STA     _fcc_long_hi
                LDA     17,S   ; fccstk d=0 b=17
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                STZ     _fcc_long_b_lo
                STZ     _fcc_long_b_hi
                STZ     _fcc_qb2
                LDX     #$3FF0
                STX     _fcc_qb3
                FGX2_FARCALL _fcc_dadd
                STA     25,S   ; fccstk d=8 b=17
                TAY
                LDA     _fcc_long_hi
                STA     27,S   ; fccstk d=8 b=19
                LDA     _fcc_q2
                STA     29,S   ; fccstk d=8 b=21
                LDA     _fcc_q3
                STA     31,S   ; fccstk d=8 b=23
                TYA
                PLA
                TAY
                PLA
                PLA
                STA     _fcc_q2
                PLA
                STA     _fcc_q3
                TYA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0000
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$4340
                STA     _fcc_long_hi
                LDA     #$0000
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #16
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _ldouble_arith_is
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                CMP     #0
                BEQ     _ldouble_arith_L28
                LDA     #0
                BRA     _ldouble_arith_L29
_ldouble_arith_L28
                LDA     #1
_ldouble_arith_L29
                CMP     #0
                BNE     *+5
                BRL     _ldouble_arith_L27
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
_ldouble_arith_L27
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0000
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$7FF8
                STA     _fcc_long_hi
                LDA     #$0000
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #32
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _ldouble_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     7,S   ; fccstk d=0 b=7
                STA     _fcc_q3
                LDA     5,S   ; fccstk d=0 b=5
                STA     _fcc_q2
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_long_hi
                LDA     1,S   ; fccstk d=0 b=1
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     23,S   ; fccstk d=8 b=15
                STA     _fcc_q3
                LDA     21,S   ; fccstk d=8 b=13
                STA     _fcc_q2
                LDA     19,S   ; fccstk d=8 b=11
                STA     _fcc_long_hi
                LDA     17,S   ; fccstk d=8 b=9
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
                BEQ     _ldouble_arith_L41
                LDA     #0
                BRA     _ldouble_arith_L42
_ldouble_arith_L41
                LDA     #1
_ldouble_arith_L42
                CMP     #0
                BEQ     *+5
                BRL     _ldouble_arith_L39
                LDA     7,S   ; fccstk d=0 b=7
                STA     _fcc_q3
                LDA     5,S   ; fccstk d=0 b=5
                STA     _fcc_q2
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_long_hi
                LDA     1,S   ; fccstk d=0 b=1
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     23,S   ; fccstk d=8 b=15
                STA     _fcc_q3
                LDA     21,S   ; fccstk d=8 b=13
                STA     _fcc_q2
                LDA     19,S   ; fccstk d=8 b=11
                STA     _fcc_long_hi
                LDA     17,S   ; fccstk d=8 b=9
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
                BEQ     *+5
                BRL     _ldouble_arith_L39
                LDA     #0
                BRL     _ldouble_arith_L40
_ldouble_arith_L39
                LDA     #1
_ldouble_arith_L40
                CMP     #0
                BEQ     *+5
                BRL     _ldouble_arith_L37
                LDA     7,S   ; fccstk d=0 b=7
                STA     _fcc_q3
                LDA     5,S   ; fccstk d=0 b=5
                STA     _fcc_q2
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_long_hi
                LDA     1,S   ; fccstk d=0 b=1
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     23,S   ; fccstk d=8 b=15
                STA     _fcc_q3
                LDA     21,S   ; fccstk d=8 b=13
                STA     _fcc_q2
                LDA     19,S   ; fccstk d=8 b=11
                STA     _fcc_long_hi
                LDA     17,S   ; fccstk d=8 b=9
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
                INC
                CMP     #2
                BCC     *+7
                LDA     #0
                BRA     *+5
                LDA     #1
                CMP     #0
                BEQ     _ldouble_arith_L43
                LDA     #0
                BRA     _ldouble_arith_L44
_ldouble_arith_L43
                LDA     #1
_ldouble_arith_L44
                CMP     #0
                BEQ     *+5
                BRL     _ldouble_arith_L37
                LDA     #0
                BRL     _ldouble_arith_L38
_ldouble_arith_L37
                LDA     #1
_ldouble_arith_L38
                CMP     #0
                BEQ     *+5
                BRL     _ldouble_arith_L35
                LDA     7,S   ; fccstk d=0 b=7
                STA     _fcc_q3
                LDA     5,S   ; fccstk d=0 b=5
                STA     _fcc_q2
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_long_hi
                LDA     1,S   ; fccstk d=0 b=1
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     23,S   ; fccstk d=8 b=15
                STA     _fcc_q3
                LDA     21,S   ; fccstk d=8 b=13
                STA     _fcc_q2
                LDA     19,S   ; fccstk d=8 b=11
                STA     _fcc_long_hi
                LDA     17,S   ; fccstk d=8 b=9
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
                CMP     #2
                BCC     *+7
                LDA     #0
                BRA     *+5
                LDA     #1
                CMP     #0
                BEQ     *+5
                BRL     _ldouble_arith_L35
                LDA     #0
                BRL     _ldouble_arith_L36
_ldouble_arith_L35
                LDA     #1
_ldouble_arith_L36
                CMP     #0
                BEQ     *+5
                BRL     _ldouble_arith_L33
                LDA     7,S   ; fccstk d=0 b=7
                STA     _fcc_q3
                LDA     5,S   ; fccstk d=0 b=5
                STA     _fcc_q2
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_long_hi
                LDA     1,S   ; fccstk d=0 b=1
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     23,S   ; fccstk d=8 b=15
                STA     _fcc_q3
                LDA     21,S   ; fccstk d=8 b=13
                STA     _fcc_q2
                LDA     19,S   ; fccstk d=8 b=11
                STA     _fcc_long_hi
                LDA     17,S   ; fccstk d=8 b=9
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
                CMP     #0
                BEQ     *+5
                BRL     _ldouble_arith_L33
                LDA     #0
                BRL     _ldouble_arith_L34
_ldouble_arith_L33
                LDA     #1
_ldouble_arith_L34
                CMP     #0
                BEQ     *+5
                BRL     _ldouble_arith_L31
                LDA     7,S   ; fccstk d=0 b=7
                STA     _fcc_q3
                LDA     5,S   ; fccstk d=0 b=5
                STA     _fcc_q2
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_long_hi
                LDA     1,S   ; fccstk d=0 b=1
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     23,S   ; fccstk d=8 b=15
                STA     _fcc_q3
                LDA     21,S   ; fccstk d=8 b=13
                STA     _fcc_q2
                LDA     19,S   ; fccstk d=8 b=11
                STA     _fcc_long_hi
                LDA     17,S   ; fccstk d=8 b=9
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
                BNE     *+7
                LDA     #0
                BRA     *+5
                LDA     #1
                CMP     #0
                BEQ     _ldouble_arith_L45
                LDA     #0
                BRA     _ldouble_arith_L46
_ldouble_arith_L45
                LDA     #1
_ldouble_arith_L46
                CMP     #0
                BEQ     *+5
                BRL     _ldouble_arith_L31
                LDA     #0
                BRL     _ldouble_arith_L32
_ldouble_arith_L31
                LDA     #1
_ldouble_arith_L32
                CMP     #0
                BNE     *+5
                BRL     _ldouble_arith_L30
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
_ldouble_arith_L30
                LDA     15,S   ; fccstk d=0 b=15
                STA     _fcc_q3
                LDA     13,S   ; fccstk d=0 b=13
                STA     _fcc_q2
                LDA     11,S   ; fccstk d=0 b=11
                STA     _fcc_long_hi
                LDA     9,S   ; fccstk d=0 b=9
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #3
                JSR     _fcc_long_from_int
                FGX2_FARCALL _fcc_dfroml
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
                INC
                CMP     #2
                BCC     *+7
                LDA     #0
                BRA     *+5
                LDA     #1
                CMP     #0
                BEQ     _ldouble_arith_L56
                LDA     #0
                BRA     _ldouble_arith_L57
_ldouble_arith_L56
                LDA     #1
_ldouble_arith_L57
                CMP     #0
                BEQ     *+5
                BRL     _ldouble_arith_L54
                LDA     15,S   ; fccstk d=0 b=15
                STA     _fcc_q3
                LDA     13,S   ; fccstk d=0 b=13
                STA     _fcc_q2
                LDA     11,S   ; fccstk d=0 b=11
                STA     _fcc_long_hi
                LDA     9,S   ; fccstk d=0 b=9
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #3
                JSR     _fcc_long_from_int
                FGX2_FARCALL _fcc_dfroml
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
                CMP     #2
                BCC     *+7
                LDA     #0
                BRA     *+5
                LDA     #1
                CMP     #0
                BEQ     _ldouble_arith_L58
                LDA     #0
                BRA     _ldouble_arith_L59
_ldouble_arith_L58
                LDA     #1
_ldouble_arith_L59
                CMP     #0
                BEQ     *+5
                BRL     _ldouble_arith_L54
                LDA     #0
                BRL     _ldouble_arith_L55
_ldouble_arith_L54
                LDA     #1
_ldouble_arith_L55
                CMP     #0
                BEQ     *+5
                BRL     _ldouble_arith_L52
                LDA     #3
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
                LDA     23,S   ; fccstk d=8 b=15
                STA     _fcc_q3
                LDA     21,S   ; fccstk d=8 b=13
                STA     _fcc_q2
                LDA     19,S   ; fccstk d=8 b=11
                STA     _fcc_long_hi
                LDA     17,S   ; fccstk d=8 b=9
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
                CMP     #0
                BEQ     _ldouble_arith_L60
                LDA     #0
                BRA     _ldouble_arith_L61
_ldouble_arith_L60
                LDA     #1
_ldouble_arith_L61
                CMP     #0
                BEQ     *+5
                BRL     _ldouble_arith_L52
                LDA     #0
                BRL     _ldouble_arith_L53
_ldouble_arith_L52
                LDA     #1
_ldouble_arith_L53
                CMP     #0
                BEQ     *+5
                BRL     _ldouble_arith_L50
                LDA     15,S   ; fccstk d=0 b=15
                STA     _fcc_q3
                LDA     13,S   ; fccstk d=0 b=13
                STA     _fcc_q2
                LDA     11,S   ; fccstk d=0 b=11
                STA     _fcc_long_hi
                LDA     9,S   ; fccstk d=0 b=9
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #3
                JSR     _fcc_long_from_int
                FGX2_FARCALL _fcc_dfroml
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
                BEQ     *+5
                BRL     _ldouble_arith_L50
                LDA     #0
                BRL     _ldouble_arith_L51
_ldouble_arith_L50
                LDA     #1
_ldouble_arith_L51
                CMP     #0
                BEQ     *+5
                BRL     _ldouble_arith_L48
                LDA     15,S   ; fccstk d=0 b=15
                STA     _fcc_q3
                LDA     13,S   ; fccstk d=0 b=13
                STA     _fcc_q2
                LDA     11,S   ; fccstk d=0 b=11
                STA     _fcc_long_hi
                LDA     9,S   ; fccstk d=0 b=9
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #3
                JSR     _fcc_long_from_int
                FGX2_FARCALL _fcc_dfroml
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
                BEQ     *+5
                BRL     _ldouble_arith_L48
                LDA     #0
                BRL     _ldouble_arith_L49
_ldouble_arith_L48
                LDA     #1
_ldouble_arith_L49
                CMP     #0
                BNE     *+5
                BRL     _ldouble_arith_L47
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
_ldouble_arith_L47
                LDA     39,S   ; fccstk d=0 b=39
                STA     _fcc_q3
                LDA     37,S   ; fccstk d=0 b=37
                STA     _fcc_q2
                LDA     35,S   ; fccstk d=0 b=35
                STA     _fcc_long_hi
                LDA     33,S   ; fccstk d=0 b=33
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     15,S   ; fccstk d=8 b=7
                STA     _fcc_q3
                LDA     13,S   ; fccstk d=8 b=5
                STA     _fcc_q2
                LDA     11,S   ; fccstk d=8 b=3
                STA     _fcc_long_hi
                LDA     9,S   ; fccstk d=8 b=1
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
                BEQ     *+5
                BRL     _ldouble_arith_L69
                LDA     39,S   ; fccstk d=0 b=39
                STA     _fcc_q3
                LDA     37,S   ; fccstk d=0 b=37
                STA     _fcc_q2
                LDA     35,S   ; fccstk d=0 b=35
                STA     _fcc_long_hi
                LDA     33,S   ; fccstk d=0 b=33
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     15,S   ; fccstk d=8 b=7
                STA     _fcc_q3
                LDA     13,S   ; fccstk d=8 b=5
                STA     _fcc_q2
                LDA     11,S   ; fccstk d=8 b=3
                STA     _fcc_long_hi
                LDA     9,S   ; fccstk d=8 b=1
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
                BEQ     *+5
                BRL     _ldouble_arith_L69
                LDA     #0
                BRL     _ldouble_arith_L70
_ldouble_arith_L69
                LDA     #1
_ldouble_arith_L70
                CMP     #0
                BEQ     *+5
                BRL     _ldouble_arith_L67
                LDA     39,S   ; fccstk d=0 b=39
                STA     _fcc_q3
                LDA     37,S   ; fccstk d=0 b=37
                STA     _fcc_q2
                LDA     35,S   ; fccstk d=0 b=35
                STA     _fcc_long_hi
                LDA     33,S   ; fccstk d=0 b=33
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     15,S   ; fccstk d=8 b=7
                STA     _fcc_q3
                LDA     13,S   ; fccstk d=8 b=5
                STA     _fcc_q2
                LDA     11,S   ; fccstk d=8 b=3
                STA     _fcc_long_hi
                LDA     9,S   ; fccstk d=8 b=1
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
                INC
                CMP     #2
                BCC     *+7
                LDA     #0
                BRA     *+5
                LDA     #1
                CMP     #0
                BEQ     *+5
                BRL     _ldouble_arith_L67
                LDA     #0
                BRL     _ldouble_arith_L68
_ldouble_arith_L67
                LDA     #1
_ldouble_arith_L68
                CMP     #0
                BEQ     *+5
                BRL     _ldouble_arith_L65
                LDA     39,S   ; fccstk d=0 b=39
                STA     _fcc_q3
                LDA     37,S   ; fccstk d=0 b=37
                STA     _fcc_q2
                LDA     35,S   ; fccstk d=0 b=35
                STA     _fcc_long_hi
                LDA     33,S   ; fccstk d=0 b=33
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     15,S   ; fccstk d=8 b=7
                STA     _fcc_q3
                LDA     13,S   ; fccstk d=8 b=5
                STA     _fcc_q2
                LDA     11,S   ; fccstk d=8 b=3
                STA     _fcc_long_hi
                LDA     9,S   ; fccstk d=8 b=1
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
                CMP     #2
                BCC     *+7
                LDA     #0
                BRA     *+5
                LDA     #1
                CMP     #0
                BEQ     *+5
                BRL     _ldouble_arith_L65
                LDA     #0
                BRL     _ldouble_arith_L66
_ldouble_arith_L65
                LDA     #1
_ldouble_arith_L66
                CMP     #0
                BEQ     *+5
                BRL     _ldouble_arith_L63
                LDA     39,S   ; fccstk d=0 b=39
                STA     _fcc_q3
                LDA     37,S   ; fccstk d=0 b=37
                STA     _fcc_q2
                LDA     35,S   ; fccstk d=0 b=35
                STA     _fcc_long_hi
                LDA     33,S   ; fccstk d=0 b=33
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     47,S   ; fccstk d=8 b=39
                STA     _fcc_q3
                LDA     45,S   ; fccstk d=8 b=37
                STA     _fcc_q2
                LDA     43,S   ; fccstk d=8 b=35
                STA     _fcc_long_hi
                LDA     41,S   ; fccstk d=8 b=33
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
                CMP     #0
                BEQ     *+5
                BRL     _ldouble_arith_L63
                LDA     #0
                BRL     _ldouble_arith_L64
_ldouble_arith_L63
                LDA     #1
_ldouble_arith_L64
                CMP     #0
                BNE     *+5
                BRL     _ldouble_arith_L62
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
_ldouble_arith_L62
                LDA     39,S   ; fccstk d=0 b=39
                STA     _fcc_q3
                LDA     37,S   ; fccstk d=0 b=37
                STA     _fcc_q2
                LDA     35,S   ; fccstk d=0 b=35
                STA     _fcc_long_hi
                LDA     33,S   ; fccstk d=0 b=33
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     47,S   ; fccstk d=8 b=39
                STA     _fcc_q3
                LDA     45,S   ; fccstk d=8 b=37
                STA     _fcc_q2
                LDA     43,S   ; fccstk d=8 b=35
                STA     _fcc_long_hi
                LDA     41,S   ; fccstk d=8 b=33
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
                BNE     *+7
                LDA     #0
                BRA     *+5
                LDA     #1
                CMP     #0
                BEQ     _ldouble_arith_L72
                LDA     #0
                BRA     _ldouble_arith_L73
_ldouble_arith_L72
                LDA     #1
_ldouble_arith_L73
                CMP     #0
                BNE     *+5
                BRL     _ldouble_arith_L71
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
_ldouble_arith_L71
                LDA     #0
                JSR     _fcc_long_from_int
                FGX2_FARCALL _fcc_dfroml
                STA     25,S   ; fccstk d=0 b=25
                TAY
                LDA     _fcc_long_hi
                STA     27,S   ; fccstk d=0 b=27
                LDA     _fcc_q2
                STA     29,S   ; fccstk d=0 b=29
                LDA     _fcc_q3
                STA     31,S   ; fccstk d=0 b=31
                TYA
                LDA     31,S   ; fccstk d=0 b=31
                STA     _fcc_q3
                LDA     29,S   ; fccstk d=0 b=29
                STA     _fcc_q2
                LDA     27,S   ; fccstk d=0 b=27
                STA     _fcc_long_hi
                LDA     25,S   ; fccstk d=0 b=25
                TAY
                LDA     _fcc_q3
                EOR     #$8000
                STA     _fcc_q3
                TYA
                STA     25,S   ; fccstk d=0 b=25
                TAY
                LDA     _fcc_long_hi
                STA     27,S   ; fccstk d=0 b=27
                LDA     _fcc_q2
                STA     29,S   ; fccstk d=0 b=29
                LDA     _fcc_q3
                STA     31,S   ; fccstk d=0 b=31
                TYA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0000
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$8000
                STA     _fcc_long_hi
                LDA     #$0000
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #24
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _ldouble_arith_is
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                CMP     #0
                BEQ     _ldouble_arith_L75
                LDA     #0
                BRA     _ldouble_arith_L76
_ldouble_arith_L75
                LDA     #1
_ldouble_arith_L76
                CMP     #0
                BNE     *+5
                BRL     _ldouble_arith_L74
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
_ldouble_arith_L74
                LDA     31,S   ; fccstk d=0 b=31
                STA     _fcc_q3
                LDA     29,S   ; fccstk d=0 b=29
                STA     _fcc_q2
                LDA     27,S   ; fccstk d=0 b=27
                STA     _fcc_long_hi
                LDA     25,S   ; fccstk d=0 b=25
                TAY
                LDA     _fcc_q3
                AND     #$7FFF
                ORA     _fcc_q2
                ORA     _fcc_long_hi
                STY     _fcc_tmp_b
                ORA     _fcc_tmp_b
                BEQ     *+5
                BRL     _ldouble_arith_L80
                LDA     39,S   ; fccstk d=0 b=39
                STA     _fcc_q3
                LDA     37,S   ; fccstk d=0 b=37
                STA     _fcc_q2
                LDA     35,S   ; fccstk d=0 b=35
                STA     _fcc_long_hi
                LDA     33,S   ; fccstk d=0 b=33
                TAY
                LDA     _fcc_q3
                AND     #$7FFF
                ORA     _fcc_q2
                ORA     _fcc_long_hi
                STY     _fcc_tmp_b
                ORA     _fcc_tmp_b
                BEQ     _ldouble_arith_L82
                LDA     #0
                BRA     _ldouble_arith_L83
_ldouble_arith_L82
                LDA     #1
_ldouble_arith_L83
                CMP     #0
                BEQ     *+5
                BRL     _ldouble_arith_L80
                LDA     #0
                BRL     _ldouble_arith_L81
_ldouble_arith_L80
                LDA     #1
_ldouble_arith_L81
                CMP     #0
                BEQ     *+5
                BRL     _ldouble_arith_L78
                LDA     7,S   ; fccstk d=0 b=7
                STA     _fcc_q3
                LDA     5,S   ; fccstk d=0 b=5
                STA     _fcc_q2
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_long_hi
                LDA     1,S   ; fccstk d=0 b=1
                TAY
                LDA     _fcc_q3
                AND     #$7FFF
                ORA     _fcc_q2
                ORA     _fcc_long_hi
                STY     _fcc_tmp_b
                ORA     _fcc_tmp_b
                BEQ     _ldouble_arith_L84
                LDA     #0
                BRA     _ldouble_arith_L85
_ldouble_arith_L84
                LDA     #1
_ldouble_arith_L85
                CMP     #0
                BEQ     *+5
                BRL     _ldouble_arith_L78
                LDA     #0
                BRL     _ldouble_arith_L79
_ldouble_arith_L78
                LDA     #1
_ldouble_arith_L79
                CMP     #0
                BNE     *+5
                BRL     _ldouble_arith_L77
                LDA     #16
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_ldouble_arith_L77
                LDA     31,S   ; fccstk d=0 b=31
                STA     _fcc_q3
                LDA     29,S   ; fccstk d=0 b=29
                STA     _fcc_q2
                LDA     27,S   ; fccstk d=0 b=27
                STA     _fcc_long_hi
                LDA     25,S   ; fccstk d=0 b=25
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #0
                JSR     _fcc_long_from_int
                FGX2_FARCALL _fcc_dfroml
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
                CMP     #0
                BEQ     _ldouble_arith_L87
                LDA     #0
                BRA     _ldouble_arith_L88
_ldouble_arith_L87
                LDA     #1
_ldouble_arith_L88
                CMP     #0
                BNE     *+5
                BRL     _ldouble_arith_L86
                LDA     #17
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_ldouble_arith_L86
                LDA     #$FFFB
                JSR     _fcc_long_from_int
                FGX2_FARCALL _fcc_dfroml
                STA     17,S   ; fccstk d=0 b=17
                TAY
                LDA     _fcc_long_hi
                STA     19,S   ; fccstk d=0 b=19
                LDA     _fcc_q2
                STA     21,S   ; fccstk d=0 b=21
                LDA     _fcc_q3
                STA     23,S   ; fccstk d=0 b=23
                TYA
                LDA     23,S   ; fccstk d=0 b=23
                STA     _fcc_q3
                LDA     21,S   ; fccstk d=0 b=21
                STA     _fcc_q2
                LDA     19,S   ; fccstk d=0 b=19
                STA     _fcc_long_hi
                LDA     17,S   ; fccstk d=0 b=17
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #2
                JSR     _fcc_long_from_int
                FGX2_FARCALL _fcc_dfroml
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
                FGX2_FARCALL _fcc_ddiv
                STA     17,S   ; fccstk d=0 b=17
                TAY
                LDA     _fcc_long_hi
                STA     19,S   ; fccstk d=0 b=19
                LDA     _fcc_q2
                STA     21,S   ; fccstk d=0 b=21
                LDA     _fcc_q3
                STA     23,S   ; fccstk d=0 b=23
                TYA
                LDA     23,S   ; fccstk d=0 b=23
                STA     _fcc_q3
                LDA     21,S   ; fccstk d=0 b=21
                STA     _fcc_q2
                LDA     19,S   ; fccstk d=0 b=19
                STA     _fcc_long_hi
                LDA     17,S   ; fccstk d=0 b=17
                FGX2_FARCALL _fcc_dtol
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0002
                JSR     _fcc_long_neg
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_ne
                CMP     #0
                BEQ     *+5
                BRL     _ldouble_arith_L90
                LDA     23,S   ; fccstk d=0 b=23
                STA     _fcc_q3
                LDA     21,S   ; fccstk d=0 b=21
                STA     _fcc_q2
                LDA     19,S   ; fccstk d=0 b=19
                STA     _fcc_long_hi
                LDA     17,S   ; fccstk d=0 b=17
                FGX2_FARCALL _fcc_dtol
                CMP     #$FFFE
                BEQ     *+5
                BRL     _ldouble_arith_L90
                LDA     #0
                BRL     _ldouble_arith_L91
_ldouble_arith_L90
                LDA     #1
_ldouble_arith_L91
                CMP     #0
                BNE     *+5
                BRL     _ldouble_arith_L89
                LDA     #18
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_ldouble_arith_L89
                LDA     #79
                JSR     _fcc_long_from_int
                FGX2_FARCALL _fcc_dfroml
                STA     17,S   ; fccstk d=0 b=17
                TAY
                LDA     _fcc_long_hi
                STA     19,S   ; fccstk d=0 b=19
                LDA     _fcc_q2
                STA     21,S   ; fccstk d=0 b=21
                LDA     _fcc_q3
                STA     23,S   ; fccstk d=0 b=23
                TYA
                LDA     23,S   ; fccstk d=0 b=23
                STA     _fcc_q3
                LDA     21,S   ; fccstk d=0 b=21
                STA     _fcc_q2
                LDA     19,S   ; fccstk d=0 b=19
                STA     _fcc_long_hi
                LDA     17,S   ; fccstk d=0 b=17
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #10
                JSR     _fcc_long_from_int
                FGX2_FARCALL _fcc_dfroml
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
                FGX2_FARCALL _fcc_ddiv
                STA     17,S   ; fccstk d=0 b=17
                TAY
                LDA     _fcc_long_hi
                STA     19,S   ; fccstk d=0 b=19
                LDA     _fcc_q2
                STA     21,S   ; fccstk d=0 b=21
                LDA     _fcc_q3
                STA     23,S   ; fccstk d=0 b=23
                TYA
                LDA     23,S   ; fccstk d=0 b=23
                STA     _fcc_q3
                LDA     21,S   ; fccstk d=0 b=21
                STA     _fcc_q2
                LDA     19,S   ; fccstk d=0 b=19
                STA     _fcc_long_hi
                LDA     17,S   ; fccstk d=0 b=17
                FGX2_FARCALL _fcc_dtol
                STA     55,S   ; fccstk d=0 b=55
                TAX
                TXA
                CMP     #7
                BNE     *+5
                BRL     _ldouble_arith_L92
                LDA     #19
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_ldouble_arith_L92
                LDA     7,S   ; fccstk d=0 b=7
                STA     _fcc_q3
                LDA     5,S   ; fccstk d=0 b=5
                STA     _fcc_q2
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_long_hi
                LDA     1,S   ; fccstk d=0 b=1
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     23,S   ; fccstk d=8 b=15
                STA     _fcc_q3
                LDA     21,S   ; fccstk d=8 b=13
                STA     _fcc_q2
                LDA     19,S   ; fccstk d=8 b=11
                STA     _fcc_long_hi
                LDA     17,S   ; fccstk d=8 b=9
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
                FGX2_FARCALL _fcc_ddiv
                FGX2_FARCALL _fcc_dtof
                STA     57,S   ; fccstk d=0 b=57
                TAY
                LDA     _fcc_long_hi
                STA     59,S   ; fccstk d=0 b=59
                TYA
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #56
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
                LDA     #$3EAA
                STA     _fcc_long_hi
                LDA     #$AAAB
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_ne
                CMP     #0
                BNE     *+5
                BRL     _ldouble_arith_L93
                LDA     #20
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_ldouble_arith_L93
                LDA     #16313
                STA     _fcc_q3
                LDA     #39321
                STA     _fcc_q2
                LDA     #39321
                STA     _fcc_long_hi
                LDA     #39322
                FGX2_FARCALL _fcc_dtof
                STA     57,S   ; fccstk d=0 b=57
                TAY
                LDA     _fcc_long_hi
                STA     59,S   ; fccstk d=0 b=59
                TYA
                LDA     59,S   ; fccstk d=0 b=59
                STA     _fcc_long_hi
                LDA     57,S   ; fccstk d=0 b=57
                FGX2_FARCALL _fcc_dfromf
                STA     17,S   ; fccstk d=0 b=17
                TAY
                LDA     _fcc_long_hi
                STA     19,S   ; fccstk d=0 b=19
                LDA     _fcc_q2
                STA     21,S   ; fccstk d=0 b=21
                LDA     _fcc_q3
                STA     23,S   ; fccstk d=0 b=23
                TYA
                LDA     #$A000
                STA     _fcc_long_hi
                LDA     #$0000
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$3FB9
                STA     _fcc_long_hi
                LDA     #$9999
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #16
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _ldouble_arith_is
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                CMP     #0
                BEQ     _ldouble_arith_L95
                LDA     #0
                BRA     _ldouble_arith_L96
_ldouble_arith_L95
                LDA     #1
_ldouble_arith_L96
                CMP     #0
                BNE     *+5
                BRL     _ldouble_arith_L94
                LDA     #21
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_ldouble_arith_L94
                LDA     #10
                JSR     _fcc_long_from_int
                FGX2_FARCALL _fcc_dfroml
                STA     g
                TAY
                LDA     _fcc_long_hi
                STA     g+2
                LDA     _fcc_q2
                STA     g+4
                LDA     _fcc_q3
                STA     g+6
                TYA
                LDA     g+6
                STA     _fcc_q3
                LDA     g+4
                STA     _fcc_q2
                LDA     g+2
                STA     _fcc_long_hi
                LDA     g
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                STZ     _fcc_long_b_lo
                STZ     _fcc_long_b_hi
                STZ     _fcc_qb2
                LDX     #$3FF0
                STX     _fcc_qb3
                FGX2_FARCALL _fcc_dadd
                STA     g
                TAY
                LDA     _fcc_long_hi
                STA     g+2
                LDA     _fcc_q2
                STA     g+4
                LDA     _fcc_q3
                STA     g+6
                TYA
                PLA
                TAY
                PLA
                PLA
                PLA
                TYA
                LDA     g+6
                STA     _fcc_q3
                LDA     g+4
                STA     _fcc_q2
                LDA     g+2
                STA     _fcc_long_hi
                LDA     g
                STZ     _fcc_long_b_lo
                STZ     _fcc_long_b_hi
                STZ     _fcc_qb2
                LDX     #$3FF0
                STX     _fcc_qb3
                FGX2_FARCALL _fcc_dadd
                STA     g
                TAY
                LDA     _fcc_long_hi
                STA     g+2
                LDA     _fcc_q2
                STA     g+4
                LDA     _fcc_q3
                STA     g+6
                TYA
                LDA     g+6
                STA     _fcc_q3
                LDA     g+4
                STA     _fcc_q2
                LDA     g+2
                STA     _fcc_long_hi
                LDA     g
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                STZ     _fcc_long_b_lo
                STZ     _fcc_long_b_hi
                STZ     _fcc_qb2
                LDX     #$BFF0
                STX     _fcc_qb3
                FGX2_FARCALL _fcc_dadd
                STA     g
                TAY
                LDA     _fcc_long_hi
                STA     g+2
                LDA     _fcc_q2
                STA     g+4
                LDA     _fcc_q3
                STA     g+6
                TYA
                PLA
                TAY
                PLA
                PLA
                PLA
                TYA
                LDA     g+6
                STA     _fcc_q3
                LDA     g+4
                STA     _fcc_q2
                LDA     g+2
                STA     _fcc_long_hi
                LDA     g
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #11
                JSR     _fcc_long_from_int
                FGX2_FARCALL _fcc_dfroml
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
                BNE     *+7
                LDA     #0
                BRA     *+5
                LDA     #1
                CMP     #0
                BNE     *+5
                BRL     _ldouble_arith_L97
                LDA     #22
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_ldouble_arith_L97
                LDA     #1
                JSR     _fcc_long_from_int
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #garr+8
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _fcc_dfroml
                TAY
                PLA
                STA     _fcc_fpr0
                PLA
                STA     _fcc_fpr0+2
                TYA
                LDY     #0
                STA     [_fcc_fpr0],Y
                TAX
                LDA     _fcc_long_hi
                LDY     #2
                STA     [_fcc_fpr0],Y
                LDA     _fcc_q2
                LDY     #4
                STA     [_fcc_fpr0],Y
                LDA     _fcc_q3
                LDY     #6
                STA     [_fcc_fpr0],Y
                TXA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #garr+8
                STA     _fcc_fpr0
                PLA
                LDA     _fcc_fpr0+2
                STA     43,S   ; fccstk d=0 b=43
                LDA     _fcc_fpr0
                STA     41,S   ; fccstk d=0 b=41
                LDA     43,S   ; fccstk d=0 b=43
                STA     _fcc_fpr0+2
                LDA     41,S   ; fccstk d=0 b=41
                STA     _fcc_fpr0
                LDY     #6
                LDA     [_fcc_fpr0],Y
                STA     _fcc_q3
                LDY     #4
                LDA     [_fcc_fpr0],Y
                STA     _fcc_q2
                LDY     #2
                LDA     [_fcc_fpr0],Y
                STA     _fcc_long_hi
                LDY     #0
                LDA     [_fcc_fpr0],Y
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                STZ     _fcc_long_b_lo
                STZ     _fcc_long_b_hi
                STZ     _fcc_qb2
                LDX     #$3FF0
                STX     _fcc_qb3
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _fcc_dadd
                TAY
                PLA
                STA     _fcc_fpr0
                PLA
                STA     _fcc_fpr0+2
                TYA
                LDY     #0
                STA     [_fcc_fpr0],Y
                TAX
                LDA     _fcc_long_hi
                LDY     #2
                STA     [_fcc_fpr0],Y
                LDA     _fcc_q2
                LDY     #4
                STA     [_fcc_fpr0],Y
                LDA     _fcc_q3
                LDY     #6
                STA     [_fcc_fpr0],Y
                TXA
                PLA
                TAY
                PLA
                PLA
                PLA
                TYA
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #40
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                PHA
                SEP     #$20
                MX      %10
                LDY     #2
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                LDY     #6
                LDA     [_fcc_fpr0],Y
                STA     _fcc_q3
                LDY     #4
                LDA     [_fcc_fpr0],Y
                STA     _fcc_q2
                LDY     #2
                LDA     [_fcc_fpr0],Y
                STA     _fcc_long_hi
                LDY     #0
                LDA     [_fcc_fpr0],Y
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
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _fcc_dadd
                TAY
                PLA
                STA     _fcc_fpr0
                PLA
                STA     _fcc_fpr0+2
                TYA
                LDY     #0
                STA     [_fcc_fpr0],Y
                TAX
                LDA     _fcc_long_hi
                LDY     #2
                STA     [_fcc_fpr0],Y
                LDA     _fcc_q2
                LDY     #4
                STA     [_fcc_fpr0],Y
                LDA     _fcc_q3
                LDY     #6
                STA     [_fcc_fpr0],Y
                TXA
                LDA     garr+14
                STA     _fcc_q3
                LDA     garr+12
                STA     _fcc_q2
                LDA     garr+10
                STA     _fcc_long_hi
                LDA     garr+8
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
                BNE     *+7
                LDA     #0
                BRA     *+5
                LDA     #1
                CMP     #0
                BNE     *+5
                BRL     _ldouble_arith_L98
                LDA     #23
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_ldouble_arith_L98
                LDA     #4
                JSR     _fcc_long_from_int
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #gs+2
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _fcc_dfroml
                TAY
                PLA
                STA     _fcc_fpr0
                PLA
                STA     _fcc_fpr0+2
                TYA
                LDY     #0
                STA     [_fcc_fpr0],Y
                TAX
                LDA     _fcc_long_hi
                LDY     #2
                STA     [_fcc_fpr0],Y
                LDA     _fcc_q2
                LDY     #4
                STA     [_fcc_fpr0],Y
                LDA     _fcc_q3
                LDY     #6
                STA     [_fcc_fpr0],Y
                TXA
                LDA     gs+8
                STA     _fcc_q3
                LDA     gs+6
                STA     _fcc_q2
                LDA     gs+4
                STA     _fcc_long_hi
                LDA     gs+2
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     23,S   ; fccstk d=8 b=15
                STA     _fcc_q3
                LDA     21,S   ; fccstk d=8 b=13
                STA     _fcc_q2
                LDA     19,S   ; fccstk d=8 b=11
                STA     _fcc_long_hi
                LDA     17,S   ; fccstk d=8 b=9
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
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #gs+2
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _fcc_dmul
                TAY
                PLA
                STA     _fcc_fpr0
                PLA
                STA     _fcc_fpr0+2
                TYA
                LDY     #0
                STA     [_fcc_fpr0],Y
                TAX
                LDA     _fcc_long_hi
                LDY     #2
                STA     [_fcc_fpr0],Y
                LDA     _fcc_q2
                LDY     #4
                STA     [_fcc_fpr0],Y
                LDA     _fcc_q3
                LDY     #6
                STA     [_fcc_fpr0],Y
                TXA
                LDA     gs+8
                STA     _fcc_q3
                LDA     gs+6
                STA     _fcc_q2
                LDA     gs+4
                STA     _fcc_long_hi
                LDA     gs+2
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #1
                JSR     _fcc_long_from_int
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #gs+2
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _fcc_dfroml
                TAY
                PLA
                STA     _fcc_fpr0
                PLA
                STA     _fcc_fpr0+2
                TYA
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
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _fcc_dsub
                TAY
                PLA
                STA     _fcc_fpr0
                PLA
                STA     _fcc_fpr0+2
                TYA
                LDY     #0
                STA     [_fcc_fpr0],Y
                TAX
                LDA     _fcc_long_hi
                LDY     #2
                STA     [_fcc_fpr0],Y
                LDA     _fcc_q2
                LDY     #4
                STA     [_fcc_fpr0],Y
                LDA     _fcc_q3
                LDY     #6
                STA     [_fcc_fpr0],Y
                TXA
                LDA     gs+8
                STA     _fcc_q3
                LDA     gs+6
                STA     _fcc_q2
                LDA     gs+4
                STA     _fcc_long_hi
                LDA     gs+2
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #11
                JSR     _fcc_long_from_int
                FGX2_FARCALL _fcc_dfroml
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
                BNE     *+7
                LDA     #0
                BRA     *+5
                LDA     #1
                CMP     #0
                BNE     *+5
                BRL     _ldouble_arith_L99
                LDA     #24
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_ldouble_arith_L99
                LDA     #7
                STA     55,S   ; fccstk d=0 b=55
                LDA     55,S   ; fccstk d=0 b=55
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
                LDA     15,S   ; fccstk d=8 b=7
                STA     _fcc_q3
                LDA     13,S   ; fccstk d=8 b=5
                STA     _fcc_q2
                LDA     11,S   ; fccstk d=8 b=3
                STA     _fcc_long_hi
                LDA     9,S   ; fccstk d=8 b=1
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     31,S   ; fccstk d=16 b=15
                STA     _fcc_q3
                LDA     29,S   ; fccstk d=16 b=13
                STA     _fcc_q2
                LDA     27,S   ; fccstk d=16 b=11
                STA     _fcc_long_hi
                LDA     25,S   ; fccstk d=16 b=9
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
                FGX2_FARCALL _fcc_ddiv
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
                STA     55,S   ; fccstk d=0 b=55
                TAX
                TXA
                CMP     #7
                BNE     *+5
                BRL     _ldouble_arith_L100
                LDA     #25
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_ldouble_arith_L100
                LDA     7,S   ; fccstk d=0 b=7
                STA     _fcc_q3
                LDA     5,S   ; fccstk d=0 b=5
                STA     _fcc_q2
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_long_hi
                LDA     1,S   ; fccstk d=0 b=1
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #2
                JSR     _fcc_long_from_int
                FGX2_FARCALL _fcc_dfroml
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
                STA     1,S   ; fccstk d=0 b=1
                TAY
                LDA     _fcc_long_hi
                STA     3,S   ; fccstk d=0 b=3
                LDA     _fcc_q2
                STA     5,S   ; fccstk d=0 b=5
                LDA     _fcc_q3
                STA     7,S   ; fccstk d=0 b=7
                TYA
                LDA     7,S   ; fccstk d=0 b=7
                STA     _fcc_q3
                LDA     5,S   ; fccstk d=0 b=5
                STA     _fcc_q2
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_long_hi
                LDA     1,S   ; fccstk d=0 b=1
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #3
                JSR     _fcc_long_from_int
                FGX2_FARCALL _fcc_dfroml
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
                BNE     *+7
                LDA     #0
                BRA     *+5
                LDA     #1
                CMP     #0
                BNE     *+5
                BRL     _ldouble_arith_L101
                LDA     #26
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_ldouble_arith_L101
                LDA     45,S   ; fccstk d=0 b=45
                TAX
                TXA
                LDX     #1
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BCC     *+5
                BRL     _ldouble_arith_L102
                LDA     7,S   ; fccstk d=0 b=7
                STA     _fcc_q3
                LDA     5,S   ; fccstk d=0 b=5
                STA     _fcc_q2
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_long_hi
                LDA     1,S   ; fccstk d=0 b=1
                BRL     _ldouble_arith_L103
_ldouble_arith_L102
                LDA     #1
                JSR     _fcc_long_from_int
                FGX2_FARCALL _fcc_dfroml
_ldouble_arith_L103
                STA     17,S   ; fccstk d=0 b=17
                TAY
                LDA     _fcc_long_hi
                STA     19,S   ; fccstk d=0 b=19
                LDA     _fcc_q2
                STA     21,S   ; fccstk d=0 b=21
                LDA     _fcc_q3
                STA     23,S   ; fccstk d=0 b=23
                TYA
                LDA     23,S   ; fccstk d=0 b=23
                STA     _fcc_q3
                LDA     21,S   ; fccstk d=0 b=21
                STA     _fcc_q2
                LDA     19,S   ; fccstk d=0 b=19
                STA     _fcc_long_hi
                LDA     17,S   ; fccstk d=0 b=17
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #3
                JSR     _fcc_long_from_int
                FGX2_FARCALL _fcc_dfroml
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
                BNE     *+7
                LDA     #0
                BRA     *+5
                LDA     #1
                CMP     #0
                BNE     *+5
                BRL     _ldouble_arith_L104
                LDA     #27
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_ldouble_arith_L104
                LDA     45,S   ; fccstk d=0 b=45
                TAX
                TXA
                CMP     #1
                BCC     *+5
                BRL     _ldouble_arith_L105
                LDA     7,S   ; fccstk d=0 b=7
                STA     _fcc_q3
                LDA     5,S   ; fccstk d=0 b=5
                STA     _fcc_q2
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_long_hi
                LDA     1,S   ; fccstk d=0 b=1
                BRL     _ldouble_arith_L106
_ldouble_arith_L105
                LDA     #1
                JSR     _fcc_long_from_int
                FGX2_FARCALL _fcc_dfroml
_ldouble_arith_L106
                STA     17,S   ; fccstk d=0 b=17
                TAY
                LDA     _fcc_long_hi
                STA     19,S   ; fccstk d=0 b=19
                LDA     _fcc_q2
                STA     21,S   ; fccstk d=0 b=21
                LDA     _fcc_q3
                STA     23,S   ; fccstk d=0 b=23
                TYA
                LDA     23,S   ; fccstk d=0 b=23
                STA     _fcc_q3
                LDA     21,S   ; fccstk d=0 b=21
                STA     _fcc_q2
                LDA     19,S   ; fccstk d=0 b=19
                STA     _fcc_long_hi
                LDA     17,S   ; fccstk d=0 b=17
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #1
                JSR     _fcc_long_from_int
                FGX2_FARCALL _fcc_dfroml
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
                BNE     *+7
                LDA     #0
                BRA     *+5
                LDA     #1
                CMP     #0
                BNE     *+5
                BRL     _ldouble_arith_L107
                LDA     #28
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_ldouble_arith_L107
                LDA     7,S   ; fccstk d=0 b=7
                STA     _fcc_q3
                LDA     5,S   ; fccstk d=0 b=5
                STA     _fcc_q2
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_long_hi
                LDA     1,S   ; fccstk d=0 b=1
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #2
                JSR     _fcc_long_from_int
                FGX2_FARCALL _fcc_dfroml
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
                FGX2_FARCALL _fcc_ddiv
                FGX2_FARCALL _fcc_dtol
                PHA
                FGX2_FARCALL _ldouble_arith_trunc3
                TAY
                PLA
                TYA
                TAX
                TXA
                CMP     #1
                BNE     *+5
                BRL     _ldouble_arith_L108
                LDA     #29
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_ldouble_arith_L108
                LDA     #9
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
                FGX2_FARCALL _ldouble_arith_half
                TAY
                TSC
                CLC
                ADC     #8
                TCS
                TYA
                STA     17,S   ; fccstk d=0 b=17
                TAY
                LDA     _fcc_long_hi
                STA     19,S   ; fccstk d=0 b=19
                LDA     _fcc_q2
                STA     21,S   ; fccstk d=0 b=21
                LDA     _fcc_q3
                STA     23,S   ; fccstk d=0 b=23
                TYA
                LDA     23,S   ; fccstk d=0 b=23
                STA     _fcc_q3
                LDA     21,S   ; fccstk d=0 b=21
                STA     _fcc_q2
                LDA     19,S   ; fccstk d=0 b=19
                STA     _fcc_long_hi
                LDA     17,S   ; fccstk d=0 b=17
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #16402
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
                BNE     *+7
                LDA     #0
                BRA     *+5
                LDA     #1
                CMP     #0
                BNE     *+5
                BRL     _ldouble_arith_L109
                LDA     #30
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_ldouble_arith_L109
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
main_FRAMESIZE   EQU     60
main_STKGUARD    EQU     0
                FGX2_RELOC_COUNT 115
