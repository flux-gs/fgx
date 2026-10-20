                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from ldouble_const.c
;---------------------------------------

                MX      %00
                FGX2_EXPORT _ldouble_const_is
_ldouble_const_is            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #_ldouble_const_is_FRAMESIZE
                DO      _ldouble_const_is_STKGUARD
                BCC     _ldouble_const_is_stkovf
                CMP     _fcc_stkfloor
                BCS     _ldouble_const_is_stkok
_ldouble_const_is_stkovf       JMP     _fcc_stkoflow
                FIN
_ldouble_const_is_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      8+_ldouble_const_is_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_ldouble_const_is_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_ldouble_const_is_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+_ldouble_const_is_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_ldouble_const_is_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_ldouble_const_is_FRAMESIZE,S   ; fccstk d=0 b=6 fs
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
                DO      20+_ldouble_const_is_FRAMESIZE/256
                TSC
                CLC
                ADC     #20+_ldouble_const_is_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     20+_ldouble_const_is_FRAMESIZE,S   ; fccstk d=4 b=16 fs
                FIN
                STA     _fcc_long_hi
                DO      18+_ldouble_const_is_FRAMESIZE/256
                TSC
                CLC
                ADC     #18+_ldouble_const_is_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     18+_ldouble_const_is_FRAMESIZE,S   ; fccstk d=4 b=14 fs
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
                BRL     _ldouble_const_L0
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
                DO      16+_ldouble_const_is_FRAMESIZE/256
                TSC
                CLC
                ADC     #16+_ldouble_const_is_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     16+_ldouble_const_is_FRAMESIZE,S   ; fccstk d=4 b=12 fs
                FIN
                STA     _fcc_long_hi
                DO      14+_ldouble_const_is_FRAMESIZE/256
                TSC
                CLC
                ADC     #14+_ldouble_const_is_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     14+_ldouble_const_is_FRAMESIZE,S   ; fccstk d=4 b=10 fs
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
                BRL     _ldouble_const_L0
                LDA     #1
                BRL     _ldouble_const_L1
_ldouble_const_L0
                LDA     #0
_ldouble_const_L1
                TAY
                TSC
                CLC
                ADC     #_ldouble_const_is_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_ldouble_const_is_FRAMESIZE   EQU     4
_ldouble_const_is_STKGUARD    EQU     0
                FGX2_EXPORT _ldouble_const_local_static
_ldouble_const_local_static            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #_ldouble_const_local_static_FRAMESIZE
                DO      _ldouble_const_local_static_STKGUARD
                BCC     _ldouble_const_local_static_stkovf
                CMP     _fcc_stkfloor
                BCS     _ldouble_const_local_static_stkok
_ldouble_const_local_static_stkovf       JMP     _fcc_stkoflow
                FIN
_ldouble_const_local_static_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                LDA     _ldouble_const_local_static_sl_sl+6
                STA     _fcc_q3
                LDA     _ldouble_const_local_static_sl_sl+4
                STA     _fcc_q2
                LDA     _ldouble_const_local_static_sl_sl+2
                STA     _fcc_long_hi
                LDA     _ldouble_const_local_static_sl_sl
                TAY
                TSC
                CLC
                ADC     #_ldouble_const_local_static_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_ldouble_const_local_static_FRAMESIZE   EQU     0
_ldouble_const_local_static_STKGUARD    EQU     0
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
                LDA     #16313
                STA     _fcc_q3
                LDA     #39321
                STA     _fcc_q2
                LDA     #39321
                STA     _fcc_long_hi
                LDA     #39322
                STA     1,S   ; fccstk d=0 b=1
                TAY
                LDA     _fcc_long_hi
                STA     3,S   ; fccstk d=0 b=3
                LDA     _fcc_q2
                STA     5,S   ; fccstk d=0 b=5
                LDA     _fcc_q3
                STA     7,S   ; fccstk d=0 b=7
                TYA
                LDA     #$9999
                STA     _fcc_long_hi
                LDA     #$999A
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
                ADC     #0
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _ldouble_const_is
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                CMP     #0
                BEQ     _ldouble_const_L3
                LDA     #0
                BRA     _ldouble_const_L4
_ldouble_const_L3
                LDA     #1
