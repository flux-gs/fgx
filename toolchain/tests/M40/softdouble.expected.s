                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from softdouble.c
;---------------------------------------

                MX      %00
                FGX2_EXPORT _softdouble_dpack
_softdouble_dpack            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #_softdouble_dpack_FRAMESIZE
                DO      _softdouble_dpack_STKGUARD
                BCC     _softdouble_dpack_stkovf
                CMP     _fcc_stkfloor
                BCS     _softdouble_dpack_stkok
_softdouble_dpack_stkovf       JMP     _fcc_stkoflow
                FIN
_softdouble_dpack_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      22+_softdouble_dpack_FRAMESIZE/256
                TSC
                CLC
                ADC     #22+_softdouble_dpack_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     22+_softdouble_dpack_FRAMESIZE,S   ; fccstk d=0 b=22 fs
                FIN
                STA     _fcc_q3
                DO      20+_softdouble_dpack_FRAMESIZE/256
                TSC
                CLC
                ADC     #20+_softdouble_dpack_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     20+_softdouble_dpack_FRAMESIZE,S   ; fccstk d=0 b=20 fs
                FIN
                STA     _fcc_q2
                DO      18+_softdouble_dpack_FRAMESIZE/256
                TSC
                CLC
                ADC     #18+_softdouble_dpack_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     18+_softdouble_dpack_FRAMESIZE,S   ; fccstk d=0 b=18 fs
                FIN
                STA     _fcc_long_hi
                DO      16+_softdouble_dpack_FRAMESIZE/256
                TSC
                CLC
                ADC     #16+_softdouble_dpack_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     16+_softdouble_dpack_FRAMESIZE,S   ; fccstk d=0 b=16 fs
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
                LDA     #0
                JSR     _fcc_long_from_int
                LDX     #0
                BIT     _fcc_long_hi
                BPL     *+5
                LDX     #$FFFF
                STX     _fcc_q2
                STX     _fcc_q3
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
                FGX2_FARCALL _fcc_ll_cmpu
                BEQ     *+7
                LDA     #0
                BRA     *+5
                LDA     #1
                CMP     #0
                BNE     *+5
                BRL     _softdouble_L0
                DO      12+_softdouble_dpack_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+_softdouble_dpack_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+_softdouble_dpack_FRAMESIZE,S   ; fccstk d=0 b=12 fs
                FIN
                STA     _fcc_q3
                DO      10+_softdouble_dpack_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+_softdouble_dpack_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+_softdouble_dpack_FRAMESIZE,S   ; fccstk d=0 b=10 fs
                FIN
                STA     _fcc_q2
                DO      8+_softdouble_dpack_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_softdouble_dpack_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_softdouble_dpack_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_long_hi
                DO      6+_softdouble_dpack_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_softdouble_dpack_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_softdouble_dpack_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                TAY
                TSC
                CLC
                ADC     #_softdouble_dpack_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_softdouble_L0
                DO      14+_softdouble_dpack_FRAMESIZE/256
                TSC
                CLC
                ADC     #14+_softdouble_dpack_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     14+_softdouble_dpack_FRAMESIZE,S   ; fccstk d=0 b=14 fs
                FIN
                TAX
                TXA
                CLC
                ADC     #1023
                STA     1,S   ; fccstk d=0 b=1
                TAX
                TXA
                LDX     #0
                STA     _fcc_tmp_b
                TXA
                SEC
                SBC     _fcc_tmp_b
                BVC     _softdouble_L2
                EOR     #$8000
_softdouble_L2
                BPL     *+5
                BRL     _softdouble_L1
                DO      12+_softdouble_dpack_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+_softdouble_dpack_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+_softdouble_dpack_FRAMESIZE,S   ; fccstk d=0 b=12 fs
                FIN
                STA     _fcc_q3
                DO      10+_softdouble_dpack_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+_softdouble_dpack_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+_softdouble_dpack_FRAMESIZE,S   ; fccstk d=0 b=10 fs
                FIN
                STA     _fcc_q2
                DO      8+_softdouble_dpack_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_softdouble_dpack_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_softdouble_dpack_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_long_hi
                DO      6+_softdouble_dpack_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_softdouble_dpack_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_softdouble_dpack_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                TAY
                TSC
                CLC
                ADC     #_softdouble_dpack_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_softdouble_L1
                LDA     1,S   ; fccstk d=0 b=1
                TAX
                TXA
                SEC
                SBC     #2047
                BVC     _softdouble_L4
                EOR     #$8000
_softdouble_L4
                BPL     *+5
                BRL     _softdouble_L3
                DO      12+_softdouble_dpack_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+_softdouble_dpack_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+_softdouble_dpack_FRAMESIZE,S   ; fccstk d=0 b=12 fs
                FIN
                STA     _fcc_q3
                DO      10+_softdouble_dpack_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+_softdouble_dpack_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+_softdouble_dpack_FRAMESIZE,S   ; fccstk d=0 b=10 fs
                FIN
                STA     _fcc_q2
                DO      8+_softdouble_dpack_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_softdouble_dpack_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_softdouble_dpack_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_long_hi
                DO      6+_softdouble_dpack_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_softdouble_dpack_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_softdouble_dpack_FRAMESIZE,S   ; fccstk d=0 b=6 fs
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
                LDA     #32752
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
                FGX2_FARCALL _fcc_ll_or
                TAY
                TSC
                CLC
                ADC     #_softdouble_dpack_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_softdouble_L3
                DO      12+_softdouble_dpack_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+_softdouble_dpack_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+_softdouble_dpack_FRAMESIZE,S   ; fccstk d=0 b=12 fs
                FIN
                STA     _fcc_q3
                DO      10+_softdouble_dpack_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+_softdouble_dpack_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+_softdouble_dpack_FRAMESIZE,S   ; fccstk d=0 b=10 fs
                FIN
                STA     _fcc_q2
                DO      8+_softdouble_dpack_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_softdouble_dpack_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_softdouble_dpack_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_long_hi
                DO      6+_softdouble_dpack_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_softdouble_dpack_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_softdouble_dpack_FRAMESIZE,S   ; fccstk d=0 b=6 fs
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
                DO      30+_softdouble_dpack_FRAMESIZE/256
                TSC
                CLC
                ADC     #30+_softdouble_dpack_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     30+_softdouble_dpack_FRAMESIZE,S   ; fccstk d=8 b=22 fs
                FIN
                STA     _fcc_q3
                DO      28+_softdouble_dpack_FRAMESIZE/256
                TSC
                CLC
                ADC     #28+_softdouble_dpack_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     28+_softdouble_dpack_FRAMESIZE,S   ; fccstk d=8 b=20 fs
                FIN
                STA     _fcc_q2
                DO      26+_softdouble_dpack_FRAMESIZE/256
                TSC
                CLC
                ADC     #26+_softdouble_dpack_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     26+_softdouble_dpack_FRAMESIZE,S   ; fccstk d=8 b=18 fs
                FIN
                STA     _fcc_long_hi
                DO      24+_softdouble_dpack_FRAMESIZE/256
                TSC
                CLC
                ADC     #24+_softdouble_dpack_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     24+_softdouble_dpack_FRAMESIZE,S   ; fccstk d=8 b=16 fs
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
                LDA     #15
                STA     _fcc_q3
                LDA     #65535
                STA     _fcc_q2
                LDA     #65535
                STA     _fcc_long_hi
                LDA     #65535
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
                FGX2_FARCALL _fcc_ll_and
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
                FGX2_FARCALL _fcc_ll_or
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     9,S   ; fccstk d=8 b=1
                LDX     #0
                STX     _fcc_long_hi
                STZ     _fcc_q2
                STZ     _fcc_q3
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #52
                STA     _fcc_long_b_lo
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                PLA
                STA     _fcc_q2
                PLA
                STA     _fcc_q3
                TYA
                FGX2_FARCALL _fcc_ll_shl
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
                FGX2_FARCALL _fcc_ll_or
                TAY
                TSC
                CLC
                ADC     #_softdouble_dpack_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_softdouble_dpack_FRAMESIZE   EQU     2
_softdouble_dpack_STKGUARD    EQU     0
                FGX2_EXPORT _softdouble_dclass
_softdouble_dclass            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #_softdouble_dclass_FRAMESIZE
                DO      _softdouble_dclass_STKGUARD
                BCC     _softdouble_dclass_stkovf
                CMP     _fcc_stkfloor
                BCS     _softdouble_dclass_stkok
_softdouble_dclass_stkovf       JMP     _fcc_stkoflow
                FIN
_softdouble_dclass_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      16+_softdouble_dclass_FRAMESIZE/256
                TSC
                CLC
                ADC     #16+_softdouble_dclass_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     16+_softdouble_dclass_FRAMESIZE,S   ; fccstk d=0 b=16 fs
                FIN
                STA     _fcc_fpr0+2
                DO      14+_softdouble_dclass_FRAMESIZE/256
                TSC
                CLC
                ADC     #14+_softdouble_dclass_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     14+_softdouble_dclass_FRAMESIZE,S   ; fccstk d=0 b=14 fs
                FIN
                STA     _fcc_fpr0
                DO      12+_softdouble_dclass_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+_softdouble_dclass_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+_softdouble_dclass_FRAMESIZE,S   ; fccstk d=0 b=12 fs
                FIN
                STA     _fcc_q3
                DO      10+_softdouble_dclass_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+_softdouble_dclass_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+_softdouble_dclass_FRAMESIZE,S   ; fccstk d=0 b=10 fs
                FIN
                STA     _fcc_q2
                DO      8+_softdouble_dclass_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_softdouble_dclass_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_softdouble_dclass_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_long_hi
                DO      6+_softdouble_dclass_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_softdouble_dclass_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_softdouble_dclass_FRAMESIZE,S   ; fccstk d=0 b=6 fs
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
                LDA     #32768
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
                FGX2_FARCALL _fcc_ll_and
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
                DO      12+_softdouble_dclass_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+_softdouble_dclass_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+_softdouble_dclass_FRAMESIZE,S   ; fccstk d=0 b=12 fs
                FIN
                STA     _fcc_q3
                DO      10+_softdouble_dclass_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+_softdouble_dclass_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+_softdouble_dclass_FRAMESIZE,S   ; fccstk d=0 b=10 fs
                FIN
                STA     _fcc_q2
                DO      8+_softdouble_dclass_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_softdouble_dclass_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_softdouble_dclass_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_long_hi
                DO      6+_softdouble_dclass_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_softdouble_dclass_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_softdouble_dclass_FRAMESIZE,S   ; fccstk d=0 b=6 fs
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
                LDA     #52
                STA     _fcc_long_b_lo
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                PLA
                STA     _fcc_q2
                PLA
                STA     _fcc_q3
                TYA
                FGX2_FARCALL _fcc_ll_shru
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #2047
                JSR     _fcc_long_from_int
                LDX     #0
                BIT     _fcc_long_hi
                BPL     *+5
                LDX     #$FFFF
                STX     _fcc_q2
                STX     _fcc_q3
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
                FGX2_FARCALL _fcc_ll_and
                STA     1,S   ; fccstk d=0 b=1
                DO      12+_softdouble_dclass_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+_softdouble_dclass_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+_softdouble_dclass_FRAMESIZE,S   ; fccstk d=0 b=12 fs
                FIN
                STA     _fcc_q3
                DO      10+_softdouble_dclass_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+_softdouble_dclass_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+_softdouble_dclass_FRAMESIZE,S   ; fccstk d=0 b=10 fs
                FIN
                STA     _fcc_q2
                DO      8+_softdouble_dclass_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_softdouble_dclass_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_softdouble_dclass_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_long_hi
                DO      6+_softdouble_dclass_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_softdouble_dclass_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_softdouble_dclass_FRAMESIZE,S   ; fccstk d=0 b=6 fs
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
                LDA     #15
                STA     _fcc_q3
                LDA     #65535
                STA     _fcc_q2
                LDA     #65535
                STA     _fcc_long_hi
                LDA     #65535
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
                FGX2_FARCALL _fcc_ll_and
                STA     3,S   ; fccstk d=0 b=3
                TAY
                LDA     _fcc_long_hi
                STA     5,S   ; fccstk d=0 b=5
                LDA     _fcc_q2
                STA     7,S   ; fccstk d=0 b=7
                LDA     _fcc_q3
                STA     9,S   ; fccstk d=0 b=9
                TYA
                LDA     1,S   ; fccstk d=0 b=1
                TAX
                TXA
                CMP     #0
                BEQ     *+5
                BRL     _softdouble_L5
                DO      20+_softdouble_dclass_FRAMESIZE/256
                TSC
                CLC
                ADC     #20+_softdouble_dclass_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     20+_softdouble_dclass_FRAMESIZE,S   ; fccstk d=0 b=20 fs
                FIN
                STA     _fcc_fpr0+2
                DO      18+_softdouble_dclass_FRAMESIZE/256
                TSC
                CLC
                ADC     #18+_softdouble_dclass_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     18+_softdouble_dclass_FRAMESIZE,S   ; fccstk d=0 b=18 fs
                FIN
                STA     _fcc_fpr0
                LDA     #0
                STA     [_fcc_fpr0]
                DO      24+_softdouble_dclass_FRAMESIZE/256
                TSC
                CLC
                ADC     #24+_softdouble_dclass_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     24+_softdouble_dclass_FRAMESIZE,S   ; fccstk d=0 b=24 fs
                FIN
                STA     _fcc_fpr0+2
                DO      22+_softdouble_dclass_FRAMESIZE/256
                TSC
                CLC
                ADC     #22+_softdouble_dclass_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     22+_softdouble_dclass_FRAMESIZE,S   ; fccstk d=0 b=22 fs
                FIN
                STA     _fcc_fpr0
                LDA     #0
                JSR     _fcc_long_from_int
                LDX     #0
                BIT     _fcc_long_hi
                BPL     *+5
                LDX     #$FFFF
                STX     _fcc_q2
                STX     _fcc_q3
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
                LDA     #0
                TAY
                TSC
                CLC
                ADC     #_softdouble_dclass_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_softdouble_L5
                LDA     1,S   ; fccstk d=0 b=1
                TAX
                TXA
                CMP     #2047
                BEQ     *+5
                BRL     _softdouble_L6
                DO      20+_softdouble_dclass_FRAMESIZE/256
                TSC
                CLC
                ADC     #20+_softdouble_dclass_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     20+_softdouble_dclass_FRAMESIZE,S   ; fccstk d=0 b=20 fs
                FIN
                STA     _fcc_fpr0+2
                DO      18+_softdouble_dclass_FRAMESIZE/256
                TSC
                CLC
                ADC     #18+_softdouble_dclass_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     18+_softdouble_dclass_FRAMESIZE,S   ; fccstk d=0 b=18 fs
                FIN
                STA     _fcc_fpr0
                LDA     #2047
                STA     [_fcc_fpr0]
                DO      24+_softdouble_dclass_FRAMESIZE/256
                TSC
                CLC
                ADC     #24+_softdouble_dclass_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     24+_softdouble_dclass_FRAMESIZE,S   ; fccstk d=0 b=24 fs
                FIN
                STA     _fcc_fpr0+2
                DO      22+_softdouble_dclass_FRAMESIZE/256
                TSC
                CLC
                ADC     #22+_softdouble_dclass_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     22+_softdouble_dclass_FRAMESIZE,S   ; fccstk d=0 b=22 fs
                FIN
                STA     _fcc_fpr0
                LDA     9,S   ; fccstk d=0 b=9
                STA     _fcc_q3
                LDA     7,S   ; fccstk d=0 b=7
                STA     _fcc_q2
                LDA     5,S   ; fccstk d=0 b=5
                STA     _fcc_long_hi
                LDA     3,S   ; fccstk d=0 b=3
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
                LDA     9,S   ; fccstk d=0 b=9
                STA     _fcc_q3
                LDA     7,S   ; fccstk d=0 b=7
                STA     _fcc_q2
                LDA     5,S   ; fccstk d=0 b=5
                STA     _fcc_long_hi
                LDA     3,S   ; fccstk d=0 b=3
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
                LDX     #0
                BIT     _fcc_long_hi
                BPL     *+5
                LDX     #$FFFF
                STX     _fcc_q2
                STX     _fcc_q3
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
                FGX2_FARCALL _fcc_ll_cmpu
                BEQ     *+7
                LDA     #0
                BRA     *+5
                LDA     #1
                CMP     #0
                BNE     *+5
                BRL     _softdouble_L7
                LDA     #2
                BRL     _softdouble_L8
_softdouble_L7
                LDA     #3
_softdouble_L8
                TAY
                TSC
                CLC
                ADC     #_softdouble_dclass_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_softdouble_L6
                DO      20+_softdouble_dclass_FRAMESIZE/256
                TSC
                CLC
                ADC     #20+_softdouble_dclass_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     20+_softdouble_dclass_FRAMESIZE,S   ; fccstk d=0 b=20 fs
                FIN
                STA     _fcc_fpr0+2
                DO      18+_softdouble_dclass_FRAMESIZE/256
                TSC
                CLC
                ADC     #18+_softdouble_dclass_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     18+_softdouble_dclass_FRAMESIZE,S   ; fccstk d=0 b=18 fs
                FIN
                STA     _fcc_fpr0
                LDA     1,S   ; fccstk d=0 b=1
                TAX
                TXA
                SEC
                SBC     #1023
                STA     [_fcc_fpr0]
                DO      24+_softdouble_dclass_FRAMESIZE/256
                TSC
                CLC
                ADC     #24+_softdouble_dclass_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     24+_softdouble_dclass_FRAMESIZE,S   ; fccstk d=0 b=24 fs
                FIN
                STA     _fcc_fpr0+2
                DO      22+_softdouble_dclass_FRAMESIZE/256
                TSC
                CLC
                ADC     #22+_softdouble_dclass_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     22+_softdouble_dclass_FRAMESIZE,S   ; fccstk d=0 b=22 fs
                FIN
                STA     _fcc_fpr0
                LDA     9,S   ; fccstk d=0 b=9
                STA     _fcc_q3
                LDA     7,S   ; fccstk d=0 b=7
                STA     _fcc_q2
                LDA     5,S   ; fccstk d=0 b=5
                STA     _fcc_long_hi
                LDA     3,S   ; fccstk d=0 b=3
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #16
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
                FGX2_FARCALL _fcc_ll_or
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
                LDA     #1
                TAY
                TSC
                CLC
                ADC     #_softdouble_dclass_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_softdouble_dclass_FRAMESIZE   EQU     10
_softdouble_dclass_STKGUARD    EQU     0
                FGX2_EXPORT __adddf3
__adddf3            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #__adddf3_FRAMESIZE
                DO      __adddf3_STKGUARD
                BCC     __adddf3_stkovf
                CMP     _fcc_stkfloor
                BCS     __adddf3_stkok
__adddf3_stkovf       JMP     _fcc_stkoflow
                FIN
__adddf3_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
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
                DO      24+__adddf3_FRAMESIZE/256
                TSC
                CLC
                ADC     #24+__adddf3_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     24+__adddf3_FRAMESIZE,S   ; fccstk d=12 b=12 fs
                FIN
                STA     _fcc_q3
                DO      22+__adddf3_FRAMESIZE/256
                TSC
                CLC
                ADC     #22+__adddf3_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     22+__adddf3_FRAMESIZE,S   ; fccstk d=12 b=10 fs
                FIN
                STA     _fcc_q2
                DO      20+__adddf3_FRAMESIZE/256
                TSC
                CLC
                ADC     #20+__adddf3_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     20+__adddf3_FRAMESIZE,S   ; fccstk d=12 b=8 fs
                FIN
                STA     _fcc_long_hi
                DO      18+__adddf3_FRAMESIZE/256
                TSC
                CLC
                ADC     #18+__adddf3_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     18+__adddf3_FRAMESIZE,S   ; fccstk d=12 b=6 fs
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
                FGX2_FARCALL _softdouble_dclass
                TAY
                TSC
                CLC
                ADC     #20
                TCS
                TYA
                STA     37,S   ; fccstk d=0 b=37
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
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #34
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
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
                DO      32+__adddf3_FRAMESIZE/256
                TSC
                CLC
                ADC     #32+__adddf3_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     32+__adddf3_FRAMESIZE,S   ; fccstk d=12 b=20 fs
                FIN
                STA     _fcc_q3
                DO      30+__adddf3_FRAMESIZE/256
                TSC
                CLC
                ADC     #30+__adddf3_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     30+__adddf3_FRAMESIZE,S   ; fccstk d=12 b=18 fs
                FIN
                STA     _fcc_q2
                DO      28+__adddf3_FRAMESIZE/256
                TSC
                CLC
                ADC     #28+__adddf3_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     28+__adddf3_FRAMESIZE,S   ; fccstk d=12 b=16 fs
                FIN
                STA     _fcc_long_hi
                DO      26+__adddf3_FRAMESIZE/256
                TSC
                CLC
                ADC     #26+__adddf3_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     26+__adddf3_FRAMESIZE,S   ; fccstk d=12 b=14 fs
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
                FGX2_FARCALL _softdouble_dclass
                TAY
                TSC
                CLC
                ADC     #20
                TCS
                TYA
                STA     39,S   ; fccstk d=0 b=39
                LDA     37,S   ; fccstk d=0 b=37
                TAX
                TXA
                CMP     #0
                BEQ     *+5
                BRL     _softdouble_L9
                DO      20+__adddf3_FRAMESIZE/256
                TSC
                CLC
                ADC     #20+__adddf3_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     20+__adddf3_FRAMESIZE,S   ; fccstk d=0 b=20 fs
                FIN
                STA     _fcc_q3
                DO      18+__adddf3_FRAMESIZE/256
                TSC
                CLC
                ADC     #18+__adddf3_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     18+__adddf3_FRAMESIZE,S   ; fccstk d=0 b=18 fs
                FIN
                STA     _fcc_q2
                DO      16+__adddf3_FRAMESIZE/256
                TSC
                CLC
                ADC     #16+__adddf3_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     16+__adddf3_FRAMESIZE,S   ; fccstk d=0 b=16 fs
                FIN
                STA     _fcc_long_hi
                DO      14+__adddf3_FRAMESIZE/256
                TSC
                CLC
                ADC     #14+__adddf3_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     14+__adddf3_FRAMESIZE,S   ; fccstk d=0 b=14 fs
                FIN
                TAY
                TSC
                CLC
                ADC     #__adddf3_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_softdouble_L9
                LDA     39,S   ; fccstk d=0 b=39
                TAX
                TXA
                CMP     #0
                BEQ     *+5
                BRL     _softdouble_L10
                DO      12+__adddf3_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+__adddf3_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+__adddf3_FRAMESIZE,S   ; fccstk d=0 b=12 fs
                FIN
                STA     _fcc_q3
                DO      10+__adddf3_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+__adddf3_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+__adddf3_FRAMESIZE,S   ; fccstk d=0 b=10 fs
                FIN
                STA     _fcc_q2
                DO      8+__adddf3_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+__adddf3_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+__adddf3_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_long_hi
                DO      6+__adddf3_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+__adddf3_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+__adddf3_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                TAY
                TSC
                CLC
                ADC     #__adddf3_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_softdouble_L10
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
                STA     _fcc_long_b_lo
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                PLA
                STA     _fcc_q2
                PLA
                STA     _fcc_q3
                TYA
                FGX2_FARCALL _fcc_ll_shl
                STA     17,S   ; fccstk d=0 b=17
                TAY
                LDA     _fcc_long_hi
                STA     19,S   ; fccstk d=0 b=19
                LDA     _fcc_q2
                STA     21,S   ; fccstk d=0 b=21
                LDA     _fcc_q3
                STA     23,S   ; fccstk d=0 b=23
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
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #3
                STA     _fcc_long_b_lo
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                PLA
                STA     _fcc_q2
                PLA
                STA     _fcc_q3
                TYA
                FGX2_FARCALL _fcc_ll_shl
                STA     25,S   ; fccstk d=0 b=25
                TAY
                LDA     _fcc_long_hi
                STA     27,S   ; fccstk d=0 b=27
                LDA     _fcc_q2
                STA     29,S   ; fccstk d=0 b=29
                LDA     _fcc_q3
                STA     31,S   ; fccstk d=0 b=31
                TYA
                LDA     33,S   ; fccstk d=0 b=33
                TAX
                LDA     35,S   ; fccstk d=0 b=35
                STA     _fcc_tmp_b
                TXA
                LDX     _fcc_tmp_b
                STA     _fcc_tmp_b
                TXA
                SEC
                SBC     _fcc_tmp_b
                BVC     _softdouble_L12
                EOR     #$8000
_softdouble_L12
                BMI     *+5
                BRL     _softdouble_L11
                LDA     33,S   ; fccstk d=0 b=33
                SEC
                SBC     35,S   ; fccstk d=0 b=35
                STA     41,S   ; fccstk d=0 b=41
                TAX
                TXA
                LDX     #56
                STA     _fcc_tmp_b
                TXA
                SEC
                SBC     _fcc_tmp_b
                BVC     _softdouble_L14
                EOR     #$8000
_softdouble_L14
                BMI     *+5
                BRL     _softdouble_L13
                DO      12+__adddf3_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+__adddf3_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+__adddf3_FRAMESIZE,S   ; fccstk d=0 b=12 fs
                FIN
                STA     _fcc_q3
                DO      10+__adddf3_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+__adddf3_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+__adddf3_FRAMESIZE,S   ; fccstk d=0 b=10 fs
                FIN
                STA     _fcc_q2
                DO      8+__adddf3_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+__adddf3_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+__adddf3_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_long_hi
                DO      6+__adddf3_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+__adddf3_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+__adddf3_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                TAY
                TSC
                CLC
                ADC     #__adddf3_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_softdouble_L13
                LDA     #0
                JSR     _fcc_long_from_int
                LDX     #0
                BIT     _fcc_long_hi
                BPL     *+5
                LDX     #$FFFF
                STX     _fcc_q2
                STX     _fcc_q3
                STA     43,S   ; fccstk d=0 b=43
                TAY
                LDA     _fcc_long_hi
                STA     45,S   ; fccstk d=0 b=45
                LDA     _fcc_q2
                STA     47,S   ; fccstk d=0 b=47
                LDA     _fcc_q3
                STA     49,S   ; fccstk d=0 b=49
                TYA
                LDA     41,S   ; fccstk d=0 b=41
                TAX
                TXA
                LDX     #3
                STA     _fcc_tmp_b
                TXA
                SEC
                SBC     _fcc_tmp_b
                BVC     _softdouble_L16
                EOR     #$8000
_softdouble_L16
                BMI     *+5
                BRL     _softdouble_L15
                LDA     41,S   ; fccstk d=0 b=41
                TAX
                TXA
                SEC
                SBC     #64
                BVC     _softdouble_L19
                EOR     #$8000
_softdouble_L19
                BPL     *+5
                BRL     _softdouble_L17
                LDA     #0
                STA     _fcc_q3
                LDA     #0
                STA     _fcc_q2
                LDA     #0
                STA     _fcc_long_hi
                LDA     #0
                FGX2_FARCALL _fcc_ll_com
                BRL     _softdouble_L18
