                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from float_promote.c
;---------------------------------------

                MX      %00
                FGX2_EXPORT _float_promote_vsum
_float_promote_vsum            ENT
                PEI     _fcc_fb
                PEI     _fcc_img16
                PEI     _fcc_img17
                TSC
                SEC
                SBC     #_float_promote_vsum_FRAMESIZE-4
                DO      _float_promote_vsum_STKGUARD
                BCC     _float_promote_vsum_stkovf
                CMP     _fcc_stkfloor
                BCS     _float_promote_vsum_stkok
_float_promote_vsum_stkovf       JMP     _fcc_stkoflow
                FIN
_float_promote_vsum_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                LDA     #0
                JSR     _fcc_long_from_int
                FGX2_FARCALL _fcc_dfroml
                STA     5,S   ; fccstk d=0 b=5
                TAY
                LDA     _fcc_long_hi
                STA     7,S   ; fccstk d=0 b=7
                LDA     _fcc_q2
                STA     9,S   ; fccstk d=0 b=9
                LDA     _fcc_q3
                STA     11,S   ; fccstk d=0 b=11
                TYA
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                TSC
                CLC
                ADC     #6+_float_promote_vsum_FRAMESIZE
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                LDA     _fcc_ptr+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #2
                TAX
                INC
                PHA
                LDA     #1
                EOR     #$FFFF
                STA     _fcc_tmp_b
                PLA
                AND     _fcc_tmp_b
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     _fcc_img17
                LDA     _fcc_fpr0
                STA     _fcc_img16
_float_promote_L0
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                DO      6+_float_promote_vsum_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_float_promote_vsum_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_float_promote_vsum_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_tmp_b
                DEC
                DO      6+_float_promote_vsum_FRAMESIZE/256
                PHA
                TSC
                CLC
                ADC     #8+_float_promote_vsum_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                PLA
                STA     [_fcc_fp]
                ELSE
                STA     6+_float_promote_vsum_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                LDA     _fcc_tmp_b
                LDX     #0
                STA     _fcc_tmp_b
                TXA
                SEC
                SBC     _fcc_tmp_b
                BVC     _float_promote_L2
                EOR     #$8000
_float_promote_L2
                BMI     *+5
                BRL     _float_promote_L1
                LDA     11,S   ; fccstk d=0 b=11
                STA     _fcc_q3
                LDA     9,S   ; fccstk d=0 b=9
                STA     _fcc_q2
                LDA     7,S   ; fccstk d=0 b=7
                STA     _fcc_long_hi
                LDA     5,S   ; fccstk d=0 b=5
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     _fcc_img17
                STA     _fcc_fpr0+2
                LDA     _fcc_img16
                STA     _fcc_fpr0
                LDA     #8
                INC
                PHA
                LDA     #1
                EOR     #$FFFF
                STA     _fcc_tmp_b
                PLA
                AND     _fcc_tmp_b
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     _fcc_img17
                LDA     _fcc_fpr0
                STA     _fcc_img16
                LDA     #8
                INC
                PHA
                LDA     #1
                EOR     #$FFFF
                STA     _fcc_tmp_b
                PLA
                AND     _fcc_tmp_b
                STA     _fcc_tmp_b
                LDA     _fcc_fpr0
                SEC
                SBC     _fcc_tmp_b
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
                STA     5,S   ; fccstk d=0 b=5
                TAY
                LDA     _fcc_long_hi
                STA     7,S   ; fccstk d=0 b=7
                LDA     _fcc_q2
                STA     9,S   ; fccstk d=0 b=9
                LDA     _fcc_q3
                STA     11,S   ; fccstk d=0 b=11
                TYA
                BRL     _float_promote_L0
_float_promote_L1
                LDA     #0
                STA     _fcc_fpr0
                STZ     _fcc_fpr0+2
                LDA     11,S   ; fccstk d=0 b=11
                STA     _fcc_q3
                LDA     9,S   ; fccstk d=0 b=9
                STA     _fcc_q2
                LDA     7,S   ; fccstk d=0 b=7
                STA     _fcc_long_hi
                LDA     5,S   ; fccstk d=0 b=5
                TAY
                TSC
                CLC
                ADC     #_float_promote_vsum_FRAMESIZE-4
                TCS
                PLA
                STA     _fcc_img17
                PLA
                STA     _fcc_img16
                PLA
                STA     _fcc_fb
                TYA
                RTL