_ldouble_const_L4
                CMP     #0
                BNE     *+5
                BRL     _ldouble_const_L2
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
_ldouble_const_L2
                LDA     #17215
                STA     _fcc_q3
                LDA     #65535
                STA     _fcc_q2
                LDA     #65535
                STA     _fcc_long_hi
                LDA     #65535
                STA     1,S   ; fccstk d=0 b=1
                TAY
                LDA     _fcc_long_hi
                STA     3,S   ; fccstk d=0 b=3
                LDA     _fcc_q2
                STA     5,S   ; fccstk d=0 b=5
                LDA     _fcc_q3
                STA     7,S   ; fccstk d=0 b=7
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
                ADC     #0
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _ldouble_const_is
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                CMP     #0
                BEQ     _ldouble_const_L6
                LDA     #0
                BRA     _ldouble_const_L7
_ldouble_const_L6
                LDA     #1
_ldouble_const_L7
                CMP     #0
                BNE     *+5
                BRL     _ldouble_const_L5
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
_ldouble_const_L5
                LDA     #16368
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
                FGX2_FARCALL _fcc_ddiv
                STA     1,S   ; fccstk d=0 b=1
                TAY
                LDA     _fcc_long_hi
                STA     3,S   ; fccstk d=0 b=3
                LDA     _fcc_q2
                STA     5,S   ; fccstk d=0 b=5
                LDA     _fcc_q3
                STA     7,S   ; fccstk d=0 b=7
                TYA
                LDA     #16341
                STA     _fcc_q3
                LDA     #21845
                STA     _fcc_q2
                LDA     #21845
                STA     _fcc_long_hi
                LDA     #21845
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
                FGX2_FARCALL _fcc_dcmp
                BNE     *+7
                LDA     #0
                BRA     *+5
                LDA     #1
                CMP     #0
                BNE     *+5
                BRL     _ldouble_const_L8
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
_ldouble_const_L8
                LDA     #16376
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
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0000
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$4004
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
                ADC     #0
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _ldouble_const_is
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                CMP     #0
                BEQ     _ldouble_const_L10
                LDA     #0
                BRA     _ldouble_const_L11
_ldouble_const_L10
                LDA     #1
_ldouble_const_L11
                CMP     #0
                BNE     *+5
                BRL     _ldouble_const_L9
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
_ldouble_const_L9
                LDA     #16313
                STA     _fcc_q3
                LDA     #39321
                STA     _fcc_q2
                LDA     #39321
                STA     _fcc_long_hi
                LDA     #39322
                TAY
                LDA     _fcc_q3
                EOR     #$8000
                STA     _fcc_q3
                TYA
                STA     1,S   ; fccstk d=0 b=1
                TAY
                LDA     _fcc_long_hi
                STA     3,S   ; fccstk d=0 b=3
                LDA     _fcc_q2
                STA     5,S   ; fccstk d=0 b=5
                LDA     _fcc_q3
                STA     7,S   ; fccstk d=0 b=7
                TYA
                LDA     #$9999
                STA     _fcc_long_hi
                LDA     #$999A
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$BFB9
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
                ADC     #0
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _ldouble_const_is
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                CMP     #0
                BEQ     _ldouble_const_L13
                LDA     #0
                BRA     _ldouble_const_L14
_ldouble_const_L13
                LDA     #1
_ldouble_const_L14
                CMP     #0
                BNE     *+5
                BRL     _ldouble_const_L12
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
_ldouble_const_L12
                LDA     #16313
                STA     _fcc_q3
                LDA     #39321
                STA     _fcc_q2
                LDA     #39321
                STA     _fcc_long_hi
                LDA     #39322
                STA     1,S   ; fccstk d=0 b=1
                TAY
                LDA     _fcc_long_hi
                STA     3,S   ; fccstk d=0 b=3
                LDA     _fcc_q2
                STA     5,S   ; fccstk d=0 b=5
                LDA     _fcc_q3
                STA     7,S   ; fccstk d=0 b=7
                TYA
                LDA     #$9999
                STA     _fcc_long_hi
                LDA     #$999A
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
                ADC     #0
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _ldouble_const_is
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                CMP     #0
                BEQ     _ldouble_const_L16
                LDA     #0
                BRA     _ldouble_const_L17
_ldouble_const_L16
                LDA     #1
_ldouble_const_L17
                CMP     #0
                BNE     *+5
                BRL     _ldouble_const_L15
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
_ldouble_const_L15
                LDA     #$3DCC
                STA     _fcc_long_hi
                LDA     #$CCCD
                FGX2_FARCALL _fcc_dfromf
                STA     1,S   ; fccstk d=0 b=1
                TAY
                LDA     _fcc_long_hi
                STA     3,S   ; fccstk d=0 b=3
                LDA     _fcc_q2
                STA     5,S   ; fccstk d=0 b=5
                LDA     _fcc_q3
                STA     7,S   ; fccstk d=0 b=7
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
                ADC     #0
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _ldouble_const_is
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                CMP     #0
                BEQ     _ldouble_const_L19
                LDA     #0
                BRA     _ldouble_const_L20