_softdouble_L17
                LDA     #0
                STA     _fcc_q3
                LDA     #0
                STA     _fcc_q2
                LDA     #0
                STA     _fcc_long_hi
                LDA     #1
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     49,S   ; fccstk d=8 b=41
                STA     _fcc_long_b_lo
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                PLA
                STA     _fcc_q2
                PLA
                STA     _fcc_q3
                TYA
                FGX2_FARCALL _fcc_ll_shl
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
                LDX     #0
                BIT     _fcc_long_hi
                BPL     *+5
                LDX     #$FFFF
                STX     _fcc_q2
                STX     _fcc_q3
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
                FGX2_FARCALL _fcc_ll_sub
_softdouble_L18
                STA     51,S   ; fccstk d=0 b=51
                TAY
                LDA     _fcc_long_hi
                STA     53,S   ; fccstk d=0 b=53
                LDA     _fcc_q2
                STA     55,S   ; fccstk d=0 b=55
                LDA     _fcc_q3
                STA     57,S   ; fccstk d=0 b=57
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
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     65,S   ; fccstk d=8 b=57
                STA     _fcc_q3
                LDA     63,S   ; fccstk d=8 b=55
                STA     _fcc_q2
                LDA     61,S   ; fccstk d=8 b=53
                STA     _fcc_long_hi
                LDA     59,S   ; fccstk d=8 b=51
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
                FGX2_FARCALL _fcc_ll_and
                ORA     _fcc_long_hi
                ORA     _fcc_q2
                ORA     _fcc_q3
                BNE     *+5
                BRL     _softdouble_L20
                LDA     #1
                BRL     _softdouble_L21
_softdouble_L20
                LDA     #0
_softdouble_L21
                JSR     _fcc_long_from_int
                LDX     #0
                BIT     _fcc_long_hi
                BPL     *+5
                LDX     #$FFFF
                STX     _fcc_q2
                STX     _fcc_q3
                STA     43,S   ; fccstk d=0 b=43
                TAY
                LDA     _fcc_long_hi
                STA     45,S   ; fccstk d=0 b=45
                LDA     _fcc_q2
                STA     47,S   ; fccstk d=0 b=47
                LDA     _fcc_q3
                STA     49,S   ; fccstk d=0 b=49
                TYA
_softdouble_L15
                LDA     41,S   ; fccstk d=0 b=41
                TAX
                TXA
                SEC
                SBC     #64
                BVC     _softdouble_L24
                EOR     #$8000
_softdouble_L24
                BPL     *+5
                BRL     _softdouble_L22
                LDA     #0
                JSR     _fcc_long_from_int
                LDX     #0
                BIT     _fcc_long_hi
                BPL     *+5
                LDX     #$FFFF
                STX     _fcc_q2
                STX     _fcc_q3
                BRL     _softdouble_L23
_softdouble_L22
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
                LDA     49,S   ; fccstk d=8 b=41
                STA     _fcc_long_b_lo
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                PLA
                STA     _fcc_q2
                PLA
                STA     _fcc_q3
                TYA
                FGX2_FARCALL _fcc_ll_shru
_softdouble_L23
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
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     57,S   ; fccstk d=8 b=49
                STA     _fcc_q3
                LDA     55,S   ; fccstk d=8 b=47
                STA     _fcc_q2
                LDA     53,S   ; fccstk d=8 b=45
                STA     _fcc_long_hi
                LDA     51,S   ; fccstk d=8 b=43
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
                FGX2_FARCALL _fcc_ll_or
                STA     25,S   ; fccstk d=0 b=25
                TAY
                LDA     _fcc_long_hi
                STA     27,S   ; fccstk d=0 b=27
                LDA     _fcc_q2
                STA     29,S   ; fccstk d=0 b=29
                LDA     _fcc_q3
                STA     31,S   ; fccstk d=0 b=31
                TYA
                LDA     33,S   ; fccstk d=0 b=33
                STA     35,S   ; fccstk d=0 b=35
                BRL     _softdouble_L25
_softdouble_L11
                LDA     35,S   ; fccstk d=0 b=35
                TAX
                LDA     33,S   ; fccstk d=0 b=33
                STA     _fcc_tmp_b
                TXA
                LDX     _fcc_tmp_b
                STA     _fcc_tmp_b
                TXA
                SEC
                SBC     _fcc_tmp_b
                BVC     _softdouble_L27
                EOR     #$8000
_softdouble_L27
                BMI     *+5
                BRL     _softdouble_L26
                LDA     35,S   ; fccstk d=0 b=35
                SEC
                SBC     33,S   ; fccstk d=0 b=33
                STA     59,S   ; fccstk d=0 b=59
                TAX
                TXA
                LDX     #56
                STA     _fcc_tmp_b
                TXA
                SEC
                SBC     _fcc_tmp_b
                BVC     _softdouble_L29
                EOR     #$8000
_softdouble_L29
                BMI     *+5
                BRL     _softdouble_L28
                DO      20+__adddf3_FRAMESIZE/256
                TSC
                CLC
                ADC     #20+__adddf3_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     20+__adddf3_FRAMESIZE,S   ; fccstk d=0 b=20 fs
                FIN
                STA     _fcc_q3
                DO      18+__adddf3_FRAMESIZE/256
                TSC
                CLC
                ADC     #18+__adddf3_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     18+__adddf3_FRAMESIZE,S   ; fccstk d=0 b=18 fs
                FIN
                STA     _fcc_q2
                DO      16+__adddf3_FRAMESIZE/256
                TSC
                CLC
                ADC     #16+__adddf3_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     16+__adddf3_FRAMESIZE,S   ; fccstk d=0 b=16 fs
                FIN
                STA     _fcc_long_hi
                DO      14+__adddf3_FRAMESIZE/256
                TSC
                CLC
                ADC     #14+__adddf3_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     14+__adddf3_FRAMESIZE,S   ; fccstk d=0 b=14 fs
                FIN
                TAY
                TSC
                CLC
                ADC     #__adddf3_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_softdouble_L28
                LDA     #0
                JSR     _fcc_long_from_int
                LDX     #0
                BIT     _fcc_long_hi
                BPL     *+5
                LDX     #$FFFF
                STX     _fcc_q2
                STX     _fcc_q3
                STA     61,S   ; fccstk d=0 b=61
                TAY
                LDA     _fcc_long_hi
                STA     63,S   ; fccstk d=0 b=63
                LDA     _fcc_q2
                STA     65,S   ; fccstk d=0 b=65
                LDA     _fcc_q3
                STA     67,S   ; fccstk d=0 b=67
                TYA
                LDA     59,S   ; fccstk d=0 b=59
                TAX
                TXA
                LDX     #3
                STA     _fcc_tmp_b
                TXA
                SEC
                SBC     _fcc_tmp_b
                BVC     _softdouble_L31
                EOR     #$8000
_softdouble_L31
                BMI     *+5
                BRL     _softdouble_L30
                LDA     59,S   ; fccstk d=0 b=59
                TAX
                TXA
                SEC
                SBC     #64
                BVC     _softdouble_L34
                EOR     #$8000
_softdouble_L34
                BPL     *+5
                BRL     _softdouble_L32
                LDA     #0
                STA     _fcc_q3
                LDA     #0
                STA     _fcc_q2
                LDA     #0
                STA     _fcc_long_hi
                LDA     #0
                FGX2_FARCALL _fcc_ll_com
                BRL     _softdouble_L33
_softdouble_L32
                LDA     #0
                STA     _fcc_q3
                LDA     #0
                STA     _fcc_q2
                LDA     #0
                STA     _fcc_long_hi
                LDA     #1
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     67,S   ; fccstk d=8 b=59
                STA     _fcc_long_b_lo
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                PLA
                STA     _fcc_q2
                PLA
                STA     _fcc_q3
                TYA
                FGX2_FARCALL _fcc_ll_shl
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
                LDX     #0
                BIT     _fcc_long_hi
                BPL     *+5
                LDX     #$FFFF
                STX     _fcc_q2
                STX     _fcc_q3
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
                FGX2_FARCALL _fcc_ll_sub
_softdouble_L33
                STA     69,S   ; fccstk d=0 b=69
                TAY
                LDA     _fcc_long_hi
                STA     71,S   ; fccstk d=0 b=71
                LDA     _fcc_q2
                STA     73,S   ; fccstk d=0 b=73
                LDA     _fcc_q3
                STA     75,S   ; fccstk d=0 b=75
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
                LDA     83,S   ; fccstk d=8 b=75
                STA     _fcc_q3
                LDA     81,S   ; fccstk d=8 b=73
                STA     _fcc_q2
                LDA     79,S   ; fccstk d=8 b=71
                STA     _fcc_long_hi
                LDA     77,S   ; fccstk d=8 b=69
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
                FGX2_FARCALL _fcc_ll_and
                ORA     _fcc_long_hi
                ORA     _fcc_q2
                ORA     _fcc_q3
                BNE     *+5
                BRL     _softdouble_L35
                LDA     #1
                BRL     _softdouble_L36
_softdouble_L35
                LDA     #0
_softdouble_L36
                JSR     _fcc_long_from_int
                LDX     #0
                BIT     _fcc_long_hi
                BPL     *+5
                LDX     #$FFFF
                STX     _fcc_q2
                STX     _fcc_q3
                STA     61,S   ; fccstk d=0 b=61
                TAY
                LDA     _fcc_long_hi
                STA     63,S   ; fccstk d=0 b=63
                LDA     _fcc_q2
                STA     65,S   ; fccstk d=0 b=65
                LDA     _fcc_q3
                STA     67,S   ; fccstk d=0 b=67
                TYA
_softdouble_L30
                LDA     59,S   ; fccstk d=0 b=59
                TAX
                TXA
                SEC
                SBC     #64
                BVC     _softdouble_L39
                EOR     #$8000
_softdouble_L39
                BPL     *+5
                BRL     _softdouble_L37
                LDA     #0
                JSR     _fcc_long_from_int
                LDX     #0
                BIT     _fcc_long_hi
                BPL     *+5
                LDX     #$FFFF
                STX     _fcc_q2
                STX     _fcc_q3
                BRL     _softdouble_L38
_softdouble_L37
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
                LDA     67,S   ; fccstk d=8 b=59
                STA     _fcc_long_b_lo
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                PLA
                STA     _fcc_q2
                PLA
                STA     _fcc_q3
                TYA
                FGX2_FARCALL _fcc_ll_shru
_softdouble_L38
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
                LDA     75,S   ; fccstk d=8 b=67
                STA     _fcc_q3
                LDA     73,S   ; fccstk d=8 b=65
                STA     _fcc_q2
                LDA     71,S   ; fccstk d=8 b=63
                STA     _fcc_long_hi
                LDA     69,S   ; fccstk d=8 b=61
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
                FGX2_FARCALL _fcc_ll_or
                STA     17,S   ; fccstk d=0 b=17
                TAY
                LDA     _fcc_long_hi
                STA     19,S   ; fccstk d=0 b=19
                LDA     _fcc_q2
                STA     21,S   ; fccstk d=0 b=21
                LDA     _fcc_q3
                STA     23,S   ; fccstk d=0 b=23
                TYA
                LDA     35,S   ; fccstk d=0 b=35
                STA     33,S   ; fccstk d=0 b=33
_softdouble_L26
_softdouble_L25
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
                FGX2_FARCALL _fcc_ll_cmpu
                BEQ     *+7
                LDA     #0
                BRA     *+5
                LDA     #1
                CMP     #0
                BNE     *+5
                BRL     _softdouble_L40
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
                LDA     39,S   ; fccstk d=8 b=31
                STA     _fcc_q3
                LDA     37,S   ; fccstk d=8 b=29
                STA     _fcc_q2
                LDA     35,S   ; fccstk d=8 b=27
                STA     _fcc_long_hi
                LDA     33,S   ; fccstk d=8 b=25
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
                FGX2_FARCALL _fcc_ll_add
                STA     77,S   ; fccstk d=0 b=77
                TAY
                LDA     _fcc_long_hi
                STA     79,S   ; fccstk d=0 b=79
                LDA     _fcc_q2
                STA     81,S   ; fccstk d=0 b=81
                LDA     _fcc_q3
                STA     83,S   ; fccstk d=0 b=83
                TYA
                LDA     7,S   ; fccstk d=0 b=7
                STA     _fcc_q3
                LDA     5,S   ; fccstk d=0 b=5
                STA     _fcc_q2
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_long_hi
                LDA     1,S   ; fccstk d=0 b=1
                STA     85,S   ; fccstk d=0 b=85
                TAY
                LDA     _fcc_long_hi
                STA     87,S   ; fccstk d=0 b=87
                LDA     _fcc_q2
                STA     89,S   ; fccstk d=0 b=89
                LDA     _fcc_q3
                STA     91,S   ; fccstk d=0 b=91
                TYA
                BRL     _softdouble_L41
_softdouble_L40
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
                LDA     39,S   ; fccstk d=8 b=31
                STA     _fcc_q3
                LDA     37,S   ; fccstk d=8 b=29
                STA     _fcc_q2
                LDA     35,S   ; fccstk d=8 b=27
                STA     _fcc_long_hi
                LDA     33,S   ; fccstk d=8 b=25
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
                FGX2_FARCALL _fcc_ll_cmpu
                BPL     *+7
                LDA     #0
                BRA     *+5
                LDA     #1
                CMP     #0
                BNE     *+5
                BRL     _softdouble_L42
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
                LDA     39,S   ; fccstk d=8 b=31
                STA     _fcc_q3
                LDA     37,S   ; fccstk d=8 b=29
                STA     _fcc_q2
                LDA     35,S   ; fccstk d=8 b=27
                STA     _fcc_long_hi
                LDA     33,S   ; fccstk d=8 b=25
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
                FGX2_FARCALL _fcc_ll_sub
                STA     77,S   ; fccstk d=0 b=77
                TAY
                LDA     _fcc_long_hi
                STA     79,S   ; fccstk d=0 b=79
                LDA     _fcc_q2
                STA     81,S   ; fccstk d=0 b=81
                LDA     _fcc_q3
                STA     83,S   ; fccstk d=0 b=83
                TYA
                LDA     7,S   ; fccstk d=0 b=7
                STA     _fcc_q3
                LDA     5,S   ; fccstk d=0 b=5
                STA     _fcc_q2
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_long_hi
                LDA     1,S   ; fccstk d=0 b=1
                STA     85,S   ; fccstk d=0 b=85
                TAY
                LDA     _fcc_long_hi
                STA     87,S   ; fccstk d=0 b=87
                LDA     _fcc_q2
                STA     89,S   ; fccstk d=0 b=89
                LDA     _fcc_q3
                STA     91,S   ; fccstk d=0 b=91
                TYA
                BRL     _softdouble_L43
_softdouble_L42
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
                LDA     31,S   ; fccstk d=8 b=23
                STA     _fcc_q3
                LDA     29,S   ; fccstk d=8 b=21
                STA     _fcc_q2
                LDA     27,S   ; fccstk d=8 b=19
                STA     _fcc_long_hi
                LDA     25,S   ; fccstk d=8 b=17
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
                FGX2_FARCALL _fcc_ll_sub
                STA     77,S   ; fccstk d=0 b=77
                TAY
                LDA     _fcc_long_hi
                STA     79,S   ; fccstk d=0 b=79
                LDA     _fcc_q2
                STA     81,S   ; fccstk d=0 b=81
                LDA     _fcc_q3
                STA     83,S   ; fccstk d=0 b=83
                TYA
                LDA     15,S   ; fccstk d=0 b=15
                STA     _fcc_q3
                LDA     13,S   ; fccstk d=0 b=13
                STA     _fcc_q2
                LDA     11,S   ; fccstk d=0 b=11
                STA     _fcc_long_hi
                LDA     9,S   ; fccstk d=0 b=9
                STA     85,S   ; fccstk d=0 b=85
                TAY
                LDA     _fcc_long_hi
                STA     87,S   ; fccstk d=0 b=87
                LDA     _fcc_q2
                STA     89,S   ; fccstk d=0 b=89
                LDA     _fcc_q3
                STA     91,S   ; fccstk d=0 b=91
                TYA
_softdouble_L43
_softdouble_L41
                LDA     83,S   ; fccstk d=0 b=83
                STA     _fcc_q3
                LDA     81,S   ; fccstk d=0 b=81
                STA     _fcc_q2
                LDA     79,S   ; fccstk d=0 b=79
                STA     _fcc_long_hi
                LDA     77,S   ; fccstk d=0 b=77
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
                LDX     #0
                BIT     _fcc_long_hi
                BPL     *+5
                LDX     #$FFFF
                STX     _fcc_q2
                STX     _fcc_q3
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
                FGX2_FARCALL _fcc_ll_cmpu
                BEQ     *+7
                LDA     #0
                BRA     *+5
                LDA     #1
                CMP     #0
                BNE     *+5
                BRL     _softdouble_L44
                LDA     #0
                JSR     _fcc_long_from_int
                LDX     #0
                BIT     _fcc_long_hi
                BPL     *+5
                LDX     #$FFFF
                STX     _fcc_q2
                STX     _fcc_q3
                TAY
                TSC
                CLC
                ADC     #__adddf3_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_softdouble_L44
                LDA     83,S   ; fccstk d=0 b=83
                STA     _fcc_q3
                LDA     81,S   ; fccstk d=0 b=81
                STA     _fcc_q2
                LDA     79,S   ; fccstk d=0 b=79
                STA     _fcc_long_hi
                LDA     77,S   ; fccstk d=0 b=77
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
                STA     _fcc_q3
                LDA     #0
                STA     _fcc_q2
                LDA     #0
                STA     _fcc_long_hi
                LDA     #1
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #56
                STA     _fcc_long_b_lo
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                PLA
                STA     _fcc_q2
                PLA
                STA     _fcc_q3
                TYA
                FGX2_FARCALL _fcc_ll_shl
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
                LDX     #0
                BIT     _fcc_long_hi
                BPL     *+5
                LDX     #$FFFF
                STX     _fcc_q2
                STX     _fcc_q3
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
                FGX2_FARCALL _fcc_ll_sub
                FGX2_FARCALL _fcc_ll_com
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
                FGX2_FARCALL _fcc_ll_and
                ORA     _fcc_long_hi
                ORA     _fcc_q2
                ORA     _fcc_q3
                BNE     *+5
                BRL     _softdouble_L45
_softdouble_L46
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     83,S   ; fccstk d=0 b=83
                STA     _fcc_q3
                LDA     81,S   ; fccstk d=0 b=81
                STA     _fcc_q2
                LDA     79,S   ; fccstk d=0 b=79
                STA     _fcc_long_hi
                LDA     77,S   ; fccstk d=0 b=77
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
                LDX     #0
                BIT     _fcc_long_hi
                BPL     *+5
                LDX     #$FFFF
                STX     _fcc_q2
                STX     _fcc_q3
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
                FGX2_FARCALL _fcc_ll_and
                STA     93,S   ; fccstk d=0 b=93
                TAY
                LDA     _fcc_long_hi
                STA     95,S   ; fccstk d=0 b=95
                LDA     _fcc_q2
                STA     97,S   ; fccstk d=0 b=97
                LDA     _fcc_q3
                STA     99,S   ; fccstk d=0 b=99
                TYA
                LDA     83,S   ; fccstk d=0 b=83
                STA     _fcc_q3
                LDA     81,S   ; fccstk d=0 b=81
                STA     _fcc_q2
                LDA     79,S   ; fccstk d=0 b=79
                STA     _fcc_long_hi
                LDA     77,S   ; fccstk d=0 b=77
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
                STA     _fcc_long_b_lo
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                PLA
                STA     _fcc_q2
                PLA
                STA     _fcc_q3
                TYA
                FGX2_FARCALL _fcc_ll_shru
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     107,S   ; fccstk d=8 b=99
                STA     _fcc_q3
                LDA     105,S   ; fccstk d=8 b=97
                STA     _fcc_q2
                LDA     103,S   ; fccstk d=8 b=95
                STA     _fcc_long_hi
                LDA     101,S   ; fccstk d=8 b=93
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
                FGX2_FARCALL _fcc_ll_or
                STA     77,S   ; fccstk d=0 b=77
                TAY
                LDA     _fcc_long_hi
                STA     79,S   ; fccstk d=0 b=79
                LDA     _fcc_q2
                STA     81,S   ; fccstk d=0 b=81
                LDA     _fcc_q3
                STA     83,S   ; fccstk d=0 b=83
                TYA
                LDA     33,S   ; fccstk d=0 b=33
                CLC
                ADC     #1
                STA     33,S   ; fccstk d=0 b=33
_softdouble_L47
                LDA     83,S   ; fccstk d=0 b=83
                STA     _fcc_q3
                LDA     81,S   ; fccstk d=0 b=81
                STA     _fcc_q2
                LDA     79,S   ; fccstk d=0 b=79
                STA     _fcc_long_hi
                LDA     77,S   ; fccstk d=0 b=77
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
                STA     _fcc_q3
                LDA     #0
                STA     _fcc_q2
                LDA     #0
                STA     _fcc_long_hi
                LDA     #1
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #56
                STA     _fcc_long_b_lo
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                PLA
                STA     _fcc_q2
                PLA
                STA     _fcc_q3
                TYA
                FGX2_FARCALL _fcc_ll_shl
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
                LDX     #0
                BIT     _fcc_long_hi
                BPL     *+5
                LDX     #$FFFF
                STX     _fcc_q2
                STX     _fcc_q3
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
                FGX2_FARCALL _fcc_ll_sub
                FGX2_FARCALL _fcc_ll_com
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
                FGX2_FARCALL _fcc_ll_and
                ORA     _fcc_long_hi
                ORA     _fcc_q2
                ORA     _fcc_q3
                BNE     *+5
                BRL     _softdouble_L48
                BRL     _softdouble_L46
_softdouble_L48
_softdouble_L45
                LDA     83,S   ; fccstk d=0 b=83
                STA     _fcc_q3
                LDA     81,S   ; fccstk d=0 b=81
                STA     _fcc_q2
                LDA     79,S   ; fccstk d=0 b=79
                STA     _fcc_long_hi
                LDA     77,S   ; fccstk d=0 b=77
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
                STA     _fcc_q3
                LDA     #0
                STA     _fcc_q2
                LDA     #0
                STA     _fcc_long_hi
                LDA     #1
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #55
                STA     _fcc_long_b_lo
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                PLA
                STA     _fcc_q2
                PLA
                STA     _fcc_q3
                TYA
                FGX2_FARCALL _fcc_ll_shl
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
                FGX2_FARCALL _fcc_ll_and
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
                LDX     #0
                BIT     _fcc_long_hi
                BPL     *+5
                LDX     #$FFFF
                STX     _fcc_q2
                STX     _fcc_q3
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
                FGX2_FARCALL _fcc_ll_cmpu
                BEQ     *+7
                LDA     #0
                BRA     *+5
                LDA     #1
                CMP     #0
                BNE     *+5
                BRL     _softdouble_L50
                LDA     83,S   ; fccstk d=0 b=83
                STA     _fcc_q3
                LDA     81,S   ; fccstk d=0 b=81
                STA     _fcc_q2
                LDA     79,S   ; fccstk d=0 b=79
                STA     _fcc_long_hi
                LDA     77,S   ; fccstk d=0 b=77
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
                LDX     #0
                BIT     _fcc_long_hi
                BPL     *+5
                LDX     #$FFFF
                STX     _fcc_q2
                STX     _fcc_q3
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
                FGX2_FARCALL _fcc_ll_cmpu
                BNE     *+7
                LDA     #0
                BRA     *+5
                LDA     #1
                CMP     #0
                BNE     *+5
                BRL     _softdouble_L50
                LDA     #1
                BRL     _softdouble_L51
_softdouble_L50
                LDA     #0
_softdouble_L51
                CMP     #0
                BNE     *+5
                BRL     _softdouble_L49
_softdouble_L52
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     83,S   ; fccstk d=0 b=83
                STA     _fcc_q3
                LDA     81,S   ; fccstk d=0 b=81
                STA     _fcc_q2
                LDA     79,S   ; fccstk d=0 b=79
                STA     _fcc_long_hi
                LDA     77,S   ; fccstk d=0 b=77
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
                STA     _fcc_long_b_lo
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                PLA
                STA     _fcc_q2
                PLA
                STA     _fcc_q3
                TYA
                FGX2_FARCALL _fcc_ll_shl
                STA     77,S   ; fccstk d=0 b=77
                TAY
                LDA     _fcc_long_hi
                STA     79,S   ; fccstk d=0 b=79
                LDA     _fcc_q2
                STA     81,S   ; fccstk d=0 b=81
                LDA     _fcc_q3
                STA     83,S   ; fccstk d=0 b=83
                TYA
                LDA     33,S   ; fccstk d=0 b=33
                SEC
                SBC     #1
                STA     33,S   ; fccstk d=0 b=33
_softdouble_L53
                LDA     83,S   ; fccstk d=0 b=83
                STA     _fcc_q3
                LDA     81,S   ; fccstk d=0 b=81
                STA     _fcc_q2
                LDA     79,S   ; fccstk d=0 b=79
                STA     _fcc_long_hi
                LDA     77,S   ; fccstk d=0 b=77
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
                STA     _fcc_q3
                LDA     #0
                STA     _fcc_q2
                LDA     #0
                STA     _fcc_long_hi
                LDA     #1
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #55
                STA     _fcc_long_b_lo
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                PLA
                STA     _fcc_q2
                PLA
                STA     _fcc_q3
                TYA
                FGX2_FARCALL _fcc_ll_shl
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
                FGX2_FARCALL _fcc_ll_and
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
                LDX     #0
                BIT     _fcc_long_hi
                BPL     *+5
                LDX     #$FFFF
                STX     _fcc_q2
                STX     _fcc_q3
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
                FGX2_FARCALL _fcc_ll_cmpu
                BEQ     *+7
                LDA     #0
                BRA     *+5
                LDA     #1
                CMP     #0
                BNE     *+5
                BRL     _softdouble_L55
                LDA     83,S   ; fccstk d=0 b=83
                STA     _fcc_q3
                LDA     81,S   ; fccstk d=0 b=81
                STA     _fcc_q2
                LDA     79,S   ; fccstk d=0 b=79
                STA     _fcc_long_hi
                LDA     77,S   ; fccstk d=0 b=77
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
                LDX     #0
                BIT     _fcc_long_hi
                BPL     *+5
                LDX     #$FFFF
                STX     _fcc_q2
                STX     _fcc_q3
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
                FGX2_FARCALL _fcc_ll_cmpu
                BNE     *+7
                LDA     #0
                BRA     *+5
                LDA     #1
                CMP     #0
                BNE     *+5
                BRL     _softdouble_L55
                LDA     #1
                BRL     _softdouble_L56
_softdouble_L55
                LDA     #0
_softdouble_L56
                CMP     #0
                BNE     *+5
                BRL     _softdouble_L54
                BRL     _softdouble_L52