_float_promote_vsum_FRAMESIZE   EQU     16
_float_promote_vsum_STKGUARD    EQU     0
                FGX2_EXPORT _float_promote_twice
_float_promote_twice            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #_float_promote_twice_FRAMESIZE
                DO      _float_promote_twice_STKGUARD
                BCC     _float_promote_twice_stkovf
                CMP     _fcc_stkfloor
                BCS     _float_promote_twice_stkok
_float_promote_twice_stkovf       JMP     _fcc_stkoflow
                FIN
_float_promote_twice_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      12+_float_promote_twice_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+_float_promote_twice_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+_float_promote_twice_FRAMESIZE,S   ; fccstk d=0 b=12 fs
                FIN
                STA     _fcc_q3
                DO      10+_float_promote_twice_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+_float_promote_twice_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+_float_promote_twice_FRAMESIZE,S   ; fccstk d=0 b=10 fs
                FIN
                STA     _fcc_q2
                DO      8+_float_promote_twice_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_float_promote_twice_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_float_promote_twice_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_long_hi
                DO      6+_float_promote_twice_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_float_promote_twice_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_float_promote_twice_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                FGX2_FARCALL _fcc_dtof
                DO      6+_float_promote_twice_FRAMESIZE/256
                PHA
                TSC
                CLC
                ADC     #8+_float_promote_twice_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                PLA
                STA     [_fcc_fp]
                ELSE
                STA     6+_float_promote_twice_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                TAY
                LDA     _fcc_long_hi
                DO      8+_float_promote_twice_FRAMESIZE/256
                PHA
                TSC
                CLC
                ADC     #10+_float_promote_twice_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                PLA
                STA     [_fcc_fp]
                ELSE
                STA     8+_float_promote_twice_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                TYA
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                TSC
                CLC
                ADC     #6+_float_promote_twice_FRAMESIZE
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                LDA     _fcc_ptr+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0+2
                STA     3,S   ; fccstk d=0 b=3
                LDA     _fcc_fpr0
                STA     1,S   ; fccstk d=0 b=1
                STA     _fcc_ptr
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_ptr+2
                LDY     #2
                LDA     [_fcc_ptr],Y
                STA     _fcc_long_hi
                LDA     [_fcc_ptr]
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #2
                JSR     _fcc_itof
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_fmul
                TAY
                TSC
                CLC
                ADC     #_float_promote_twice_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_float_promote_twice_FRAMESIZE   EQU     4
_float_promote_twice_STKGUARD    EQU     0
                FGX2_EXPORT _float_promote_mix
_float_promote_mix            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #_float_promote_mix_FRAMESIZE
                DO      _float_promote_mix_STKGUARD
                BCC     _float_promote_mix_stkovf
                CMP     _fcc_stkfloor
                BCS     _float_promote_mix_stkok
_float_promote_mix_stkovf       JMP     _fcc_stkoflow
                FIN