_ldouble_const_L19
                LDA     #1
_ldouble_const_L20
                CMP     #0
                BNE     *+5
                BRL     _ldouble_const_L18
                LDA     #31
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_ldouble_const_L18
                LDA     #16352
                STA     _fcc_q3
                LDA     #0
                STA     _fcc_q2
                LDA     #0
                STA     _fcc_long_hi
                LDA     #0
                FGX2_FARCALL _fcc_dtof
                STA     17,S   ; fccstk d=0 b=17
                TAY
                LDA     _fcc_long_hi
                STA     19,S   ; fccstk d=0 b=19
                TYA
                LDA     19,S   ; fccstk d=0 b=19
                STA     _fcc_long_hi
                LDA     17,S   ; fccstk d=0 b=17
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$3F00
                STA     _fcc_long_hi
                LDA     #$0000
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_fne
                CMP     #0
                BNE     *+5
                BRL     _ldouble_const_L21
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
_ldouble_const_L21
                LDA     #8
                TAX
                LDA     #8
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BEQ     *+5
                BRL     _ldouble_const_L23
                LDA     #8
                PHA
                LDA     #8
                STA     _fcc_tmp_b
                PLA
                CMP     _fcc_tmp_b
                BEQ     *+5
                BRL     _ldouble_const_L23
                LDA     #0
                BRL     _ldouble_const_L24
_ldouble_const_L23
                LDA     #1
_ldouble_const_L24
                CMP     #0
                BNE     *+5
                BRL     _ldouble_const_L22
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
_ldouble_const_L22
                LDA     #4
                TAX
                LDA     #4
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BNE     *+5
                BRL     _ldouble_const_L25
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
_ldouble_const_L25
                LDA     #$9999
                STA     _fcc_long_hi
                LDA     #$999A
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
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #g1
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _ldouble_const_is
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                CMP     #0
                BEQ     _ldouble_const_L27
                LDA     #0
                BRA     _ldouble_const_L28
_ldouble_const_L27
                LDA     #1
_ldouble_const_L28
                CMP     #0
                BNE     *+5
                BRL     _ldouble_const_L26
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
_ldouble_const_L26
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0000
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$C004
                STA     _fcc_long_hi
                LDA     #$0000
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
                LDA     #g2
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _ldouble_const_is
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                CMP     #0
                BEQ     _ldouble_const_L30
                LDA     #0
                BRA     _ldouble_const_L31
_ldouble_const_L30
                LDA     #1
_ldouble_const_L31
                CMP     #0
                BNE     *+5
                BRL     _ldouble_const_L29
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
_ldouble_const_L29
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0000
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$4008
                STA     _fcc_long_hi
                LDA     #$0000
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
                LDA     #g3
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _ldouble_const_is
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                CMP     #0
                BEQ     _ldouble_const_L33
                LDA     #0
                BRA     _ldouble_const_L34
_ldouble_const_L33
                LDA     #1
_ldouble_const_L34
                CMP     #0
                BNE     *+5
                BRL     _ldouble_const_L32
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
_ldouble_const_L32
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0000
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$40E3
                STA     _fcc_long_hi
                LDA     #$8800
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
                LDA     #g4
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _ldouble_const_is
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                CMP     #0
                BEQ     _ldouble_const_L36
                LDA     #0
                BRA     _ldouble_const_L37
_ldouble_const_L36
                LDA     #1
_ldouble_const_L37
                CMP     #0
                BNE     *+5
                BRL     _ldouble_const_L35
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
_ldouble_const_L35
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0000
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$BFF0
                STA     _fcc_long_hi
                LDA     #$0000
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
                LDA     #g5
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _ldouble_const_is
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                CMP     #0
                BEQ     _ldouble_const_L39
                LDA     #0
                BRA     _ldouble_const_L40
_ldouble_const_L39
                LDA     #1
_ldouble_const_L40
                CMP     #0
                BNE     *+5
                BRL     _ldouble_const_L38
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
_ldouble_const_L38
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0000
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$41F0
                STA     _fcc_long_hi
                LDA     #$0000
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
                LDA     #g6
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _ldouble_const_is
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                CMP     #0
                BEQ     _ldouble_const_L42
                LDA     #0
                BRA     _ldouble_const_L43
_ldouble_const_L42
                LDA     #1