_softdouble_L54
_softdouble_L49
                LDA     83,S   ; fccstk d=0 b=83
                STA     _fcc_q3
                LDA     81,S   ; fccstk d=0 b=81
                STA     _fcc_q2
                LDA     79,S   ; fccstk d=0 b=79
                STA     _fcc_long_hi
                LDA     77,S   ; fccstk d=0 b=77
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
                STA     _fcc_long_b_lo
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                PLA
                STA     _fcc_q2
                PLA
                STA     _fcc_q3
                TYA
                FGX2_FARCALL _fcc_ll_shru
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
                LDX     #0
                BIT     _fcc_long_hi
                BPL     *+5
                LDX     #$FFFF
                STX     _fcc_q2
                STX     _fcc_q3
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
                FGX2_FARCALL _fcc_ll_and
                STA     101,S   ; fccstk d=0 b=101
                LDA     83,S   ; fccstk d=0 b=83
                STA     _fcc_q3
                LDA     81,S   ; fccstk d=0 b=81
                STA     _fcc_q2
                LDA     79,S   ; fccstk d=0 b=79
                STA     _fcc_long_hi
                LDA     77,S   ; fccstk d=0 b=77
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
                LDX     #0
                BIT     _fcc_long_hi
                BPL     *+5
                LDX     #$FFFF
                STX     _fcc_q2
                STX     _fcc_q3
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
                FGX2_FARCALL _fcc_ll_and
                STA     103,S   ; fccstk d=0 b=103
                LDA     83,S   ; fccstk d=0 b=83
                STA     _fcc_q3
                LDA     81,S   ; fccstk d=0 b=81
                STA     _fcc_q2
                LDA     79,S   ; fccstk d=0 b=79
                STA     _fcc_long_hi
                LDA     77,S   ; fccstk d=0 b=77
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
                STA     _fcc_long_b_lo
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                PLA
                STA     _fcc_q2
                PLA
                STA     _fcc_q3
                TYA
                FGX2_FARCALL _fcc_ll_shru
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
                LDX     #0
                BIT     _fcc_long_hi
                BPL     *+5
                LDX     #$FFFF
                STX     _fcc_q2
                STX     _fcc_q3
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
                FGX2_FARCALL _fcc_ll_and
                STA     105,S   ; fccstk d=0 b=105
                LDA     83,S   ; fccstk d=0 b=83
                STA     _fcc_q3
                LDA     81,S   ; fccstk d=0 b=81
                STA     _fcc_q2
                LDA     79,S   ; fccstk d=0 b=79
                STA     _fcc_long_hi
                LDA     77,S   ; fccstk d=0 b=77
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
                STA     _fcc_long_b_lo
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                PLA
                STA     _fcc_q2
                PLA
                STA     _fcc_q3
                TYA
                FGX2_FARCALL _fcc_ll_shru
                STA     77,S   ; fccstk d=0 b=77
                TAY
                LDA     _fcc_long_hi
                STA     79,S   ; fccstk d=0 b=79
                LDA     _fcc_q2
                STA     81,S   ; fccstk d=0 b=81
                LDA     _fcc_q3
                STA     83,S   ; fccstk d=0 b=83
                TYA
                LDA     101,S   ; fccstk d=0 b=101
                CMP     #0
                BNE     *+5
                BRL     _softdouble_L58
                LDA     103,S   ; fccstk d=0 b=103
                CMP     #0
                BEQ     *+5
                BRL     _softdouble_L60
                LDA     105,S   ; fccstk d=0 b=105
                CMP     #0
                BEQ     *+5
                BRL     _softdouble_L60
                LDA     #0
                BRL     _softdouble_L61
_softdouble_L60
                LDA     #1
_softdouble_L61
                CMP     #0
                BNE     *+5
                BRL     _softdouble_L58
                LDA     #1
                BRL     _softdouble_L59
_softdouble_L58
                LDA     #0
_softdouble_L59
                CMP     #0
                BNE     *+5
                BRL     _softdouble_L57
                LDA     83,S   ; fccstk d=0 b=83
                STA     _fcc_q3
                LDA     81,S   ; fccstk d=0 b=81
                STA     _fcc_q2
                LDA     79,S   ; fccstk d=0 b=79
                STA     _fcc_long_hi
                LDA     77,S   ; fccstk d=0 b=77
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                CLC
                ADC     #1
                TAY
                LDA     _fcc_long_hi
                ADC     #0
                STA     _fcc_long_hi
                LDA     _fcc_q2
                ADC     #0
                STA     _fcc_q2
                LDA     _fcc_q3
                ADC     #0
                STA     _fcc_q3
                TYA
                STA     85,S   ; fccstk d=8 b=77
                TAY
                LDA     _fcc_long_hi
                STA     87,S   ; fccstk d=8 b=79
                LDA     _fcc_q2
                STA     89,S   ; fccstk d=8 b=81
                LDA     _fcc_q3
                STA     91,S   ; fccstk d=8 b=83
                TYA
                PLA
                TAY
                PLA
                PLA
                PLA
                TYA
                LDA     83,S   ; fccstk d=0 b=83
                STA     _fcc_q3
                LDA     81,S   ; fccstk d=0 b=81
                STA     _fcc_q2
                LDA     79,S   ; fccstk d=0 b=79
                STA     _fcc_long_hi
                LDA     77,S   ; fccstk d=0 b=77
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
                STA     _fcc_q3
                LDA     #0
                STA     _fcc_q2
                LDA     #0
                STA     _fcc_long_hi
                LDA     #1
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #53
                STA     _fcc_long_b_lo
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                PLA
                STA     _fcc_q2
                PLA
                STA     _fcc_q3
                TYA
                FGX2_FARCALL _fcc_ll_shl
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
                FGX2_FARCALL _fcc_ll_and
                ORA     _fcc_long_hi
                ORA     _fcc_q2
                ORA     _fcc_q3
                BNE     *+5
                BRL     _softdouble_L62
                LDA     83,S   ; fccstk d=0 b=83
                STA     _fcc_q3
                LDA     81,S   ; fccstk d=0 b=81
                STA     _fcc_q2
                LDA     79,S   ; fccstk d=0 b=79
                STA     _fcc_long_hi
                LDA     77,S   ; fccstk d=0 b=77
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
                STA     _fcc_long_b_lo
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                PLA
                STA     _fcc_q2
                PLA
                STA     _fcc_q3
                TYA
                FGX2_FARCALL _fcc_ll_shru
                STA     77,S   ; fccstk d=0 b=77
                TAY
                LDA     _fcc_long_hi
                STA     79,S   ; fccstk d=0 b=79
                LDA     _fcc_q2
                STA     81,S   ; fccstk d=0 b=81
                LDA     _fcc_q3
                STA     83,S   ; fccstk d=0 b=83
                TYA
                LDA     33,S   ; fccstk d=0 b=33
                CLC
                ADC     #1
                STA     33,S   ; fccstk d=0 b=33
_softdouble_L62
_softdouble_L57
                LDA     83,S   ; fccstk d=0 b=83
                STA     _fcc_q3
                LDA     81,S   ; fccstk d=0 b=81
                STA     _fcc_q2
                LDA     79,S   ; fccstk d=0 b=79
                STA     _fcc_long_hi
                LDA     77,S   ; fccstk d=0 b=77
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     41,S   ; fccstk d=8 b=33
                PHA
                LDA     101,S   ; fccstk d=10 b=91
                STA     _fcc_q3
                LDA     99,S   ; fccstk d=10 b=89
                STA     _fcc_q2
                LDA     97,S   ; fccstk d=10 b=87
                STA     _fcc_long_hi
                LDA     95,S   ; fccstk d=10 b=85
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                FGX2_FARCALL _softdouble_dpack
                TAY
                TSC
                CLC
                ADC     #18
                TCS
                TYA
                TAY
                TSC
                CLC
                ADC     #__adddf3_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
__adddf3_FRAMESIZE   EQU     106
__adddf3_STKGUARD    EQU     0
                FGX2_EXPORT __subdf3
__subdf3            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #__subdf3_FRAMESIZE
                DO      __subdf3_STKGUARD
                BCC     __subdf3_stkovf
                CMP     _fcc_stkfloor
                BCS     __subdf3_stkok
__subdf3_stkovf       JMP     _fcc_stkoflow
                FIN
__subdf3_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      20+__subdf3_FRAMESIZE/256
                TSC
                CLC
                ADC     #20+__subdf3_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     20+__subdf3_FRAMESIZE,S   ; fccstk d=0 b=20 fs
                FIN
                STA     _fcc_q3
                DO      18+__subdf3_FRAMESIZE/256
                TSC
                CLC
                ADC     #18+__subdf3_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     18+__subdf3_FRAMESIZE,S   ; fccstk d=0 b=18 fs
                FIN
                STA     _fcc_q2
                DO      16+__subdf3_FRAMESIZE/256
                TSC
                CLC
                ADC     #16+__subdf3_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     16+__subdf3_FRAMESIZE,S   ; fccstk d=0 b=16 fs
                FIN
                STA     _fcc_long_hi
                DO      14+__subdf3_FRAMESIZE/256
                TSC
                CLC
                ADC     #14+__subdf3_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     14+__subdf3_FRAMESIZE,S   ; fccstk d=0 b=14 fs
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
                LDA     #32768
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
                FGX2_FARCALL _fcc_ll_xor
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                DO      20+__subdf3_FRAMESIZE/256
                TSC
                CLC
                ADC     #20+__subdf3_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     20+__subdf3_FRAMESIZE,S   ; fccstk d=8 b=12 fs
                FIN
                STA     _fcc_q3
                DO      18+__subdf3_FRAMESIZE/256
                TSC
                CLC
                ADC     #18+__subdf3_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     18+__subdf3_FRAMESIZE,S   ; fccstk d=8 b=10 fs
                FIN
                STA     _fcc_q2
                DO      16+__subdf3_FRAMESIZE/256
                TSC
                CLC
                ADC     #16+__subdf3_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     16+__subdf3_FRAMESIZE,S   ; fccstk d=8 b=8 fs
                FIN
                STA     _fcc_long_hi
                DO      14+__subdf3_FRAMESIZE/256
                TSC
                CLC
                ADC     #14+__subdf3_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     14+__subdf3_FRAMESIZE,S   ; fccstk d=8 b=6 fs
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
                FGX2_FARCALL __adddf3
                TAY
                TSC
                CLC
                ADC     #16
                TCS
                TYA
                TAY
                TSC
                CLC
                ADC     #__subdf3_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
__subdf3_FRAMESIZE   EQU     0
__subdf3_STKGUARD    EQU     0
                FGX2_EXPORT __negdf2
__negdf2            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #__negdf2_FRAMESIZE
                DO      __negdf2_STKGUARD
                BCC     __negdf2_stkovf
                CMP     _fcc_stkfloor
                BCS     __negdf2_stkok
__negdf2_stkovf       JMP     _fcc_stkoflow
                FIN
__negdf2_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      12+__negdf2_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+__negdf2_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+__negdf2_FRAMESIZE,S   ; fccstk d=0 b=12 fs
                FIN
                STA     _fcc_q3
                DO      10+__negdf2_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+__negdf2_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+__negdf2_FRAMESIZE,S   ; fccstk d=0 b=10 fs
                FIN
                STA     _fcc_q2
                DO      8+__negdf2_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+__negdf2_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+__negdf2_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_long_hi
                DO      6+__negdf2_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+__negdf2_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+__negdf2_FRAMESIZE,S   ; fccstk d=0 b=6 fs
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
                LDA     #32768
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
                FGX2_FARCALL _fcc_ll_xor
                TAY
                TSC
                CLC
                ADC     #__negdf2_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
__negdf2_FRAMESIZE   EQU     0
__negdf2_STKGUARD    EQU     0
                FGX2_EXPORT _softdouble_mulhi64Aligned
_softdouble_mulhi64Aligned            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #_softdouble_mulhi64Aligned_FRAMESIZE
                DO      _softdouble_mulhi64Aligned_STKGUARD
                BCC     _softdouble_mulhi64Aligned_stkovf
                CMP     _fcc_stkfloor
                BCS     _softdouble_mulhi64Aligned_stkok
_softdouble_mulhi64Aligned_stkovf       JMP     _fcc_stkoflow
                FIN
_softdouble_mulhi64Aligned_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      12+_softdouble_mulhi64Aligned_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+_softdouble_mulhi64Aligned_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+_softdouble_mulhi64Aligned_FRAMESIZE,S   ; fccstk d=0 b=12 fs
                FIN
                DO      10+_softdouble_mulhi64Aligned_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+_softdouble_mulhi64Aligned_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+_softdouble_mulhi64Aligned_FRAMESIZE,S   ; fccstk d=0 b=10 fs
                FIN
                DO      8+_softdouble_mulhi64Aligned_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_softdouble_mulhi64Aligned_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_softdouble_mulhi64Aligned_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_long_hi
                DO      6+_softdouble_mulhi64Aligned_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_softdouble_mulhi64Aligned_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_softdouble_mulhi64Aligned_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     1,S   ; fccstk d=0 b=1
                TAY
                LDA     _fcc_long_hi
                STA     3,S   ; fccstk d=0 b=3
                TYA
                DO      12+_softdouble_mulhi64Aligned_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+_softdouble_mulhi64Aligned_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+_softdouble_mulhi64Aligned_FRAMESIZE,S   ; fccstk d=0 b=12 fs
                FIN
                STA     _fcc_q3
                DO      10+_softdouble_mulhi64Aligned_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+_softdouble_mulhi64Aligned_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+_softdouble_mulhi64Aligned_FRAMESIZE,S   ; fccstk d=0 b=10 fs
                FIN
                STA     _fcc_q2
                DO      8+_softdouble_mulhi64Aligned_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_softdouble_mulhi64Aligned_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_softdouble_mulhi64Aligned_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_long_hi
                DO      6+_softdouble_mulhi64Aligned_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_softdouble_mulhi64Aligned_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_softdouble_mulhi64Aligned_FRAMESIZE,S   ; fccstk d=0 b=6 fs
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
                LDA     #32
                STA     _fcc_long_b_lo
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                PLA
                STA     _fcc_q2
                PLA
                STA     _fcc_q3
                TYA
                FGX2_FARCALL _fcc_ll_shru
                STA     5,S   ; fccstk d=0 b=5
                TAY
                LDA     _fcc_long_hi
                STA     7,S   ; fccstk d=0 b=7
                TYA
                DO      20+_softdouble_mulhi64Aligned_FRAMESIZE/256
                TSC
                CLC
                ADC     #20+_softdouble_mulhi64Aligned_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     20+_softdouble_mulhi64Aligned_FRAMESIZE,S   ; fccstk d=0 b=20 fs
                FIN
                DO      18+_softdouble_mulhi64Aligned_FRAMESIZE/256
                TSC
                CLC
                ADC     #18+_softdouble_mulhi64Aligned_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     18+_softdouble_mulhi64Aligned_FRAMESIZE,S   ; fccstk d=0 b=18 fs
                FIN
                DO      16+_softdouble_mulhi64Aligned_FRAMESIZE/256
                TSC
                CLC
                ADC     #16+_softdouble_mulhi64Aligned_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     16+_softdouble_mulhi64Aligned_FRAMESIZE,S   ; fccstk d=0 b=16 fs
                FIN
                STA     _fcc_long_hi
                DO      14+_softdouble_mulhi64Aligned_FRAMESIZE/256
                TSC
                CLC
                ADC     #14+_softdouble_mulhi64Aligned_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     14+_softdouble_mulhi64Aligned_FRAMESIZE,S   ; fccstk d=0 b=14 fs
                FIN
                STA     9,S   ; fccstk d=0 b=9
                TAY
                LDA     _fcc_long_hi
                STA     11,S   ; fccstk d=0 b=11
                TYA
                DO      20+_softdouble_mulhi64Aligned_FRAMESIZE/256
                TSC
                CLC
                ADC     #20+_softdouble_mulhi64Aligned_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     20+_softdouble_mulhi64Aligned_FRAMESIZE,S   ; fccstk d=0 b=20 fs
                FIN
                STA     _fcc_q3
                DO      18+_softdouble_mulhi64Aligned_FRAMESIZE/256
                TSC
                CLC
                ADC     #18+_softdouble_mulhi64Aligned_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     18+_softdouble_mulhi64Aligned_FRAMESIZE,S   ; fccstk d=0 b=18 fs
                FIN
                STA     _fcc_q2
                DO      16+_softdouble_mulhi64Aligned_FRAMESIZE/256
                TSC
                CLC
                ADC     #16+_softdouble_mulhi64Aligned_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     16+_softdouble_mulhi64Aligned_FRAMESIZE,S   ; fccstk d=0 b=16 fs
                FIN
                STA     _fcc_long_hi
                DO      14+_softdouble_mulhi64Aligned_FRAMESIZE/256
                TSC
                CLC
                ADC     #14+_softdouble_mulhi64Aligned_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     14+_softdouble_mulhi64Aligned_FRAMESIZE,S   ; fccstk d=0 b=14 fs
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
                LDA     #32
                STA     _fcc_long_b_lo
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                PLA
                STA     _fcc_q2
                PLA
                STA     _fcc_q3
                TYA
                FGX2_FARCALL _fcc_ll_shru
                STA     13,S   ; fccstk d=0 b=13
                TAY
                LDA     _fcc_long_hi
                STA     15,S   ; fccstk d=0 b=15
                TYA
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_long_hi
                LDA     1,S   ; fccstk d=0 b=1
                STZ     _fcc_q2
                STZ     _fcc_q3
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     19,S   ; fccstk d=8 b=11
                STA     _fcc_long_hi
                LDA     17,S   ; fccstk d=8 b=9
                STZ     _fcc_q2
                STZ     _fcc_q3
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
                FGX2_FARCALL _fcc_ll_mul
                STA     17,S   ; fccstk d=0 b=17
                TAY
                LDA     _fcc_long_hi
                STA     19,S   ; fccstk d=0 b=19
                LDA     _fcc_q2
                STA     21,S   ; fccstk d=0 b=21
                LDA     _fcc_q3
                STA     23,S   ; fccstk d=0 b=23
                TYA
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_long_hi
                LDA     1,S   ; fccstk d=0 b=1
                STZ     _fcc_q2
                STZ     _fcc_q3
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
                STA     _fcc_long_hi
                LDA     21,S   ; fccstk d=8 b=13
                STZ     _fcc_q2
                STZ     _fcc_q3
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
                FGX2_FARCALL _fcc_ll_mul
                STA     25,S   ; fccstk d=0 b=25
                TAY
                LDA     _fcc_long_hi
                STA     27,S   ; fccstk d=0 b=27
                LDA     _fcc_q2
                STA     29,S   ; fccstk d=0 b=29
                LDA     _fcc_q3
                STA     31,S   ; fccstk d=0 b=31
                TYA
                LDA     7,S   ; fccstk d=0 b=7
                STA     _fcc_long_hi
                LDA     5,S   ; fccstk d=0 b=5
                STZ     _fcc_q2
                STZ     _fcc_q3
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     19,S   ; fccstk d=8 b=11
                STA     _fcc_long_hi
                LDA     17,S   ; fccstk d=8 b=9
                STZ     _fcc_q2
                STZ     _fcc_q3
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
                FGX2_FARCALL _fcc_ll_mul
                STA     33,S   ; fccstk d=0 b=33
                TAY
                LDA     _fcc_long_hi
                STA     35,S   ; fccstk d=0 b=35
                LDA     _fcc_q2
                STA     37,S   ; fccstk d=0 b=37
                LDA     _fcc_q3
                STA     39,S   ; fccstk d=0 b=39
                TYA
                LDA     7,S   ; fccstk d=0 b=7
                STA     _fcc_long_hi
                LDA     5,S   ; fccstk d=0 b=5
                STZ     _fcc_q2
                STZ     _fcc_q3
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
                STA     _fcc_long_hi
                LDA     21,S   ; fccstk d=8 b=13
                STZ     _fcc_q2
                STZ     _fcc_q3
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
                FGX2_FARCALL _fcc_ll_mul
                STA     41,S   ; fccstk d=0 b=41
                TAY
                LDA     _fcc_long_hi
                STA     43,S   ; fccstk d=0 b=43
                LDA     _fcc_q2
                STA     45,S   ; fccstk d=0 b=45
                LDA     _fcc_q3
                STA     47,S   ; fccstk d=0 b=47
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
                FGX2_FARCALL _fcc_ll_add
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     31,S   ; fccstk d=8 b=23
                STA     _fcc_q3
                LDA     29,S   ; fccstk d=8 b=21
                STA     _fcc_q2
                LDA     27,S   ; fccstk d=8 b=19
                STA     _fcc_long_hi
                LDA     25,S   ; fccstk d=8 b=17
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #32
                STA     _fcc_long_b_lo
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                PLA
                STA     _fcc_q2
                PLA
                STA     _fcc_q3
                TYA
                FGX2_FARCALL _fcc_ll_shru
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
                FGX2_FARCALL _fcc_ll_add
                STA     49,S   ; fccstk d=0 b=49
                TAY
                LDA     _fcc_long_hi
                STA     51,S   ; fccstk d=0 b=51
                LDA     _fcc_q2
                STA     53,S   ; fccstk d=0 b=53
                LDA     _fcc_q3
                STA     55,S   ; fccstk d=0 b=55
                TYA
                LDA     47,S   ; fccstk d=0 b=47
                STA     _fcc_q3
                LDA     45,S   ; fccstk d=0 b=45
                STA     _fcc_q2
                LDA     43,S   ; fccstk d=0 b=43
                STA     _fcc_long_hi
                LDA     41,S   ; fccstk d=0 b=41
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     63,S   ; fccstk d=8 b=55
                STA     _fcc_q3
                LDA     61,S   ; fccstk d=8 b=53
                STA     _fcc_q2
                LDA     59,S   ; fccstk d=8 b=51
                STA     _fcc_long_hi
                LDA     57,S   ; fccstk d=8 b=49
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #32
                STA     _fcc_long_b_lo
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                PLA
                STA     _fcc_q2
                PLA
                STA     _fcc_q3
                TYA
                FGX2_FARCALL _fcc_ll_shru
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
                FGX2_FARCALL _fcc_ll_add
                STA     57,S   ; fccstk d=0 b=57
                TAY
                LDA     _fcc_long_hi
                STA     59,S   ; fccstk d=0 b=59
                LDA     _fcc_q2
                STA     61,S   ; fccstk d=0 b=61
                LDA     _fcc_q3
                STA     63,S   ; fccstk d=0 b=63
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
                LDA     #0
                STA     _fcc_q3
                LDA     #0
                STA     _fcc_q2
                LDA     #65535
                STA     _fcc_long_hi
                LDA     #65535
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
                FGX2_FARCALL _fcc_ll_and
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     63,S   ; fccstk d=8 b=55
                STA     _fcc_q3
                LDA     61,S   ; fccstk d=8 b=53
                STA     _fcc_q2
                LDA     59,S   ; fccstk d=8 b=51
                STA     _fcc_long_hi
                LDA     57,S   ; fccstk d=8 b=49
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
                STA     _fcc_q3
                LDA     #0
                STA     _fcc_q2
                LDA     #65535
                STA     _fcc_long_hi
                LDA     #65535
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
                FGX2_FARCALL _fcc_ll_and
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #32
                STA     _fcc_long_b_lo
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                PLA
                STA     _fcc_q2
                PLA
                STA     _fcc_q3
                TYA
                FGX2_FARCALL _fcc_ll_shl
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
                FGX2_FARCALL _fcc_ll_or
                STA     65,S   ; fccstk d=0 b=65
                TAY
                LDA     _fcc_long_hi
                STA     67,S   ; fccstk d=0 b=67
                LDA     _fcc_q2
                STA     69,S   ; fccstk d=0 b=69
                LDA     _fcc_q3
                STA     71,S   ; fccstk d=0 b=71
                TYA
                LDA     63,S   ; fccstk d=0 b=63
                STA     _fcc_q3
                LDA     61,S   ; fccstk d=0 b=61
                STA     _fcc_q2
                LDA     59,S   ; fccstk d=0 b=59
                STA     _fcc_long_hi
                LDA     57,S   ; fccstk d=0 b=57
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
                STA     _fcc_q3
                LDA     #0
                STA     _fcc_q2
                LDA     #0
                STA     _fcc_long_hi
                LDA     #1
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #41
                STA     _fcc_long_b_lo
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                PLA
                STA     _fcc_q2
                PLA
                STA     _fcc_q3
                TYA
                FGX2_FARCALL _fcc_ll_shl
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
                FGX2_FARCALL _fcc_ll_and
                ORA     _fcc_long_hi
                ORA     _fcc_q2
                ORA     _fcc_q3
                BNE     *+5
                BRL     _softdouble_L63
                DO      24+_softdouble_mulhi64Aligned_FRAMESIZE/256
                TSC
                CLC
                ADC     #24+_softdouble_mulhi64Aligned_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     24+_softdouble_mulhi64Aligned_FRAMESIZE,S   ; fccstk d=0 b=24 fs
                FIN
                STA     _fcc_fpr0+2
                DO      22+_softdouble_mulhi64Aligned_FRAMESIZE/256
                TSC
                CLC
                ADC     #22+_softdouble_mulhi64Aligned_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     22+_softdouble_mulhi64Aligned_FRAMESIZE,S   ; fccstk d=0 b=22 fs
                FIN
                STA     _fcc_fpr0
                LDA     #1
                STA     [_fcc_fpr0]
                LDA     71,S   ; fccstk d=0 b=71
                STA     _fcc_q3
                LDA     69,S   ; fccstk d=0 b=69
                STA     _fcc_q2
                LDA     67,S   ; fccstk d=0 b=67
                STA     _fcc_long_hi
                LDA     65,S   ; fccstk d=0 b=65
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #52
                STA     _fcc_long_b_lo
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                PLA
                STA     _fcc_q2
                PLA
                STA     _fcc_q3
                TYA
                FGX2_FARCALL _fcc_ll_shru
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
                LDX     #0
                BIT     _fcc_long_hi
                BPL     *+5
                LDX     #$FFFF
                STX     _fcc_q2
                STX     _fcc_q3
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
                FGX2_FARCALL _fcc_ll_and
                STA     73,S   ; fccstk d=0 b=73
                LDA     71,S   ; fccstk d=0 b=71
                STA     _fcc_q3
                LDA     69,S   ; fccstk d=0 b=69
                STA     _fcc_q2
                LDA     67,S   ; fccstk d=0 b=67
                STA     _fcc_long_hi
                LDA     65,S   ; fccstk d=0 b=65
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
                STA     _fcc_q3
                LDA     #0
                STA     _fcc_q2
                LDA     #0
                STA     _fcc_long_hi
                LDA     #1
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #52
                STA     _fcc_long_b_lo
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                PLA
                STA     _fcc_q2
                PLA
                STA     _fcc_q3
                TYA
                FGX2_FARCALL _fcc_ll_shl
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
                LDX     #0
                BIT     _fcc_long_hi
                BPL     *+5
                LDX     #$FFFF
                STX     _fcc_q2
                STX     _fcc_q3
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
                FGX2_FARCALL _fcc_ll_sub
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
                FGX2_FARCALL _fcc_ll_and
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
                LDX     #0
                BIT     _fcc_long_hi
                BPL     *+5
                LDX     #$FFFF
                STX     _fcc_q2
                STX     _fcc_q3
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
                FGX2_FARCALL _fcc_ll_cmpu
                BNE     *+7
                LDA     #0
                BRA     *+5
                LDA     #1
                STA     75,S   ; fccstk d=0 b=75
                DO      28+_softdouble_mulhi64Aligned_FRAMESIZE/256
                TSC
                CLC
                ADC     #28+_softdouble_mulhi64Aligned_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     28+_softdouble_mulhi64Aligned_FRAMESIZE,S   ; fccstk d=0 b=28 fs
                FIN
                STA     _fcc_fpr0+2
                DO      26+_softdouble_mulhi64Aligned_FRAMESIZE/256
                TSC
                CLC
                ADC     #26+_softdouble_mulhi64Aligned_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     26+_softdouble_mulhi64Aligned_FRAMESIZE,S   ; fccstk d=0 b=26 fs
                FIN
                STA     _fcc_fpr0
                LDA     73,S   ; fccstk d=0 b=73
                ASL
                ORA     75,S   ; fccstk d=0 b=75
                STA     [_fcc_fpr0]
                LDA     63,S   ; fccstk d=0 b=63
                STA     _fcc_q3
                LDA     61,S   ; fccstk d=0 b=61
                STA     _fcc_q2
                LDA     59,S   ; fccstk d=0 b=59
                STA     _fcc_long_hi
                LDA     57,S   ; fccstk d=0 b=57
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
                STA     _fcc_long_b_lo
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                PLA
                STA     _fcc_q2
                PLA
                STA     _fcc_q3
                TYA
                FGX2_FARCALL _fcc_ll_shl
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     79,S   ; fccstk d=8 b=71
                STA     _fcc_q3
                LDA     77,S   ; fccstk d=8 b=69
                STA     _fcc_q2
                LDA     75,S   ; fccstk d=8 b=67
                STA     _fcc_long_hi
                LDA     73,S   ; fccstk d=8 b=65
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #53
                STA     _fcc_long_b_lo
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                PLA
                STA     _fcc_q2
                PLA
                STA     _fcc_q3
                TYA
                FGX2_FARCALL _fcc_ll_shru
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
                FGX2_FARCALL _fcc_ll_or
                TAY
                TSC
                CLC
                ADC     #_softdouble_mulhi64Aligned_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_softdouble_L63
                DO      24+_softdouble_mulhi64Aligned_FRAMESIZE/256
                TSC
                CLC
                ADC     #24+_softdouble_mulhi64Aligned_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     24+_softdouble_mulhi64Aligned_FRAMESIZE,S   ; fccstk d=0 b=24 fs
                FIN
                STA     _fcc_fpr0+2
                DO      22+_softdouble_mulhi64Aligned_FRAMESIZE/256
                TSC
                CLC
                ADC     #22+_softdouble_mulhi64Aligned_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     22+_softdouble_mulhi64Aligned_FRAMESIZE,S   ; fccstk d=0 b=22 fs
                FIN
                STA     _fcc_fpr0
                LDA     #0
                STA     [_fcc_fpr0]
                LDA     71,S   ; fccstk d=0 b=71
                STA     _fcc_q3
                LDA     69,S   ; fccstk d=0 b=69
                STA     _fcc_q2
                LDA     67,S   ; fccstk d=0 b=67
                STA     _fcc_long_hi
                LDA     65,S   ; fccstk d=0 b=65
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #51
                STA     _fcc_long_b_lo
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                PLA
                STA     _fcc_q2
                PLA
                STA     _fcc_q3
                TYA
                FGX2_FARCALL _fcc_ll_shru
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
                LDX     #0
                BIT     _fcc_long_hi
                BPL     *+5
                LDX     #$FFFF
                STX     _fcc_q2
                STX     _fcc_q3
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
                FGX2_FARCALL _fcc_ll_and
                STA     77,S   ; fccstk d=0 b=77
                LDA     71,S   ; fccstk d=0 b=71
                STA     _fcc_q3
                LDA     69,S   ; fccstk d=0 b=69
                STA     _fcc_q2
                LDA     67,S   ; fccstk d=0 b=67
                STA     _fcc_long_hi
                LDA     65,S   ; fccstk d=0 b=65
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
                STA     _fcc_q3
                LDA     #0
                STA     _fcc_q2
                LDA     #0
                STA     _fcc_long_hi
                LDA     #1
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #51
                STA     _fcc_long_b_lo
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                PLA
                STA     _fcc_q2
                PLA
                STA     _fcc_q3
                TYA
                FGX2_FARCALL _fcc_ll_shl
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
                LDX     #0
                BIT     _fcc_long_hi
                BPL     *+5
                LDX     #$FFFF
                STX     _fcc_q2
                STX     _fcc_q3
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
                FGX2_FARCALL _fcc_ll_sub
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
                FGX2_FARCALL _fcc_ll_and
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
                LDX     #0
                BIT     _fcc_long_hi
                BPL     *+5
                LDX     #$FFFF
                STX     _fcc_q2
                STX     _fcc_q3
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
                FGX2_FARCALL _fcc_ll_cmpu
                BNE     *+7
                LDA     #0
                BRA     *+5
                LDA     #1
                STA     79,S   ; fccstk d=0 b=79
                DO      28+_softdouble_mulhi64Aligned_FRAMESIZE/256
                TSC
                CLC
                ADC     #28+_softdouble_mulhi64Aligned_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     28+_softdouble_mulhi64Aligned_FRAMESIZE,S   ; fccstk d=0 b=28 fs
                FIN
                STA     _fcc_fpr0+2
                DO      26+_softdouble_mulhi64Aligned_FRAMESIZE/256
                TSC
                CLC
                ADC     #26+_softdouble_mulhi64Aligned_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     26+_softdouble_mulhi64Aligned_FRAMESIZE,S   ; fccstk d=0 b=26 fs
                FIN
                STA     _fcc_fpr0
                LDA     77,S   ; fccstk d=0 b=77
                ASL
                ORA     79,S   ; fccstk d=0 b=79
                STA     [_fcc_fpr0]
                LDA     63,S   ; fccstk d=0 b=63
                STA     _fcc_q3
                LDA     61,S   ; fccstk d=0 b=61
                STA     _fcc_q2
                LDA     59,S   ; fccstk d=0 b=59
                STA     _fcc_long_hi
                LDA     57,S   ; fccstk d=0 b=57
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #12
                STA     _fcc_long_b_lo
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                PLA
                STA     _fcc_q2
                PLA
                STA     _fcc_q3
                TYA
                FGX2_FARCALL _fcc_ll_shl
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     79,S   ; fccstk d=8 b=71
                STA     _fcc_q3
                LDA     77,S   ; fccstk d=8 b=69
                STA     _fcc_q2
                LDA     75,S   ; fccstk d=8 b=67
                STA     _fcc_long_hi
                LDA     73,S   ; fccstk d=8 b=65
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #52
                STA     _fcc_long_b_lo
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                PLA
                STA     _fcc_q2
                PLA
                STA     _fcc_q3
                TYA
                FGX2_FARCALL _fcc_ll_shru
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
                FGX2_FARCALL _fcc_ll_or
                TAY
                TSC
                CLC
                ADC     #_softdouble_mulhi64Aligned_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_softdouble_mulhi64Aligned_FRAMESIZE   EQU     80