_float_promote_mix_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      14+_float_promote_mix_FRAMESIZE/256
                TSC
                CLC
                ADC     #14+_float_promote_mix_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     14+_float_promote_mix_FRAMESIZE,S   ; fccstk d=0 b=14 fs
                FIN
                STA     _fcc_q3
                DO      12+_float_promote_mix_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+_float_promote_mix_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+_float_promote_mix_FRAMESIZE,S   ; fccstk d=0 b=12 fs
                FIN
                STA     _fcc_q2
                DO      10+_float_promote_mix_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+_float_promote_mix_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+_float_promote_mix_FRAMESIZE,S   ; fccstk d=0 b=10 fs
                FIN
                STA     _fcc_long_hi
                DO      8+_float_promote_mix_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_float_promote_mix_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_float_promote_mix_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                FGX2_FARCALL _fcc_dtof
                DO      8+_float_promote_mix_FRAMESIZE/256
                PHA
                TSC
                CLC
                ADC     #10+_float_promote_mix_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                PLA
                STA     [_fcc_fp]
                ELSE
                STA     8+_float_promote_mix_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                TAY
                LDA     _fcc_long_hi
                DO      10+_float_promote_mix_FRAMESIZE/256
                PHA
                TSC
                CLC
                ADC     #12+_float_promote_mix_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                PLA
                STA     [_fcc_fp]
                ELSE
                STA     10+_float_promote_mix_FRAMESIZE,S   ; fccstk d=0 b=10 fs
                FIN
                TYA
                DO      6+_float_promote_mix_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_float_promote_mix_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_float_promote_mix_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                PHA
                DO      12+_float_promote_mix_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+_float_promote_mix_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+_float_promote_mix_FRAMESIZE,S   ; fccstk d=2 b=10 fs
                FIN
                STA     _fcc_long_hi
                DO      10+_float_promote_mix_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+_float_promote_mix_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+_float_promote_mix_FRAMESIZE,S   ; fccstk d=2 b=8 fs
                FIN
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #4
                JSR     _fcc_itof
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_fmul
                JSR     _fcc_ftol
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                JSR     _fcc_long_from_int
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
                JSR     _fcc_long_add
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                DO      22+_float_promote_mix_FRAMESIZE/256
                TSC
                CLC
                ADC     #22+_float_promote_mix_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     22+_float_promote_mix_FRAMESIZE,S   ; fccstk d=4 b=18 fs
                FIN
                STA     _fcc_long_hi
                DO      20+_float_promote_mix_FRAMESIZE/256
                TSC
                CLC
                ADC     #20+_float_promote_mix_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     20+_float_promote_mix_FRAMESIZE,S   ; fccstk d=4 b=16 fs
                FIN
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_add
                TAY
                TSC
                CLC
                ADC     #_float_promote_mix_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_float_promote_mix_FRAMESIZE   EQU     0
_float_promote_mix_STKGUARD    EQU     0
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
                LDA     #$3FC0
                STA     _fcc_long_hi
                LDA     #$0000
                STA     1,S   ; fccstk d=0 b=1
                TAY
                LDA     _fcc_long_hi
                STA     3,S   ; fccstk d=0 b=3
                TYA
                LDA     #$4010
                STA     _fcc_long_hi
                LDA     #$0000
                STA     5,S   ; fccstk d=0 b=5
                TAY
                LDA     _fcc_long_hi
                STA     7,S   ; fccstk d=0 b=7
                TYA
                LDA     #$3F40
                STA     _fcc_long_hi
                LDA     #$0000
                JSR     _fcc_fneg
                STA     9,S   ; fccstk d=0 b=9
                TAY
                LDA     _fcc_long_hi
                STA     11,S   ; fccstk d=0 b=11
                TYA
                SEP     #$20
                MX      %10
                LDA     _float_promote_FA3+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _float_promote_FA3
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     19,S   ; fccstk d=0 b=19
                LDA     _fcc_fpr0
                STA     17,S   ; fccstk d=0 b=17
                LDA     11,S   ; fccstk d=0 b=11
                STA     _fcc_long_hi
                LDA     9,S   ; fccstk d=0 b=9
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
                LDA     15,S   ; fccstk d=8 b=7
                STA     _fcc_long_hi
                LDA     13,S   ; fccstk d=8 b=5
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
                LDA     19,S   ; fccstk d=16 b=3
                STA     _fcc_long_hi
                LDA     17,S   ; fccstk d=16 b=1
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
                LDA     #3
                PHA
                FGX2_FARCALL _float_promote_vsum
                TAY
                TSC
                CLC
                ADC     #26
                TCS
                TYA
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
                FGX2_FARCALL _fcc_dcmp
                BNE     *+7
                LDA     #0
                BRA     *+5
                LDA     #1
                CMP     #0
                BEQ     _float_promote_L4
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
_float_promote_L4
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_long_hi
                LDA     1,S   ; fccstk d=0 b=1
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     7,S   ; fccstk d=4 b=3
                STA     _fcc_long_hi
                LDA     5,S   ; fccstk d=4 b=1
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_fadd
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     7,S   ; fccstk d=4 b=3
                STA     _fcc_long_hi
                LDA     5,S   ; fccstk d=4 b=1
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_fadd
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     7,S   ; fccstk d=4 b=3
                STA     _fcc_long_hi
                LDA     5,S   ; fccstk d=4 b=1
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_fadd
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #2
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
                FGX2_FARCALL half
                TAY
                TSC
                CLC
                ADC     #8
                TCS
                TYA
                FGX2_FARCALL _fcc_dtof
                STA     13,S   ; fccstk d=0 b=13
                TAY
                LDA     _fcc_long_hi
                STA     15,S   ; fccstk d=0 b=15
                TYA
                LDA     15,S   ; fccstk d=0 b=15
                STA     _fcc_long_hi
                LDA     13,S   ; fccstk d=0 b=13
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$4080
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
                BEQ     _float_promote_L5
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
_float_promote_L5
                LDA     #$3FA0
                STA     _fcc_long_hi
                LDA     #$0000
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
                FGX2_FARCALL _float_promote_twice
                TAY
                TSC
                CLC
                ADC     #8
                TCS
                TYA
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$4020
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
                BEQ     _float_promote_L6
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
_float_promote_L6
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
                FGX2_FARCALL _float_promote_twice
                TAY
                TSC
                CLC
                ADC     #8
                TCS
                TYA
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$40C0
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
                BEQ     _float_promote_L7
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
_float_promote_L7
                LDA     #$0001
                STA     _fcc_long_hi
                LDA     #$86A0
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$3F00
                STA     _fcc_long_hi
                LDA     #$0000
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
                LDA     #1
                PHA
                FGX2_FARCALL _float_promote_mix
                TAY
                TSC
                CLC
                ADC     #14
                TCS
                TYA
                LDX     #34467
                STX     _fcc_long_b_lo
                LDX     #1
                STX     _fcc_long_b_hi
                JSR     _fcc_long_ne
                CMP     #0
                BEQ     _float_promote_L8
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
_float_promote_L8
                LDA     #$4000
                STA     _fcc_long_hi
                LDA     #$0000
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
                LDA     27,S   ; fccstk d=8 b=19
                STA     _fcc_fpr0+2
                LDA     25,S   ; fccstk d=8 b=17
                STA     _fcc_fpr0
                PHK
                PEA     _float_promote_L10-1
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                PHA
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0
                DEC
                PHA
                RTL