_ldouble_const_L43
                CMP     #0
                BNE     *+5
                BRL     _ldouble_const_L41
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
_ldouble_const_L41
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0000
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$40EF
                STA     _fcc_long_hi
                LDA     #$FFE0
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
                LDA     #g7
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _ldouble_const_is
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                CMP     #0
                BEQ     _ldouble_const_L45
                LDA     #0
                BRA     _ldouble_const_L46
_ldouble_const_L45
                LDA     #1
_ldouble_const_L46
                CMP     #0
                BNE     *+5
                BRL     _ldouble_const_L44
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
_ldouble_const_L44
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0000
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$4050
                STA     _fcc_long_hi
                LDA     #$4000
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
                LDA     #g8
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _ldouble_const_is
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                CMP     #0
                BEQ     _ldouble_const_L48
                LDA     #0
                BRA     _ldouble_const_L49
_ldouble_const_L48
                LDA     #1
_ldouble_const_L49
                CMP     #0
                BNE     *+5
                BRL     _ldouble_const_L47
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
_ldouble_const_L47
                LDA     #$8800
                STA     _fcc_long_hi
                LDA     #$759C
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$7E37
                STA     _fcc_long_hi
                LDA     #$E43C
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
                LDA     #g9
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _ldouble_const_is
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                CMP     #0
                BEQ     _ldouble_const_L51
                LDA     #0
                BRA     _ldouble_const_L52
_ldouble_const_L51
                LDA     #1
_ldouble_const_L52
                CMP     #0
                BNE     *+5
                BRL     _ldouble_const_L50
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
_ldouble_const_L50
                LDA     #16313
                STA     _fcc_q3
                LDA     #39321
                STA     _fcc_q2
                LDA     #39321
                STA     _fcc_long_hi
                LDA     #39322
                STA     1,S   ; fccstk d=0 b=1
                TAY
                LDA     _fcc_long_hi
                STA     3,S   ; fccstk d=0 b=3
                LDA     _fcc_q2
                STA     5,S   ; fccstk d=0 b=5
                LDA     _fcc_q3
                STA     7,S   ; fccstk d=0 b=7
                TYA
                LDA     gw+6
                STA     _fcc_q3
                LDA     gw+4
                STA     _fcc_q2
                LDA     gw+2
                STA     _fcc_long_hi
                LDA     gw
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
                BNE     *+7
                LDA     #0
                BRA     *+5
                LDA     #1
                CMP     #0
                BNE     *+5
                BRL     _ldouble_const_L53
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
_ldouble_const_L53
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0000
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$3FF0
                STA     _fcc_long_hi
                LDA     #$0000
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
                LDA     #ga
                STA     _fcc_fpr0
                LDA     #0
                ASL
                ASL
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _ldouble_const_is
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                CMP     #0
                BEQ     _ldouble_const_L55
                LDA     #0
                BRA     _ldouble_const_L56
_ldouble_const_L55
                LDA     #1
_ldouble_const_L56
                CMP     #0
                BNE     *+5
                BRL     _ldouble_const_L54
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
_ldouble_const_L54
                LDA     #$9999
                STA     _fcc_long_hi
                LDA     #$999A
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$BFB9
                STA     _fcc_long_hi
                LDA     #$9999
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
                LDA     #ga
                STA     _fcc_fpr0
                LDA     #1
                ASL
                ASL
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _ldouble_const_is
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                CMP     #0
                BEQ     _ldouble_const_L58
                LDA     #0
                BRA     _ldouble_const_L59
_ldouble_const_L58
                LDA     #1
_ldouble_const_L59
                CMP     #0
                BNE     *+5
                BRL     _ldouble_const_L57
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
_ldouble_const_L57
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0000
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$401C
                STA     _fcc_long_hi
                LDA     #$0000
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
                LDA     #ga
                STA     _fcc_fpr0
                LDA     #2
                ASL
                ASL
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _ldouble_const_is
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                CMP     #0
                BEQ     _ldouble_const_L61
                LDA     #0
                BRA     _ldouble_const_L62
_ldouble_const_L61
                LDA     #1
_ldouble_const_L62
                CMP     #0
                BNE     *+5
                BRL     _ldouble_const_L60
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
_ldouble_const_L60
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0000
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$4000
                STA     _fcc_long_hi
                LDA     #$0000
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
                LDA     #gm
                STA     _fcc_fpr0
                LDA     #0
                ASL
                ASL
                ASL
                ASL
                PHA
                LDA     #1
                ASL
                ASL
                ASL
                CLC
                ADC     1,S
                STA     1,S
                PLA
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _ldouble_const_is
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                CMP     #0
                BEQ     _ldouble_const_L64
                LDA     #0
                BRA     _ldouble_const_L65
_ldouble_const_L64
                LDA     #1