_softdouble_mulhi64Aligned_STKGUARD    EQU     0
                FGX2_EXPORT __muldf3
__muldf3            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #__muldf3_FRAMESIZE
                DO      __muldf3_STKGUARD
                BCC     __muldf3_stkovf
                CMP     _fcc_stkfloor
                BCS     __muldf3_stkok
__muldf3_stkovf       JMP     _fcc_stkoflow
                FIN
__muldf3_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
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
                DO      24+__muldf3_FRAMESIZE/256
                TSC
                CLC
                ADC     #24+__muldf3_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     24+__muldf3_FRAMESIZE,S   ; fccstk d=12 b=12 fs
                FIN
                STA     _fcc_q3
                DO      22+__muldf3_FRAMESIZE/256
                TSC
                CLC
                ADC     #22+__muldf3_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     22+__muldf3_FRAMESIZE,S   ; fccstk d=12 b=10 fs
                FIN
                STA     _fcc_q2
                DO      20+__muldf3_FRAMESIZE/256
                TSC
                CLC
                ADC     #20+__muldf3_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     20+__muldf3_FRAMESIZE,S   ; fccstk d=12 b=8 fs
                FIN
                STA     _fcc_long_hi
                DO      18+__muldf3_FRAMESIZE/256
                TSC
                CLC
                ADC     #18+__muldf3_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     18+__muldf3_FRAMESIZE,S   ; fccstk d=12 b=6 fs
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
                FGX2_FARCALL _softdouble_dclass
                TAY
                TSC
                CLC
                ADC     #20
                TCS
                TYA
                STA     37,S   ; fccstk d=0 b=37
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
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #34
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
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
                DO      32+__muldf3_FRAMESIZE/256
                TSC
                CLC
                ADC     #32+__muldf3_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     32+__muldf3_FRAMESIZE,S   ; fccstk d=12 b=20 fs
                FIN
                STA     _fcc_q3
                DO      30+__muldf3_FRAMESIZE/256
                TSC
                CLC
                ADC     #30+__muldf3_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     30+__muldf3_FRAMESIZE,S   ; fccstk d=12 b=18 fs
                FIN
                STA     _fcc_q2
                DO      28+__muldf3_FRAMESIZE/256
                TSC
                CLC
                ADC     #28+__muldf3_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     28+__muldf3_FRAMESIZE,S   ; fccstk d=12 b=16 fs
                FIN
                STA     _fcc_long_hi
                DO      26+__muldf3_FRAMESIZE/256
                TSC
                CLC
                ADC     #26+__muldf3_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     26+__muldf3_FRAMESIZE,S   ; fccstk d=12 b=14 fs
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
                FGX2_FARCALL _softdouble_dclass
                TAY
                TSC
                CLC
                ADC     #20
                TCS
                TYA
                STA     39,S   ; fccstk d=0 b=39
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
                FGX2_FARCALL _fcc_ll_xor
                STA     41,S   ; fccstk d=0 b=41
                TAY
                LDA     _fcc_long_hi
                STA     43,S   ; fccstk d=0 b=43
                LDA     _fcc_q2
                STA     45,S   ; fccstk d=0 b=45
                LDA     _fcc_q3
                STA     47,S   ; fccstk d=0 b=47
                TYA
                LDA     37,S   ; fccstk d=0 b=37
                TAX
                TXA
                CMP     #0
                BNE     *+5
                BRL     _softdouble_L65
                LDA     39,S   ; fccstk d=0 b=39
                TAX
                TXA
                CMP     #0
                BNE     *+5
                BRL     _softdouble_L65
                LDA     #0
                BRL     _softdouble_L66
_softdouble_L65
                LDA     #1
_softdouble_L66
                CMP     #0
                BNE     *+5
                BRL     _softdouble_L64
                LDA     47,S   ; fccstk d=0 b=47
                STA     _fcc_q3
                LDA     45,S   ; fccstk d=0 b=45
                STA     _fcc_q2
                LDA     43,S   ; fccstk d=0 b=43
                STA     _fcc_long_hi
                LDA     41,S   ; fccstk d=0 b=41
                TAY
                TSC
                CLC
                ADC     #__muldf3_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_softdouble_L64
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #50
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #48
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     39,S   ; fccstk d=8 b=31
                STA     _fcc_q3
                LDA     37,S   ; fccstk d=8 b=29
                STA     _fcc_q2
                LDA     35,S   ; fccstk d=8 b=27
                STA     _fcc_long_hi
                LDA     33,S   ; fccstk d=8 b=25
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     39,S   ; fccstk d=16 b=23
                STA     _fcc_q3
                LDA     37,S   ; fccstk d=16 b=21
                STA     _fcc_q2
                LDA     35,S   ; fccstk d=16 b=19
                STA     _fcc_long_hi
                LDA     33,S   ; fccstk d=16 b=17
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                FGX2_FARCALL _softdouble_mulhi64Aligned
                TAY
                TSC
                CLC
                ADC     #24
                TCS
                TYA
                STA     53,S   ; fccstk d=0 b=53
                TAY
                LDA     _fcc_long_hi
                STA     55,S   ; fccstk d=0 b=55
                LDA     _fcc_q2
                STA     57,S   ; fccstk d=0 b=57
                LDA     _fcc_q3
                STA     59,S   ; fccstk d=0 b=59
                TYA
                LDA     33,S   ; fccstk d=0 b=33
                CLC
                ADC     35,S   ; fccstk d=0 b=35
                CLC
                ADC     49,S   ; fccstk d=0 b=49
                STA     61,S   ; fccstk d=0 b=61
                LDA     51,S   ; fccstk d=0 b=51
                LSR
                TAX
                TXA
                AND     #1
                STA     63,S   ; fccstk d=0 b=63
                LDA     51,S   ; fccstk d=0 b=51
                TAX
                TXA
                AND     #1
                STA     65,S   ; fccstk d=0 b=65
                LDA     63,S   ; fccstk d=0 b=63
                CMP     #0
                BNE     *+5
                BRL     _softdouble_L68
                LDA     65,S   ; fccstk d=0 b=65
                CMP     #0
                BEQ     *+5
                BRL     _softdouble_L70
                LDA     59,S   ; fccstk d=0 b=59
                STA     _fcc_q3
                LDA     57,S   ; fccstk d=0 b=57
                STA     _fcc_q2
                LDA     55,S   ; fccstk d=0 b=55
                STA     _fcc_long_hi
                LDA     53,S   ; fccstk d=0 b=53
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
                LDX     #0
                BIT     _fcc_long_hi
                BPL     *+5
                LDX     #$FFFF
                STX     _fcc_q2
                STX     _fcc_q3
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
                FGX2_FARCALL _fcc_ll_and
                ORA     _fcc_long_hi
                ORA     _fcc_q2
                ORA     _fcc_q3
                BEQ     *+5
                BRL     _softdouble_L70
                LDA     #0
                BRL     _softdouble_L71
_softdouble_L70
                LDA     #1
_softdouble_L71
                CMP     #0
                BNE     *+5
                BRL     _softdouble_L68
                LDA     #1
                BRL     _softdouble_L69
_softdouble_L68
                LDA     #0
_softdouble_L69
                CMP     #0
                BNE     *+5
                BRL     _softdouble_L67
                LDA     59,S   ; fccstk d=0 b=59
                STA     _fcc_q3
                LDA     57,S   ; fccstk d=0 b=57
                STA     _fcc_q2
                LDA     55,S   ; fccstk d=0 b=55
                STA     _fcc_long_hi
                LDA     53,S   ; fccstk d=0 b=53
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                CLC
                ADC     #1
                TAY
                LDA     _fcc_long_hi
                ADC     #0
                STA     _fcc_long_hi
                LDA     _fcc_q2
                ADC     #0
                STA     _fcc_q2
                LDA     _fcc_q3
                ADC     #0
                STA     _fcc_q3
                TYA
                STA     61,S   ; fccstk d=8 b=53
                TAY
                LDA     _fcc_long_hi
                STA     63,S   ; fccstk d=8 b=55
                LDA     _fcc_q2
                STA     65,S   ; fccstk d=8 b=57
                LDA     _fcc_q3
                STA     67,S   ; fccstk d=8 b=59
                TYA
                PLA
                TAY
                PLA
                PLA
                PLA
                TYA
                LDA     59,S   ; fccstk d=0 b=59
                STA     _fcc_q3
                LDA     57,S   ; fccstk d=0 b=57
                STA     _fcc_q2
                LDA     55,S   ; fccstk d=0 b=55
                STA     _fcc_long_hi
                LDA     53,S   ; fccstk d=0 b=53
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
                STA     _fcc_q3
                LDA     #0
                STA     _fcc_q2
                LDA     #0
                STA     _fcc_long_hi
                LDA     #1
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #53
                STA     _fcc_long_b_lo
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                PLA
                STA     _fcc_q2
                PLA
                STA     _fcc_q3
                TYA
                FGX2_FARCALL _fcc_ll_shl
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
                FGX2_FARCALL _fcc_ll_and
                ORA     _fcc_long_hi
                ORA     _fcc_q2
                ORA     _fcc_q3
                BNE     *+5
                BRL     _softdouble_L72
                LDA     59,S   ; fccstk d=0 b=59
                STA     _fcc_q3
                LDA     57,S   ; fccstk d=0 b=57
                STA     _fcc_q2
                LDA     55,S   ; fccstk d=0 b=55
                STA     _fcc_long_hi
                LDA     53,S   ; fccstk d=0 b=53
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
                STA     _fcc_long_b_lo
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                PLA
                STA     _fcc_q2
                PLA
                STA     _fcc_q3
                TYA
                FGX2_FARCALL _fcc_ll_shru
                STA     53,S   ; fccstk d=0 b=53
                TAY
                LDA     _fcc_long_hi
                STA     55,S   ; fccstk d=0 b=55
                LDA     _fcc_q2
                STA     57,S   ; fccstk d=0 b=57
                LDA     _fcc_q3
                STA     59,S   ; fccstk d=0 b=59
                TYA
                LDA     61,S   ; fccstk d=0 b=61
                CLC
                ADC     #1
                STA     61,S   ; fccstk d=0 b=61
_softdouble_L72
_softdouble_L67
                LDA     59,S   ; fccstk d=0 b=59
                STA     _fcc_q3
                LDA     57,S   ; fccstk d=0 b=57
                STA     _fcc_q2
                LDA     55,S   ; fccstk d=0 b=55
                STA     _fcc_long_hi
                LDA     53,S   ; fccstk d=0 b=53
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     69,S   ; fccstk d=8 b=61
                PHA
                LDA     57,S   ; fccstk d=10 b=47
                STA     _fcc_q3
                LDA     55,S   ; fccstk d=10 b=45
                STA     _fcc_q2
                LDA     53,S   ; fccstk d=10 b=43
                STA     _fcc_long_hi
                LDA     51,S   ; fccstk d=10 b=41
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                FGX2_FARCALL _softdouble_dpack
                TAY
                TSC
                CLC
                ADC     #18
                TCS
                TYA
                TAY
                TSC
                CLC
                ADC     #__muldf3_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
__muldf3_FRAMESIZE   EQU     66
__muldf3_STKGUARD    EQU     0
                FGX2_EXPORT __divdf3
__divdf3            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #__divdf3_FRAMESIZE
                DO      __divdf3_STKGUARD
                BCC     __divdf3_stkovf
                CMP     _fcc_stkfloor
                BCS     __divdf3_stkok
__divdf3_stkovf       JMP     _fcc_stkoflow
                FIN
__divdf3_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
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
                DO      24+__divdf3_FRAMESIZE/256
                TSC
                CLC
                ADC     #24+__divdf3_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     24+__divdf3_FRAMESIZE,S   ; fccstk d=12 b=12 fs
                FIN
                STA     _fcc_q3
                DO      22+__divdf3_FRAMESIZE/256
                TSC
                CLC
                ADC     #22+__divdf3_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     22+__divdf3_FRAMESIZE,S   ; fccstk d=12 b=10 fs
                FIN
                STA     _fcc_q2
                DO      20+__divdf3_FRAMESIZE/256
                TSC
                CLC
                ADC     #20+__divdf3_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     20+__divdf3_FRAMESIZE,S   ; fccstk d=12 b=8 fs
                FIN
                STA     _fcc_long_hi
                DO      18+__divdf3_FRAMESIZE/256
                TSC
                CLC
                ADC     #18+__divdf3_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     18+__divdf3_FRAMESIZE,S   ; fccstk d=12 b=6 fs
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
                FGX2_FARCALL _softdouble_dclass
                TAY
                TSC
                CLC
                ADC     #20
                TCS
                TYA
                STA     37,S   ; fccstk d=0 b=37
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
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #34
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
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
                DO      32+__divdf3_FRAMESIZE/256
                TSC
                CLC
                ADC     #32+__divdf3_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     32+__divdf3_FRAMESIZE,S   ; fccstk d=12 b=20 fs
                FIN
                STA     _fcc_q3
                DO      30+__divdf3_FRAMESIZE/256
                TSC
                CLC
                ADC     #30+__divdf3_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     30+__divdf3_FRAMESIZE,S   ; fccstk d=12 b=18 fs
                FIN
                STA     _fcc_q2
                DO      28+__divdf3_FRAMESIZE/256
                TSC
                CLC
                ADC     #28+__divdf3_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     28+__divdf3_FRAMESIZE,S   ; fccstk d=12 b=16 fs
                FIN
                STA     _fcc_long_hi
                DO      26+__divdf3_FRAMESIZE/256
                TSC
                CLC
                ADC     #26+__divdf3_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     26+__divdf3_FRAMESIZE,S   ; fccstk d=12 b=14 fs
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
                FGX2_FARCALL _softdouble_dclass
                TAY
                TSC
                CLC
                ADC     #20
                TCS
                TYA
                STA     39,S   ; fccstk d=0 b=39
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
                FGX2_FARCALL _fcc_ll_xor
                STA     41,S   ; fccstk d=0 b=41
                TAY
                LDA     _fcc_long_hi
                STA     43,S   ; fccstk d=0 b=43
                LDA     _fcc_q2
                STA     45,S   ; fccstk d=0 b=45
                LDA     _fcc_q3
                STA     47,S   ; fccstk d=0 b=47
                TYA
                LDA     37,S   ; fccstk d=0 b=37
                TAX
                TXA
                CMP     #0
                BEQ     *+5
                BRL     _softdouble_L73
                LDA     47,S   ; fccstk d=0 b=47
                STA     _fcc_q3
                LDA     45,S   ; fccstk d=0 b=45
                STA     _fcc_q2
                LDA     43,S   ; fccstk d=0 b=43
                STA     _fcc_long_hi
                LDA     41,S   ; fccstk d=0 b=41
                TAY
                TSC
                CLC
                ADC     #__divdf3_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_softdouble_L73
                LDA     39,S   ; fccstk d=0 b=39
                TAX
                TXA
                CMP     #0
                BEQ     *+5
                BRL     _softdouble_L74
                LDA     47,S   ; fccstk d=0 b=47
                STA     _fcc_q3
                LDA     45,S   ; fccstk d=0 b=45
                STA     _fcc_q2
                LDA     43,S   ; fccstk d=0 b=43
                STA     _fcc_long_hi
                LDA     41,S   ; fccstk d=0 b=41
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #32752
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
                FGX2_FARCALL _fcc_ll_or
                TAY
                TSC
                CLC
                ADC     #__divdf3_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_softdouble_L74
                LDA     33,S   ; fccstk d=0 b=33
                SEC
                SBC     35,S   ; fccstk d=0 b=35
                STA     49,S   ; fccstk d=0 b=49
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
                LDA     39,S   ; fccstk d=8 b=31
                STA     _fcc_q3
                LDA     37,S   ; fccstk d=8 b=29
                STA     _fcc_q2
                LDA     35,S   ; fccstk d=8 b=27
                STA     _fcc_long_hi
                LDA     33,S   ; fccstk d=8 b=25
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
                FGX2_FARCALL _fcc_ll_cmpu
                BMI     *+7
                LDA     #0
                BRA     *+5
                LDA     #1
                CMP     #0
                BNE     *+5
                BRL     _softdouble_L75
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
                STA     _fcc_long_b_lo
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                PLA
                STA     _fcc_q2
                PLA
                STA     _fcc_q3
                TYA
                FGX2_FARCALL _fcc_ll_shl
                STA     17,S   ; fccstk d=0 b=17
                TAY
                LDA     _fcc_long_hi
                STA     19,S   ; fccstk d=0 b=19
                LDA     _fcc_q2
                STA     21,S   ; fccstk d=0 b=21
                LDA     _fcc_q3
                STA     23,S   ; fccstk d=0 b=23
                TYA
                LDA     49,S   ; fccstk d=0 b=49
                SEC
                SBC     #1
                STA     49,S   ; fccstk d=0 b=49
_softdouble_L75
                LDA     #16
                STA     _fcc_q3
                LDA     #0
                STA     _fcc_q2
                LDA     #0
                STA     _fcc_long_hi
                LDA     #0
                STA     51,S   ; fccstk d=0 b=51
                TAY
                LDA     _fcc_long_hi
                STA     53,S   ; fccstk d=0 b=53
                LDA     _fcc_q2
                STA     55,S   ; fccstk d=0 b=55
                LDA     _fcc_q3
                STA     57,S   ; fccstk d=0 b=57
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
                LDA     39,S   ; fccstk d=8 b=31
                STA     _fcc_q3
                LDA     37,S   ; fccstk d=8 b=29
                STA     _fcc_q2
                LDA     35,S   ; fccstk d=8 b=27
                STA     _fcc_long_hi
                LDA     33,S   ; fccstk d=8 b=25
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
                FGX2_FARCALL _fcc_ll_sub
                STA     59,S   ; fccstk d=0 b=59
                TAY
                LDA     _fcc_long_hi
                STA     61,S   ; fccstk d=0 b=61
                LDA     _fcc_q2
                STA     63,S   ; fccstk d=0 b=63
                LDA     _fcc_q3
                STA     65,S   ; fccstk d=0 b=65
                TYA
                LDA     #51
                STA     67,S   ; fccstk d=0 b=67
_softdouble_L76
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     67,S   ; fccstk d=0 b=67
                TAX
                TXA
                SEC
                SBC     #0
                BVC     _softdouble_L79
                EOR     #$8000
_softdouble_L79
                BPL     *+5
                BRL     _softdouble_L78
                LDA     65,S   ; fccstk d=0 b=65
                STA     _fcc_q3
                LDA     63,S   ; fccstk d=0 b=63
                STA     _fcc_q2
                LDA     61,S   ; fccstk d=0 b=61
                STA     _fcc_long_hi
                LDA     59,S   ; fccstk d=0 b=59
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
                STA     _fcc_long_b_lo
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                PLA
                STA     _fcc_q2
                PLA
                STA     _fcc_q3
                TYA
                FGX2_FARCALL _fcc_ll_shl
                STA     59,S   ; fccstk d=0 b=59
                TAY
                LDA     _fcc_long_hi
                STA     61,S   ; fccstk d=0 b=61
                LDA     _fcc_q2
                STA     63,S   ; fccstk d=0 b=63
                LDA     _fcc_q3
                STA     65,S   ; fccstk d=0 b=65
                TYA
                LDA     65,S   ; fccstk d=0 b=65
                STA     _fcc_q3
                LDA     63,S   ; fccstk d=0 b=63
                STA     _fcc_q2
                LDA     61,S   ; fccstk d=0 b=61
                STA     _fcc_long_hi
                LDA     59,S   ; fccstk d=0 b=59
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     39,S   ; fccstk d=8 b=31
                STA     _fcc_q3
                LDA     37,S   ; fccstk d=8 b=29
                STA     _fcc_q2
                LDA     35,S   ; fccstk d=8 b=27
                STA     _fcc_long_hi
                LDA     33,S   ; fccstk d=8 b=25
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
                FGX2_FARCALL _fcc_ll_cmpu
                BPL     *+7
                LDA     #0
                BRA     *+5
                LDA     #1
                CMP     #0
                BNE     *+5
                BRL     _softdouble_L80
                LDA     65,S   ; fccstk d=0 b=65
                STA     _fcc_q3
                LDA     63,S   ; fccstk d=0 b=63
                STA     _fcc_q2
                LDA     61,S   ; fccstk d=0 b=61
                STA     _fcc_long_hi
                LDA     59,S   ; fccstk d=0 b=59
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     39,S   ; fccstk d=8 b=31
                STA     _fcc_q3
                LDA     37,S   ; fccstk d=8 b=29
                STA     _fcc_q2
                LDA     35,S   ; fccstk d=8 b=27
                STA     _fcc_long_hi
                LDA     33,S   ; fccstk d=8 b=25
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
                FGX2_FARCALL _fcc_ll_sub
                STA     59,S   ; fccstk d=0 b=59
                TAY
                LDA     _fcc_long_hi
                STA     61,S   ; fccstk d=0 b=61
                LDA     _fcc_q2
                STA     63,S   ; fccstk d=0 b=63
                LDA     _fcc_q3
                STA     65,S   ; fccstk d=0 b=65
                TYA
                LDA     57,S   ; fccstk d=0 b=57
                STA     _fcc_q3
                LDA     55,S   ; fccstk d=0 b=55
                STA     _fcc_q2
                LDA     53,S   ; fccstk d=0 b=53
                STA     _fcc_long_hi
                LDA     51,S   ; fccstk d=0 b=51
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
                STA     _fcc_q3
                LDA     #0
                STA     _fcc_q2
                LDA     #0
                STA     _fcc_long_hi
                LDA     #1
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     83,S   ; fccstk d=16 b=67
                STA     _fcc_long_b_lo
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                PLA
                STA     _fcc_q2
                PLA
                STA     _fcc_q3
                TYA
                FGX2_FARCALL _fcc_ll_shl
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
                FGX2_FARCALL _fcc_ll_or
                STA     51,S   ; fccstk d=0 b=51
                TAY
                LDA     _fcc_long_hi
                STA     53,S   ; fccstk d=0 b=53
                LDA     _fcc_q2
                STA     55,S   ; fccstk d=0 b=55
                LDA     _fcc_q3
                STA     57,S   ; fccstk d=0 b=57
                TYA