_float_promote_L10
                TAY
                TSC
                CLC
                ADC     #8
                TCS
                TYA
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$4080
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
                BEQ     _float_promote_L9
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
_float_promote_L9
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
main_STKGUARD    EQU     1
                FGX2_EXPORT half
half            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #half_FRAMESIZE
                DO      half_STKGUARD
                BCC     half_stkovf
                CMP     _fcc_stkfloor
                BCS     half_stkok
half_stkovf       JMP     _fcc_stkoflow
                FIN
half_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      12+half_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+half_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+half_FRAMESIZE,S   ; fccstk d=0 b=12 fs
                FIN
                STA     _fcc_q3
                DO      10+half_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+half_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+half_FRAMESIZE,S   ; fccstk d=0 b=10 fs
                FIN
                STA     _fcc_q2
                DO      8+half_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+half_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+half_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_long_hi
                DO      6+half_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+half_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+half_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                FGX2_FARCALL _fcc_dtof
                DO      6+half_FRAMESIZE/256
                PHA
                TSC
                CLC
                ADC     #8+half_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                PLA
                STA     [_fcc_fp]
                ELSE
                STA     6+half_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                TAY
                LDA     _fcc_long_hi
                DO      8+half_FRAMESIZE/256
                PHA
                TSC
                CLC
                ADC     #10+half_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                PLA
                STA     [_fcc_fp]
                ELSE
                STA     8+half_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                TYA
                DO      8+half_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+half_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+half_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_long_hi
                DO      6+half_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+half_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+half_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #2
                JSR     _fcc_itof
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_fdiv
                FGX2_FARCALL _fcc_dfromf
                TAY
                TSC
                CLC
                ADC     #half_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
half_FRAMESIZE   EQU     0
half_STKGUARD    EQU     0
                FGX2_RELOC_COUNT 27
]__lc_fltused   =       1