_ldouble_const_L65
                CMP     #0
                BNE     *+5
                BRL     _ldouble_const_L63
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
_ldouble_const_L63
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0000
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$4010
                STA     _fcc_long_hi
                LDA     #$0000
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
                LDA     #gm
                STA     _fcc_fpr0
                LDA     #1
                ASL
                ASL
                ASL
                ASL
                PHA
                LDA     #1
                ASL
                ASL
                ASL
                CLC
                ADC     1,S
                STA     1,S
                PLA
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _ldouble_const_is
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                CMP     #0
                BEQ     _ldouble_const_L67
                LDA     #0
                BRA     _ldouble_const_L68
_ldouble_const_L67
                LDA     #1
_ldouble_const_L68
                CMP     #0
                BNE     *+5
                BRL     _ldouble_const_L66
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
_ldouble_const_L66
                LDA     #24
                TAX
                LDA     #24
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BEQ     *+5
                BRL     _ldouble_const_L70
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0000
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$4008
                STA     _fcc_long_hi
                LDA     #$0000
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
                LDA     #gu
                STA     _fcc_fpr0
                LDA     #2
                ASL
                ASL
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _ldouble_const_is
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                CMP     #0
                BEQ     _ldouble_const_L72
                LDA     #0
                BRA     _ldouble_const_L73
_ldouble_const_L72
                LDA     #1
_ldouble_const_L73
                CMP     #0
                BEQ     *+5
                BRL     _ldouble_const_L70
                LDA     #0
                BRL     _ldouble_const_L71
_ldouble_const_L70
                LDA     #1
_ldouble_const_L71
                CMP     #0
                BNE     *+5
                BRL     _ldouble_const_L69
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
_ldouble_const_L69
                LDA     gs+0
                TAX
                LDA     #5
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BEQ     *+5
                BRL     _ldouble_const_L75
                LDA     #$9999
                STA     _fcc_long_hi
                LDA     #$999A
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$BFB9
                STA     _fcc_long_hi
                LDA     #$9999
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
                LDA     #gs
                INC
                INC
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _ldouble_const_is
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                CMP     #0
                BEQ     _ldouble_const_L77
                LDA     #0
                BRA     _ldouble_const_L78
_ldouble_const_L77
                LDA     #1
_ldouble_const_L78
                CMP     #0
                BEQ     *+5
                BRL     _ldouble_const_L75
                LDA     #0
                BRL     _ldouble_const_L76
_ldouble_const_L75
                LDA     #1
_ldouble_const_L76
                CMP     #0
                BNE     *+5
                BRL     _ldouble_const_L74
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
_ldouble_const_L74
                FGX2_FARCALL _ldouble_const_local_static
                STA     1,S   ; fccstk d=0 b=1
                TAY
                LDA     _fcc_long_hi
                STA     3,S   ; fccstk d=0 b=3
                LDA     _fcc_q2
                STA     5,S   ; fccstk d=0 b=5
                LDA     _fcc_q3
                STA     7,S   ; fccstk d=0 b=7
                TYA
                LDA     #$9999
                STA     _fcc_long_hi
                LDA     #$999A
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$BFB9
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
                ADC     #0
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _ldouble_const_is
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                CMP     #0
                BEQ     _ldouble_const_L80
                LDA     #0
                BRA     _ldouble_const_L81
_ldouble_const_L80
                LDA     #1
_ldouble_const_L81
                CMP     #0
                BNE     *+5
                BRL     _ldouble_const_L79
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
_ldouble_const_L79
                LDA     gi
                TAX
                LDA     #2
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BNE     *+5
                BRL     _ldouble_const_L82
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
_ldouble_const_L82
                LDA     gf+2
                STA     _fcc_long_hi
                LDA     gf
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$3F00
                STA     _fcc_long_hi
                LDA     #$0000
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_fne
                CMP     #0
                BNE     *+5
                BRL     _ldouble_const_L83
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
_ldouble_const_L83
                LDA     #$B505
                STA     _fcc_long_hi
                LDA     #$6E17
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$4493
                STA     _fcc_long_hi
                LDA     #$B8B5
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
                LDA     #g5p32
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _ldouble_const_is
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                CMP     #0
                BEQ     _ldouble_const_L85
                LDA     #0
                BRA     _ldouble_const_L86
_ldouble_const_L85
                LDA     #1
_ldouble_const_L86
                CMP     #0
                BNE     *+5
                BRL     _ldouble_const_L84
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
_ldouble_const_L84
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
main_FRAMESIZE   EQU     20
main_STKGUARD    EQU     0
                FGX2_RELOC_COUNT 37