_softdouble_L80
_softdouble_L77
                LDA     67,S   ; fccstk d=0 b=67
                SEC
                SBC     #1
                STA     67,S   ; fccstk d=0 b=67
                BRL     _softdouble_L76
_softdouble_L78
                LDA     65,S   ; fccstk d=0 b=65
                STA     _fcc_q3
                LDA     63,S   ; fccstk d=0 b=63
                STA     _fcc_q2
                LDA     61,S   ; fccstk d=0 b=61
                STA     _fcc_long_hi
                LDA     59,S   ; fccstk d=0 b=59
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
                STA     _fcc_long_b_lo
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                PLA
                STA     _fcc_q2
                PLA
                STA     _fcc_q3
                TYA
                FGX2_FARCALL _fcc_ll_shl
                STA     59,S   ; fccstk d=0 b=59
                TAY
                LDA     _fcc_long_hi
                STA     61,S   ; fccstk d=0 b=61
                LDA     _fcc_q2
                STA     63,S   ; fccstk d=0 b=63
                LDA     _fcc_q3
                STA     65,S   ; fccstk d=0 b=65
                TYA
                LDA     65,S   ; fccstk d=0 b=65
                STA     _fcc_q3
                LDA     63,S   ; fccstk d=0 b=63
                STA     _fcc_q2
                LDA     61,S   ; fccstk d=0 b=61
                STA     _fcc_long_hi
                LDA     59,S   ; fccstk d=0 b=59
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     39,S   ; fccstk d=8 b=31
                STA     _fcc_q3
                LDA     37,S   ; fccstk d=8 b=29
                STA     _fcc_q2
                LDA     35,S   ; fccstk d=8 b=27
                STA     _fcc_long_hi
                LDA     33,S   ; fccstk d=8 b=25
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
                FGX2_FARCALL _fcc_ll_cmpu
                BPL     *+7
                LDA     #0
                BRA     *+5
                LDA     #1
                CMP     #0
                BNE     *+5
                BRL     _softdouble_L81
                LDA     #1
                BRL     _softdouble_L82
_softdouble_L81
                LDA     #0
_softdouble_L82
                STA     69,S   ; fccstk d=0 b=69
                CMP     #0
                BNE     *+5
                BRL     _softdouble_L83
                LDA     65,S   ; fccstk d=0 b=65
                STA     _fcc_q3
                LDA     63,S   ; fccstk d=0 b=63
                STA     _fcc_q2
                LDA     61,S   ; fccstk d=0 b=61
                STA     _fcc_long_hi
                LDA     59,S   ; fccstk d=0 b=59
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     39,S   ; fccstk d=8 b=31
                STA     _fcc_q3
                LDA     37,S   ; fccstk d=8 b=29
                STA     _fcc_q2
                LDA     35,S   ; fccstk d=8 b=27
                STA     _fcc_long_hi
                LDA     33,S   ; fccstk d=8 b=25
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
                FGX2_FARCALL _fcc_ll_sub
                STA     59,S   ; fccstk d=0 b=59
                TAY
                LDA     _fcc_long_hi
                STA     61,S   ; fccstk d=0 b=61
                LDA     _fcc_q2
                STA     63,S   ; fccstk d=0 b=63
                LDA     _fcc_q3
                STA     65,S   ; fccstk d=0 b=65
                TYA
_softdouble_L83
                LDA     65,S   ; fccstk d=0 b=65
                STA     _fcc_q3
                LDA     63,S   ; fccstk d=0 b=63
                STA     _fcc_q2
                LDA     61,S   ; fccstk d=0 b=61
                STA     _fcc_long_hi
                LDA     59,S   ; fccstk d=0 b=59
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
                LDX     #0
                BIT     _fcc_long_hi
                BPL     *+5
                LDX     #$FFFF
                STX     _fcc_q2
                STX     _fcc_q3
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
                FGX2_FARCALL _fcc_ll_cmpu
                BNE     *+7
                LDA     #0
                BRA     *+5
                LDA     #1
                CMP     #0
                BNE     *+5
                BRL     _softdouble_L84
                LDA     #1
                BRL     _softdouble_L85
_softdouble_L84
                LDA     #0
_softdouble_L85
                STA     71,S   ; fccstk d=0 b=71
                LDA     69,S   ; fccstk d=0 b=69
                CMP     #0
                BNE     *+5
                BRL     _softdouble_L87
                LDA     71,S   ; fccstk d=0 b=71
                CMP     #0
                BEQ     *+5
                BRL     _softdouble_L89
                LDA     57,S   ; fccstk d=0 b=57
                STA     _fcc_q3
                LDA     55,S   ; fccstk d=0 b=55
                STA     _fcc_q2
                LDA     53,S   ; fccstk d=0 b=53
                STA     _fcc_long_hi
                LDA     51,S   ; fccstk d=0 b=51
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
                LDX     #0
                BIT     _fcc_long_hi
                BPL     *+5
                LDX     #$FFFF
                STX     _fcc_q2
                STX     _fcc_q3
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
                FGX2_FARCALL _fcc_ll_and
                ORA     _fcc_long_hi
                ORA     _fcc_q2
                ORA     _fcc_q3
                BEQ     *+5
                BRL     _softdouble_L89
                LDA     #0
                BRL     _softdouble_L90
_softdouble_L89
                LDA     #1
_softdouble_L90
                CMP     #0
                BNE     *+5
                BRL     _softdouble_L87
                LDA     #1
                BRL     _softdouble_L88
_softdouble_L87
                LDA     #0
_softdouble_L88
                CMP     #0
                BNE     *+5
                BRL     _softdouble_L86
                LDA     57,S   ; fccstk d=0 b=57
                STA     _fcc_q3
                LDA     55,S   ; fccstk d=0 b=55
                STA     _fcc_q2
                LDA     53,S   ; fccstk d=0 b=53
                STA     _fcc_long_hi
                LDA     51,S   ; fccstk d=0 b=51
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                CLC
                ADC     #1
                TAY
                LDA     _fcc_long_hi
                ADC     #0
                STA     _fcc_long_hi
                LDA     _fcc_q2
                ADC     #0
                STA     _fcc_q2
                LDA     _fcc_q3
                ADC     #0
                STA     _fcc_q3
                TYA
                STA     59,S   ; fccstk d=8 b=51
                TAY
                LDA     _fcc_long_hi
                STA     61,S   ; fccstk d=8 b=53
                LDA     _fcc_q2
                STA     63,S   ; fccstk d=8 b=55
                LDA     _fcc_q3
                STA     65,S   ; fccstk d=8 b=57
                TYA
                PLA
                TAY
                PLA
                PLA
                PLA
                TYA
                LDA     57,S   ; fccstk d=0 b=57
                STA     _fcc_q3
                LDA     55,S   ; fccstk d=0 b=55
                STA     _fcc_q2
                LDA     53,S   ; fccstk d=0 b=53
                STA     _fcc_long_hi
                LDA     51,S   ; fccstk d=0 b=51
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
                STA     _fcc_q3
                LDA     #0
                STA     _fcc_q2
                LDA     #0
                STA     _fcc_long_hi
                LDA     #1
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #53
                STA     _fcc_long_b_lo
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                PLA
                STA     _fcc_q2
                PLA
                STA     _fcc_q3
                TYA
                FGX2_FARCALL _fcc_ll_shl
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
                FGX2_FARCALL _fcc_ll_and
                ORA     _fcc_long_hi
                ORA     _fcc_q2
                ORA     _fcc_q3
                BNE     *+5
                BRL     _softdouble_L91
                LDA     57,S   ; fccstk d=0 b=57
                STA     _fcc_q3
                LDA     55,S   ; fccstk d=0 b=55
                STA     _fcc_q2
                LDA     53,S   ; fccstk d=0 b=53
                STA     _fcc_long_hi
                LDA     51,S   ; fccstk d=0 b=51
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
                STA     _fcc_long_b_lo
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                PLA
                STA     _fcc_q2
                PLA
                STA     _fcc_q3
                TYA
                FGX2_FARCALL _fcc_ll_shru
                STA     51,S   ; fccstk d=0 b=51
                TAY
                LDA     _fcc_long_hi
                STA     53,S   ; fccstk d=0 b=53
                LDA     _fcc_q2
                STA     55,S   ; fccstk d=0 b=55
                LDA     _fcc_q3
                STA     57,S   ; fccstk d=0 b=57
                TYA
                LDA     49,S   ; fccstk d=0 b=49
                CLC
                ADC     #1
                STA     49,S   ; fccstk d=0 b=49
_softdouble_L91
_softdouble_L86
                LDA     57,S   ; fccstk d=0 b=57
                STA     _fcc_q3
                LDA     55,S   ; fccstk d=0 b=55
                STA     _fcc_q2
                LDA     53,S   ; fccstk d=0 b=53
                STA     _fcc_long_hi
                LDA     51,S   ; fccstk d=0 b=51
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     57,S   ; fccstk d=8 b=49
                PHA
                LDA     57,S   ; fccstk d=10 b=47
                STA     _fcc_q3
                LDA     55,S   ; fccstk d=10 b=45
                STA     _fcc_q2
                LDA     53,S   ; fccstk d=10 b=43
                STA     _fcc_long_hi
                LDA     51,S   ; fccstk d=10 b=41
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                FGX2_FARCALL _softdouble_dpack
                TAY
                TSC
                CLC
                ADC     #18
                TCS
                TYA
                TAY
                TSC
                CLC
                ADC     #__divdf3_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
__divdf3_FRAMESIZE   EQU     72
__divdf3_STKGUARD    EQU     0
                FGX2_EXPORT __cmpdf2
__cmpdf2            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #__cmpdf2_FRAMESIZE
                DO      __cmpdf2_STKGUARD
                BCC     __cmpdf2_stkovf
                CMP     _fcc_stkfloor
                BCS     __cmpdf2_stkok
__cmpdf2_stkovf       JMP     _fcc_stkoflow
                FIN
__cmpdf2_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      12+__cmpdf2_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+__cmpdf2_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+__cmpdf2_FRAMESIZE,S   ; fccstk d=0 b=12 fs
                FIN
                STA     _fcc_q3
                DO      10+__cmpdf2_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+__cmpdf2_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+__cmpdf2_FRAMESIZE,S   ; fccstk d=0 b=10 fs
                FIN
                STA     _fcc_q2
                DO      8+__cmpdf2_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+__cmpdf2_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+__cmpdf2_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_long_hi
                DO      6+__cmpdf2_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+__cmpdf2_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+__cmpdf2_FRAMESIZE,S   ; fccstk d=0 b=6 fs
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
                LDA     #32768
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
                FGX2_FARCALL _fcc_ll_and
                STA     1,S   ; fccstk d=0 b=1
                TAY
                LDA     _fcc_long_hi
                STA     3,S   ; fccstk d=0 b=3
                LDA     _fcc_q2
                STA     5,S   ; fccstk d=0 b=5
                LDA     _fcc_q3
                STA     7,S   ; fccstk d=0 b=7
                TYA
                DO      20+__cmpdf2_FRAMESIZE/256
                TSC
                CLC
                ADC     #20+__cmpdf2_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     20+__cmpdf2_FRAMESIZE,S   ; fccstk d=0 b=20 fs
                FIN
                STA     _fcc_q3
                DO      18+__cmpdf2_FRAMESIZE/256
                TSC
                CLC
                ADC     #18+__cmpdf2_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     18+__cmpdf2_FRAMESIZE,S   ; fccstk d=0 b=18 fs
                FIN
                STA     _fcc_q2
                DO      16+__cmpdf2_FRAMESIZE/256
                TSC
                CLC
                ADC     #16+__cmpdf2_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     16+__cmpdf2_FRAMESIZE,S   ; fccstk d=0 b=16 fs
                FIN
                STA     _fcc_long_hi
                DO      14+__cmpdf2_FRAMESIZE/256
                TSC
                CLC
                ADC     #14+__cmpdf2_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     14+__cmpdf2_FRAMESIZE,S   ; fccstk d=0 b=14 fs
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
                LDA     #32768
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
                FGX2_FARCALL _fcc_ll_and
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
                FGX2_FARCALL _fcc_ll_cmpu
                BNE     *+7
                LDA     #0
                BRA     *+5
                LDA     #1
                CMP     #0
                BNE     *+5
                BRL     _softdouble_L92
                DO      12+__cmpdf2_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+__cmpdf2_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+__cmpdf2_FRAMESIZE,S   ; fccstk d=0 b=12 fs
                FIN
                STA     _fcc_q3
                DO      10+__cmpdf2_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+__cmpdf2_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+__cmpdf2_FRAMESIZE,S   ; fccstk d=0 b=10 fs
                FIN
                STA     _fcc_q2
                DO      8+__cmpdf2_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+__cmpdf2_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+__cmpdf2_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_long_hi
                DO      6+__cmpdf2_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+__cmpdf2_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+__cmpdf2_FRAMESIZE,S   ; fccstk d=0 b=6 fs
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
                DO      28+__cmpdf2_FRAMESIZE/256
                TSC
                CLC
                ADC     #28+__cmpdf2_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     28+__cmpdf2_FRAMESIZE,S   ; fccstk d=8 b=20 fs
                FIN
                STA     _fcc_q3
                DO      26+__cmpdf2_FRAMESIZE/256
                TSC
                CLC
                ADC     #26+__cmpdf2_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     26+__cmpdf2_FRAMESIZE,S   ; fccstk d=8 b=18 fs
                FIN
                STA     _fcc_q2
                DO      24+__cmpdf2_FRAMESIZE/256
                TSC
                CLC
                ADC     #24+__cmpdf2_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     24+__cmpdf2_FRAMESIZE,S   ; fccstk d=8 b=16 fs
                FIN
                STA     _fcc_long_hi
                DO      22+__cmpdf2_FRAMESIZE/256
                TSC
                CLC
                ADC     #22+__cmpdf2_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     22+__cmpdf2_FRAMESIZE,S   ; fccstk d=8 b=14 fs
                FIN
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
                FGX2_FARCALL _fcc_ll_or
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
                STA     _fcc_long_b_lo
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                PLA
                STA     _fcc_q2
                PLA
                STA     _fcc_q3
                TYA
                FGX2_FARCALL _fcc_ll_shl
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
                LDX     #0
                BIT     _fcc_long_hi
                BPL     *+5
                LDX     #$FFFF
                STX     _fcc_q2
                STX     _fcc_q3
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
                FGX2_FARCALL _fcc_ll_cmpu
                BEQ     *+7
                LDA     #0
                BRA     *+5
                LDA     #1
                CMP     #0
                BNE     *+5
                BRL     _softdouble_L93
                LDA     #0
                TAY
                TSC
                CLC
                ADC     #__cmpdf2_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_softdouble_L93
                LDA     7,S   ; fccstk d=0 b=7
                STA     _fcc_q3
                LDA     5,S   ; fccstk d=0 b=5
                STA     _fcc_q2
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_long_hi
                LDA     1,S   ; fccstk d=0 b=1
                ORA     _fcc_long_hi
                ORA     _fcc_q2
                ORA     _fcc_q3
                BNE     *+5
                BRL     _softdouble_L94
                LDA     #$FFFF
                BRL     _softdouble_L95
_softdouble_L94
                LDA     #1
_softdouble_L95
                TAY
                TSC
                CLC
                ADC     #__cmpdf2_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_softdouble_L92
                DO      12+__cmpdf2_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+__cmpdf2_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+__cmpdf2_FRAMESIZE,S   ; fccstk d=0 b=12 fs
                FIN
                STA     _fcc_q3
                DO      10+__cmpdf2_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+__cmpdf2_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+__cmpdf2_FRAMESIZE,S   ; fccstk d=0 b=10 fs
                FIN
                STA     _fcc_q2
                DO      8+__cmpdf2_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+__cmpdf2_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+__cmpdf2_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_long_hi
                DO      6+__cmpdf2_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+__cmpdf2_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+__cmpdf2_FRAMESIZE,S   ; fccstk d=0 b=6 fs
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
                DO      28+__cmpdf2_FRAMESIZE/256
                TSC
                CLC
                ADC     #28+__cmpdf2_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     28+__cmpdf2_FRAMESIZE,S   ; fccstk d=8 b=20 fs
                FIN
                STA     _fcc_q3
                DO      26+__cmpdf2_FRAMESIZE/256
                TSC
                CLC
                ADC     #26+__cmpdf2_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     26+__cmpdf2_FRAMESIZE,S   ; fccstk d=8 b=18 fs
                FIN
                STA     _fcc_q2
                DO      24+__cmpdf2_FRAMESIZE/256
                TSC
                CLC
                ADC     #24+__cmpdf2_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     24+__cmpdf2_FRAMESIZE,S   ; fccstk d=8 b=16 fs
                FIN
                STA     _fcc_long_hi
                DO      22+__cmpdf2_FRAMESIZE/256
                TSC
                CLC
                ADC     #22+__cmpdf2_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     22+__cmpdf2_FRAMESIZE,S   ; fccstk d=8 b=14 fs
                FIN
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
                FGX2_FARCALL _fcc_ll_cmpu
                BEQ     *+7
                LDA     #0
                BRA     *+5
                LDA     #1
                CMP     #0
                BNE     *+5
                BRL     _softdouble_L96
                LDA     #0
                TAY
                TSC
                CLC
                ADC     #__cmpdf2_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_softdouble_L96
                LDA     7,S   ; fccstk d=0 b=7
                STA     _fcc_q3
                LDA     5,S   ; fccstk d=0 b=5
                STA     _fcc_q2
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_long_hi
                LDA     1,S   ; fccstk d=0 b=1
                ORA     _fcc_long_hi
                ORA     _fcc_q2
                ORA     _fcc_q3
                BNE     *+5
                BRL     _softdouble_L97
                DO      12+__cmpdf2_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+__cmpdf2_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+__cmpdf2_FRAMESIZE,S   ; fccstk d=0 b=12 fs
                FIN
                STA     _fcc_q3
                DO      10+__cmpdf2_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+__cmpdf2_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+__cmpdf2_FRAMESIZE,S   ; fccstk d=0 b=10 fs
                FIN
                STA     _fcc_q2
                DO      8+__cmpdf2_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+__cmpdf2_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+__cmpdf2_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_long_hi
                DO      6+__cmpdf2_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+__cmpdf2_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+__cmpdf2_FRAMESIZE,S   ; fccstk d=0 b=6 fs
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
                DO      28+__cmpdf2_FRAMESIZE/256
                TSC
                CLC
                ADC     #28+__cmpdf2_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     28+__cmpdf2_FRAMESIZE,S   ; fccstk d=8 b=20 fs
                FIN
                STA     _fcc_q3
                DO      26+__cmpdf2_FRAMESIZE/256
                TSC
                CLC
                ADC     #26+__cmpdf2_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     26+__cmpdf2_FRAMESIZE,S   ; fccstk d=8 b=18 fs
                FIN
                STA     _fcc_q2
                DO      24+__cmpdf2_FRAMESIZE/256
                TSC
                CLC
                ADC     #24+__cmpdf2_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     24+__cmpdf2_FRAMESIZE,S   ; fccstk d=8 b=16 fs
                FIN
                STA     _fcc_long_hi
                DO      22+__cmpdf2_FRAMESIZE/256
                TSC
                CLC
                ADC     #22+__cmpdf2_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     22+__cmpdf2_FRAMESIZE,S   ; fccstk d=8 b=14 fs
                FIN
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
                FGX2_FARCALL _fcc_ll_cmpu
                BMI     *+7
                LDA     #0
                BRA     *+5
                LDA     #1
                CMP     #0
                BNE     *+5
                BRL     _softdouble_L98
                LDA     #1
                BRL     _softdouble_L99
_softdouble_L98
                LDA     #$FFFF
_softdouble_L99
                TAY
                TSC
                CLC
                ADC     #__cmpdf2_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_softdouble_L97
                DO      12+__cmpdf2_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+__cmpdf2_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+__cmpdf2_FRAMESIZE,S   ; fccstk d=0 b=12 fs
                FIN
                STA     _fcc_q3
                DO      10+__cmpdf2_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+__cmpdf2_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+__cmpdf2_FRAMESIZE,S   ; fccstk d=0 b=10 fs
                FIN
                STA     _fcc_q2
                DO      8+__cmpdf2_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+__cmpdf2_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+__cmpdf2_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_long_hi
                DO      6+__cmpdf2_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+__cmpdf2_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+__cmpdf2_FRAMESIZE,S   ; fccstk d=0 b=6 fs
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
                DO      28+__cmpdf2_FRAMESIZE/256
                TSC
                CLC
                ADC     #28+__cmpdf2_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     28+__cmpdf2_FRAMESIZE,S   ; fccstk d=8 b=20 fs
                FIN
                STA     _fcc_q3
                DO      26+__cmpdf2_FRAMESIZE/256
                TSC
                CLC
                ADC     #26+__cmpdf2_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     26+__cmpdf2_FRAMESIZE,S   ; fccstk d=8 b=18 fs
                FIN
                STA     _fcc_q2
                DO      24+__cmpdf2_FRAMESIZE/256
                TSC
                CLC
                ADC     #24+__cmpdf2_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     24+__cmpdf2_FRAMESIZE,S   ; fccstk d=8 b=16 fs
                FIN
                STA     _fcc_long_hi
                DO      22+__cmpdf2_FRAMESIZE/256
                TSC
                CLC
                ADC     #22+__cmpdf2_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     22+__cmpdf2_FRAMESIZE,S   ; fccstk d=8 b=14 fs
                FIN
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
                FGX2_FARCALL _fcc_ll_cmpu
                BMI     *+7
                LDA     #0
                BRA     *+5
                LDA     #1
                CMP     #0
                BNE     *+5
                BRL     _softdouble_L100
                LDA     #$FFFF
                BRL     _softdouble_L101
_softdouble_L100
                LDA     #1
_softdouble_L101
                TAY
                TSC
                CLC
                ADC     #__cmpdf2_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
__cmpdf2_FRAMESIZE   EQU     16
__cmpdf2_STKGUARD    EQU     0
                FGX2_EXPORT __unorddf2
__unorddf2            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #__unorddf2_FRAMESIZE
                DO      __unorddf2_STKGUARD
                BCC     __unorddf2_stkovf
                CMP     _fcc_stkfloor
                BCS     __unorddf2_stkok
__unorddf2_stkovf       JMP     _fcc_stkoflow
                FIN
__unorddf2_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      12+__unorddf2_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+__unorddf2_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+__unorddf2_FRAMESIZE,S   ; fccstk d=0 b=12 fs
                FIN
                STA     _fcc_q3
                DO      10+__unorddf2_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+__unorddf2_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+__unorddf2_FRAMESIZE,S   ; fccstk d=0 b=10 fs
                FIN
                STA     _fcc_q2
                DO      8+__unorddf2_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+__unorddf2_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+__unorddf2_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_long_hi
                DO      6+__unorddf2_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+__unorddf2_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+__unorddf2_FRAMESIZE,S   ; fccstk d=0 b=6 fs
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
                LDA     #52
                STA     _fcc_long_b_lo
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                PLA
                STA     _fcc_q2
                PLA
                STA     _fcc_q3
                TYA
                FGX2_FARCALL _fcc_ll_shru
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #2047
                JSR     _fcc_long_from_int
                LDX     #0
                BIT     _fcc_long_hi
                BPL     *+5
                LDX     #$FFFF
                STX     _fcc_q2
                STX     _fcc_q3
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
                FGX2_FARCALL _fcc_ll_and
                STA     1,S   ; fccstk d=0 b=1
                TAY
                LDA     _fcc_long_hi
                STA     3,S   ; fccstk d=0 b=3
                LDA     _fcc_q2
                STA     5,S   ; fccstk d=0 b=5
                LDA     _fcc_q3
                STA     7,S   ; fccstk d=0 b=7
                TYA
                DO      20+__unorddf2_FRAMESIZE/256
                TSC
                CLC
                ADC     #20+__unorddf2_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     20+__unorddf2_FRAMESIZE,S   ; fccstk d=0 b=20 fs
                FIN
                STA     _fcc_q3
                DO      18+__unorddf2_FRAMESIZE/256
                TSC
                CLC
                ADC     #18+__unorddf2_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     18+__unorddf2_FRAMESIZE,S   ; fccstk d=0 b=18 fs
                FIN
                STA     _fcc_q2
                DO      16+__unorddf2_FRAMESIZE/256
                TSC
                CLC
                ADC     #16+__unorddf2_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     16+__unorddf2_FRAMESIZE,S   ; fccstk d=0 b=16 fs
                FIN
                STA     _fcc_long_hi
                DO      14+__unorddf2_FRAMESIZE/256
                TSC
                CLC
                ADC     #14+__unorddf2_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     14+__unorddf2_FRAMESIZE,S   ; fccstk d=0 b=14 fs
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
                LDA     #52
                STA     _fcc_long_b_lo
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                PLA
                STA     _fcc_q2
                PLA
                STA     _fcc_q3
                TYA
                FGX2_FARCALL _fcc_ll_shru
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #2047
                JSR     _fcc_long_from_int
                LDX     #0
                BIT     _fcc_long_hi
                BPL     *+5
                LDX     #$FFFF
                STX     _fcc_q2
                STX     _fcc_q3
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
                FGX2_FARCALL _fcc_ll_and
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
                LDA     #2047
                JSR     _fcc_long_from_int
                LDX     #0
                BIT     _fcc_long_hi
                BPL     *+5
                LDX     #$FFFF
                STX     _fcc_q2
                STX     _fcc_q3
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
                FGX2_FARCALL _fcc_ll_cmpu
                BEQ     *+7
                LDA     #0
                BRA     *+5
                LDA     #1
                CMP     #0
                BNE     *+5
                BRL     _softdouble_L103
                DO      12+__unorddf2_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+__unorddf2_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+__unorddf2_FRAMESIZE,S   ; fccstk d=0 b=12 fs
                FIN
                STA     _fcc_q3
                DO      10+__unorddf2_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+__unorddf2_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+__unorddf2_FRAMESIZE,S   ; fccstk d=0 b=10 fs
                FIN
                STA     _fcc_q2
                DO      8+__unorddf2_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+__unorddf2_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+__unorddf2_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_long_hi
                DO      6+__unorddf2_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+__unorddf2_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+__unorddf2_FRAMESIZE,S   ; fccstk d=0 b=6 fs
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
                LDA     #15
                STA     _fcc_q3
                LDA     #65535
                STA     _fcc_q2
                LDA     #65535
                STA     _fcc_long_hi
                LDA     #65535
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
                FGX2_FARCALL _fcc_ll_and
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
                LDX     #0
                BIT     _fcc_long_hi
                BPL     *+5
                LDX     #$FFFF
                STX     _fcc_q2
                STX     _fcc_q3
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
                FGX2_FARCALL _fcc_ll_cmpu
                BNE     *+7
                LDA     #0
                BRA     *+5
                LDA     #1
                CMP     #0
                BNE     *+5
                BRL     _softdouble_L103
                LDA     #1
                BRL     _softdouble_L104
_softdouble_L103
                LDA     #0
_softdouble_L104
                CMP     #0
                BNE     *+5
                BRL     _softdouble_L102
                LDA     #1
                TAY
                TSC
                CLC
                ADC     #__unorddf2_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_softdouble_L102
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
                LDA     #2047
                JSR     _fcc_long_from_int
                LDX     #0
                BIT     _fcc_long_hi
                BPL     *+5
                LDX     #$FFFF
                STX     _fcc_q2
                STX     _fcc_q3
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
                FGX2_FARCALL _fcc_ll_cmpu
                BEQ     *+7
                LDA     #0
                BRA     *+5
                LDA     #1
                CMP     #0
                BNE     *+5
                BRL     _softdouble_L106
                DO      20+__unorddf2_FRAMESIZE/256
                TSC
                CLC
                ADC     #20+__unorddf2_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     20+__unorddf2_FRAMESIZE,S   ; fccstk d=0 b=20 fs
                FIN
                STA     _fcc_q3
                DO      18+__unorddf2_FRAMESIZE/256
                TSC
                CLC
                ADC     #18+__unorddf2_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     18+__unorddf2_FRAMESIZE,S   ; fccstk d=0 b=18 fs
                FIN
                STA     _fcc_q2
                DO      16+__unorddf2_FRAMESIZE/256
                TSC
                CLC
                ADC     #16+__unorddf2_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     16+__unorddf2_FRAMESIZE,S   ; fccstk d=0 b=16 fs
                FIN
                STA     _fcc_long_hi
                DO      14+__unorddf2_FRAMESIZE/256
                TSC
                CLC
                ADC     #14+__unorddf2_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     14+__unorddf2_FRAMESIZE,S   ; fccstk d=0 b=14 fs
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
                LDA     #15
                STA     _fcc_q3
                LDA     #65535
                STA     _fcc_q2
                LDA     #65535
                STA     _fcc_long_hi
                LDA     #65535
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
                FGX2_FARCALL _fcc_ll_and
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
                LDX     #0
                BIT     _fcc_long_hi
                BPL     *+5
                LDX     #$FFFF
                STX     _fcc_q2
                STX     _fcc_q3
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
                FGX2_FARCALL _fcc_ll_cmpu
                BNE     *+7
                LDA     #0
                BRA     *+5
                LDA     #1
                CMP     #0
                BNE     *+5
                BRL     _softdouble_L106
                LDA     #1
                BRL     _softdouble_L107
_softdouble_L106
                LDA     #0
_softdouble_L107
                CMP     #0
                BNE     *+5
                BRL     _softdouble_L105
                LDA     #1
                TAY
                TSC
                CLC
                ADC     #__unorddf2_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_softdouble_L105
                LDA     #0
                TAY
                TSC
                CLC
                ADC     #__unorddf2_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
__unorddf2_FRAMESIZE   EQU     16
__unorddf2_STKGUARD    EQU     0
                FGX2_EXPORT __eqdf2
__eqdf2            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #__eqdf2_FRAMESIZE
                DO      __eqdf2_STKGUARD
                BCC     __eqdf2_stkovf
                CMP     _fcc_stkfloor
                BCS     __eqdf2_stkok
__eqdf2_stkovf       JMP     _fcc_stkoflow
                FIN
__eqdf2_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      20+__eqdf2_FRAMESIZE/256
                TSC
                CLC
                ADC     #20+__eqdf2_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     20+__eqdf2_FRAMESIZE,S   ; fccstk d=0 b=20 fs
                FIN
                STA     _fcc_q3
                DO      18+__eqdf2_FRAMESIZE/256
                TSC
                CLC
                ADC     #18+__eqdf2_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     18+__eqdf2_FRAMESIZE,S   ; fccstk d=0 b=18 fs
                FIN
                STA     _fcc_q2
                DO      16+__eqdf2_FRAMESIZE/256
                TSC
                CLC
                ADC     #16+__eqdf2_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     16+__eqdf2_FRAMESIZE,S   ; fccstk d=0 b=16 fs
                FIN
                STA     _fcc_long_hi
                DO      14+__eqdf2_FRAMESIZE/256
                TSC
                CLC
                ADC     #14+__eqdf2_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     14+__eqdf2_FRAMESIZE,S   ; fccstk d=0 b=14 fs
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
                DO      20+__eqdf2_FRAMESIZE/256
                TSC
                CLC
                ADC     #20+__eqdf2_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     20+__eqdf2_FRAMESIZE,S   ; fccstk d=8 b=12 fs
                FIN
                STA     _fcc_q3
                DO      18+__eqdf2_FRAMESIZE/256
                TSC
                CLC
                ADC     #18+__eqdf2_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     18+__eqdf2_FRAMESIZE,S   ; fccstk d=8 b=10 fs
                FIN
                STA     _fcc_q2
                DO      16+__eqdf2_FRAMESIZE/256
                TSC
                CLC
                ADC     #16+__eqdf2_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     16+__eqdf2_FRAMESIZE,S   ; fccstk d=8 b=8 fs
                FIN
                STA     _fcc_long_hi
                DO      14+__eqdf2_FRAMESIZE/256
                TSC
                CLC
                ADC     #14+__eqdf2_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     14+__eqdf2_FRAMESIZE,S   ; fccstk d=8 b=6 fs
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
                FGX2_FARCALL __cmpdf2
                TAY
                TSC
                CLC
                ADC     #16
                TCS
                TYA
                TAX
                LDA     #0
                STA     _fcc_tmp_b
                TXA
                JSR     _fcc_ne16
                TAY
                TSC
                CLC
                ADC     #__eqdf2_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
__eqdf2_FRAMESIZE   EQU     0
__eqdf2_STKGUARD    EQU     0
                FGX2_EXPORT __nedf2
__nedf2            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #__nedf2_FRAMESIZE
                DO      __nedf2_STKGUARD
                BCC     __nedf2_stkovf
                CMP     _fcc_stkfloor
                BCS     __nedf2_stkok
__nedf2_stkovf       JMP     _fcc_stkoflow
                FIN
__nedf2_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      20+__nedf2_FRAMESIZE/256
                TSC
                CLC
                ADC     #20+__nedf2_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     20+__nedf2_FRAMESIZE,S   ; fccstk d=0 b=20 fs
                FIN
                STA     _fcc_q3
                DO      18+__nedf2_FRAMESIZE/256
                TSC
                CLC
                ADC     #18+__nedf2_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     18+__nedf2_FRAMESIZE,S   ; fccstk d=0 b=18 fs
                FIN
                STA     _fcc_q2
                DO      16+__nedf2_FRAMESIZE/256
                TSC
                CLC
                ADC     #16+__nedf2_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     16+__nedf2_FRAMESIZE,S   ; fccstk d=0 b=16 fs
                FIN
                STA     _fcc_long_hi
                DO      14+__nedf2_FRAMESIZE/256
                TSC
                CLC
                ADC     #14+__nedf2_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     14+__nedf2_FRAMESIZE,S   ; fccstk d=0 b=14 fs
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
                DO      20+__nedf2_FRAMESIZE/256
                TSC
                CLC
                ADC     #20+__nedf2_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     20+__nedf2_FRAMESIZE,S   ; fccstk d=8 b=12 fs
                FIN
                STA     _fcc_q3
                DO      18+__nedf2_FRAMESIZE/256
                TSC
                CLC
                ADC     #18+__nedf2_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     18+__nedf2_FRAMESIZE,S   ; fccstk d=8 b=10 fs
                FIN
                STA     _fcc_q2
                DO      16+__nedf2_FRAMESIZE/256
                TSC
                CLC
                ADC     #16+__nedf2_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     16+__nedf2_FRAMESIZE,S   ; fccstk d=8 b=8 fs
                FIN
                STA     _fcc_long_hi
                DO      14+__nedf2_FRAMESIZE/256
                TSC
                CLC
                ADC     #14+__nedf2_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     14+__nedf2_FRAMESIZE,S   ; fccstk d=8 b=6 fs
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
                FGX2_FARCALL __cmpdf2
                TAY
                TSC
                CLC
                ADC     #16
                TCS
                TYA
                TAX
                LDA     #0
                STA     _fcc_tmp_b
                TXA
                JSR     _fcc_ne16
                TAY
                TSC
                CLC
                ADC     #__nedf2_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
__nedf2_FRAMESIZE   EQU     0
__nedf2_STKGUARD    EQU     0
                FGX2_EXPORT __ltdf2
__ltdf2            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #__ltdf2_FRAMESIZE
                DO      __ltdf2_STKGUARD
                BCC     __ltdf2_stkovf
                CMP     _fcc_stkfloor
                BCS     __ltdf2_stkok
__ltdf2_stkovf       JMP     _fcc_stkoflow
                FIN
__ltdf2_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      20+__ltdf2_FRAMESIZE/256
                TSC
                CLC
                ADC     #20+__ltdf2_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     20+__ltdf2_FRAMESIZE,S   ; fccstk d=0 b=20 fs
                FIN
                STA     _fcc_q3
                DO      18+__ltdf2_FRAMESIZE/256
                TSC
                CLC
                ADC     #18+__ltdf2_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     18+__ltdf2_FRAMESIZE,S   ; fccstk d=0 b=18 fs
                FIN
                STA     _fcc_q2
                DO      16+__ltdf2_FRAMESIZE/256
                TSC
                CLC
                ADC     #16+__ltdf2_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     16+__ltdf2_FRAMESIZE,S   ; fccstk d=0 b=16 fs
                FIN
                STA     _fcc_long_hi
                DO      14+__ltdf2_FRAMESIZE/256
                TSC
                CLC
                ADC     #14+__ltdf2_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     14+__ltdf2_FRAMESIZE,S   ; fccstk d=0 b=14 fs
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
                DO      20+__ltdf2_FRAMESIZE/256
                TSC
                CLC
                ADC     #20+__ltdf2_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     20+__ltdf2_FRAMESIZE,S   ; fccstk d=8 b=12 fs
                FIN
                STA     _fcc_q3
                DO      18+__ltdf2_FRAMESIZE/256
                TSC
                CLC
                ADC     #18+__ltdf2_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     18+__ltdf2_FRAMESIZE,S   ; fccstk d=8 b=10 fs
                FIN
                STA     _fcc_q2
                DO      16+__ltdf2_FRAMESIZE/256
                TSC
                CLC
                ADC     #16+__ltdf2_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     16+__ltdf2_FRAMESIZE,S   ; fccstk d=8 b=8 fs
                FIN
                STA     _fcc_long_hi
                DO      14+__ltdf2_FRAMESIZE/256
                TSC
                CLC
                ADC     #14+__ltdf2_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     14+__ltdf2_FRAMESIZE,S   ; fccstk d=8 b=6 fs
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
                FGX2_FARCALL __cmpdf2
                TAY
                TSC
                CLC
                ADC     #16
                TCS
                TYA
                TAX
                LDA     #0
                STA     _fcc_tmp_b
                TXA
                JSR     _fcc_lts16
                TAY
                TSC
                CLC
                ADC     #__ltdf2_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
__ltdf2_FRAMESIZE   EQU     0
__ltdf2_STKGUARD    EQU     0
                FGX2_EXPORT __ledf2
__ledf2            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #__ledf2_FRAMESIZE
                DO      __ledf2_STKGUARD
                BCC     __ledf2_stkovf
                CMP     _fcc_stkfloor
                BCS     __ledf2_stkok
__ledf2_stkovf       JMP     _fcc_stkoflow
                FIN
__ledf2_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      20+__ledf2_FRAMESIZE/256
                TSC
                CLC
                ADC     #20+__ledf2_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     20+__ledf2_FRAMESIZE,S   ; fccstk d=0 b=20 fs
                FIN
                STA     _fcc_q3
                DO      18+__ledf2_FRAMESIZE/256
                TSC
                CLC
                ADC     #18+__ledf2_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     18+__ledf2_FRAMESIZE,S   ; fccstk d=0 b=18 fs
                FIN
                STA     _fcc_q2
                DO      16+__ledf2_FRAMESIZE/256
                TSC
                CLC
                ADC     #16+__ledf2_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     16+__ledf2_FRAMESIZE,S   ; fccstk d=0 b=16 fs
                FIN
                STA     _fcc_long_hi
                DO      14+__ledf2_FRAMESIZE/256
                TSC
                CLC
                ADC     #14+__ledf2_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     14+__ledf2_FRAMESIZE,S   ; fccstk d=0 b=14 fs
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
                DO      20+__ledf2_FRAMESIZE/256
                TSC
                CLC
                ADC     #20+__ledf2_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     20+__ledf2_FRAMESIZE,S   ; fccstk d=8 b=12 fs
                FIN
                STA     _fcc_q3
                DO      18+__ledf2_FRAMESIZE/256
                TSC
                CLC
                ADC     #18+__ledf2_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     18+__ledf2_FRAMESIZE,S   ; fccstk d=8 b=10 fs
                FIN
                STA     _fcc_q2
                DO      16+__ledf2_FRAMESIZE/256
                TSC
                CLC
                ADC     #16+__ledf2_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     16+__ledf2_FRAMESIZE,S   ; fccstk d=8 b=8 fs
                FIN
                STA     _fcc_long_hi
                DO      14+__ledf2_FRAMESIZE/256
                TSC
                CLC
                ADC     #14+__ledf2_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     14+__ledf2_FRAMESIZE,S   ; fccstk d=8 b=6 fs
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
                FGX2_FARCALL __cmpdf2
                TAY
                TSC
                CLC
                ADC     #16
                TCS
                TYA
                TAX
                LDA     #0
                STA     _fcc_tmp_b
                TXA
                JSR     _fcc_les16
                TAY
                TSC
                CLC
                ADC     #__ledf2_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
__ledf2_FRAMESIZE   EQU     0
__ledf2_STKGUARD    EQU     0
                FGX2_EXPORT __gtdf2
__gtdf2            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #__gtdf2_FRAMESIZE
                DO      __gtdf2_STKGUARD
                BCC     __gtdf2_stkovf
                CMP     _fcc_stkfloor
                BCS     __gtdf2_stkok
__gtdf2_stkovf       JMP     _fcc_stkoflow
                FIN
__gtdf2_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      20+__gtdf2_FRAMESIZE/256
                TSC
                CLC
                ADC     #20+__gtdf2_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     20+__gtdf2_FRAMESIZE,S   ; fccstk d=0 b=20 fs
                FIN
                STA     _fcc_q3
                DO      18+__gtdf2_FRAMESIZE/256
                TSC
                CLC
                ADC     #18+__gtdf2_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     18+__gtdf2_FRAMESIZE,S   ; fccstk d=0 b=18 fs
                FIN
                STA     _fcc_q2
                DO      16+__gtdf2_FRAMESIZE/256
                TSC
                CLC
                ADC     #16+__gtdf2_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     16+__gtdf2_FRAMESIZE,S   ; fccstk d=0 b=16 fs
                FIN
                STA     _fcc_long_hi
                DO      14+__gtdf2_FRAMESIZE/256
                TSC
                CLC
                ADC     #14+__gtdf2_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     14+__gtdf2_FRAMESIZE,S   ; fccstk d=0 b=14 fs
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
                DO      20+__gtdf2_FRAMESIZE/256
                TSC
                CLC
                ADC     #20+__gtdf2_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     20+__gtdf2_FRAMESIZE,S   ; fccstk d=8 b=12 fs
                FIN
                STA     _fcc_q3
                DO      18+__gtdf2_FRAMESIZE/256
                TSC
                CLC
                ADC     #18+__gtdf2_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     18+__gtdf2_FRAMESIZE,S   ; fccstk d=8 b=10 fs
                FIN
                STA     _fcc_q2
                DO      16+__gtdf2_FRAMESIZE/256
                TSC
                CLC
                ADC     #16+__gtdf2_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     16+__gtdf2_FRAMESIZE,S   ; fccstk d=8 b=8 fs
                FIN
                STA     _fcc_long_hi
                DO      14+__gtdf2_FRAMESIZE/256
                TSC
                CLC
                ADC     #14+__gtdf2_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     14+__gtdf2_FRAMESIZE,S   ; fccstk d=8 b=6 fs
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
                FGX2_FARCALL __cmpdf2
                TAY
                TSC
                CLC
                ADC     #16
                TCS
                TYA
                TAX
                LDA     #0
                STA     _fcc_tmp_b
                TXA
                JSR     _fcc_gts16
                TAY
                TSC
                CLC
                ADC     #__gtdf2_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
__gtdf2_FRAMESIZE   EQU     0
__gtdf2_STKGUARD    EQU     0
                FGX2_EXPORT __gedf2
__gedf2            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #__gedf2_FRAMESIZE
                DO      __gedf2_STKGUARD
                BCC     __gedf2_stkovf
                CMP     _fcc_stkfloor
                BCS     __gedf2_stkok
__gedf2_stkovf       JMP     _fcc_stkoflow
                FIN
__gedf2_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      20+__gedf2_FRAMESIZE/256
                TSC
                CLC
                ADC     #20+__gedf2_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     20+__gedf2_FRAMESIZE,S   ; fccstk d=0 b=20 fs
                FIN
                STA     _fcc_q3
                DO      18+__gedf2_FRAMESIZE/256
                TSC
                CLC
                ADC     #18+__gedf2_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     18+__gedf2_FRAMESIZE,S   ; fccstk d=0 b=18 fs
                FIN
                STA     _fcc_q2
                DO      16+__gedf2_FRAMESIZE/256
                TSC
                CLC
                ADC     #16+__gedf2_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     16+__gedf2_FRAMESIZE,S   ; fccstk d=0 b=16 fs
                FIN
                STA     _fcc_long_hi
                DO      14+__gedf2_FRAMESIZE/256
                TSC
                CLC
                ADC     #14+__gedf2_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     14+__gedf2_FRAMESIZE,S   ; fccstk d=0 b=14 fs
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
                DO      20+__gedf2_FRAMESIZE/256
                TSC
                CLC
                ADC     #20+__gedf2_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     20+__gedf2_FRAMESIZE,S   ; fccstk d=8 b=12 fs
                FIN
                STA     _fcc_q3
                DO      18+__gedf2_FRAMESIZE/256
                TSC
                CLC
                ADC     #18+__gedf2_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     18+__gedf2_FRAMESIZE,S   ; fccstk d=8 b=10 fs
                FIN
                STA     _fcc_q2
                DO      16+__gedf2_FRAMESIZE/256
                TSC
                CLC
                ADC     #16+__gedf2_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     16+__gedf2_FRAMESIZE,S   ; fccstk d=8 b=8 fs
                FIN
                STA     _fcc_long_hi
                DO      14+__gedf2_FRAMESIZE/256
                TSC
                CLC
                ADC     #14+__gedf2_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     14+__gedf2_FRAMESIZE,S   ; fccstk d=8 b=6 fs
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
                FGX2_FARCALL __cmpdf2
                TAY
                TSC
                CLC
                ADC     #16
                TCS
                TYA
                TAX
                LDA     #0
                STA     _fcc_tmp_b
                TXA
                JSR     _fcc_ges16
                TAY
                TSC
                CLC
                ADC     #__gedf2_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
__gedf2_FRAMESIZE   EQU     0
__gedf2_STKGUARD    EQU     0
                FGX2_EXPORT __extendsfdf2
__extendsfdf2            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #__extendsfdf2_FRAMESIZE
                DO      __extendsfdf2_STKGUARD
                BCC     __extendsfdf2_stkovf
                CMP     _fcc_stkfloor
                BCS     __extendsfdf2_stkok
__extendsfdf2_stkovf       JMP     _fcc_stkoflow
                FIN
__extendsfdf2_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      8+__extendsfdf2_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+__extendsfdf2_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+__extendsfdf2_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_long_hi
                DO      6+__extendsfdf2_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+__extendsfdf2_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+__extendsfdf2_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STZ     _fcc_q2
                STZ     _fcc_q3
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$8000
                STA     _fcc_long_hi
                LDA     #$0000
                STZ     _fcc_q2
                STZ     _fcc_q3
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
                FGX2_FARCALL _fcc_ll_and
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #32
                STA     _fcc_long_b_lo
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                PLA
                STA     _fcc_q2
                PLA
                STA     _fcc_q3
                TYA
                FGX2_FARCALL _fcc_ll_shl
                STA     1,S   ; fccstk d=0 b=1
                TAY
                LDA     _fcc_long_hi
                STA     3,S   ; fccstk d=0 b=3
                LDA     _fcc_q2
                STA     5,S   ; fccstk d=0 b=5
                LDA     _fcc_q3
                STA     7,S   ; fccstk d=0 b=7
                TYA
                DO      8+__extendsfdf2_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+__extendsfdf2_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+__extendsfdf2_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_long_hi
                DO      6+__extendsfdf2_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+__extendsfdf2_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+__extendsfdf2_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                LDA     _fcc_long_hi
                LSR
                LSR
                LSR
                LSR
                LSR
                LSR
                LSR
                STZ     _fcc_long_hi
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #255
                JSR     _fcc_long_from_int
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_and
                STA     9,S   ; fccstk d=0 b=9
                DO      8+__extendsfdf2_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+__extendsfdf2_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+__extendsfdf2_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_long_hi
                DO      6+__extendsfdf2_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+__extendsfdf2_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+__extendsfdf2_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$007F
                STA     _fcc_long_hi
                LDA     #$FFFF
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_and
                STA     11,S   ; fccstk d=0 b=11
                TAY
                LDA     _fcc_long_hi
                STA     13,S   ; fccstk d=0 b=13
                TYA
                LDA     9,S   ; fccstk d=0 b=9
                TAX
                TXA
                CMP     #0
                BEQ     *+5
                BRL     _softdouble_L108
                LDA     7,S   ; fccstk d=0 b=7
                STA     _fcc_q3
                LDA     5,S   ; fccstk d=0 b=5
                STA     _fcc_q2
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_long_hi
                LDA     1,S   ; fccstk d=0 b=1
                TAY
                TSC
                CLC
                ADC     #__extendsfdf2_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_softdouble_L108
                LDA     9,S   ; fccstk d=0 b=9
                TAX
                TXA
                CMP     #255
                BEQ     *+5
                BRL     _softdouble_L109
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
                LDA     #32752
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
                FGX2_FARCALL _fcc_ll_or
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     21,S   ; fccstk d=8 b=13
                STA     _fcc_long_hi
                LDA     19,S   ; fccstk d=8 b=11
                STZ     _fcc_q2
                STZ     _fcc_q3
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #29
                STA     _fcc_long_b_lo
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                PLA
                STA     _fcc_q2
                PLA
                STA     _fcc_q3
                TYA
                FGX2_FARCALL _fcc_ll_shl
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
                FGX2_FARCALL _fcc_ll_or
                TAY
                TSC
                CLC
                ADC     #__extendsfdf2_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_softdouble_L109
                LDA     9,S   ; fccstk d=0 b=9
                TAX
                TXA
                SEC
                SBC     #127
                STA     15,S   ; fccstk d=0 b=15
                LDA     13,S   ; fccstk d=0 b=13
                STA     _fcc_long_hi
                LDA     11,S   ; fccstk d=0 b=11
                STZ     _fcc_q2
                STZ     _fcc_q3
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #29
                STA     _fcc_long_b_lo
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                PLA
                STA     _fcc_q2
                PLA
                STA     _fcc_q3
                TYA
                FGX2_FARCALL _fcc_ll_shl
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #16
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
                FGX2_FARCALL _fcc_ll_or
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
                PHA
                LDA     17,S   ; fccstk d=10 b=7
                STA     _fcc_q3
                LDA     15,S   ; fccstk d=10 b=5
                STA     _fcc_q2
                LDA     13,S   ; fccstk d=10 b=3
                STA     _fcc_long_hi
                LDA     11,S   ; fccstk d=10 b=1
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                FGX2_FARCALL _softdouble_dpack
                TAY
                TSC
                CLC
                ADC     #18
                TCS
                TYA
                TAY
                TSC
                CLC
                ADC     #__extendsfdf2_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
__extendsfdf2_FRAMESIZE   EQU     16
__extendsfdf2_STKGUARD    EQU     0
                FGX2_EXPORT __truncdfsf2
__truncdfsf2            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #__truncdfsf2_FRAMESIZE
                DO      __truncdfsf2_STKGUARD
                BCC     __truncdfsf2_stkovf
                CMP     _fcc_stkfloor
                BCS     __truncdfsf2_stkok
__truncdfsf2_stkovf       JMP     _fcc_stkoflow
                FIN
__truncdfsf2_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      12+__truncdfsf2_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+__truncdfsf2_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+__truncdfsf2_FRAMESIZE,S   ; fccstk d=0 b=12 fs
                FIN
                STA     _fcc_q3
                DO      10+__truncdfsf2_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+__truncdfsf2_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+__truncdfsf2_FRAMESIZE,S   ; fccstk d=0 b=10 fs
                FIN
                STA     _fcc_q2
                DO      8+__truncdfsf2_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+__truncdfsf2_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+__truncdfsf2_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_long_hi
                DO      6+__truncdfsf2_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+__truncdfsf2_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+__truncdfsf2_FRAMESIZE,S   ; fccstk d=0 b=6 fs
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
                LDA     #32768
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
                FGX2_FARCALL _fcc_ll_and
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #32
                STA     _fcc_long_b_lo
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                PLA
                STA     _fcc_q2
                PLA
                STA     _fcc_q3
                TYA
                FGX2_FARCALL _fcc_ll_shru
                STA     1,S   ; fccstk d=0 b=1
                TAY
                LDA     _fcc_long_hi
                STA     3,S   ; fccstk d=0 b=3
                LDA     _fcc_q2
                STA     5,S   ; fccstk d=0 b=5
                LDA     _fcc_q3
                STA     7,S   ; fccstk d=0 b=7
                TYA
                DO      12+__truncdfsf2_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+__truncdfsf2_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+__truncdfsf2_FRAMESIZE,S   ; fccstk d=0 b=12 fs
                FIN
                STA     _fcc_q3
                DO      10+__truncdfsf2_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+__truncdfsf2_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+__truncdfsf2_FRAMESIZE,S   ; fccstk d=0 b=10 fs
                FIN
                STA     _fcc_q2
                DO      8+__truncdfsf2_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+__truncdfsf2_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+__truncdfsf2_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_long_hi
                DO      6+__truncdfsf2_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+__truncdfsf2_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+__truncdfsf2_FRAMESIZE,S   ; fccstk d=0 b=6 fs
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
                LDA     #52
                STA     _fcc_long_b_lo
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                PLA
                STA     _fcc_q2
                PLA
                STA     _fcc_q3
                TYA
                FGX2_FARCALL _fcc_ll_shru
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #2047
                JSR     _fcc_long_from_int
                LDX     #0
                BIT     _fcc_long_hi
                BPL     *+5
                LDX     #$FFFF
                STX     _fcc_q2
                STX     _fcc_q3
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
                FGX2_FARCALL _fcc_ll_and
                STA     9,S   ; fccstk d=0 b=9
                DO      12+__truncdfsf2_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+__truncdfsf2_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+__truncdfsf2_FRAMESIZE,S   ; fccstk d=0 b=12 fs
                FIN
                STA     _fcc_q3
                DO      10+__truncdfsf2_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+__truncdfsf2_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+__truncdfsf2_FRAMESIZE,S   ; fccstk d=0 b=10 fs
                FIN
                STA     _fcc_q2
                DO      8+__truncdfsf2_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+__truncdfsf2_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+__truncdfsf2_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_long_hi
                DO      6+__truncdfsf2_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+__truncdfsf2_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+__truncdfsf2_FRAMESIZE,S   ; fccstk d=0 b=6 fs
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
                LDA     #15
                STA     _fcc_q3
                LDA     #65535
                STA     _fcc_q2
                LDA     #65535
                STA     _fcc_long_hi
                LDA     #65535
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
                FGX2_FARCALL _fcc_ll_and
                STA     11,S   ; fccstk d=0 b=11
                TAY
                LDA     _fcc_long_hi
                STA     13,S   ; fccstk d=0 b=13
                LDA     _fcc_q2
                STA     15,S   ; fccstk d=0 b=15
                LDA     _fcc_q3
                STA     17,S   ; fccstk d=0 b=17
                TYA
                LDA     9,S   ; fccstk d=0 b=9
                TAX
                TXA
                CMP     #0
                BEQ     *+5
                BRL     _softdouble_L110
                LDA     7,S   ; fccstk d=0 b=7
                STA     _fcc_q3
                LDA     5,S   ; fccstk d=0 b=5
                STA     _fcc_q2
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_long_hi
                LDA     1,S   ; fccstk d=0 b=1
                TAY
                TSC
                CLC
                ADC     #__truncdfsf2_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_softdouble_L110
                LDA     9,S   ; fccstk d=0 b=9
                TAX
                TXA
                CMP     #2047
                BEQ     *+5
                BRL     _softdouble_L111
                LDA     17,S   ; fccstk d=0 b=17
                STA     _fcc_q3
                LDA     15,S   ; fccstk d=0 b=15
                STA     _fcc_q2
                LDA     13,S   ; fccstk d=0 b=13
                STA     _fcc_long_hi
                LDA     11,S   ; fccstk d=0 b=11
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #29
                STA     _fcc_long_b_lo
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                PLA
                STA     _fcc_q2
                PLA
                STA     _fcc_q3
                TYA
                FGX2_FARCALL _fcc_ll_shru
                STA     19,S   ; fccstk d=0 b=19
                TAY
                LDA     _fcc_long_hi
                STA     21,S   ; fccstk d=0 b=21
                TYA
                LDA     17,S   ; fccstk d=0 b=17
                STA     _fcc_q3
                LDA     15,S   ; fccstk d=0 b=15
                STA     _fcc_q2
                LDA     13,S   ; fccstk d=0 b=13
                STA     _fcc_long_hi
                LDA     11,S   ; fccstk d=0 b=11
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
                LDX     #0
                BIT     _fcc_long_hi
                BPL     *+5
                LDX     #$FFFF
                STX     _fcc_q2
                STX     _fcc_q3
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
                FGX2_FARCALL _fcc_ll_cmpu
                BNE     *+7
                LDA     #0
                BRA     *+5
                LDA     #1
                CMP     #0
                BNE     *+5
                BRL     _softdouble_L113
                LDA     21,S   ; fccstk d=0 b=21
                STA     _fcc_long_hi
                LDA     19,S   ; fccstk d=0 b=19
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
                JSR     _fcc_long_eq
                CMP     #0
                BNE     *+5
                BRL     _softdouble_L113
                LDA     #1
                BRL     _softdouble_L114
_softdouble_L113
                LDA     #0
_softdouble_L114
                CMP     #0
                BNE     *+5
                BRL     _softdouble_L112
                LDA     #$0040
                STA     _fcc_long_hi
                LDA     #$0000
                STA     19,S   ; fccstk d=0 b=19
                TAY
                LDA     _fcc_long_hi
                STA     21,S   ; fccstk d=0 b=21
                TYA
_softdouble_L112
                LDA     7,S   ; fccstk d=0 b=7
                STA     _fcc_q3
                LDA     5,S   ; fccstk d=0 b=5
                STA     _fcc_q2
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_long_hi
                LDA     1,S   ; fccstk d=0 b=1
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$7F80
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
                JSR     _fcc_long_or
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     25,S   ; fccstk d=4 b=21
                STA     _fcc_long_hi
                LDA     23,S   ; fccstk d=4 b=19
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_or
                TAY
                TSC
                CLC
                ADC     #__truncdfsf2_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_softdouble_L111
                LDA     9,S   ; fccstk d=0 b=9
                TAX
                TXA
                SEC
                SBC     #1023
                STA     23,S   ; fccstk d=0 b=23
                TAX
                TXA
                CLC
                ADC     #127
                STA     25,S   ; fccstk d=0 b=25
                TAX
                TXA
                LDX     #0
                STA     _fcc_tmp_b
                TXA
                SEC
                SBC     _fcc_tmp_b
                BVC     _softdouble_L116
                EOR     #$8000
_softdouble_L116
                BPL     *+5
                BRL     _softdouble_L115
                LDA     7,S   ; fccstk d=0 b=7
                STA     _fcc_q3
                LDA     5,S   ; fccstk d=0 b=5
                STA     _fcc_q2
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_long_hi
                LDA     1,S   ; fccstk d=0 b=1
                TAY
                TSC
                CLC
                ADC     #__truncdfsf2_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_softdouble_L115
                LDA     17,S   ; fccstk d=0 b=17
                STA     _fcc_q3
                LDA     15,S   ; fccstk d=0 b=15
                STA     _fcc_q2
                LDA     13,S   ; fccstk d=0 b=13
                STA     _fcc_long_hi
                LDA     11,S   ; fccstk d=0 b=11
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #29
                STA     _fcc_long_b_lo
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                PLA
                STA     _fcc_q2
                PLA
                STA     _fcc_q3
                TYA
                FGX2_FARCALL _fcc_ll_shru
                STA     27,S   ; fccstk d=0 b=27
                TAY
                LDA     _fcc_long_hi
                STA     29,S   ; fccstk d=0 b=29
                TYA
                LDA     17,S   ; fccstk d=0 b=17
                STA     _fcc_q3
                LDA     15,S   ; fccstk d=0 b=15
                STA     _fcc_q2
                LDA     13,S   ; fccstk d=0 b=13
                STA     _fcc_long_hi
                LDA     11,S   ; fccstk d=0 b=11
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$1FFF
                STA     _fcc_long_hi
                LDA     #$FFFF
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_and
                STA     31,S   ; fccstk d=0 b=31
                TAY
                LDA     _fcc_long_hi
                STA     33,S   ; fccstk d=0 b=33
                TYA
                LDA     33,S   ; fccstk d=0 b=33
                STA     _fcc_long_hi
                LDA     31,S   ; fccstk d=0 b=31
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$1000
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
                JSR     _fcc_long_gtu
                CMP     #0
                BEQ     *+5
                BRL     _softdouble_L118
                LDA     33,S   ; fccstk d=0 b=33
                STA     _fcc_long_hi
                LDA     31,S   ; fccstk d=0 b=31
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$1000
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
                JSR     _fcc_long_eq
                CMP     #0
                BNE     *+5
                BRL     _softdouble_L120
                LDA     29,S   ; fccstk d=0 b=29
                STA     _fcc_long_hi
                LDA     27,S   ; fccstk d=0 b=27
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
                JSR     _fcc_long_and
                ORA     _fcc_long_hi
                BNE     *+5
                BRL     _softdouble_L120
                LDA     #1
                BRL     _softdouble_L121
_softdouble_L120
                LDA     #0
_softdouble_L121
                CMP     #0
                BEQ     *+5
                BRL     _softdouble_L118
                LDA     #0
                BRL     _softdouble_L119
_softdouble_L118
                LDA     #1
_softdouble_L119
                CMP     #0
                BNE     *+5
                BRL     _softdouble_L117
                LDA     #1
                JSR     _fcc_long_from_int
                STA     _fcc_long_b_lo
                LDA     _fcc_long_hi
                STA     _fcc_long_b_hi
                LDA     29,S   ; fccstk d=0 b=29
                STA     _fcc_long_hi
                LDA     27,S   ; fccstk d=0 b=27
                JSR     _fcc_long_add
                STA     27,S   ; fccstk d=0 b=27
                TAY
                LDA     _fcc_long_hi
                STA     29,S   ; fccstk d=0 b=29
                TYA
                LDA     29,S   ; fccstk d=0 b=29
                STA     _fcc_long_hi
                LDA     27,S   ; fccstk d=0 b=27
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0080
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
                JSR     _fcc_long_eq
                CMP     #0
                BNE     *+5
                BRL     _softdouble_L122
                LDA     #0
                STA     27,S   ; fccstk d=0 b=27
                TAY
                JSR     _fcc_long_from_int
                LDA     _fcc_long_hi
                STA     29,S   ; fccstk d=0 b=29
                TYA
                LDA     25,S   ; fccstk d=0 b=25
                CLC
                ADC     #1
                STA     25,S   ; fccstk d=0 b=25
_softdouble_L122
_softdouble_L117
                LDA     25,S   ; fccstk d=0 b=25
                TAX
                TXA
                SEC
                SBC     #255
                BVC     _softdouble_L124
                EOR     #$8000
_softdouble_L124
                BPL     *+5
                BRL     _softdouble_L123
                LDA     7,S   ; fccstk d=0 b=7
                STA     _fcc_q3
                LDA     5,S   ; fccstk d=0 b=5
                STA     _fcc_q2
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_long_hi
                LDA     1,S   ; fccstk d=0 b=1
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$7F80
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
                JSR     _fcc_long_or
                TAY
                TSC
                CLC
                ADC     #__truncdfsf2_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_softdouble_L123
                LDA     7,S   ; fccstk d=0 b=7
                STA     _fcc_q3
                LDA     5,S   ; fccstk d=0 b=5
                STA     _fcc_q2
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_long_hi
                LDA     1,S   ; fccstk d=0 b=1
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     29,S   ; fccstk d=4 b=25
                JSR     _fcc_long_from_int
                ASL
                ASL
                ASL
                ASL
                ASL
                ASL
                ASL
                STA     _fcc_long_hi
                LDA     #0
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_or
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     33,S   ; fccstk d=4 b=29
                STA     _fcc_long_hi
                LDA     31,S   ; fccstk d=4 b=27
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_or
                TAY
                TSC
                CLC
                ADC     #__truncdfsf2_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
__truncdfsf2_FRAMESIZE   EQU     34
__truncdfsf2_STKGUARD    EQU     0
                FGX2_EXPORT __floatsidf
__floatsidf            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #__floatsidf_FRAMESIZE
                DO      __floatsidf_STKGUARD
                BCC     __floatsidf_stkovf
                CMP     _fcc_stkfloor
                BCS     __floatsidf_stkok
__floatsidf_stkovf       JMP     _fcc_stkoflow
                FIN
__floatsidf_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      8+__floatsidf_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+__floatsidf_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+__floatsidf_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_long_hi
                DO      6+__floatsidf_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+__floatsidf_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+__floatsidf_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
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
                JSR     _fcc_long_eq
                CMP     #0
                BNE     *+5
                BRL     _softdouble_L125
                LDA     #0
                JSR     _fcc_long_from_int
                LDX     #0
                BIT     _fcc_long_hi
                BPL     *+5
                LDX     #$FFFF
                STX     _fcc_q2
                STX     _fcc_q3
                TAY
                TSC
                CLC
                ADC     #__floatsidf_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_softdouble_L125
                DO      8+__floatsidf_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+__floatsidf_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+__floatsidf_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_long_hi
                DO      6+__floatsidf_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+__floatsidf_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+__floatsidf_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
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
                JSR     _fcc_long_lts
                CMP     #0
                BNE     *+5
                BRL     _softdouble_L126
                LDA     #32768
                STA     _fcc_q3
                LDA     #0
                STA     _fcc_q2
                LDA     #0
                STA     _fcc_long_hi
                LDA     #0
                BRL     _softdouble_L127
_softdouble_L126
                LDA     #0
                JSR     _fcc_long_from_int
                LDX     #0
                BIT     _fcc_long_hi
                BPL     *+5
                LDX     #$FFFF
                STX     _fcc_q2
                STX     _fcc_q3
_softdouble_L127
                STA     1,S   ; fccstk d=0 b=1
                TAY
                LDA     _fcc_long_hi
                STA     3,S   ; fccstk d=0 b=3
                LDA     _fcc_q2
                STA     5,S   ; fccstk d=0 b=5
                LDA     _fcc_q3
                STA     7,S   ; fccstk d=0 b=7
                TYA
                DO      8+__floatsidf_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+__floatsidf_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+__floatsidf_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_long_hi
                DO      6+__floatsidf_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+__floatsidf_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+__floatsidf_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                LDX     #0
                BIT     _fcc_long_hi
                BPL     *+5
                LDX     #$FFFF
                STX     _fcc_q2
                STX     _fcc_q3
                STA     9,S   ; fccstk d=0 b=9
                TAY
                LDA     _fcc_long_hi
                STA     11,S   ; fccstk d=0 b=11
                LDA     _fcc_q2
                STA     13,S   ; fccstk d=0 b=13
                LDA     _fcc_q3
                STA     15,S   ; fccstk d=0 b=15
                TYA
                DO      8+__floatsidf_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+__floatsidf_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+__floatsidf_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_long_hi
                DO      6+__floatsidf_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+__floatsidf_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+__floatsidf_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
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
                JSR     _fcc_long_lts
                CMP     #0
                BNE     *+5
                BRL     _softdouble_L128
                LDA     15,S   ; fccstk d=0 b=15
                STA     _fcc_q3
                LDA     13,S   ; fccstk d=0 b=13
                STA     _fcc_q2
                LDA     11,S   ; fccstk d=0 b=11
                STA     _fcc_long_hi
                LDA     9,S   ; fccstk d=0 b=9
                FGX2_FARCALL _fcc_ll_neg
                STA     9,S   ; fccstk d=0 b=9
                TAY
                LDA     _fcc_long_hi
                STA     11,S   ; fccstk d=0 b=11
                LDA     _fcc_q2
                STA     13,S   ; fccstk d=0 b=13
                LDA     _fcc_q3
                STA     15,S   ; fccstk d=0 b=15
                TYA
_softdouble_L128
                LDA     #0
                STA     17,S   ; fccstk d=0 b=17
_softdouble_L129
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
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
                LDA     #16
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
                FGX2_FARCALL _fcc_ll_and
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
                LDX     #0
                BIT     _fcc_long_hi
                BPL     *+5
                LDX     #$FFFF
                STX     _fcc_q2
                STX     _fcc_q3
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
                FGX2_FARCALL _fcc_ll_cmpu
                BEQ     *+7
                LDA     #0
                BRA     *+5
                LDA     #1
                CMP     #0
                BNE     *+5
                BRL     _softdouble_L130
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
                LDA     #1
                STA     _fcc_long_b_lo
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                PLA
                STA     _fcc_q2
                PLA
                STA     _fcc_q3
                TYA
                FGX2_FARCALL _fcc_ll_shl
                STA     9,S   ; fccstk d=0 b=9
                TAY
                LDA     _fcc_long_hi
                STA     11,S   ; fccstk d=0 b=11
                LDA     _fcc_q2
                STA     13,S   ; fccstk d=0 b=13
                LDA     _fcc_q3
                STA     15,S   ; fccstk d=0 b=15
                TYA
                LDA     17,S   ; fccstk d=0 b=17
                SEC
                SBC     #1
                STA     17,S   ; fccstk d=0 b=17
                BRL     _softdouble_L129
_softdouble_L130
                LDA     17,S   ; fccstk d=0 b=17
                TAX
                LDA     #31
                TAY
                TYA
                CLC
                ADC     #21
                STA     _fcc_tmp_b
                TXA
                CLC
                ADC     _fcc_tmp_b
                STA     17,S   ; fccstk d=0 b=17
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
                LDA     25,S   ; fccstk d=8 b=17
                PHA
                LDA     17,S   ; fccstk d=10 b=7
                STA     _fcc_q3
                LDA     15,S   ; fccstk d=10 b=5
                STA     _fcc_q2
                LDA     13,S   ; fccstk d=10 b=3
                STA     _fcc_long_hi
                LDA     11,S   ; fccstk d=10 b=1
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                FGX2_FARCALL _softdouble_dpack
                TAY
                TSC
                CLC
                ADC     #18
                TCS
                TYA
                TAY
                TSC
                CLC
                ADC     #__floatsidf_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
__floatsidf_FRAMESIZE   EQU     18
__floatsidf_STKGUARD    EQU     0
                FGX2_EXPORT __floatunsidf
__floatunsidf            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #__floatunsidf_FRAMESIZE
                DO      __floatunsidf_STKGUARD
                BCC     __floatunsidf_stkovf
                CMP     _fcc_stkfloor
                BCS     __floatunsidf_stkok
__floatunsidf_stkovf       JMP     _fcc_stkoflow
                FIN
__floatunsidf_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      8+__floatunsidf_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+__floatunsidf_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+__floatunsidf_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_long_hi
                DO      6+__floatunsidf_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+__floatunsidf_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+__floatunsidf_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
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
                JSR     _fcc_long_eq
                CMP     #0
                BNE     *+5
                BRL     _softdouble_L131
                LDA     #0
                JSR     _fcc_long_from_int
                LDX     #0
                BIT     _fcc_long_hi
                BPL     *+5
                LDX     #$FFFF
                STX     _fcc_q2
                STX     _fcc_q3
                TAY
                TSC
                CLC
                ADC     #__floatunsidf_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_softdouble_L131
                DO      8+__floatunsidf_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+__floatunsidf_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+__floatunsidf_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_long_hi
                DO      6+__floatunsidf_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+__floatunsidf_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+__floatunsidf_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STZ     _fcc_q2
                STZ     _fcc_q3
                STA     1,S   ; fccstk d=0 b=1
                TAY
                LDA     _fcc_long_hi
                STA     3,S   ; fccstk d=0 b=3
                LDA     _fcc_q2
                STA     5,S   ; fccstk d=0 b=5
                LDA     _fcc_q3
                STA     7,S   ; fccstk d=0 b=7
                TYA
                LDA     #0
                STA     9,S   ; fccstk d=0 b=9
_softdouble_L132
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
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
                LDA     #16
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
                FGX2_FARCALL _fcc_ll_and
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
                LDX     #0
                BIT     _fcc_long_hi
                BPL     *+5
                LDX     #$FFFF
                STX     _fcc_q2
                STX     _fcc_q3
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
                FGX2_FARCALL _fcc_ll_cmpu
                BEQ     *+7
                LDA     #0
                BRA     *+5
                LDA     #1
                CMP     #0
                BNE     *+5
                BRL     _softdouble_L133
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
                LDA     #1
                STA     _fcc_long_b_lo
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                PLA
                STA     _fcc_q2
                PLA
                STA     _fcc_q3
                TYA
                FGX2_FARCALL _fcc_ll_shl
                STA     1,S   ; fccstk d=0 b=1
                TAY
                LDA     _fcc_long_hi
                STA     3,S   ; fccstk d=0 b=3
                LDA     _fcc_q2
                STA     5,S   ; fccstk d=0 b=5
                LDA     _fcc_q3
                STA     7,S   ; fccstk d=0 b=7
                TYA
                LDA     9,S   ; fccstk d=0 b=9
                SEC
                SBC     #1
                STA     9,S   ; fccstk d=0 b=9
                BRL     _softdouble_L132
_softdouble_L133
                LDA     9,S   ; fccstk d=0 b=9
                TAX
                LDA     #31
                TAY
                TYA
                CLC
                ADC     #21
                STA     _fcc_tmp_b
                TXA
                CLC
                ADC     _fcc_tmp_b
                STA     9,S   ; fccstk d=0 b=9
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
                LDA     17,S   ; fccstk d=8 b=9
                PHA
                LDA     #0
                JSR     _fcc_long_from_int
                LDX     #0
                BIT     _fcc_long_hi
                BPL     *+5
                LDX     #$FFFF
                STX     _fcc_q2
                STX     _fcc_q3
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                FGX2_FARCALL _softdouble_dpack
                TAY
                TSC
                CLC
                ADC     #18
                TCS
                TYA
                TAY
                TSC
                CLC
                ADC     #__floatunsidf_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
__floatunsidf_FRAMESIZE   EQU     10
__floatunsidf_STKGUARD    EQU     0
                FGX2_EXPORT __fixdfsi
__fixdfsi            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #__fixdfsi_FRAMESIZE
                DO      __fixdfsi_STKGUARD
                BCC     __fixdfsi_stkovf
                CMP     _fcc_stkfloor
                BCS     __fixdfsi_stkok
__fixdfsi_stkovf       JMP     _fcc_stkoflow
                FIN
__fixdfsi_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      12+__fixdfsi_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+__fixdfsi_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+__fixdfsi_FRAMESIZE,S   ; fccstk d=0 b=12 fs
                FIN
                STA     _fcc_q3
                DO      10+__fixdfsi_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+__fixdfsi_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+__fixdfsi_FRAMESIZE,S   ; fccstk d=0 b=10 fs
                FIN
                STA     _fcc_q2
                DO      8+__fixdfsi_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+__fixdfsi_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+__fixdfsi_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_long_hi
                DO      6+__fixdfsi_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+__fixdfsi_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+__fixdfsi_FRAMESIZE,S   ; fccstk d=0 b=6 fs
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
                LDA     #32768
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
                FGX2_FARCALL _fcc_ll_and
                STA     1,S   ; fccstk d=0 b=1
                TAY
                LDA     _fcc_long_hi
                STA     3,S   ; fccstk d=0 b=3
                LDA     _fcc_q2
                STA     5,S   ; fccstk d=0 b=5
                LDA     _fcc_q3
                STA     7,S   ; fccstk d=0 b=7
                TYA
                DO      12+__fixdfsi_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+__fixdfsi_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+__fixdfsi_FRAMESIZE,S   ; fccstk d=0 b=12 fs
                FIN
                STA     _fcc_q3
                DO      10+__fixdfsi_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+__fixdfsi_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+__fixdfsi_FRAMESIZE,S   ; fccstk d=0 b=10 fs
                FIN
                STA     _fcc_q2
                DO      8+__fixdfsi_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+__fixdfsi_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+__fixdfsi_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_long_hi
                DO      6+__fixdfsi_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+__fixdfsi_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+__fixdfsi_FRAMESIZE,S   ; fccstk d=0 b=6 fs
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
                LDA     #52
                STA     _fcc_long_b_lo
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                PLA
                STA     _fcc_q2
                PLA
                STA     _fcc_q3
                TYA
                FGX2_FARCALL _fcc_ll_shru
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #2047
                JSR     _fcc_long_from_int
                LDX     #0
                BIT     _fcc_long_hi
                BPL     *+5
                LDX     #$FFFF
                STX     _fcc_q2
                STX     _fcc_q3
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
                FGX2_FARCALL _fcc_ll_and
                STA     9,S   ; fccstk d=0 b=9
                TAX
                TXA
                CMP     #0
                BEQ     *+5
                BRL     _softdouble_L134
                LDA     #0
                JSR     _fcc_long_from_int
                TAY
                TSC
                CLC
                ADC     #__fixdfsi_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_softdouble_L134
                LDA     9,S   ; fccstk d=0 b=9
                TAX
                TXA
                CMP     #2047
                BEQ     *+5
                BRL     _softdouble_L135
                LDA     7,S   ; fccstk d=0 b=7
                STA     _fcc_q3
                LDA     5,S   ; fccstk d=0 b=5
                STA     _fcc_q2
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_long_hi
                LDA     1,S   ; fccstk d=0 b=1
                ORA     _fcc_long_hi
                ORA     _fcc_q2
                ORA     _fcc_q3
                BNE     *+5
                BRL     _softdouble_L136
                LDA     #$8000
                STA     _fcc_long_hi
                LDA     #$0000
                BRL     _softdouble_L137
_softdouble_L136
                LDA     #$7FFF
                STA     _fcc_long_hi
                LDA     #$FFFF
_softdouble_L137
                TAY
                TSC
                CLC
                ADC     #__fixdfsi_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_softdouble_L135
                LDA     9,S   ; fccstk d=0 b=9
                TAX
                TXA
                SEC
                SBC     #1023
                STA     11,S   ; fccstk d=0 b=11
                TAX
                TXA
                SEC
                SBC     #0
                BVC     _softdouble_L139
                EOR     #$8000
_softdouble_L139
                BMI     *+5
                BRL     _softdouble_L138
                LDA     #0
                JSR     _fcc_long_from_int
                TAY
                TSC
                CLC
                ADC     #__fixdfsi_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_softdouble_L138
                LDA     11,S   ; fccstk d=0 b=11
                TAX
                TXA
                LDX     #30
                STA     _fcc_tmp_b
                TXA
                SEC
                SBC     _fcc_tmp_b
                BVC     _softdouble_L141
                EOR     #$8000
_softdouble_L141
                BMI     *+5
                BRL     _softdouble_L140
                LDA     7,S   ; fccstk d=0 b=7
                STA     _fcc_q3
                LDA     5,S   ; fccstk d=0 b=5
                STA     _fcc_q2
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_long_hi
                LDA     1,S   ; fccstk d=0 b=1
                ORA     _fcc_long_hi
                ORA     _fcc_q2
                ORA     _fcc_q3
                BNE     *+5
                BRL     _softdouble_L142
                LDA     #$8000
                STA     _fcc_long_hi
                LDA     #$0000
                BRL     _softdouble_L143
_softdouble_L142
                LDA     #$7FFF
                STA     _fcc_long_hi
                LDA     #$FFFF
_softdouble_L143
                TAY
                TSC
                CLC
                ADC     #__fixdfsi_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_softdouble_L140
                DO      12+__fixdfsi_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+__fixdfsi_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+__fixdfsi_FRAMESIZE,S   ; fccstk d=0 b=12 fs
                FIN
                STA     _fcc_q3
                DO      10+__fixdfsi_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+__fixdfsi_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+__fixdfsi_FRAMESIZE,S   ; fccstk d=0 b=10 fs
                FIN
                STA     _fcc_q2
                DO      8+__fixdfsi_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+__fixdfsi_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+__fixdfsi_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_long_hi
                DO      6+__fixdfsi_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+__fixdfsi_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+__fixdfsi_FRAMESIZE,S   ; fccstk d=0 b=6 fs
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
                LDA     #15
                STA     _fcc_q3
                LDA     #65535
                STA     _fcc_q2
                LDA     #65535
                STA     _fcc_long_hi
                LDA     #65535
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
                FGX2_FARCALL _fcc_ll_and
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #16
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
                FGX2_FARCALL _fcc_ll_or
                STA     13,S   ; fccstk d=0 b=13
                TAY
                LDA     _fcc_long_hi
                STA     15,S   ; fccstk d=0 b=15
                LDA     _fcc_q2
                STA     17,S   ; fccstk d=0 b=17
                LDA     _fcc_q3
                STA     19,S   ; fccstk d=0 b=19
                TYA
                LDA     #52
                SEC
                SBC     11,S   ; fccstk d=0 b=11
                STA     21,S   ; fccstk d=0 b=21
                TAX
                TXA
                SEC
                SBC     #0
                BVC     _softdouble_L145
                EOR     #$8000
_softdouble_L145
                BPL     *+5
                BRL     _softdouble_L144
                LDA     19,S   ; fccstk d=0 b=19
                STA     _fcc_q3
                LDA     17,S   ; fccstk d=0 b=17
                STA     _fcc_q2
                LDA     15,S   ; fccstk d=0 b=15
                STA     _fcc_long_hi
                LDA     13,S   ; fccstk d=0 b=13
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     29,S   ; fccstk d=8 b=21
                STA     _fcc_long_b_lo
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                PLA
                STA     _fcc_q2
                PLA
                STA     _fcc_q3
                TYA
                FGX2_FARCALL _fcc_ll_shru
                STA     13,S   ; fccstk d=0 b=13
                TAY
                LDA     _fcc_long_hi
                STA     15,S   ; fccstk d=0 b=15
                LDA     _fcc_q2
                STA     17,S   ; fccstk d=0 b=17
                LDA     _fcc_q3
                STA     19,S   ; fccstk d=0 b=19
                TYA
                BRL     _softdouble_L146
_softdouble_L144
                LDA     19,S   ; fccstk d=0 b=19
                STA     _fcc_q3
                LDA     17,S   ; fccstk d=0 b=17
                STA     _fcc_q2
                LDA     15,S   ; fccstk d=0 b=15
                STA     _fcc_long_hi
                LDA     13,S   ; fccstk d=0 b=13
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     29,S   ; fccstk d=8 b=21
                EOR     #$FFFF
                INC
                STA     _fcc_long_b_lo
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                PLA
                STA     _fcc_q2
                PLA
                STA     _fcc_q3
                TYA
                FGX2_FARCALL _fcc_ll_shl
                STA     13,S   ; fccstk d=0 b=13
                TAY
                LDA     _fcc_long_hi
                STA     15,S   ; fccstk d=0 b=15
                LDA     _fcc_q2
                STA     17,S   ; fccstk d=0 b=17
                LDA     _fcc_q3
                STA     19,S   ; fccstk d=0 b=19
                TYA
_softdouble_L146
                LDA     7,S   ; fccstk d=0 b=7
                STA     _fcc_q3
                LDA     5,S   ; fccstk d=0 b=5
                STA     _fcc_q2
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_long_hi
                LDA     1,S   ; fccstk d=0 b=1
                ORA     _fcc_long_hi
                ORA     _fcc_q2
                ORA     _fcc_q3
                BNE     *+5
                BRL     _softdouble_L147
                LDA     19,S   ; fccstk d=0 b=19
                STA     _fcc_q3
                LDA     17,S   ; fccstk d=0 b=17
                STA     _fcc_q2
                LDA     15,S   ; fccstk d=0 b=15
                STA     _fcc_long_hi
                LDA     13,S   ; fccstk d=0 b=13
                JSR     _fcc_long_neg
                BRL     _softdouble_L148
_softdouble_L147
                LDA     19,S   ; fccstk d=0 b=19
                STA     _fcc_q3
                LDA     17,S   ; fccstk d=0 b=17
                STA     _fcc_q2
                LDA     15,S   ; fccstk d=0 b=15
                STA     _fcc_long_hi
                LDA     13,S   ; fccstk d=0 b=13
_softdouble_L148
                TAY
                TSC
                CLC
                ADC     #__fixdfsi_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
__fixdfsi_FRAMESIZE   EQU     22
__fixdfsi_STKGUARD    EQU     0
                FGX2_EXPORT __fixunsdfsi
__fixunsdfsi            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #__fixunsdfsi_FRAMESIZE
                DO      __fixunsdfsi_STKGUARD
                BCC     __fixunsdfsi_stkovf
                CMP     _fcc_stkfloor
                BCS     __fixunsdfsi_stkok
__fixunsdfsi_stkovf       JMP     _fcc_stkoflow
                FIN
__fixunsdfsi_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      12+__fixunsdfsi_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+__fixunsdfsi_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+__fixunsdfsi_FRAMESIZE,S   ; fccstk d=0 b=12 fs
                FIN
                STA     _fcc_q3
                DO      10+__fixunsdfsi_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+__fixunsdfsi_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+__fixunsdfsi_FRAMESIZE,S   ; fccstk d=0 b=10 fs
                FIN
                STA     _fcc_q2
                DO      8+__fixunsdfsi_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+__fixunsdfsi_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+__fixunsdfsi_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_long_hi
                DO      6+__fixunsdfsi_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+__fixunsdfsi_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+__fixunsdfsi_FRAMESIZE,S   ; fccstk d=0 b=6 fs
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
                LDA     #32768
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
                FGX2_FARCALL _fcc_ll_and
                ORA     _fcc_long_hi
                ORA     _fcc_q2
                ORA     _fcc_q3
                BNE     *+5
                BRL     _softdouble_L149
                LDA     #0
                JSR     _fcc_long_from_int
                TAY
                TSC
                CLC
                ADC     #__fixunsdfsi_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_softdouble_L149
                DO      12+__fixunsdfsi_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+__fixunsdfsi_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+__fixunsdfsi_FRAMESIZE,S   ; fccstk d=0 b=12 fs
                FIN
                STA     _fcc_q3
                DO      10+__fixunsdfsi_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+__fixunsdfsi_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+__fixunsdfsi_FRAMESIZE,S   ; fccstk d=0 b=10 fs
                FIN
                STA     _fcc_q2
                DO      8+__fixunsdfsi_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+__fixunsdfsi_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+__fixunsdfsi_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_long_hi
                DO      6+__fixunsdfsi_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+__fixunsdfsi_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+__fixunsdfsi_FRAMESIZE,S   ; fccstk d=0 b=6 fs
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
                LDA     #52
                STA     _fcc_long_b_lo
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                PLA
                STA     _fcc_q2
                PLA
                STA     _fcc_q3
                TYA
                FGX2_FARCALL _fcc_ll_shru
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #2047
                JSR     _fcc_long_from_int
                LDX     #0
                BIT     _fcc_long_hi
                BPL     *+5
                LDX     #$FFFF
                STX     _fcc_q2
                STX     _fcc_q3
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
                FGX2_FARCALL _fcc_ll_and
                STA     1,S   ; fccstk d=0 b=1
                TAX
                TXA
                CMP     #0
                BEQ     *+5
                BRL     _softdouble_L150
                LDA     #0
                JSR     _fcc_long_from_int
                TAY
                TSC
                CLC
                ADC     #__fixunsdfsi_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_softdouble_L150
                LDA     1,S   ; fccstk d=0 b=1
                TAX
                TXA
                CMP     #2047
                BEQ     *+5
                BRL     _softdouble_L151
                LDA     #$FFFF
                STA     _fcc_long_hi
                LDA     #$FFFF
                TAY
                TSC
                CLC
                ADC     #__fixunsdfsi_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_softdouble_L151
                LDA     1,S   ; fccstk d=0 b=1
                TAX
                TXA
                SEC
                SBC     #1023
                STA     3,S   ; fccstk d=0 b=3
                TAX
                TXA
                SEC
                SBC     #0
                BVC     _softdouble_L153
                EOR     #$8000
_softdouble_L153
                BMI     *+5
                BRL     _softdouble_L152
                LDA     #0
                JSR     _fcc_long_from_int
                TAY
                TSC
                CLC
                ADC     #__fixunsdfsi_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_softdouble_L152
                LDA     3,S   ; fccstk d=0 b=3
                TAX
                TXA
                LDX     #31
                STA     _fcc_tmp_b
                TXA
                SEC
                SBC     _fcc_tmp_b
                BVC     _softdouble_L155
                EOR     #$8000
_softdouble_L155
                BMI     *+5
                BRL     _softdouble_L154
                LDA     #$FFFF
                STA     _fcc_long_hi
                LDA     #$FFFF
                TAY
                TSC
                CLC
                ADC     #__fixunsdfsi_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_softdouble_L154
                DO      12+__fixunsdfsi_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+__fixunsdfsi_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+__fixunsdfsi_FRAMESIZE,S   ; fccstk d=0 b=12 fs
                FIN
                STA     _fcc_q3
                DO      10+__fixunsdfsi_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+__fixunsdfsi_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+__fixunsdfsi_FRAMESIZE,S   ; fccstk d=0 b=10 fs
                FIN
                STA     _fcc_q2
                DO      8+__fixunsdfsi_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+__fixunsdfsi_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+__fixunsdfsi_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_long_hi
                DO      6+__fixunsdfsi_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+__fixunsdfsi_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+__fixunsdfsi_FRAMESIZE,S   ; fccstk d=0 b=6 fs
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
                LDA     #15
                STA     _fcc_q3
                LDA     #65535
                STA     _fcc_q2
                LDA     #65535
                STA     _fcc_long_hi
                LDA     #65535
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
                FGX2_FARCALL _fcc_ll_and
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #16
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
                FGX2_FARCALL _fcc_ll_or
                STA     5,S   ; fccstk d=0 b=5
                TAY
                LDA     _fcc_long_hi
                STA     7,S   ; fccstk d=0 b=7
                LDA     _fcc_q2
                STA     9,S   ; fccstk d=0 b=9
                LDA     _fcc_q3
                STA     11,S   ; fccstk d=0 b=11
                TYA
                LDA     3,S   ; fccstk d=0 b=3
                TAX
                TXA
                SEC
                SBC     #52
                BVC     _softdouble_L157
                EOR     #$8000
_softdouble_L157
                BPL     *+5
                BRL     _softdouble_L156
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
                LDA     11,S   ; fccstk d=8 b=3
                TAX
                TXA
                SEC
                SBC     #52
                STA     _fcc_long_b_lo
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                PLA
                STA     _fcc_q2
                PLA
                STA     _fcc_q3
                TYA
                FGX2_FARCALL _fcc_ll_shl
                STA     5,S   ; fccstk d=0 b=5
                TAY
                LDA     _fcc_long_hi
                STA     7,S   ; fccstk d=0 b=7
                LDA     _fcc_q2
                STA     9,S   ; fccstk d=0 b=9
                LDA     _fcc_q3
                STA     11,S   ; fccstk d=0 b=11
                TYA
                BRL     _softdouble_L158
_softdouble_L156
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
                LDA     #52
                SEC
                SBC     11,S   ; fccstk d=8 b=3
                STA     _fcc_long_b_lo
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                PLA
                STA     _fcc_q2
                PLA
                STA     _fcc_q3
                TYA
                FGX2_FARCALL _fcc_ll_shru
                STA     5,S   ; fccstk d=0 b=5
                TAY
                LDA     _fcc_long_hi
                STA     7,S   ; fccstk d=0 b=7
                LDA     _fcc_q2
                STA     9,S   ; fccstk d=0 b=9
                LDA     _fcc_q3
                STA     11,S   ; fccstk d=0 b=11
                TYA
_softdouble_L158
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
                ADC     #__fixunsdfsi_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
__fixunsdfsi_FRAMESIZE   EQU     12
__fixunsdfsi_STKGUARD    EQU     0
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
_softdouble_L159
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     1,S   ; fccstk d=0 b=1
                PHA
                LDA     #2400
                PHA
                LDA     #50
                STA     _fcc_tmp_b
                PLA
                JSR     _fcc_divs16
                STA     _fcc_tmp_b
                PLA
                SEC
                SBC     _fcc_tmp_b
                BVC     _softdouble_L162
                EOR     #$8000
_softdouble_L162
                BMI     *+5
                BRL     _softdouble_L161
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_softdouble_vec
                STA     _fcc_fpr0
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                ASL
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     5,S   ; fccstk d=0 b=5
                LDA     _fcc_fpr0
                STA     3,S   ; fccstk d=0 b=3
                LDA     5,S   ; fccstk d=0 b=5
                STA     _fcc_fpr0+2
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0
                LDY     #14
                LDA     [_fcc_fpr0],Y
                STA     _fcc_q3
                LDY     #12
                LDA     [_fcc_fpr0],Y
                STA     _fcc_q2
                LDY     #10
                LDA     [_fcc_fpr0],Y
                STA     _fcc_long_hi
                LDY     #8
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
                LDA     13,S   ; fccstk d=8 b=5
                STA     _fcc_fpr0+2
                LDA     11,S   ; fccstk d=8 b=3
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
                FGX2_FARCALL __adddf3
                TAY
                TSC
                CLC
                ADC     #16
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
                LDA     13,S   ; fccstk d=8 b=5
                STA     _fcc_fpr0+2
                LDA     11,S   ; fccstk d=8 b=3
                STA     _fcc_fpr0
                LDY     #22
                LDA     [_fcc_fpr0],Y
                STA     _fcc_q3
                LDY     #20
                LDA     [_fcc_fpr0],Y
                STA     _fcc_q2
                LDY     #18
                LDA     [_fcc_fpr0],Y
                STA     _fcc_long_hi
                LDY     #16
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
                FGX2_FARCALL _fcc_ll_cmpu
                BNE     *+7
                LDA     #0
                BRA     *+5
                LDA     #1
                CMP     #0
                BEQ     *+5
                BRL     _softdouble_L168
                LDA     5,S   ; fccstk d=0 b=5
                STA     _fcc_fpr0+2
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0
                LDY     #14
                LDA     [_fcc_fpr0],Y
                STA     _fcc_q3
                LDY     #12
                LDA     [_fcc_fpr0],Y
                STA     _fcc_q2
                LDY     #10
                LDA     [_fcc_fpr0],Y
                STA     _fcc_long_hi
                LDY     #8
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
                LDA     13,S   ; fccstk d=8 b=5
                STA     _fcc_fpr0+2
                LDA     11,S   ; fccstk d=8 b=3
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
                FGX2_FARCALL __subdf3
                TAY
                TSC
                CLC
                ADC     #16
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
                LDA     13,S   ; fccstk d=8 b=5
                STA     _fcc_fpr0+2
                LDA     11,S   ; fccstk d=8 b=3
                STA     _fcc_fpr0
                LDY     #30
                LDA     [_fcc_fpr0],Y
                STA     _fcc_q3
                LDY     #28
                LDA     [_fcc_fpr0],Y
                STA     _fcc_q2
                LDY     #26
                LDA     [_fcc_fpr0],Y
                STA     _fcc_long_hi
                LDY     #24
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
                FGX2_FARCALL _fcc_ll_cmpu
                BNE     *+7
                LDA     #0
                BRA     *+5
                LDA     #1
                CMP     #0
                BEQ     *+5
                BRL     _softdouble_L168
                LDA     #0
                BRL     _softdouble_L169
_softdouble_L168
                LDA     #1
_softdouble_L169
                CMP     #0
                BEQ     *+5
                BRL     _softdouble_L166
                LDA     5,S   ; fccstk d=0 b=5
                STA     _fcc_fpr0+2
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0
                LDY     #14
                LDA     [_fcc_fpr0],Y
                STA     _fcc_q3
                LDY     #12
                LDA     [_fcc_fpr0],Y
                STA     _fcc_q2
                LDY     #10
                LDA     [_fcc_fpr0],Y
                STA     _fcc_long_hi
                LDY     #8
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
                LDA     13,S   ; fccstk d=8 b=5
                STA     _fcc_fpr0+2
                LDA     11,S   ; fccstk d=8 b=3
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
                FGX2_FARCALL __muldf3
                TAY
                TSC
                CLC
                ADC     #16
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
                LDA     13,S   ; fccstk d=8 b=5
                STA     _fcc_fpr0+2
                LDA     11,S   ; fccstk d=8 b=3
                STA     _fcc_fpr0
                LDY     #38
                LDA     [_fcc_fpr0],Y
                STA     _fcc_q3
                LDY     #36
                LDA     [_fcc_fpr0],Y
                STA     _fcc_q2
                LDY     #34
                LDA     [_fcc_fpr0],Y
                STA     _fcc_long_hi
                LDY     #32
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
                FGX2_FARCALL _fcc_ll_cmpu
                BNE     *+7
                LDA     #0
                BRA     *+5
                LDA     #1
                CMP     #0
                BEQ     *+5
                BRL     _softdouble_L166
                LDA     #0
                BRL     _softdouble_L167
_softdouble_L166
                LDA     #1
_softdouble_L167
                CMP     #0
                BEQ     *+5
                BRL     _softdouble_L164
                LDA     5,S   ; fccstk d=0 b=5
                STA     _fcc_fpr0+2
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0
                LDY     #14
                LDA     [_fcc_fpr0],Y
                STA     _fcc_q3
                LDY     #12
                LDA     [_fcc_fpr0],Y
                STA     _fcc_q2
                LDY     #10
                LDA     [_fcc_fpr0],Y
                STA     _fcc_long_hi
                LDY     #8
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
                LDA     13,S   ; fccstk d=8 b=5
                STA     _fcc_fpr0+2
                LDA     11,S   ; fccstk d=8 b=3
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
                FGX2_FARCALL __divdf3
                TAY
                TSC
                CLC
                ADC     #16
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
                LDA     13,S   ; fccstk d=8 b=5
                STA     _fcc_fpr0+2
                LDA     11,S   ; fccstk d=8 b=3
                STA     _fcc_fpr0
                LDY     #46
                LDA     [_fcc_fpr0],Y
                STA     _fcc_q3
                LDY     #44
                LDA     [_fcc_fpr0],Y
                STA     _fcc_q2
                LDY     #42
                LDA     [_fcc_fpr0],Y
                STA     _fcc_long_hi
                LDY     #40
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
                FGX2_FARCALL _fcc_ll_cmpu
                BNE     *+7
                LDA     #0
                BRA     *+5
                LDA     #1
                CMP     #0
                BEQ     *+5
                BRL     _softdouble_L164
                LDA     #0
                BRL     _softdouble_L165
_softdouble_L164
                LDA     #1
_softdouble_L165
                CMP     #0
                BNE     *+5
                BRL     _softdouble_L163
                LDA     1,S   ; fccstk d=0 b=1
                TAX
                TXA
                INC
                TAX
                TXA
                SEC
                SBC     #42
                BVC     _softdouble_L172
                EOR     #$8000
_softdouble_L172
                BPL     *+5
                BRL     _softdouble_L170
                LDA     1,S   ; fccstk d=0 b=1
                TAX
                TXA
                CLC
                ADC     #2
                BRL     _softdouble_L171
_softdouble_L170
                LDA     1,S   ; fccstk d=0 b=1
                TAX
                TXA
                CLC
                ADC     #1
_softdouble_L171
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_softdouble_L163
                LDA     5,S   ; fccstk d=0 b=5
                STA     _fcc_fpr0+2
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0
                LDY     #14
                LDA     [_fcc_fpr0],Y
                STA     _fcc_q3
                LDY     #12
                LDA     [_fcc_fpr0],Y
                STA     _fcc_q2
                LDY     #10
                LDA     [_fcc_fpr0],Y
                STA     _fcc_long_hi
                LDY     #8
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
                LDA     13,S   ; fccstk d=8 b=5
                STA     _fcc_fpr0+2
                LDA     11,S   ; fccstk d=8 b=3
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
                FGX2_FARCALL __cmpdf2
                TAY
                TSC
                CLC
                ADC     #16
                TCS
                TYA
                PHA
                LDA     7,S   ; fccstk d=2 b=5
                STA     _fcc_fpr0+2
                LDA     5,S   ; fccstk d=2 b=3
                STA     _fcc_fpr0
                LDY     #48
                LDA     [_fcc_fpr0],Y
                STA     _fcc_tmp_b
                PLA
                CMP     _fcc_tmp_b
                BNE     *+5
                BRL     _softdouble_L173
                LDA     #101
                CLC
                ADC     1,S   ; fccstk d=0 b=1
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_softdouble_L173
_softdouble_L160
                LDA     1,S   ; fccstk d=0 b=1
                CLC
                ADC     #1
                STA     1,S   ; fccstk d=0 b=1
                BRL     _softdouble_L159
_softdouble_L161
                LDA     #0
                STA     1,S   ; fccstk d=0 b=1
_softdouble_L174
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     1,S   ; fccstk d=0 b=1
                PHA
                LDA     #144
                PHA
                LDA     #16
                STA     _fcc_tmp_b
                PLA
                JSR     _fcc_divs16
                STA     _fcc_tmp_b
                PLA
                SEC
                SBC     _fcc_tmp_b
                BVC     _softdouble_L177
                EOR     #$8000
_softdouble_L177
                BMI     *+5
                BRL     _softdouble_L176
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_softdouble_cvt
                STA     _fcc_fpr0
                LDA     1,S   ; fccstk d=0 b=1
                ASL
                ASL
                ASL
                ASL
                CLC
                ADC     _fcc_fpr0
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
                FGX2_FARCALL __floatsidf
                TAY
                TSC
                CLC
                ADC     #4
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
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_softdouble_cvt
                STA     _fcc_fpr0
                LDA     9,S   ; fccstk d=8 b=1
                ASL
                ASL
                ASL
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDY     #10
                LDA     [_fcc_fpr0],Y
                STA     _fcc_q3
                LDY     #8
                LDA     [_fcc_fpr0],Y
                STA     _fcc_q2
                LDY     #6
                LDA     [_fcc_fpr0],Y
                STA     _fcc_long_hi
                LDY     #4
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
                FGX2_FARCALL _fcc_ll_cmpu
                BNE     *+7
                LDA     #0
                BRA     *+5
                LDA     #1
                CMP     #0
                BEQ     *+5
                BRL     _softdouble_L179
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_softdouble_cvt
                STA     _fcc_fpr0
                LDA     1,S   ; fccstk d=0 b=1
                ASL
                ASL
                ASL
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDY     #10
                LDA     [_fcc_fpr0],Y
                STA     _fcc_q3
                LDY     #8
                LDA     [_fcc_fpr0],Y
                STA     _fcc_q2
                LDY     #6
                LDA     [_fcc_fpr0],Y
                STA     _fcc_long_hi
                LDY     #4
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
                FGX2_FARCALL __fixdfsi
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
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_softdouble_cvt
                STA     _fcc_fpr0
                LDA     5,S   ; fccstk d=4 b=1
                ASL
                ASL
                ASL
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDY     #14
                LDA     [_fcc_fpr0],Y
                STA     _fcc_long_hi
                LDY     #12
                LDA     [_fcc_fpr0],Y
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
                BRL     _softdouble_L179
                LDA     #0
                BRL     _softdouble_L180
_softdouble_L179
                LDA     #1
_softdouble_L180
                CMP     #0
                BNE     *+5
                BRL     _softdouble_L178
                LDA     #201
                CLC
                ADC     1,S   ; fccstk d=0 b=1
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_softdouble_L178
_softdouble_L175
                LDA     1,S   ; fccstk d=0 b=1
                CLC
                ADC     #1
                STA     1,S   ; fccstk d=0 b=1
                BRL     _softdouble_L174
_softdouble_L176
                LDA     #0
                STA     1,S   ; fccstk d=0 b=1
_softdouble_L181
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     1,S   ; fccstk d=0 b=1
                PHA
                LDA     #80
                PHA
                LDA     #16
                STA     _fcc_tmp_b
                PLA
                JSR     _fcc_divs16
                STA     _fcc_tmp_b
                PLA
                SEC
                SBC     _fcc_tmp_b
                BVC     _softdouble_L184
                EOR     #$8000
_softdouble_L184
                BMI     *+5
                BRL     _softdouble_L183
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_softdouble_flt
                STA     _fcc_fpr0
                LDA     1,S   ; fccstk d=0 b=1
                ASL
                ASL
                ASL
                ASL
                CLC
                ADC     _fcc_fpr0
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
                FGX2_FARCALL __extendsfdf2
                TAY
                TSC
                CLC
                ADC     #4
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
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_softdouble_flt
                STA     _fcc_fpr0
                LDA     9,S   ; fccstk d=8 b=1
                ASL
                ASL
                ASL
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDY     #10
                LDA     [_fcc_fpr0],Y
                STA     _fcc_q3
                LDY     #8
                LDA     [_fcc_fpr0],Y
                STA     _fcc_q2
                LDY     #6
                LDA     [_fcc_fpr0],Y
                STA     _fcc_long_hi
                LDY     #4
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
                FGX2_FARCALL _fcc_ll_cmpu
                BNE     *+7
                LDA     #0
                BRA     *+5
                LDA     #1
                CMP     #0
                BEQ     *+5
                BRL     _softdouble_L186
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_softdouble_flt
                STA     _fcc_fpr0
                LDA     1,S   ; fccstk d=0 b=1
                ASL
                ASL
                ASL
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDY     #10
                LDA     [_fcc_fpr0],Y
                STA     _fcc_q3
                LDY     #8
                LDA     [_fcc_fpr0],Y
                STA     _fcc_q2
                LDY     #6
                LDA     [_fcc_fpr0],Y
                STA     _fcc_long_hi
                LDY     #4
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
                FGX2_FARCALL __truncdfsf2
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
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_softdouble_flt
                STA     _fcc_fpr0
                LDA     5,S   ; fccstk d=4 b=1
                ASL
                ASL
                ASL
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDY     #14
                LDA     [_fcc_fpr0],Y
                STA     _fcc_long_hi
                LDY     #12
                LDA     [_fcc_fpr0],Y
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
                BRL     _softdouble_L186
                LDA     #0
                BRL     _softdouble_L187
_softdouble_L186
                LDA     #1
_softdouble_L187
                CMP     #0
                BNE     *+5
                BRL     _softdouble_L185
                LDA     #211
                CLC
                ADC     1,S   ; fccstk d=0 b=1
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_softdouble_L185
_softdouble_L182
                LDA     1,S   ; fccstk d=0 b=1
                CLC
                ADC     #1
                STA     1,S   ; fccstk d=0 b=1
                BRL     _softdouble_L181
_softdouble_L183
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
main_FRAMESIZE   EQU     6
main_STKGUARD    EQU     0
                FGX2_RELOC_COUNT 235
