                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from llong_arith.c
;---------------------------------------

                MX      %00
                FGX2_EXPORT _llong_arith_put
_llong_arith_put            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #_llong_arith_put_FRAMESIZE
                DO      _llong_arith_put_STKGUARD
                BCC     _llong_arith_put_stkovf
                CMP     _fcc_stkfloor
                BCS     _llong_arith_put_stkok
_llong_arith_put_stkovf       JMP     _fcc_stkoflow
                FIN
_llong_arith_put_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      8+_llong_arith_put_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_llong_arith_put_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_llong_arith_put_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+_llong_arith_put_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_llong_arith_put_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_llong_arith_put_FRAMESIZE,S   ; fccstk d=0 b=6 fs
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
                DO      20+_llong_arith_put_FRAMESIZE/256
                TSC
                CLC
                ADC     #20+_llong_arith_put_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     20+_llong_arith_put_FRAMESIZE,S   ; fccstk d=4 b=16 fs
                FIN
                STA     _fcc_long_hi
                DO      18+_llong_arith_put_FRAMESIZE/256
                TSC
                CLC
                ADC     #18+_llong_arith_put_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     18+_llong_arith_put_FRAMESIZE,S   ; fccstk d=4 b=14 fs
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
                DO      16+_llong_arith_put_FRAMESIZE/256
                TSC
                CLC
                ADC     #16+_llong_arith_put_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     16+_llong_arith_put_FRAMESIZE,S   ; fccstk d=4 b=12 fs
                FIN
                STA     _fcc_long_hi
                DO      14+_llong_arith_put_FRAMESIZE/256
                TSC
                CLC
                ADC     #14+_llong_arith_put_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     14+_llong_arith_put_FRAMESIZE,S   ; fccstk d=4 b=10 fs
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
                ADC     #_llong_arith_put_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_llong_arith_put_FRAMESIZE   EQU     4
_llong_arith_put_STKGUARD    EQU     0
                FGX2_EXPORT _llong_arith_is
_llong_arith_is            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #_llong_arith_is_FRAMESIZE
                DO      _llong_arith_is_STKGUARD
                BCC     _llong_arith_is_stkovf
                CMP     _fcc_stkfloor
                BCS     _llong_arith_is_stkok
_llong_arith_is_stkovf       JMP     _fcc_stkoflow
                FIN
_llong_arith_is_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                TSC
                CLC
                ADC     #6+_llong_arith_is_FRAMESIZE
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
                DO      24+_llong_arith_is_FRAMESIZE/256
                TSC
                CLC
                ADC     #24+_llong_arith_is_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     24+_llong_arith_is_FRAMESIZE,S   ; fccstk d=4 b=20 fs
                FIN
                STA     _fcc_long_hi
                DO      22+_llong_arith_is_FRAMESIZE/256
                TSC
                CLC
                ADC     #22+_llong_arith_is_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     22+_llong_arith_is_FRAMESIZE,S   ; fccstk d=4 b=18 fs
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
                BEQ     _llong_arith_L0
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
                DO      20+_llong_arith_is_FRAMESIZE/256
                TSC
                CLC
                ADC     #20+_llong_arith_is_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     20+_llong_arith_is_FRAMESIZE,S   ; fccstk d=4 b=16 fs
                FIN
                STA     _fcc_long_hi
                DO      18+_llong_arith_is_FRAMESIZE/256
                TSC
                CLC
                ADC     #18+_llong_arith_is_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     18+_llong_arith_is_FRAMESIZE,S   ; fccstk d=4 b=14 fs
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
                BEQ     _llong_arith_L0
                LDA     #1
                BRA     _llong_arith_L1
_llong_arith_L0
                LDA     #0
_llong_arith_L1
                TAY
                TSC
                CLC
                ADC     #_llong_arith_is_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_llong_arith_is_FRAMESIZE   EQU     4
_llong_arith_is_STKGUARD    EQU     0
                FGX2_EXPORT _llong_arith_uis
_llong_arith_uis            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #_llong_arith_uis_FRAMESIZE
                DO      _llong_arith_uis_STKGUARD
                BCC     _llong_arith_uis_stkovf
                CMP     _fcc_stkfloor
                BCS     _llong_arith_uis_stkok
_llong_arith_uis_stkovf       JMP     _fcc_stkoflow
                FIN
_llong_arith_uis_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                TSC
                CLC
                ADC     #6+_llong_arith_uis_FRAMESIZE
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
                DO      24+_llong_arith_uis_FRAMESIZE/256
                TSC
                CLC
                ADC     #24+_llong_arith_uis_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     24+_llong_arith_uis_FRAMESIZE,S   ; fccstk d=4 b=20 fs
                FIN
                STA     _fcc_long_hi
                DO      22+_llong_arith_uis_FRAMESIZE/256
                TSC
                CLC
                ADC     #22+_llong_arith_uis_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     22+_llong_arith_uis_FRAMESIZE,S   ; fccstk d=4 b=18 fs
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
                BEQ     _llong_arith_L2
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
                DO      20+_llong_arith_uis_FRAMESIZE/256
                TSC
                CLC
                ADC     #20+_llong_arith_uis_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     20+_llong_arith_uis_FRAMESIZE,S   ; fccstk d=4 b=16 fs
                FIN
                STA     _fcc_long_hi
                DO      18+_llong_arith_uis_FRAMESIZE/256
                TSC
                CLC
                ADC     #18+_llong_arith_uis_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     18+_llong_arith_uis_FRAMESIZE,S   ; fccstk d=4 b=14 fs
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
                BEQ     _llong_arith_L2
                LDA     #1
                BRA     _llong_arith_L3
_llong_arith_L2
                LDA     #0
_llong_arith_L3
                TAY
                TSC
                CLC
                ADC     #_llong_arith_uis_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_llong_arith_uis_FRAMESIZE   EQU     4
_llong_arith_uis_STKGUARD    EQU     0
                FGX2_EXPORT _llong_arith_run
_llong_arith_run            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #_llong_arith_run_FRAMESIZE
                DO      _llong_arith_run_STKGUARD
                BCC     _llong_arith_run_stkovf
                CMP     _fcc_stkfloor
                BCS     _llong_arith_run_stkok
_llong_arith_run_stkovf       JMP     _fcc_stkoflow
                FIN
_llong_arith_run_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                LDA     #$FFFF
                STA     _fcc_long_hi
                LDA     #$FFFF
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0000
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #a
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0001
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0000
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
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
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     a+6
                STA     _fcc_q3
                LDA     a+4
                STA     _fcc_q2
                LDA     a+2
                STA     _fcc_long_hi
                LDA     a
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     b+6
                STA     _fcc_q3
                LDA     b+4
                STA     _fcc_q2
                LDA     b+2
                STA     _fcc_long_hi
                LDA     b
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
                STA     r
                TAY
                LDA     _fcc_long_hi
                STA     r+2
                LDA     _fcc_q2
                STA     r+4
                LDA     _fcc_q3
                STA     r+6
                TYA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0000
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0001
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     r+6
                STA     _fcc_q3
                LDA     r+4
                STA     _fcc_q2
                LDA     r+2
                STA     _fcc_long_hi
                LDA     r
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                FGX2_FARCALL _llong_arith_is
                TAY
                TSC
                CLC
                ADC     #16
                TCS
                TYA
                BNE     _llong_arith_L4
                LDA     #1
                TAY
                TSC
                CLC
                ADC     #_llong_arith_run_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_llong_arith_L4
                LDA     #$FFFF
                STA     _fcc_long_hi
                LDA     #$FFFF
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0000
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #a
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0001
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0000
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
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
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     a+6
                STA     _fcc_q3
                LDA     a+4
                STA     _fcc_q2
                LDA     a+2
                STA     _fcc_long_hi
                LDA     a
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     b+6
                STA     _fcc_q3
                LDA     b+4
                STA     _fcc_q2
                LDA     b+2
                STA     _fcc_long_hi
                LDA     b
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
                STA     r
                TAY
                LDA     _fcc_long_hi
                STA     r+2
                LDA     _fcc_q2
                STA     r+4
                LDA     _fcc_q3
                STA     r+6
                TYA
                LDA     #$FFFF
                STA     _fcc_long_hi
                LDA     #$FFFE
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0000
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     r+6
                STA     _fcc_q3
                LDA     r+4
                STA     _fcc_q2
                LDA     r+2
                STA     _fcc_long_hi
                LDA     r
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                FGX2_FARCALL _llong_arith_is
                TAY
                TSC
                CLC
                ADC     #16
                TCS
                TYA
                BNE     _llong_arith_L5
                LDA     #2
                TAY
                TSC
                CLC
                ADC     #_llong_arith_run_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_llong_arith_L5
                LDA     #$FFFF
                STA     _fcc_long_hi
                LDA     #$FFFF
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0000
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #a
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0001
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0000
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
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
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     a+6
                STA     _fcc_q3
                LDA     a+4
                STA     _fcc_q2
                LDA     a+2
                STA     _fcc_long_hi
                LDA     a
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     b+6
                STA     _fcc_q3
                LDA     b+4
                STA     _fcc_q2
                LDA     b+2
                STA     _fcc_long_hi
                LDA     b
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
                STA     r
                TAY
                LDA     _fcc_long_hi
                STA     r+2
                LDA     _fcc_q2
                STA     r+4
                LDA     _fcc_q3
                STA     r+6
                TYA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0001
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0000
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     r+6
                STA     _fcc_q3
                LDA     r+4
                STA     _fcc_q2
                LDA     r+2
                STA     _fcc_long_hi
                LDA     r
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                FGX2_FARCALL _llong_arith_is
                TAY
                TSC
                CLC
                ADC     #16
                TCS
                TYA
                BNE     _llong_arith_L6
                LDA     #3
                TAY
                TSC
                CLC
                ADC     #_llong_arith_run_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_llong_arith_L6
                LDA     #$FFFF
                STA     _fcc_long_hi
                LDA     #$FFFF
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0000
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #a
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0001
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0000
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
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
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     a+6
                STA     _fcc_q3
                LDA     a+4
                STA     _fcc_q2
                LDA     a+2
                STA     _fcc_long_hi
                LDA     a
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     b+6
                STA     _fcc_q3
                LDA     b+4
                STA     _fcc_q2
                LDA     b+2
                STA     _fcc_long_hi
                LDA     b
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
                STA     r
                TAY
                LDA     _fcc_long_hi
                STA     r+2
                LDA     _fcc_q2
                STA     r+4
                LDA     _fcc_q3
                STA     r+6
                TYA
                LDA     #$FFFF
                STA     _fcc_long_hi
                LDA     #$FFFF
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0000
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     r+6
                STA     _fcc_q3
                LDA     r+4
                STA     _fcc_q2
                LDA     r+2
                STA     _fcc_long_hi
                LDA     r
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                FGX2_FARCALL _llong_arith_is
                TAY
                TSC
                CLC
                ADC     #16
                TCS
                TYA
                BNE     _llong_arith_L7
                LDA     #4
                TAY
                TSC
                CLC
                ADC     #_llong_arith_run_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_llong_arith_L7
                LDA     #$FFFF
                STA     _fcc_long_hi
                LDA     #$FFFF
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0000
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #a
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0001
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0000
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
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
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     a+6
                STA     _fcc_q3
                LDA     a+4
                STA     _fcc_q2
                LDA     a+2
                STA     _fcc_long_hi
                LDA     a
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     b+6
                STA     _fcc_q3
                LDA     b+4
                STA     _fcc_q2
                LDA     b+2
                STA     _fcc_long_hi
                LDA     b
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
                STA     r
                TAY
                LDA     _fcc_long_hi
                STA     r+2
                LDA     _fcc_q2
                STA     r+4
                LDA     _fcc_q3
                STA     r+6
                TYA
                LDA     #$FFFF
                STA     _fcc_long_hi
                LDA     #$FFFE
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0000
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     r+6
                STA     _fcc_q3
                LDA     r+4
                STA     _fcc_q2
                LDA     r+2
                STA     _fcc_long_hi
                LDA     r
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                FGX2_FARCALL _llong_arith_is
                TAY
                TSC
                CLC
                ADC     #16
                TCS
                TYA
                BNE     _llong_arith_L8
                LDA     #5
                TAY
                TSC
                CLC
                ADC     #_llong_arith_run_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_llong_arith_L8
                LDA     #$FFFF
                STA     _fcc_long_hi
                LDA     #$FFFF
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0000
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #a
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0001
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0000
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
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
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     a+6
                STA     _fcc_q3
                LDA     a+4
                STA     _fcc_q2
                LDA     a+2
                STA     _fcc_long_hi
                LDA     a
                FGX2_FARCALL _fcc_ll_com
                STA     r
                TAY
                LDA     _fcc_long_hi
                STA     r+2
                LDA     _fcc_q2
                STA     r+4
                LDA     _fcc_q3
                STA     r+6
                TYA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0000
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
                LDA     r+6
                STA     _fcc_q3
                LDA     r+4
                STA     _fcc_q2
                LDA     r+2
                STA     _fcc_long_hi
                LDA     r
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                FGX2_FARCALL _llong_arith_is
                TAY
                TSC
                CLC
                ADC     #16
                TCS
                TYA
                BNE     _llong_arith_L9
                LDA     #6
                TAY
                TSC
                CLC
                ADC     #_llong_arith_run_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_llong_arith_L9
                LDA     #$FFFF
                STA     _fcc_long_hi
                LDA     #$FFFF
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0000
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #a
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0001
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0000
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
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
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     a+6
                STA     _fcc_q3
                LDA     a+4
                STA     _fcc_q2
                LDA     a+2
                STA     _fcc_long_hi
                LDA     a
                FGX2_FARCALL _fcc_ll_neg
                STA     r
                TAY
                LDA     _fcc_long_hi
                STA     r+2
                LDA     _fcc_q2
                STA     r+4
                LDA     _fcc_q3
                STA     r+6
                TYA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0001
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
                LDA     r+6
                STA     _fcc_q3
                LDA     r+4
                STA     _fcc_q2
                LDA     r+2
                STA     _fcc_long_hi
                LDA     r
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                FGX2_FARCALL _llong_arith_is
                TAY
                TSC
                CLC
                ADC     #16
                TCS
                TYA
                BNE     _llong_arith_L10
                LDA     #7
                TAY
                TSC
                CLC
                ADC     #_llong_arith_run_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_llong_arith_L10
                LDA     #$FFFF
                STA     _fcc_long_hi
                LDA     #$FFFF
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$7FFF
                STA     _fcc_long_hi
                LDA     #$FFFF
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #a
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0001
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0000
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
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
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     a+6
                STA     _fcc_q3
                LDA     a+4
                STA     _fcc_q2
                LDA     a+2
                STA     _fcc_long_hi
                LDA     a
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     b+6
                STA     _fcc_q3
                LDA     b+4
                STA     _fcc_q2
                LDA     b+2
                STA     _fcc_long_hi
                LDA     b
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
                STA     r
                TAY
                LDA     _fcc_long_hi
                STA     r+2
                LDA     _fcc_q2
                STA     r+4
                LDA     _fcc_q3
                STA     r+6
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
                LDA     r+6
                STA     _fcc_q3
                LDA     r+4
                STA     _fcc_q2
                LDA     r+2
                STA     _fcc_long_hi
                LDA     r
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                FGX2_FARCALL _llong_arith_is
                TAY
                TSC
                CLC
                ADC     #16
                TCS
                TYA
                BNE     _llong_arith_L11
                LDA     #8
                TAY
                TSC
                CLC
                ADC     #_llong_arith_run_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_llong_arith_L11
                LDA     #$FFFF
                STA     _fcc_long_hi
                LDA     #$FFFF
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$7FFF
                STA     _fcc_long_hi
                LDA     #$FFFF
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #a
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0001
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0000
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
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
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     a+6
                STA     _fcc_q3
                LDA     a+4
                STA     _fcc_q2
                LDA     a+2
                STA     _fcc_long_hi
                LDA     a
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     b+6
                STA     _fcc_q3
                LDA     b+4
                STA     _fcc_q2
                LDA     b+2
                STA     _fcc_long_hi
                LDA     b
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
                STA     r
                TAY
                LDA     _fcc_long_hi
                STA     r+2
                LDA     _fcc_q2
                STA     r+4
                LDA     _fcc_q3
                STA     r+6
                TYA
                LDA     #$FFFF
                STA     _fcc_long_hi
                LDA     #$FFFE
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$7FFF
                STA     _fcc_long_hi
                LDA     #$FFFF
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     r+6
                STA     _fcc_q3
                LDA     r+4
                STA     _fcc_q2
                LDA     r+2
                STA     _fcc_long_hi
                LDA     r
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                FGX2_FARCALL _llong_arith_is
                TAY
                TSC
                CLC
                ADC     #16
                TCS
                TYA
                BNE     _llong_arith_L12
                LDA     #9
                TAY
                TSC
                CLC
                ADC     #_llong_arith_run_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_llong_arith_L12
                LDA     #$FFFF
                STA     _fcc_long_hi
                LDA     #$FFFF
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$7FFF
                STA     _fcc_long_hi
                LDA     #$FFFF
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #a
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0001
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0000
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
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
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     a+6
                STA     _fcc_q3
                LDA     a+4
                STA     _fcc_q2
                LDA     a+2
                STA     _fcc_long_hi
                LDA     a
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     b+6
                STA     _fcc_q3
                LDA     b+4
                STA     _fcc_q2
                LDA     b+2
                STA     _fcc_long_hi
                LDA     b
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
                STA     r
                TAY
                LDA     _fcc_long_hi
                STA     r+2
                LDA     _fcc_q2
                STA     r+4
                LDA     _fcc_q3
                STA     r+6
                TYA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0001
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0000
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     r+6
                STA     _fcc_q3
                LDA     r+4
                STA     _fcc_q2
                LDA     r+2
                STA     _fcc_long_hi
                LDA     r
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                FGX2_FARCALL _llong_arith_is
                TAY
                TSC
                CLC
                ADC     #16
                TCS
                TYA
                BNE     _llong_arith_L13
                LDA     #10
                TAY
                TSC
                CLC
                ADC     #_llong_arith_run_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_llong_arith_L13
                LDA     #$FFFF
                STA     _fcc_long_hi
                LDA     #$FFFF
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$7FFF
                STA     _fcc_long_hi
                LDA     #$FFFF
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #a
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0001
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0000
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
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
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     a+6
                STA     _fcc_q3
                LDA     a+4
                STA     _fcc_q2
                LDA     a+2
                STA     _fcc_long_hi
                LDA     a
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     b+6
                STA     _fcc_q3
                LDA     b+4
                STA     _fcc_q2
                LDA     b+2
                STA     _fcc_long_hi
                LDA     b
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
                STA     r
                TAY
                LDA     _fcc_long_hi
                STA     r+2
                LDA     _fcc_q2
                STA     r+4
                LDA     _fcc_q3
                STA     r+6
                TYA
                LDA     #$FFFF
                STA     _fcc_long_hi
                LDA     #$FFFF
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$7FFF
                STA     _fcc_long_hi
                LDA     #$FFFF
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     r+6
                STA     _fcc_q3
                LDA     r+4
                STA     _fcc_q2
                LDA     r+2
                STA     _fcc_long_hi
                LDA     r
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                FGX2_FARCALL _llong_arith_is
                TAY
                TSC
                CLC
                ADC     #16
                TCS
                TYA
                BNE     _llong_arith_L14
                LDA     #11
                TAY
                TSC
                CLC
                ADC     #_llong_arith_run_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_llong_arith_L14
                LDA     #$FFFF
                STA     _fcc_long_hi
                LDA     #$FFFF
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$7FFF
                STA     _fcc_long_hi
                LDA     #$FFFF
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #a
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0001
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0000
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
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
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     a+6
                STA     _fcc_q3
                LDA     a+4
                STA     _fcc_q2
                LDA     a+2
                STA     _fcc_long_hi
                LDA     a
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     b+6
                STA     _fcc_q3
                LDA     b+4
                STA     _fcc_q2
                LDA     b+2
                STA     _fcc_long_hi
                LDA     b
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
                STA     r
                TAY
                LDA     _fcc_long_hi
                STA     r+2
                LDA     _fcc_q2
                STA     r+4
                LDA     _fcc_q3
                STA     r+6
                TYA
                LDA     #$FFFF
                STA     _fcc_long_hi
                LDA     #$FFFE
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$7FFF
                STA     _fcc_long_hi
                LDA     #$FFFF
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     r+6
                STA     _fcc_q3
                LDA     r+4
                STA     _fcc_q2
                LDA     r+2
                STA     _fcc_long_hi
                LDA     r
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                FGX2_FARCALL _llong_arith_is
                TAY
                TSC
                CLC
                ADC     #16
                TCS
                TYA
                BNE     _llong_arith_L15
                LDA     #12
                TAY
                TSC
                CLC
                ADC     #_llong_arith_run_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_llong_arith_L15
                LDA     #$FFFF
                STA     _fcc_long_hi
                LDA     #$FFFF
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$7FFF
                STA     _fcc_long_hi
                LDA     #$FFFF
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #a
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0001
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0000
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
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
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     a+6
                STA     _fcc_q3
                LDA     a+4
                STA     _fcc_q2
                LDA     a+2
                STA     _fcc_long_hi
                LDA     a
                FGX2_FARCALL _fcc_ll_com
                STA     r
                TAY
                LDA     _fcc_long_hi
                STA     r+2
                LDA     _fcc_q2
                STA     r+4
                LDA     _fcc_q3
                STA     r+6
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
                LDA     r+6
                STA     _fcc_q3
                LDA     r+4
                STA     _fcc_q2
                LDA     r+2
                STA     _fcc_long_hi
                LDA     r
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                FGX2_FARCALL _llong_arith_is
                TAY
                TSC
                CLC
                ADC     #16
                TCS
                TYA
                BNE     _llong_arith_L16
                LDA     #13
                TAY
                TSC
                CLC
                ADC     #_llong_arith_run_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_llong_arith_L16
                LDA     #$FFFF
                STA     _fcc_long_hi
                LDA     #$FFFF
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$7FFF
                STA     _fcc_long_hi
                LDA     #$FFFF
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #a
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0001
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0000
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
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
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     a+6
                STA     _fcc_q3
                LDA     a+4
                STA     _fcc_q2
                LDA     a+2
                STA     _fcc_long_hi
                LDA     a
                FGX2_FARCALL _fcc_ll_neg
                STA     r
                TAY
                LDA     _fcc_long_hi
                STA     r+2
                LDA     _fcc_q2
                STA     r+4
                LDA     _fcc_q3
                STA     r+6
                TYA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0001
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
                LDA     r+6
                STA     _fcc_q3
                LDA     r+4
                STA     _fcc_q2
                LDA     r+2
                STA     _fcc_long_hi
                LDA     r
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                FGX2_FARCALL _llong_arith_is
                TAY
                TSC
                CLC
                ADC     #16
                TCS
                TYA
                BNE     _llong_arith_L17
                LDA     #14
                TAY
                TSC
                CLC
                ADC     #_llong_arith_run_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_llong_arith_L17
                LDA     #$89AB
                STA     _fcc_long_hi
                LDA     #$CDEF
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0123
                STA     _fcc_long_hi
                LDA     #$4567
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #a
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     #$7654
                STA     _fcc_long_hi
                LDA     #$3210
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$FEDC
                STA     _fcc_long_hi
                LDA     #$BA98
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
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
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     a+6
                STA     _fcc_q3
                LDA     a+4
                STA     _fcc_q2
                LDA     a+2
                STA     _fcc_long_hi
                LDA     a
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     b+6
                STA     _fcc_q3
                LDA     b+4
                STA     _fcc_q2
                LDA     b+2
                STA     _fcc_long_hi
                LDA     b
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
                STA     r
                TAY
                LDA     _fcc_long_hi
                STA     r+2
                LDA     _fcc_q2
                STA     r+4
                LDA     _fcc_q3
                STA     r+6
                TYA
                LDA     #$FFFF
                STA     _fcc_long_hi
                LDA     #$FFFF
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
                LDA     r+6
                STA     _fcc_q3
                LDA     r+4
                STA     _fcc_q2
                LDA     r+2
                STA     _fcc_long_hi
                LDA     r
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                FGX2_FARCALL _llong_arith_is
                TAY
                TSC
                CLC
                ADC     #16
                TCS
                TYA
                BNE     _llong_arith_L18
                LDA     #15
                TAY
                TSC
                CLC
                ADC     #_llong_arith_run_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_llong_arith_L18
                LDA     #$89AB
                STA     _fcc_long_hi
                LDA     #$CDEF
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0123
                STA     _fcc_long_hi
                LDA     #$4567
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #a
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     #$7654
                STA     _fcc_long_hi
                LDA     #$3210
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$FEDC
                STA     _fcc_long_hi
                LDA     #$BA98
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
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
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     a+6
                STA     _fcc_q3
                LDA     a+4
                STA     _fcc_q2
                LDA     a+2
                STA     _fcc_long_hi
                LDA     a
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     b+6
                STA     _fcc_q3
                LDA     b+4
                STA     _fcc_q2
                LDA     b+2
                STA     _fcc_long_hi
                LDA     b
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
                STA     r
                TAY
                LDA     _fcc_long_hi
                STA     r+2
                LDA     _fcc_q2
                STA     r+4
                LDA     _fcc_q3
                STA     r+6
                TYA
                LDA     #$1357
                STA     _fcc_long_hi
                LDA     #$9BDF
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0246
                STA     _fcc_long_hi
                LDA     #$8ACF
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     r+6
                STA     _fcc_q3
                LDA     r+4
                STA     _fcc_q2
                LDA     r+2
                STA     _fcc_long_hi
                LDA     r
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                FGX2_FARCALL _llong_arith_is
                TAY
                TSC
                CLC
                ADC     #16
                TCS
                TYA
                BNE     _llong_arith_L19
                LDA     #16
                TAY
                TSC
                CLC
                ADC     #_llong_arith_run_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_llong_arith_L19
                LDA     #$89AB
                STA     _fcc_long_hi
                LDA     #$CDEF
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0123
                STA     _fcc_long_hi
                LDA     #$4567
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #a
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     #$7654
                STA     _fcc_long_hi
                LDA     #$3210
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$FEDC
                STA     _fcc_long_hi
                LDA     #$BA98
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
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
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     a+6
                STA     _fcc_q3
                LDA     a+4
                STA     _fcc_q2
                LDA     a+2
                STA     _fcc_long_hi
                LDA     a
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     b+6
                STA     _fcc_q3
                LDA     b+4
                STA     _fcc_q2
                LDA     b+2
                STA     _fcc_long_hi
                LDA     b
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
                STA     r
                TAY
                LDA     _fcc_long_hi
                STA     r+2
                LDA     _fcc_q2
                STA     r+4
                LDA     _fcc_q3
                STA     r+6
                TYA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0000
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0000
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     r+6
                STA     _fcc_q3
                LDA     r+4
                STA     _fcc_q2
                LDA     r+2
                STA     _fcc_long_hi
                LDA     r
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                FGX2_FARCALL _llong_arith_is
                TAY
                TSC
                CLC
                ADC     #16
                TCS
                TYA
                BNE     _llong_arith_L20
                LDA     #17
                TAY
                TSC
                CLC
                ADC     #_llong_arith_run_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_llong_arith_L20
                LDA     #$89AB
                STA     _fcc_long_hi
                LDA     #$CDEF
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0123
                STA     _fcc_long_hi
                LDA     #$4567
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #a
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     #$7654
                STA     _fcc_long_hi
                LDA     #$3210
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$FEDC
                STA     _fcc_long_hi
                LDA     #$BA98
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
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
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     a+6
                STA     _fcc_q3
                LDA     a+4
                STA     _fcc_q2
                LDA     a+2
                STA     _fcc_long_hi
                LDA     a
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     b+6
                STA     _fcc_q3
                LDA     b+4
                STA     _fcc_q2
                LDA     b+2
                STA     _fcc_long_hi
                LDA     b
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
                STA     r
                TAY
                LDA     _fcc_long_hi
                STA     r+2
                LDA     _fcc_q2
                STA     r+4
                LDA     _fcc_q3
                STA     r+6
                TYA
                LDA     #$FFFF
                STA     _fcc_long_hi
                LDA     #$FFFF
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
                LDA     r+6
                STA     _fcc_q3
                LDA     r+4
                STA     _fcc_q2
                LDA     r+2
                STA     _fcc_long_hi
                LDA     r
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                FGX2_FARCALL _llong_arith_is
                TAY
                TSC
                CLC
                ADC     #16
                TCS
                TYA
                BNE     _llong_arith_L21
                LDA     #18
                TAY
                TSC
                CLC
                ADC     #_llong_arith_run_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_llong_arith_L21
                LDA     #$89AB
                STA     _fcc_long_hi
                LDA     #$CDEF
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0123
                STA     _fcc_long_hi
                LDA     #$4567
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #a
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     #$7654
                STA     _fcc_long_hi
                LDA     #$3210
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$FEDC
                STA     _fcc_long_hi
                LDA     #$BA98
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
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
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     a+6
                STA     _fcc_q3
                LDA     a+4
                STA     _fcc_q2
                LDA     a+2
                STA     _fcc_long_hi
                LDA     a
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     b+6
                STA     _fcc_q3
                LDA     b+4
                STA     _fcc_q2
                LDA     b+2
                STA     _fcc_long_hi
                LDA     b
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
                STA     r
                TAY
                LDA     _fcc_long_hi
                STA     r+2
                LDA     _fcc_q2
                STA     r+4
                LDA     _fcc_q3
                STA     r+6
                TYA
                LDA     #$FFFF
                STA     _fcc_long_hi
                LDA     #$FFFF
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
                LDA     r+6
                STA     _fcc_q3
                LDA     r+4
                STA     _fcc_q2
                LDA     r+2
                STA     _fcc_long_hi
                LDA     r
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                FGX2_FARCALL _llong_arith_is
                TAY
                TSC
                CLC
                ADC     #16
                TCS
                TYA
                BNE     _llong_arith_L22
                LDA     #19
                TAY
                TSC
                CLC
                ADC     #_llong_arith_run_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_llong_arith_L22
                LDA     #$89AB
                STA     _fcc_long_hi
                LDA     #$CDEF
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0123
                STA     _fcc_long_hi
                LDA     #$4567
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #a
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     #$7654
                STA     _fcc_long_hi
                LDA     #$3210
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$FEDC
                STA     _fcc_long_hi
                LDA     #$BA98
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
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
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     a+6
                STA     _fcc_q3
                LDA     a+4
                STA     _fcc_q2
                LDA     a+2
                STA     _fcc_long_hi
                LDA     a
                FGX2_FARCALL _fcc_ll_com
                STA     r
                TAY
                LDA     _fcc_long_hi
                STA     r+2
                LDA     _fcc_q2
                STA     r+4
                LDA     _fcc_q3
                STA     r+6
                TYA
                LDA     #$7654
                STA     _fcc_long_hi
                LDA     #$3210
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$FEDC
                STA     _fcc_long_hi
                LDA     #$BA98
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     r+6
                STA     _fcc_q3
                LDA     r+4
                STA     _fcc_q2
                LDA     r+2
                STA     _fcc_long_hi
                LDA     r
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                FGX2_FARCALL _llong_arith_is
                TAY
                TSC
                CLC
                ADC     #16
                TCS
                TYA
                BNE     _llong_arith_L23
                LDA     #20
                TAY
                TSC
                CLC
                ADC     #_llong_arith_run_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_llong_arith_L23
                LDA     #$89AB
                STA     _fcc_long_hi
                LDA     #$CDEF
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0123
                STA     _fcc_long_hi
                LDA     #$4567
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #a
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     #$7654
                STA     _fcc_long_hi
                LDA     #$3210
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$FEDC
                STA     _fcc_long_hi
                LDA     #$BA98
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
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
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     a+6
                STA     _fcc_q3
                LDA     a+4
                STA     _fcc_q2
                LDA     a+2
                STA     _fcc_long_hi
                LDA     a
                FGX2_FARCALL _fcc_ll_neg
                STA     r
                TAY
                LDA     _fcc_long_hi
                STA     r+2
                LDA     _fcc_q2
                STA     r+4
                LDA     _fcc_q3
                STA     r+6
                TYA
                LDA     #$7654
                STA     _fcc_long_hi
                LDA     #$3211
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$FEDC
                STA     _fcc_long_hi
                LDA     #$BA98
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     r+6
                STA     _fcc_q3
                LDA     r+4
                STA     _fcc_q2
                LDA     r+2
                STA     _fcc_long_hi
                LDA     r
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                FGX2_FARCALL _llong_arith_is
                TAY
                TSC
                CLC
                ADC     #16
                TCS
                TYA
                BNE     _llong_arith_L24
                LDA     #21
                TAY
                TSC
                CLC
                ADC     #_llong_arith_run_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_llong_arith_L24
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0001
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
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #a
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     #$FFFF
                STA     _fcc_long_hi
                LDA     #$FFFF
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0000
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
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
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     a+6
                STA     _fcc_q3
                LDA     a+4
                STA     _fcc_q2
                LDA     a+2
                STA     _fcc_long_hi
                LDA     a
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     b+6
                STA     _fcc_q3
                LDA     b+4
                STA     _fcc_q2
                LDA     b+2
                STA     _fcc_long_hi
                LDA     b
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
                STA     r
                TAY
                LDA     _fcc_long_hi
                STA     r+2
                LDA     _fcc_q2
                STA     r+4
                LDA     _fcc_q3
                STA     r+6
                TYA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0000
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0000
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     r+6
                STA     _fcc_q3
                LDA     r+4
                STA     _fcc_q2
                LDA     r+2
                STA     _fcc_long_hi
                LDA     r
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                FGX2_FARCALL _llong_arith_is
                TAY
                TSC
                CLC
                ADC     #16
                TCS
                TYA
                BNE     _llong_arith_L25
                LDA     #22
                TAY
                TSC
                CLC
                ADC     #_llong_arith_run_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_llong_arith_L25
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0001
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
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #a
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     #$FFFF
                STA     _fcc_long_hi
                LDA     #$FFFF
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0000
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
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
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     a+6
                STA     _fcc_q3
                LDA     a+4
                STA     _fcc_q2
                LDA     a+2
                STA     _fcc_long_hi
                LDA     a
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     b+6
                STA     _fcc_q3
                LDA     b+4
                STA     _fcc_q2
                LDA     b+2
                STA     _fcc_long_hi
                LDA     b
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
                STA     r
                TAY
                LDA     _fcc_long_hi
                STA     r+2
                LDA     _fcc_q2
                STA     r+4
                LDA     _fcc_q3
                STA     r+6
                TYA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0002
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$FFFF
                STA     _fcc_long_hi
                LDA     #$FFFE
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     r+6
                STA     _fcc_q3
                LDA     r+4
                STA     _fcc_q2
                LDA     r+2
                STA     _fcc_long_hi
                LDA     r
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                FGX2_FARCALL _llong_arith_is
                TAY
                TSC
                CLC
                ADC     #16
                TCS
                TYA
                BNE     _llong_arith_L26
                LDA     #23
                TAY
                TSC
                CLC
                ADC     #_llong_arith_run_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_llong_arith_L26
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0001
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
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #a
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     #$FFFF
                STA     _fcc_long_hi
                LDA     #$FFFF
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0000
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
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
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     a+6
                STA     _fcc_q3
                LDA     a+4
                STA     _fcc_q2
                LDA     a+2
                STA     _fcc_long_hi
                LDA     a
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     b+6
                STA     _fcc_q3
                LDA     b+4
                STA     _fcc_q2
                LDA     b+2
                STA     _fcc_long_hi
                LDA     b
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
                STA     r
                TAY
                LDA     _fcc_long_hi
                STA     r+2
                LDA     _fcc_q2
                STA     r+4
                LDA     _fcc_q3
                STA     r+6
                TYA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0001
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0000
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     r+6
                STA     _fcc_q3
                LDA     r+4
                STA     _fcc_q2
                LDA     r+2
                STA     _fcc_long_hi
                LDA     r
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                FGX2_FARCALL _llong_arith_is
                TAY
                TSC
                CLC
                ADC     #16
                TCS
                TYA
                BNE     _llong_arith_L27
                LDA     #24
                TAY
                TSC
                CLC
                ADC     #_llong_arith_run_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_llong_arith_L27
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0001
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
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #a
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     #$FFFF
                STA     _fcc_long_hi
                LDA     #$FFFF
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0000
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
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
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     a+6
                STA     _fcc_q3
                LDA     a+4
                STA     _fcc_q2
                LDA     a+2
                STA     _fcc_long_hi
                LDA     a
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     b+6
                STA     _fcc_q3
                LDA     b+4
                STA     _fcc_q2
                LDA     b+2
                STA     _fcc_long_hi
                LDA     b
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
                STA     r
                TAY
                LDA     _fcc_long_hi
                STA     r+2
                LDA     _fcc_q2
                STA     r+4
                LDA     _fcc_q3
                STA     r+6
                TYA
                LDA     #$FFFF
                STA     _fcc_long_hi
                LDA     #$FFFF
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
                LDA     r+6
                STA     _fcc_q3
                LDA     r+4
                STA     _fcc_q2
                LDA     r+2
                STA     _fcc_long_hi
                LDA     r
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                FGX2_FARCALL _llong_arith_is
                TAY
                TSC
                CLC
                ADC     #16
                TCS
                TYA
                BNE     _llong_arith_L28
                LDA     #25
                TAY
                TSC
                CLC
                ADC     #_llong_arith_run_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_llong_arith_L28
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0001
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
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #a
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     #$FFFF
                STA     _fcc_long_hi
                LDA     #$FFFF
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0000
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
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
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     a+6
                STA     _fcc_q3
                LDA     a+4
                STA     _fcc_q2
                LDA     a+2
                STA     _fcc_long_hi
                LDA     a
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     b+6
                STA     _fcc_q3
                LDA     b+4
                STA     _fcc_q2
                LDA     b+2
                STA     _fcc_long_hi
                LDA     b
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
                STA     r
                TAY
                LDA     _fcc_long_hi
                STA     r+2
                LDA     _fcc_q2
                STA     r+4
                LDA     _fcc_q3
                STA     r+6
                TYA
                LDA     #$FFFF
                STA     _fcc_long_hi
                LDA     #$FFFE
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
                LDA     r+6
                STA     _fcc_q3
                LDA     r+4
                STA     _fcc_q2
                LDA     r+2
                STA     _fcc_long_hi
                LDA     r
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                FGX2_FARCALL _llong_arith_is
                TAY
                TSC
                CLC
                ADC     #16
                TCS
                TYA
                BNE     _llong_arith_L29
                LDA     #26
                TAY
                TSC
                CLC
                ADC     #_llong_arith_run_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_llong_arith_L29
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0001
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
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #a
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     #$FFFF
                STA     _fcc_long_hi
                LDA     #$FFFF
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0000
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
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
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     a+6
                STA     _fcc_q3
                LDA     a+4
                STA     _fcc_q2
                LDA     a+2
                STA     _fcc_long_hi
                LDA     a
                FGX2_FARCALL _fcc_ll_com
                STA     r
                TAY
                LDA     _fcc_long_hi
                STA     r+2
                LDA     _fcc_q2
                STA     r+4
                LDA     _fcc_q3
                STA     r+6
                TYA
                LDA     #$FFFF
                STA     _fcc_long_hi
                LDA     #$FFFE
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0000
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     r+6
                STA     _fcc_q3
                LDA     r+4
                STA     _fcc_q2
                LDA     r+2
                STA     _fcc_long_hi
                LDA     r
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                FGX2_FARCALL _llong_arith_is
                TAY
                TSC
                CLC
                ADC     #16
                TCS
                TYA
                BNE     _llong_arith_L30
                LDA     #27
                TAY
                TSC
                CLC
                ADC     #_llong_arith_run_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_llong_arith_L30
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0001
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
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #a
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     #$FFFF
                STA     _fcc_long_hi
                LDA     #$FFFF
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0000
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
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
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     a+6
                STA     _fcc_q3
                LDA     a+4
                STA     _fcc_q2
                LDA     a+2
                STA     _fcc_long_hi
                LDA     a
                FGX2_FARCALL _fcc_ll_neg
                STA     r
                TAY
                LDA     _fcc_long_hi
                STA     r+2
                LDA     _fcc_q2
                STA     r+4
                LDA     _fcc_q3
                STA     r+6
                TYA
                LDA     #$FFFF
                STA     _fcc_long_hi
                LDA     #$FFFF
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0000
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     r+6
                STA     _fcc_q3
                LDA     r+4
                STA     _fcc_q2
                LDA     r+2
                STA     _fcc_long_hi
                LDA     r
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                FGX2_FARCALL _llong_arith_is
                TAY
                TSC
                CLC
                ADC     #16
                TCS
                TYA
                BNE     _llong_arith_L31
                LDA     #28
                TAY
                TSC
                CLC
                ADC     #_llong_arith_run_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_llong_arith_L31
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
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #a
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0001
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0000
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
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
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     a+6
                STA     _fcc_q3
                LDA     a+4
                STA     _fcc_q2
                LDA     a+2
                STA     _fcc_long_hi
                LDA     a
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     b+6
                STA     _fcc_q3
                LDA     b+4
                STA     _fcc_q2
                LDA     b+2
                STA     _fcc_long_hi
                LDA     b
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
                STA     r
                TAY
                LDA     _fcc_long_hi
                STA     r+2
                LDA     _fcc_q2
                STA     r+4
                LDA     _fcc_q3
                STA     r+6
                TYA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0001
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
                LDA     r+6
                STA     _fcc_q3
                LDA     r+4
                STA     _fcc_q2
                LDA     r+2
                STA     _fcc_long_hi
                LDA     r
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                FGX2_FARCALL _llong_arith_is
                TAY
                TSC
                CLC
                ADC     #16
                TCS
                TYA
                BNE     _llong_arith_L32
                LDA     #29
                TAY
                TSC
                CLC
                ADC     #_llong_arith_run_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_llong_arith_L32
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
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #a
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0001
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0000
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
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
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     a+6
                STA     _fcc_q3
                LDA     a+4
                STA     _fcc_q2
                LDA     a+2
                STA     _fcc_long_hi
                LDA     a
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     b+6
                STA     _fcc_q3
                LDA     b+4
                STA     _fcc_q2
                LDA     b+2
                STA     _fcc_long_hi
                LDA     b
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
                STA     r
                TAY
                LDA     _fcc_long_hi
                STA     r+2
                LDA     _fcc_q2
                STA     r+4
                LDA     _fcc_q3
                STA     r+6
                TYA
                LDA     #$FFFF
                STA     _fcc_long_hi
                LDA     #$FFFF
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$7FFF
                STA     _fcc_long_hi
                LDA     #$FFFF
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     r+6
                STA     _fcc_q3
                LDA     r+4
                STA     _fcc_q2
                LDA     r+2
                STA     _fcc_long_hi
                LDA     r
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                FGX2_FARCALL _llong_arith_is
                TAY
                TSC
                CLC
                ADC     #16
                TCS
                TYA
                BNE     _llong_arith_L33
                LDA     #30
                TAY
                TSC
                CLC
                ADC     #_llong_arith_run_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_llong_arith_L33
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
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #a
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0001
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0000
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
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
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     a+6
                STA     _fcc_q3
                LDA     a+4
                STA     _fcc_q2
                LDA     a+2
                STA     _fcc_long_hi
                LDA     a
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     b+6
                STA     _fcc_q3
                LDA     b+4
                STA     _fcc_q2
                LDA     b+2
                STA     _fcc_long_hi
                LDA     b
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
                STA     r
                TAY
                LDA     _fcc_long_hi
                STA     r+2
                LDA     _fcc_q2
                STA     r+4
                LDA     _fcc_q3
                STA     r+6
                TYA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0000
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0000
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     r+6
                STA     _fcc_q3
                LDA     r+4
                STA     _fcc_q2
                LDA     r+2
                STA     _fcc_long_hi
                LDA     r
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                FGX2_FARCALL _llong_arith_is
                TAY
                TSC
                CLC
                ADC     #16
                TCS
                TYA
                BNE     _llong_arith_L34
                LDA     #31
                TAY
                TSC
                CLC
                ADC     #_llong_arith_run_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_llong_arith_L34
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
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #a
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0001
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0000
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
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
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     a+6
                STA     _fcc_q3
                LDA     a+4
                STA     _fcc_q2
                LDA     a+2
                STA     _fcc_long_hi
                LDA     a
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     b+6
                STA     _fcc_q3
                LDA     b+4
                STA     _fcc_q2
                LDA     b+2
                STA     _fcc_long_hi
                LDA     b
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
                STA     r
                TAY
                LDA     _fcc_long_hi
                STA     r+2
                LDA     _fcc_q2
                STA     r+4
                LDA     _fcc_q3
                STA     r+6
                TYA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0001
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
                LDA     r+6
                STA     _fcc_q3
                LDA     r+4
                STA     _fcc_q2
                LDA     r+2
                STA     _fcc_long_hi
                LDA     r
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                FGX2_FARCALL _llong_arith_is
                TAY
                TSC
                CLC
                ADC     #16
                TCS
                TYA
                BNE     _llong_arith_L35
                LDA     #32
                TAY
                TSC
                CLC
                ADC     #_llong_arith_run_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_llong_arith_L35
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
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #a
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0001
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0000
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
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
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     a+6
                STA     _fcc_q3
                LDA     a+4
                STA     _fcc_q2
                LDA     a+2
                STA     _fcc_long_hi
                LDA     a
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     b+6
                STA     _fcc_q3
                LDA     b+4
                STA     _fcc_q2
                LDA     b+2
                STA     _fcc_long_hi
                LDA     b
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
                STA     r
                TAY
                LDA     _fcc_long_hi
                STA     r+2
                LDA     _fcc_q2
                STA     r+4
                LDA     _fcc_q3
                STA     r+6
                TYA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0001
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
                LDA     r+6
                STA     _fcc_q3
                LDA     r+4
                STA     _fcc_q2
                LDA     r+2
                STA     _fcc_long_hi
                LDA     r
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                FGX2_FARCALL _llong_arith_is
                TAY
                TSC
                CLC
                ADC     #16
                TCS
                TYA
                BNE     _llong_arith_L36
                LDA     #33
                TAY
                TSC
                CLC
                ADC     #_llong_arith_run_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_llong_arith_L36
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
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #a
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0001
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0000
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
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
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     a+6
                STA     _fcc_q3
                LDA     a+4
                STA     _fcc_q2
                LDA     a+2
                STA     _fcc_long_hi
                LDA     a
                FGX2_FARCALL _fcc_ll_com
                STA     r
                TAY
                LDA     _fcc_long_hi
                STA     r+2
                LDA     _fcc_q2
                STA     r+4
                LDA     _fcc_q3
                STA     r+6
                TYA
                LDA     #$FFFF
                STA     _fcc_long_hi
                LDA     #$FFFF
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$7FFF
                STA     _fcc_long_hi
                LDA     #$FFFF
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     r+6
                STA     _fcc_q3
                LDA     r+4
                STA     _fcc_q2
                LDA     r+2
                STA     _fcc_long_hi
                LDA     r
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                FGX2_FARCALL _llong_arith_is
                TAY
                TSC
                CLC
                ADC     #16
                TCS
                TYA
                BNE     _llong_arith_L37
                LDA     #34
                TAY
                TSC
                CLC
                ADC     #_llong_arith_run_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_llong_arith_L37
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
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #a
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0001
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0000
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
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
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     a+6
                STA     _fcc_q3
                LDA     a+4
                STA     _fcc_q2
                LDA     a+2
                STA     _fcc_long_hi
                LDA     a
                FGX2_FARCALL _fcc_ll_neg
                STA     r
                TAY
                LDA     _fcc_long_hi
                STA     r+2
                LDA     _fcc_q2
                STA     r+4
                LDA     _fcc_q3
                STA     r+6
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
                LDA     r+6
                STA     _fcc_q3
                LDA     r+4
                STA     _fcc_q2
                LDA     r+2
                STA     _fcc_long_hi
                LDA     r
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                FGX2_FARCALL _llong_arith_is
                TAY
                TSC
                CLC
                ADC     #16
                TCS
                TYA
                BNE     _llong_arith_L38
                LDA     #35
                TAY
                TSC
                CLC
                ADC     #_llong_arith_run_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_llong_arith_L38
                LDA     #$FFFF
                STA     _fcc_long_hi
                LDA     #$FFFF
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
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #a
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0002
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0000
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
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
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     a+6
                STA     _fcc_q3
                LDA     a+4
                STA     _fcc_q2
                LDA     a+2
                STA     _fcc_long_hi
                LDA     a
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     b+6
                STA     _fcc_q3
                LDA     b+4
                STA     _fcc_q2
                LDA     b+2
                STA     _fcc_long_hi
                LDA     b
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
                STA     r
                TAY
                LDA     _fcc_long_hi
                STA     r+2
                LDA     _fcc_q2
                STA     r+4
                LDA     _fcc_q3
                STA     r+6
                TYA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0001
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0000
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     r+6
                STA     _fcc_q3
                LDA     r+4
                STA     _fcc_q2
                LDA     r+2
                STA     _fcc_long_hi
                LDA     r
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                FGX2_FARCALL _llong_arith_is
                TAY
                TSC
                CLC
                ADC     #16
                TCS
                TYA
                BNE     _llong_arith_L39
                LDA     #36
                TAY
                TSC
                CLC
                ADC     #_llong_arith_run_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_llong_arith_L39
                LDA     #$FFFF
                STA     _fcc_long_hi
                LDA     #$FFFF
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
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #a
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0002
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0000
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
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
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     a+6
                STA     _fcc_q3
                LDA     a+4
                STA     _fcc_q2
                LDA     a+2
                STA     _fcc_long_hi
                LDA     a
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     b+6
                STA     _fcc_q3
                LDA     b+4
                STA     _fcc_q2
                LDA     b+2
                STA     _fcc_long_hi
                LDA     b
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
                STA     r
                TAY
                LDA     _fcc_long_hi
                STA     r+2
                LDA     _fcc_q2
                STA     r+4
                LDA     _fcc_q3
                STA     r+6
                TYA
                LDA     #$FFFF
                STA     _fcc_long_hi
                LDA     #$FFFD
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
                LDA     r+6
                STA     _fcc_q3
                LDA     r+4
                STA     _fcc_q2
                LDA     r+2
                STA     _fcc_long_hi
                LDA     r
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                FGX2_FARCALL _llong_arith_is
                TAY
                TSC
                CLC
                ADC     #16
                TCS
                TYA
                BNE     _llong_arith_L40
                LDA     #37
                TAY
                TSC
                CLC
                ADC     #_llong_arith_run_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_llong_arith_L40
                LDA     #$FFFF
                STA     _fcc_long_hi
                LDA     #$FFFF
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
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #a
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0002
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0000
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
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
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     a+6
                STA     _fcc_q3
                LDA     a+4
                STA     _fcc_q2
                LDA     a+2
                STA     _fcc_long_hi
                LDA     a
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     b+6
                STA     _fcc_q3
                LDA     b+4
                STA     _fcc_q2
                LDA     b+2
                STA     _fcc_long_hi
                LDA     b
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
                STA     r
                TAY
                LDA     _fcc_long_hi
                STA     r+2
                LDA     _fcc_q2
                STA     r+4
                LDA     _fcc_q3
                STA     r+6
                TYA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0002
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0000
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     r+6
                STA     _fcc_q3
                LDA     r+4
                STA     _fcc_q2
                LDA     r+2
                STA     _fcc_long_hi
                LDA     r
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                FGX2_FARCALL _llong_arith_is
                TAY
                TSC
                CLC
                ADC     #16
                TCS
                TYA
                BNE     _llong_arith_L41
                LDA     #38
                TAY
                TSC
                CLC
                ADC     #_llong_arith_run_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_llong_arith_L41
                LDA     #$FFFF
                STA     _fcc_long_hi
                LDA     #$FFFF
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
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #a
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0002
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0000
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
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
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     a+6
                STA     _fcc_q3
                LDA     a+4
                STA     _fcc_q2
                LDA     a+2
                STA     _fcc_long_hi
                LDA     a
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     b+6
                STA     _fcc_q3
                LDA     b+4
                STA     _fcc_q2
                LDA     b+2
                STA     _fcc_long_hi
                LDA     b
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
                STA     r
                TAY
                LDA     _fcc_long_hi
                STA     r+2
                LDA     _fcc_q2
                STA     r+4
                LDA     _fcc_q3
                STA     r+6
                TYA
                LDA     #$FFFF
                STA     _fcc_long_hi
                LDA     #$FFFF
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
                LDA     r+6
                STA     _fcc_q3
                LDA     r+4
                STA     _fcc_q2
                LDA     r+2
                STA     _fcc_long_hi
                LDA     r
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                FGX2_FARCALL _llong_arith_is
                TAY
                TSC
                CLC
                ADC     #16
                TCS
                TYA
                BNE     _llong_arith_L42
                LDA     #39
                TAY
                TSC
                CLC
                ADC     #_llong_arith_run_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_llong_arith_L42
                LDA     #$FFFF
                STA     _fcc_long_hi
                LDA     #$FFFF
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
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #a
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0002
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0000
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
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
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     a+6
                STA     _fcc_q3
                LDA     a+4
                STA     _fcc_q2
                LDA     a+2
                STA     _fcc_long_hi
                LDA     a
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     b+6
                STA     _fcc_q3
                LDA     b+4
                STA     _fcc_q2
                LDA     b+2
                STA     _fcc_long_hi
                LDA     b
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
                STA     r
                TAY
                LDA     _fcc_long_hi
                STA     r+2
                LDA     _fcc_q2
                STA     r+4
                LDA     _fcc_q3
                STA     r+6
                TYA
                LDA     #$FFFF
                STA     _fcc_long_hi
                LDA     #$FFFD
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
                LDA     r+6
                STA     _fcc_q3
                LDA     r+4
                STA     _fcc_q2
                LDA     r+2
                STA     _fcc_long_hi
                LDA     r
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                FGX2_FARCALL _llong_arith_is
                TAY
                TSC
                CLC
                ADC     #16
                TCS
                TYA
                BNE     _llong_arith_L43
                LDA     #40
                TAY
                TSC
                CLC
                ADC     #_llong_arith_run_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_llong_arith_L43
                LDA     #$FFFF
                STA     _fcc_long_hi
                LDA     #$FFFF
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
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #a
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0002
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0000
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
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
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     a+6
                STA     _fcc_q3
                LDA     a+4
                STA     _fcc_q2
                LDA     a+2
                STA     _fcc_long_hi
                LDA     a
                FGX2_FARCALL _fcc_ll_com
                STA     r
                TAY
                LDA     _fcc_long_hi
                STA     r+2
                LDA     _fcc_q2
                STA     r+4
                LDA     _fcc_q3
                STA     r+6
                TYA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0000
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0000
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     r+6
                STA     _fcc_q3
                LDA     r+4
                STA     _fcc_q2
                LDA     r+2
                STA     _fcc_long_hi
                LDA     r
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                FGX2_FARCALL _llong_arith_is
                TAY
                TSC
                CLC
                ADC     #16
                TCS
                TYA
                BNE     _llong_arith_L44
                LDA     #41
                TAY
                TSC
                CLC
                ADC     #_llong_arith_run_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_llong_arith_L44
                LDA     #$FFFF
                STA     _fcc_long_hi
                LDA     #$FFFF
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
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #a
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0002
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0000
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
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
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     a+6
                STA     _fcc_q3
                LDA     a+4
                STA     _fcc_q2
                LDA     a+2
                STA     _fcc_long_hi
                LDA     a
                FGX2_FARCALL _fcc_ll_neg
                STA     r
                TAY
                LDA     _fcc_long_hi
                STA     r+2
                LDA     _fcc_q2
                STA     r+4
                LDA     _fcc_q3
                STA     r+6
                TYA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0001
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0000
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     r+6
                STA     _fcc_q3
                LDA     r+4
                STA     _fcc_q2
                LDA     r+2
                STA     _fcc_long_hi
                LDA     r
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                FGX2_FARCALL _llong_arith_is
                TAY
                TSC
                CLC
                ADC     #16
                TCS
                TYA
                BNE     _llong_arith_L45
                LDA     #43
                TAY
                TSC
                CLC
                ADC     #_llong_arith_run_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_llong_arith_L45
                LDA     #$FFFF
                STA     _fcc_long_hi
                LDA     #$0000
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
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #a
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
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
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     a+6
                STA     _fcc_q3
                LDA     a+4
                STA     _fcc_q2
                LDA     a+2
                STA     _fcc_long_hi
                LDA     a
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     b+6
                STA     _fcc_q3
                LDA     b+4
                STA     _fcc_q2
                LDA     b+2
                STA     _fcc_long_hi
                LDA     b
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
                STA     r
                TAY
                LDA     _fcc_long_hi
                STA     r+2
                LDA     _fcc_q2
                STA     r+4
                LDA     _fcc_q3
                STA     r+6
                TYA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0000
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0002
                STA     _fcc_long_hi
                LDA     #$0000
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     r+6
                STA     _fcc_q3
                LDA     r+4
                STA     _fcc_q2
                LDA     r+2
                STA     _fcc_long_hi
                LDA     r
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                FGX2_FARCALL _llong_arith_is
                TAY
                TSC
                CLC
                ADC     #16
                TCS
                TYA
                BNE     _llong_arith_L46
                LDA     #44
                TAY
                TSC
                CLC
                ADC     #_llong_arith_run_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_llong_arith_L46
                LDA     #$FFFF
                STA     _fcc_long_hi
                LDA     #$0000
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
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #a
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
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
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     a+6
                STA     _fcc_q3
                LDA     a+4
                STA     _fcc_q2
                LDA     a+2
                STA     _fcc_long_hi
                LDA     a
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     b+6
                STA     _fcc_q3
                LDA     b+4
                STA     _fcc_q2
                LDA     b+2
                STA     _fcc_long_hi
                LDA     b
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
                STA     r
                TAY
                LDA     _fcc_long_hi
                STA     r+2
                LDA     _fcc_q2
                STA     r+4
                LDA     _fcc_q3
                STA     r+6
                TYA
                LDA     #$FFFE
                STA     _fcc_long_hi
                LDA     #$0000
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0001
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     r+6
                STA     _fcc_q3
                LDA     r+4
                STA     _fcc_q2
                LDA     r+2
                STA     _fcc_long_hi
                LDA     r
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                FGX2_FARCALL _llong_arith_is
                TAY
                TSC
                CLC
                ADC     #16
                TCS
                TYA
                BNE     _llong_arith_L47
                LDA     #45
                TAY
                TSC
                CLC
                ADC     #_llong_arith_run_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_llong_arith_L47
                LDA     #$FFFF
                STA     _fcc_long_hi
                LDA     #$0000
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
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #a
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
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
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     a+6
                STA     _fcc_q3
                LDA     a+4
                STA     _fcc_q2
                LDA     a+2
                STA     _fcc_long_hi
                LDA     a
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     b+6
                STA     _fcc_q3
                LDA     b+4
                STA     _fcc_q2
                LDA     b+2
                STA     _fcc_long_hi
                LDA     b
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
                STA     r
                TAY
                LDA     _fcc_long_hi
                STA     r+2
                LDA     _fcc_q2
                STA     r+4
                LDA     _fcc_q3
                STA     r+6
                TYA
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
                LDA     #$0000
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     r+6
                STA     _fcc_q3
                LDA     r+4
                STA     _fcc_q2
                LDA     r+2
                STA     _fcc_long_hi
                LDA     r
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                FGX2_FARCALL _llong_arith_is
                TAY
                TSC
                CLC
                ADC     #16
                TCS
                TYA
                BNE     _llong_arith_L48
                LDA     #46
                TAY
                TSC
                CLC
                ADC     #_llong_arith_run_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_llong_arith_L48
                LDA     #$FFFF
                STA     _fcc_long_hi
                LDA     #$0000
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
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #a
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
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
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     a+6
                STA     _fcc_q3
                LDA     a+4
                STA     _fcc_q2
                LDA     a+2
                STA     _fcc_long_hi
                LDA     a
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     b+6
                STA     _fcc_q3
                LDA     b+4
                STA     _fcc_q2
                LDA     b+2
                STA     _fcc_long_hi
                LDA     b
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
                STA     r
                TAY
                LDA     _fcc_long_hi
                STA     r+2
                LDA     _fcc_q2
                STA     r+4
                LDA     _fcc_q3
                STA     r+6
                TYA
                LDA     #$FFFF
                STA     _fcc_long_hi
                LDA     #$0000
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0001
                STA     _fcc_long_hi
                LDA     #$FFFF
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     r+6
                STA     _fcc_q3
                LDA     r+4
                STA     _fcc_q2
                LDA     r+2
                STA     _fcc_long_hi
                LDA     r
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                FGX2_FARCALL _llong_arith_is
                TAY
                TSC
                CLC
                ADC     #16
                TCS
                TYA
                BNE     _llong_arith_L49
                LDA     #47
                TAY
                TSC
                CLC
                ADC     #_llong_arith_run_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_llong_arith_L49
                LDA     #$FFFF
                STA     _fcc_long_hi
                LDA     #$0000
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
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #a
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
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
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     a+6
                STA     _fcc_q3
                LDA     a+4
                STA     _fcc_q2
                LDA     a+2
                STA     _fcc_long_hi
                LDA     a
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     b+6
                STA     _fcc_q3
                LDA     b+4
                STA     _fcc_q2
                LDA     b+2
                STA     _fcc_long_hi
                LDA     b
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
                STA     r
                TAY
                LDA     _fcc_long_hi
                STA     r+2
                LDA     _fcc_q2
                STA     r+4
                LDA     _fcc_q3
                STA     r+6
                TYA
                LDA     #$FFFE
                STA     _fcc_long_hi
                LDA     #$0000
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0001
                STA     _fcc_long_hi
                LDA     #$FFFF
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     r+6
                STA     _fcc_q3
                LDA     r+4
                STA     _fcc_q2
                LDA     r+2
                STA     _fcc_long_hi
                LDA     r
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                FGX2_FARCALL _llong_arith_is
                TAY
                TSC
                CLC
                ADC     #16
                TCS
                TYA
                BNE     _llong_arith_L50
                LDA     #48
                TAY
                TSC
                CLC
                ADC     #_llong_arith_run_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_llong_arith_L50
                LDA     #$FFFF
                STA     _fcc_long_hi
                LDA     #$0000
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
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #a
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
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
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     a+6
                STA     _fcc_q3
                LDA     a+4
                STA     _fcc_q2
                LDA     a+2
                STA     _fcc_long_hi
                LDA     a
                FGX2_FARCALL _fcc_ll_com
                STA     r
                TAY
                LDA     _fcc_long_hi
                STA     r+2
                LDA     _fcc_q2
                STA     r+4
                LDA     _fcc_q3
                STA     r+6
                TYA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$FFFF
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$FFFE
                STA     _fcc_long_hi
                LDA     #$FFFF
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     r+6
                STA     _fcc_q3
                LDA     r+4
                STA     _fcc_q2
                LDA     r+2
                STA     _fcc_long_hi
                LDA     r
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                FGX2_FARCALL _llong_arith_is
                TAY
                TSC
                CLC
                ADC     #16
                TCS
                TYA
                BNE     _llong_arith_L51
                LDA     #49
                TAY
                TSC
                CLC
                ADC     #_llong_arith_run_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_llong_arith_L51
                LDA     #$FFFF
                STA     _fcc_long_hi
                LDA     #$0000
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
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #a
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
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
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     a+6
                STA     _fcc_q3
                LDA     a+4
                STA     _fcc_q2
                LDA     a+2
                STA     _fcc_long_hi
                LDA     a
                FGX2_FARCALL _fcc_ll_neg
                STA     r
                TAY
                LDA     _fcc_long_hi
                STA     r+2
                LDA     _fcc_q2
                STA     r+4
                LDA     _fcc_q3
                STA     r+6
                TYA
                LDA     #$0001
                STA     _fcc_long_hi
                LDA     #$0000
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$FFFE
                STA     _fcc_long_hi
                LDA     #$FFFF
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     r+6
                STA     _fcc_q3
                LDA     r+4
                STA     _fcc_q2
                LDA     r+2
                STA     _fcc_long_hi
                LDA     r
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                FGX2_FARCALL _llong_arith_is
                TAY
                TSC
                CLC
                ADC     #16
                TCS
                TYA
                BNE     _llong_arith_L52
                LDA     #50
                TAY
                TSC
                CLC
                ADC     #_llong_arith_run_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_llong_arith_L52
                LDA     #$89AB
                STA     _fcc_long_hi
                LDA     #$CDEF
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0123
                STA     _fcc_long_hi
                LDA     #$4567
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #a
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     #1
                STA     n
                LDA     a+6
                STA     _fcc_q3
                LDA     a+4
                STA     _fcc_q2
                LDA     a+2
                STA     _fcc_long_hi
                LDA     a
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     n
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
                STA     r
                TAY
                LDA     _fcc_long_hi
                STA     r+2
                LDA     _fcc_q2
                STA     r+4
                LDA     _fcc_q3
                STA     r+6
                TYA
                LDA     #$1357
                STA     _fcc_long_hi
                LDA     #$9BDE
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0246
                STA     _fcc_long_hi
                LDA     #$8ACF
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     r+6
                STA     _fcc_q3
                LDA     r+4
                STA     _fcc_q2
                LDA     r+2
                STA     _fcc_long_hi
                LDA     r
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                FGX2_FARCALL _llong_arith_is
                TAY
                TSC
                CLC
                ADC     #16
                TCS
                TYA
                BNE     _llong_arith_L53
                LDA     #51
                TAY
                TSC
                CLC
                ADC     #_llong_arith_run_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_llong_arith_L53
                LDA     #$89AB
                STA     _fcc_long_hi
                LDA     #$CDEF
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0123
                STA     _fcc_long_hi
                LDA     #$4567
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #a
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     #1
                STA     n
                LDA     a+6
                STA     _fcc_q3
                LDA     a+4
                STA     _fcc_q2
                LDA     a+2
                STA     _fcc_long_hi
                LDA     a
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     n
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
                FGX2_FARCALL _fcc_ll_shr
                STA     r
                TAY
                LDA     _fcc_long_hi
                STA     r+2
                LDA     _fcc_q2
                STA     r+4
                LDA     _fcc_q3
                STA     r+6
                TYA
                LDA     #$C4D5
                STA     _fcc_long_hi
                LDA     #$E6F7
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0091
                STA     _fcc_long_hi
                LDA     #$A2B3
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     r+6
                STA     _fcc_q3
                LDA     r+4
                STA     _fcc_q2
                LDA     r+2
                STA     _fcc_long_hi
                LDA     r
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                FGX2_FARCALL _llong_arith_is
                TAY
                TSC
                CLC
                ADC     #16
                TCS
                TYA
                BNE     _llong_arith_L54
                LDA     #52
                TAY
                TSC
                CLC
                ADC     #_llong_arith_run_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_llong_arith_L54
                LDA     #$89AB
                STA     _fcc_long_hi
                LDA     #$CDEF
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0123
                STA     _fcc_long_hi
                LDA     #$4567
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #ua
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     #1
                STA     n
                LDA     ua+6
                STA     _fcc_q3
                LDA     ua+4
                STA     _fcc_q2
                LDA     ua+2
                STA     _fcc_long_hi
                LDA     ua
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     n
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
                STA     u
                TAY
                LDA     _fcc_long_hi
                STA     u+2
                LDA     _fcc_q2
                STA     u+4
                LDA     _fcc_q3
                STA     u+6
                TYA
                LDA     #$C4D5
                STA     _fcc_long_hi
                LDA     #$E6F7
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0091
                STA     _fcc_long_hi
                LDA     #$A2B3
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     u+6
                STA     _fcc_q3
                LDA     u+4
                STA     _fcc_q2
                LDA     u+2
                STA     _fcc_long_hi
                LDA     u
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                FGX2_FARCALL _llong_arith_uis
                TAY
                TSC
                CLC
                ADC     #16
                TCS
                TYA
                BNE     _llong_arith_L55
                LDA     #53
                TAY
                TSC
                CLC
                ADC     #_llong_arith_run_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_llong_arith_L55
                LDA     #$89AB
                STA     _fcc_long_hi
                LDA     #$CDEF
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0123
                STA     _fcc_long_hi
                LDA     #$4567
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #a
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     #15
                STA     n
                LDA     a+6
                STA     _fcc_q3
                LDA     a+4
                STA     _fcc_q2
                LDA     a+2
                STA     _fcc_long_hi
                LDA     a
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     n
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
                STA     r
                TAY
                LDA     _fcc_long_hi
                STA     r+2
                LDA     _fcc_q2
                STA     r+4
                LDA     _fcc_q3
                STA     r+6
                TYA
                LDA     #$E6F7
                STA     _fcc_long_hi
                LDA     #$8000
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$A2B3
                STA     _fcc_long_hi
                LDA     #$C4D5
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     r+6
                STA     _fcc_q3
                LDA     r+4
                STA     _fcc_q2
                LDA     r+2
                STA     _fcc_long_hi
                LDA     r
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                FGX2_FARCALL _llong_arith_is
                TAY
                TSC
                CLC
                ADC     #16
                TCS
                TYA
                BNE     _llong_arith_L56
                LDA     #54
                TAY
                TSC
                CLC
                ADC     #_llong_arith_run_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_llong_arith_L56
                LDA     #$89AB
                STA     _fcc_long_hi
                LDA     #$CDEF
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0123
                STA     _fcc_long_hi
                LDA     #$4567
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #a
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     #15
                STA     n
                LDA     a+6
                STA     _fcc_q3
                LDA     a+4
                STA     _fcc_q2
                LDA     a+2
                STA     _fcc_long_hi
                LDA     a
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     n
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
                FGX2_FARCALL _fcc_ll_shr
                STA     r
                TAY
                LDA     _fcc_long_hi
                STA     r+2
                LDA     _fcc_q2
                STA     r+4
                LDA     _fcc_q3
                STA     r+6
                TYA
                LDA     #$8ACF
                STA     _fcc_long_hi
                LDA     #$1357
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0246
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     r+6
                STA     _fcc_q3
                LDA     r+4
                STA     _fcc_q2
                LDA     r+2
                STA     _fcc_long_hi
                LDA     r
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                FGX2_FARCALL _llong_arith_is
                TAY
                TSC
                CLC
                ADC     #16
                TCS
                TYA
                BNE     _llong_arith_L57
                LDA     #55
                TAY
                TSC
                CLC
                ADC     #_llong_arith_run_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_llong_arith_L57
                LDA     #$89AB
                STA     _fcc_long_hi
                LDA     #$CDEF
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0123
                STA     _fcc_long_hi
                LDA     #$4567
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #ua
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     #15
                STA     n
                LDA     ua+6
                STA     _fcc_q3
                LDA     ua+4
                STA     _fcc_q2
                LDA     ua+2
                STA     _fcc_long_hi
                LDA     ua
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     n
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
                STA     u
                TAY
                LDA     _fcc_long_hi
                STA     u+2
                LDA     _fcc_q2
                STA     u+4
                LDA     _fcc_q3
                STA     u+6
                TYA
                LDA     #$8ACF
                STA     _fcc_long_hi
                LDA     #$1357
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0246
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     u+6
                STA     _fcc_q3
                LDA     u+4
                STA     _fcc_q2
                LDA     u+2
                STA     _fcc_long_hi
                LDA     u
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                FGX2_FARCALL _llong_arith_uis
                TAY
                TSC
                CLC
                ADC     #16
                TCS
                TYA
                BNE     _llong_arith_L58
                LDA     #56
                TAY
                TSC
                CLC
                ADC     #_llong_arith_run_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_llong_arith_L58
                LDA     #$89AB
                STA     _fcc_long_hi
                LDA     #$CDEF
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0123
                STA     _fcc_long_hi
                LDA     #$4567
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #a
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     #16
                STA     n
                LDA     a+6
                STA     _fcc_q3
                LDA     a+4
                STA     _fcc_q2
                LDA     a+2
                STA     _fcc_long_hi
                LDA     a
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     n
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
                STA     r
                TAY
                LDA     _fcc_long_hi
                STA     r+2
                LDA     _fcc_q2
                STA     r+4
                LDA     _fcc_q3
                STA     r+6
                TYA
                LDA     #$CDEF
                STA     _fcc_long_hi
                LDA     #$0000
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$4567
                STA     _fcc_long_hi
                LDA     #$89AB
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     r+6
                STA     _fcc_q3
                LDA     r+4
                STA     _fcc_q2
                LDA     r+2
                STA     _fcc_long_hi
                LDA     r
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                FGX2_FARCALL _llong_arith_is
                TAY
                TSC
                CLC
                ADC     #16
                TCS
                TYA
                BNE     _llong_arith_L59
                LDA     #57
                TAY
                TSC
                CLC
                ADC     #_llong_arith_run_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_llong_arith_L59
                LDA     #$89AB
                STA     _fcc_long_hi
                LDA     #$CDEF
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0123
                STA     _fcc_long_hi
                LDA     #$4567
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #a
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     #16
                STA     n
                LDA     a+6
                STA     _fcc_q3
                LDA     a+4
                STA     _fcc_q2
                LDA     a+2
                STA     _fcc_long_hi
                LDA     a
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     n
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
                FGX2_FARCALL _fcc_ll_shr
                STA     r
                TAY
                LDA     _fcc_long_hi
                STA     r+2
                LDA     _fcc_q2
                STA     r+4
                LDA     _fcc_q3
                STA     r+6
                TYA
                LDA     #$4567
                STA     _fcc_long_hi
                LDA     #$89AB
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0123
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     r+6
                STA     _fcc_q3
                LDA     r+4
                STA     _fcc_q2
                LDA     r+2
                STA     _fcc_long_hi
                LDA     r
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                FGX2_FARCALL _llong_arith_is
                TAY
                TSC
                CLC
                ADC     #16
                TCS
                TYA
                BNE     _llong_arith_L60
                LDA     #58
                TAY
                TSC
                CLC
                ADC     #_llong_arith_run_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_llong_arith_L60
                LDA     #$89AB
                STA     _fcc_long_hi
                LDA     #$CDEF
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0123
                STA     _fcc_long_hi
                LDA     #$4567
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #ua
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     #16
                STA     n
                LDA     ua+6
                STA     _fcc_q3
                LDA     ua+4
                STA     _fcc_q2
                LDA     ua+2
                STA     _fcc_long_hi
                LDA     ua
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     n
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
                STA     u
                TAY
                LDA     _fcc_long_hi
                STA     u+2
                LDA     _fcc_q2
                STA     u+4
                LDA     _fcc_q3
                STA     u+6
                TYA
                LDA     #$4567
                STA     _fcc_long_hi
                LDA     #$89AB
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0123
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     u+6
                STA     _fcc_q3
                LDA     u+4
                STA     _fcc_q2
                LDA     u+2
                STA     _fcc_long_hi
                LDA     u
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                FGX2_FARCALL _llong_arith_uis
                TAY
                TSC
                CLC
                ADC     #16
                TCS
                TYA
                BNE     _llong_arith_L61
                LDA     #59
                TAY
                TSC
                CLC
                ADC     #_llong_arith_run_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_llong_arith_L61
                LDA     #$89AB
                STA     _fcc_long_hi
                LDA     #$CDEF
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0123
                STA     _fcc_long_hi
                LDA     #$4567
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #a
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     #17
                STA     n
                LDA     a+6
                STA     _fcc_q3
                LDA     a+4
                STA     _fcc_q2
                LDA     a+2
                STA     _fcc_long_hi
                LDA     a
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     n
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
                STA     r
                TAY
                LDA     _fcc_long_hi
                STA     r+2
                LDA     _fcc_q2
                STA     r+4
                LDA     _fcc_q3
                STA     r+6
                TYA
                LDA     #$9BDE
                STA     _fcc_long_hi
                LDA     #$0000
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$8ACF
                STA     _fcc_long_hi
                LDA     #$1357
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     r+6
                STA     _fcc_q3
                LDA     r+4
                STA     _fcc_q2
                LDA     r+2
                STA     _fcc_long_hi
                LDA     r
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                FGX2_FARCALL _llong_arith_is
                TAY
                TSC
                CLC
                ADC     #16
                TCS
                TYA
                BNE     _llong_arith_L62
                LDA     #60
                TAY
                TSC
                CLC
                ADC     #_llong_arith_run_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_llong_arith_L62
                LDA     #$89AB
                STA     _fcc_long_hi
                LDA     #$CDEF
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0123
                STA     _fcc_long_hi
                LDA     #$4567
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #a
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     #17
                STA     n
                LDA     a+6
                STA     _fcc_q3
                LDA     a+4
                STA     _fcc_q2
                LDA     a+2
                STA     _fcc_long_hi
                LDA     a
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     n
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
                FGX2_FARCALL _fcc_ll_shr
                STA     r
                TAY
                LDA     _fcc_long_hi
                STA     r+2
                LDA     _fcc_q2
                STA     r+4
                LDA     _fcc_q3
                STA     r+6
                TYA
                LDA     #$A2B3
                STA     _fcc_long_hi
                LDA     #$C4D5
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0091
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     r+6
                STA     _fcc_q3
                LDA     r+4
                STA     _fcc_q2
                LDA     r+2
                STA     _fcc_long_hi
                LDA     r
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                FGX2_FARCALL _llong_arith_is
                TAY
                TSC
                CLC
                ADC     #16
                TCS
                TYA
                BNE     _llong_arith_L63
                LDA     #61
                TAY
                TSC
                CLC
                ADC     #_llong_arith_run_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_llong_arith_L63
                LDA     #$89AB
                STA     _fcc_long_hi
                LDA     #$CDEF
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0123
                STA     _fcc_long_hi
                LDA     #$4567
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #ua
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     #17
                STA     n
                LDA     ua+6
                STA     _fcc_q3
                LDA     ua+4
                STA     _fcc_q2
                LDA     ua+2
                STA     _fcc_long_hi
                LDA     ua
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     n
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
                STA     u
                TAY
                LDA     _fcc_long_hi
                STA     u+2
                LDA     _fcc_q2
                STA     u+4
                LDA     _fcc_q3
                STA     u+6
                TYA
                LDA     #$A2B3
                STA     _fcc_long_hi
                LDA     #$C4D5
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0091
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     u+6
                STA     _fcc_q3
                LDA     u+4
                STA     _fcc_q2
                LDA     u+2
                STA     _fcc_long_hi
                LDA     u
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                FGX2_FARCALL _llong_arith_uis
                TAY
                TSC
                CLC
                ADC     #16
                TCS
                TYA
                BNE     _llong_arith_L64
                LDA     #62
                TAY
                TSC
                CLC
                ADC     #_llong_arith_run_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_llong_arith_L64
                LDA     #$89AB
                STA     _fcc_long_hi
                LDA     #$CDEF
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0123
                STA     _fcc_long_hi
                LDA     #$4567
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #a
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     #31
                STA     n
                LDA     a+6
                STA     _fcc_q3
                LDA     a+4
                STA     _fcc_q2
                LDA     a+2
                STA     _fcc_long_hi
                LDA     a
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     n
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
                STA     r
                TAY
                LDA     _fcc_long_hi
                STA     r+2
                LDA     _fcc_q2
                STA     r+4
                LDA     _fcc_q3
                STA     r+6
                TYA
                LDA     #$8000
                STA     _fcc_long_hi
                LDA     #$0000
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$C4D5
                STA     _fcc_long_hi
                LDA     #$E6F7
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     r+6
                STA     _fcc_q3
                LDA     r+4
                STA     _fcc_q2
                LDA     r+2
                STA     _fcc_long_hi
                LDA     r
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                FGX2_FARCALL _llong_arith_is
                TAY
                TSC
                CLC
                ADC     #16
                TCS
                TYA
                BNE     _llong_arith_L65
                LDA     #63
                TAY
                TSC
                CLC
                ADC     #_llong_arith_run_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_llong_arith_L65
                LDA     #$89AB
                STA     _fcc_long_hi
                LDA     #$CDEF
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0123
                STA     _fcc_long_hi
                LDA     #$4567
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #a
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     #31
                STA     n
                LDA     a+6
                STA     _fcc_q3
                LDA     a+4
                STA     _fcc_q2
                LDA     a+2
                STA     _fcc_long_hi
                LDA     a
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     n
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
                FGX2_FARCALL _fcc_ll_shr
                STA     r
                TAY
                LDA     _fcc_long_hi
                STA     r+2
                LDA     _fcc_q2
                STA     r+4
                LDA     _fcc_q3
                STA     r+6
                TYA
                LDA     #$0246
                STA     _fcc_long_hi
                LDA     #$8ACF
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0000
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     r+6
                STA     _fcc_q3
                LDA     r+4
                STA     _fcc_q2
                LDA     r+2
                STA     _fcc_long_hi
                LDA     r
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                FGX2_FARCALL _llong_arith_is
                TAY
                TSC
                CLC
                ADC     #16
                TCS
                TYA
                BNE     _llong_arith_L66
                LDA     #64
                TAY
                TSC
                CLC
                ADC     #_llong_arith_run_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_llong_arith_L66
                LDA     #$89AB
                STA     _fcc_long_hi
                LDA     #$CDEF
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0123
                STA     _fcc_long_hi
                LDA     #$4567
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #ua
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     #31
                STA     n
                LDA     ua+6
                STA     _fcc_q3
                LDA     ua+4
                STA     _fcc_q2
                LDA     ua+2
                STA     _fcc_long_hi
                LDA     ua
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     n
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
                STA     u
                TAY
                LDA     _fcc_long_hi
                STA     u+2
                LDA     _fcc_q2
                STA     u+4
                LDA     _fcc_q3
                STA     u+6
                TYA
                LDA     #$0246
                STA     _fcc_long_hi
                LDA     #$8ACF
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0000
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     u+6
                STA     _fcc_q3
                LDA     u+4
                STA     _fcc_q2
                LDA     u+2
                STA     _fcc_long_hi
                LDA     u
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                FGX2_FARCALL _llong_arith_uis
                TAY
                TSC
                CLC
                ADC     #16
                TCS
                TYA
                BNE     _llong_arith_L67
                LDA     #65
                TAY
                TSC
                CLC
                ADC     #_llong_arith_run_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_llong_arith_L67
                LDA     #$89AB
                STA     _fcc_long_hi
                LDA     #$CDEF
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0123
                STA     _fcc_long_hi
                LDA     #$4567
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #a
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     #32
                STA     n
                LDA     a+6
                STA     _fcc_q3
                LDA     a+4
                STA     _fcc_q2
                LDA     a+2
                STA     _fcc_long_hi
                LDA     a
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     n
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
                STA     r
                TAY
                LDA     _fcc_long_hi
                STA     r+2
                LDA     _fcc_q2
                STA     r+4
                LDA     _fcc_q3
                STA     r+6
                TYA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0000
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$89AB
                STA     _fcc_long_hi
                LDA     #$CDEF
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     r+6
                STA     _fcc_q3
                LDA     r+4
                STA     _fcc_q2
                LDA     r+2
                STA     _fcc_long_hi
                LDA     r
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                FGX2_FARCALL _llong_arith_is
                TAY
                TSC
                CLC
                ADC     #16
                TCS
                TYA
                BNE     _llong_arith_L68
                LDA     #66
                TAY
                TSC
                CLC
                ADC     #_llong_arith_run_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_llong_arith_L68
                LDA     #$89AB
                STA     _fcc_long_hi
                LDA     #$CDEF
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0123
                STA     _fcc_long_hi
                LDA     #$4567
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #a
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     #32
                STA     n
                LDA     a+6
                STA     _fcc_q3
                LDA     a+4
                STA     _fcc_q2
                LDA     a+2
                STA     _fcc_long_hi
                LDA     a
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     n
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
                FGX2_FARCALL _fcc_ll_shr
                STA     r
                TAY
                LDA     _fcc_long_hi
                STA     r+2
                LDA     _fcc_q2
                STA     r+4
                LDA     _fcc_q3
                STA     r+6
                TYA
                LDA     #$0123
                STA     _fcc_long_hi
                LDA     #$4567
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0000
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     r+6
                STA     _fcc_q3
                LDA     r+4
                STA     _fcc_q2
                LDA     r+2
                STA     _fcc_long_hi
                LDA     r
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                FGX2_FARCALL _llong_arith_is
                TAY
                TSC
                CLC
                ADC     #16
                TCS
                TYA
                BNE     _llong_arith_L69
                LDA     #67
                TAY
                TSC
                CLC
                ADC     #_llong_arith_run_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_llong_arith_L69
                LDA     #$89AB
                STA     _fcc_long_hi
                LDA     #$CDEF
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0123
                STA     _fcc_long_hi
                LDA     #$4567
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #ua
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     #32
                STA     n
                LDA     ua+6
                STA     _fcc_q3
                LDA     ua+4
                STA     _fcc_q2
                LDA     ua+2
                STA     _fcc_long_hi
                LDA     ua
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     n
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
                STA     u
                TAY
                LDA     _fcc_long_hi
                STA     u+2
                LDA     _fcc_q2
                STA     u+4
                LDA     _fcc_q3
                STA     u+6
                TYA
                LDA     #$0123
                STA     _fcc_long_hi
                LDA     #$4567
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0000
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     u+6
                STA     _fcc_q3
                LDA     u+4
                STA     _fcc_q2
                LDA     u+2
                STA     _fcc_long_hi
                LDA     u
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                FGX2_FARCALL _llong_arith_uis
                TAY
                TSC
                CLC
                ADC     #16
                TCS
                TYA
                BNE     _llong_arith_L70
                LDA     #68
                TAY
                TSC
                CLC
                ADC     #_llong_arith_run_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_llong_arith_L70
                LDA     #$89AB
                STA     _fcc_long_hi
                LDA     #$CDEF
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0123
                STA     _fcc_long_hi
                LDA     #$4567
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #a
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     #33
                STA     n
                LDA     a+6
                STA     _fcc_q3
                LDA     a+4
                STA     _fcc_q2
                LDA     a+2
                STA     _fcc_long_hi
                LDA     a
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     n
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
                STA     r
                TAY
                LDA     _fcc_long_hi
                STA     r+2
                LDA     _fcc_q2
                STA     r+4
                LDA     _fcc_q3
                STA     r+6
                TYA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0000
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$1357
                STA     _fcc_long_hi
                LDA     #$9BDE
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     r+6
                STA     _fcc_q3
                LDA     r+4
                STA     _fcc_q2
                LDA     r+2
                STA     _fcc_long_hi
                LDA     r
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                FGX2_FARCALL _llong_arith_is
                TAY
                TSC
                CLC
                ADC     #16
                TCS
                TYA
                BNE     _llong_arith_L71
                LDA     #69
                TAY
                TSC
                CLC
                ADC     #_llong_arith_run_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_llong_arith_L71
                LDA     #$89AB
                STA     _fcc_long_hi
                LDA     #$CDEF
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0123
                STA     _fcc_long_hi
                LDA     #$4567
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #a
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     #33
                STA     n
                LDA     a+6
                STA     _fcc_q3
                LDA     a+4
                STA     _fcc_q2
                LDA     a+2
                STA     _fcc_long_hi
                LDA     a
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     n
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
                FGX2_FARCALL _fcc_ll_shr
                STA     r
                TAY
                LDA     _fcc_long_hi
                STA     r+2
                LDA     _fcc_q2
                STA     r+4
                LDA     _fcc_q3
                STA     r+6
                TYA
                LDA     #$0091
                STA     _fcc_long_hi
                LDA     #$A2B3
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0000
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     r+6
                STA     _fcc_q3
                LDA     r+4
                STA     _fcc_q2
                LDA     r+2
                STA     _fcc_long_hi
                LDA     r
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                FGX2_FARCALL _llong_arith_is
                TAY
                TSC
                CLC
                ADC     #16
                TCS
                TYA
                BNE     _llong_arith_L72
                LDA     #70
                TAY
                TSC
                CLC
                ADC     #_llong_arith_run_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_llong_arith_L72
                LDA     #$89AB
                STA     _fcc_long_hi
                LDA     #$CDEF
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0123
                STA     _fcc_long_hi
                LDA     #$4567
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #ua
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     #33
                STA     n
                LDA     ua+6
                STA     _fcc_q3
                LDA     ua+4
                STA     _fcc_q2
                LDA     ua+2
                STA     _fcc_long_hi
                LDA     ua
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     n
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
                STA     u
                TAY
                LDA     _fcc_long_hi
                STA     u+2
                LDA     _fcc_q2
                STA     u+4
                LDA     _fcc_q3
                STA     u+6
                TYA
                LDA     #$0091
                STA     _fcc_long_hi
                LDA     #$A2B3
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0000
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     u+6
                STA     _fcc_q3
                LDA     u+4
                STA     _fcc_q2
                LDA     u+2
                STA     _fcc_long_hi
                LDA     u
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                FGX2_FARCALL _llong_arith_uis
                TAY
                TSC
                CLC
                ADC     #16
                TCS
                TYA
                BNE     _llong_arith_L73
                LDA     #71
                TAY
                TSC
                CLC
                ADC     #_llong_arith_run_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_llong_arith_L73
                LDA     #$89AB
                STA     _fcc_long_hi
                LDA     #$CDEF
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0123
                STA     _fcc_long_hi
                LDA     #$4567
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #a
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     #47
                STA     n
                LDA     a+6
                STA     _fcc_q3
                LDA     a+4
                STA     _fcc_q2
                LDA     a+2
                STA     _fcc_long_hi
                LDA     a
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     n
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
                STA     r
                TAY
                LDA     _fcc_long_hi
                STA     r+2
                LDA     _fcc_q2
                STA     r+4
                LDA     _fcc_q3
                STA     r+6
                TYA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0000
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$E6F7
                STA     _fcc_long_hi
                LDA     #$8000
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     r+6
                STA     _fcc_q3
                LDA     r+4
                STA     _fcc_q2
                LDA     r+2
                STA     _fcc_long_hi
                LDA     r
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                FGX2_FARCALL _llong_arith_is
                TAY
                TSC
                CLC
                ADC     #16
                TCS
                TYA
                BNE     _llong_arith_L74
                LDA     #72
                TAY
                TSC
                CLC
                ADC     #_llong_arith_run_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_llong_arith_L74
                LDA     #$89AB
                STA     _fcc_long_hi
                LDA     #$CDEF
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0123
                STA     _fcc_long_hi
                LDA     #$4567
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #a
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     #47
                STA     n
                LDA     a+6
                STA     _fcc_q3
                LDA     a+4
                STA     _fcc_q2
                LDA     a+2
                STA     _fcc_long_hi
                LDA     a
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     n
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
                FGX2_FARCALL _fcc_ll_shr
                STA     r
                TAY
                LDA     _fcc_long_hi
                STA     r+2
                LDA     _fcc_q2
                STA     r+4
                LDA     _fcc_q3
                STA     r+6
                TYA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0246
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0000
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     r+6
                STA     _fcc_q3
                LDA     r+4
                STA     _fcc_q2
                LDA     r+2
                STA     _fcc_long_hi
                LDA     r
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                FGX2_FARCALL _llong_arith_is
                TAY
                TSC
                CLC
                ADC     #16
                TCS
                TYA
                BNE     _llong_arith_L75
                LDA     #73
                TAY
                TSC
                CLC
                ADC     #_llong_arith_run_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_llong_arith_L75
                LDA     #$89AB
                STA     _fcc_long_hi
                LDA     #$CDEF
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0123
                STA     _fcc_long_hi
                LDA     #$4567
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #ua
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     #47
                STA     n
                LDA     ua+6
                STA     _fcc_q3
                LDA     ua+4
                STA     _fcc_q2
                LDA     ua+2
                STA     _fcc_long_hi
                LDA     ua
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     n
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
                STA     u
                TAY
                LDA     _fcc_long_hi
                STA     u+2
                LDA     _fcc_q2
                STA     u+4
                LDA     _fcc_q3
                STA     u+6
                TYA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0246
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0000
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     u+6
                STA     _fcc_q3
                LDA     u+4
                STA     _fcc_q2
                LDA     u+2
                STA     _fcc_long_hi
                LDA     u
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                FGX2_FARCALL _llong_arith_uis
                TAY
                TSC
                CLC
                ADC     #16
                TCS
                TYA
                BNE     _llong_arith_L76
                LDA     #74
                TAY
                TSC
                CLC
                ADC     #_llong_arith_run_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_llong_arith_L76
                LDA     #$89AB
                STA     _fcc_long_hi
                LDA     #$CDEF
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0123
                STA     _fcc_long_hi
                LDA     #$4567
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #a
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     #48
                STA     n
                LDA     a+6
                STA     _fcc_q3
                LDA     a+4
                STA     _fcc_q2
                LDA     a+2
                STA     _fcc_long_hi
                LDA     a
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     n
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
                STA     r
                TAY
                LDA     _fcc_long_hi
                STA     r+2
                LDA     _fcc_q2
                STA     r+4
                LDA     _fcc_q3
                STA     r+6
                TYA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0000
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$CDEF
                STA     _fcc_long_hi
                LDA     #$0000
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     r+6
                STA     _fcc_q3
                LDA     r+4
                STA     _fcc_q2
                LDA     r+2
                STA     _fcc_long_hi
                LDA     r
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                FGX2_FARCALL _llong_arith_is
                TAY
                TSC
                CLC
                ADC     #16
                TCS
                TYA
                BNE     _llong_arith_L77
                LDA     #75
                TAY
                TSC
                CLC
                ADC     #_llong_arith_run_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_llong_arith_L77
                LDA     #$89AB
                STA     _fcc_long_hi
                LDA     #$CDEF
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0123
                STA     _fcc_long_hi
                LDA     #$4567
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #a
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     #48
                STA     n
                LDA     a+6
                STA     _fcc_q3
                LDA     a+4
                STA     _fcc_q2
                LDA     a+2
                STA     _fcc_long_hi
                LDA     a
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     n
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
                FGX2_FARCALL _fcc_ll_shr
                STA     r
                TAY
                LDA     _fcc_long_hi
                STA     r+2
                LDA     _fcc_q2
                STA     r+4
                LDA     _fcc_q3
                STA     r+6
                TYA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0123
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0000
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     r+6
                STA     _fcc_q3
                LDA     r+4
                STA     _fcc_q2
                LDA     r+2
                STA     _fcc_long_hi
                LDA     r
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                FGX2_FARCALL _llong_arith_is
                TAY
                TSC
                CLC
                ADC     #16
                TCS
                TYA
                BNE     _llong_arith_L78
                LDA     #76
                TAY
                TSC
                CLC
                ADC     #_llong_arith_run_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_llong_arith_L78
                LDA     #$89AB
                STA     _fcc_long_hi
                LDA     #$CDEF
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0123
                STA     _fcc_long_hi
                LDA     #$4567
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #ua
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     #48
                STA     n
                LDA     ua+6
                STA     _fcc_q3
                LDA     ua+4
                STA     _fcc_q2
                LDA     ua+2
                STA     _fcc_long_hi
                LDA     ua
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     n
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
                STA     u
                TAY
                LDA     _fcc_long_hi
                STA     u+2
                LDA     _fcc_q2
                STA     u+4
                LDA     _fcc_q3
                STA     u+6
                TYA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0123
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0000
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     u+6
                STA     _fcc_q3
                LDA     u+4
                STA     _fcc_q2
                LDA     u+2
                STA     _fcc_long_hi
                LDA     u
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                FGX2_FARCALL _llong_arith_uis
                TAY
                TSC
                CLC
                ADC     #16
                TCS
                TYA
                BNE     _llong_arith_L79
                LDA     #77
                TAY
                TSC
                CLC
                ADC     #_llong_arith_run_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_llong_arith_L79
                LDA     #$89AB
                STA     _fcc_long_hi
                LDA     #$CDEF
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0123
                STA     _fcc_long_hi
                LDA     #$4567
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #a
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     #63
                STA     n
                LDA     a+6
                STA     _fcc_q3
                LDA     a+4
                STA     _fcc_q2
                LDA     a+2
                STA     _fcc_long_hi
                LDA     a
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     n
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
                STA     r
                TAY
                LDA     _fcc_long_hi
                STA     r+2
                LDA     _fcc_q2
                STA     r+4
                LDA     _fcc_q3
                STA     r+6
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
                LDA     r+6
                STA     _fcc_q3
                LDA     r+4
                STA     _fcc_q2
                LDA     r+2
                STA     _fcc_long_hi
                LDA     r
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                FGX2_FARCALL _llong_arith_is
                TAY
                TSC
                CLC
                ADC     #16
                TCS
                TYA
                BNE     _llong_arith_L80
                LDA     #78
                TAY
                TSC
                CLC
                ADC     #_llong_arith_run_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_llong_arith_L80
                LDA     #$89AB
                STA     _fcc_long_hi
                LDA     #$CDEF
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0123
                STA     _fcc_long_hi
                LDA     #$4567
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #a
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     #63
                STA     n
                LDA     a+6
                STA     _fcc_q3
                LDA     a+4
                STA     _fcc_q2
                LDA     a+2
                STA     _fcc_long_hi
                LDA     a
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     n
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
                FGX2_FARCALL _fcc_ll_shr
                STA     r
                TAY
                LDA     _fcc_long_hi
                STA     r+2
                LDA     _fcc_q2
                STA     r+4
                LDA     _fcc_q3
                STA     r+6
                TYA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0000
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0000
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     r+6
                STA     _fcc_q3
                LDA     r+4
                STA     _fcc_q2
                LDA     r+2
                STA     _fcc_long_hi
                LDA     r
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                FGX2_FARCALL _llong_arith_is
                TAY
                TSC
                CLC
                ADC     #16
                TCS
                TYA
                BNE     _llong_arith_L81
                LDA     #79
                TAY
                TSC
                CLC
                ADC     #_llong_arith_run_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_llong_arith_L81
                LDA     #$89AB
                STA     _fcc_long_hi
                LDA     #$CDEF
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0123
                STA     _fcc_long_hi
                LDA     #$4567
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #ua
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     #63
                STA     n
                LDA     ua+6
                STA     _fcc_q3
                LDA     ua+4
                STA     _fcc_q2
                LDA     ua+2
                STA     _fcc_long_hi
                LDA     ua
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     n
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
                STA     u
                TAY
                LDA     _fcc_long_hi
                STA     u+2
                LDA     _fcc_q2
                STA     u+4
                LDA     _fcc_q3
                STA     u+6
                TYA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0000
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0000
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     u+6
                STA     _fcc_q3
                LDA     u+4
                STA     _fcc_q2
                LDA     u+2
                STA     _fcc_long_hi
                LDA     u
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                FGX2_FARCALL _llong_arith_uis
                TAY
                TSC
                CLC
                ADC     #16
                TCS
                TYA
                BNE     _llong_arith_L82
                LDA     #80
                TAY
                TSC
                CLC
                ADC     #_llong_arith_run_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_llong_arith_L82
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0001
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
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #a
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     #1
                STA     n
                LDA     a+6
                STA     _fcc_q3
                LDA     a+4
                STA     _fcc_q2
                LDA     a+2
                STA     _fcc_long_hi
                LDA     a
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     n
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
                STA     r
                TAY
                LDA     _fcc_long_hi
                STA     r+2
                LDA     _fcc_q2
                STA     r+4
                LDA     _fcc_q3
                STA     r+6
                TYA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0002
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0000
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     r+6
                STA     _fcc_q3
                LDA     r+4
                STA     _fcc_q2
                LDA     r+2
                STA     _fcc_long_hi
                LDA     r
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                FGX2_FARCALL _llong_arith_is
                TAY
                TSC
                CLC
                ADC     #16
                TCS
                TYA
                BNE     _llong_arith_L83
                LDA     #81
                TAY
                TSC
                CLC
                ADC     #_llong_arith_run_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_llong_arith_L83
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0001
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
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #a
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     #1
                STA     n
                LDA     a+6
                STA     _fcc_q3
                LDA     a+4
                STA     _fcc_q2
                LDA     a+2
                STA     _fcc_long_hi
                LDA     a
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     n
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
                FGX2_FARCALL _fcc_ll_shr
                STA     r
                TAY
                LDA     _fcc_long_hi
                STA     r+2
                LDA     _fcc_q2
                STA     r+4
                LDA     _fcc_q3
                STA     r+6
                TYA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0000
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$C000
                STA     _fcc_long_hi
                LDA     #$0000
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     r+6
                STA     _fcc_q3
                LDA     r+4
                STA     _fcc_q2
                LDA     r+2
                STA     _fcc_long_hi
                LDA     r
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                FGX2_FARCALL _llong_arith_is
                TAY
                TSC
                CLC
                ADC     #16
                TCS
                TYA
                BNE     _llong_arith_L84
                LDA     #82
                TAY
                TSC
                CLC
                ADC     #_llong_arith_run_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_llong_arith_L84
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0001
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
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #ua
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     #1
                STA     n
                LDA     ua+6
                STA     _fcc_q3
                LDA     ua+4
                STA     _fcc_q2
                LDA     ua+2
                STA     _fcc_long_hi
                LDA     ua
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     n
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
                STA     u
                TAY
                LDA     _fcc_long_hi
                STA     u+2
                LDA     _fcc_q2
                STA     u+4
                LDA     _fcc_q3
                STA     u+6
                TYA
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
                LDA     u+6
                STA     _fcc_q3
                LDA     u+4
                STA     _fcc_q2
                LDA     u+2
                STA     _fcc_long_hi
                LDA     u
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                FGX2_FARCALL _llong_arith_uis
                TAY
                TSC
                CLC
                ADC     #16
                TCS
                TYA
                BNE     _llong_arith_L85
                LDA     #83
                TAY
                TSC
                CLC
                ADC     #_llong_arith_run_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_llong_arith_L85
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0001
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
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #a
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     #15
                STA     n
                LDA     a+6
                STA     _fcc_q3
                LDA     a+4
                STA     _fcc_q2
                LDA     a+2
                STA     _fcc_long_hi
                LDA     a
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     n
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
                STA     r
                TAY
                LDA     _fcc_long_hi
                STA     r+2
                LDA     _fcc_q2
                STA     r+4
                LDA     _fcc_q3
                STA     r+6
                TYA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$8000
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0000
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     r+6
                STA     _fcc_q3
                LDA     r+4
                STA     _fcc_q2
                LDA     r+2
                STA     _fcc_long_hi
                LDA     r
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                FGX2_FARCALL _llong_arith_is
                TAY
                TSC
                CLC
                ADC     #16
                TCS
                TYA
                BNE     _llong_arith_L86
                LDA     #84
                TAY
                TSC
                CLC
                ADC     #_llong_arith_run_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_llong_arith_L86
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0001
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
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #a
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     #15
                STA     n
                LDA     a+6
                STA     _fcc_q3
                LDA     a+4
                STA     _fcc_q2
                LDA     a+2
                STA     _fcc_long_hi
                LDA     a
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     n
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
                FGX2_FARCALL _fcc_ll_shr
                STA     r
                TAY
                LDA     _fcc_long_hi
                STA     r+2
                LDA     _fcc_q2
                STA     r+4
                LDA     _fcc_q3
                STA     r+6
                TYA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0000
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$FFFF
                STA     _fcc_long_hi
                LDA     #$0000
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     r+6
                STA     _fcc_q3
                LDA     r+4
                STA     _fcc_q2
                LDA     r+2
                STA     _fcc_long_hi
                LDA     r
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                FGX2_FARCALL _llong_arith_is
                TAY
                TSC
                CLC
                ADC     #16
                TCS
                TYA
                BNE     _llong_arith_L87
                LDA     #85
                TAY
                TSC
                CLC
                ADC     #_llong_arith_run_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_llong_arith_L87
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0001
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
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #ua
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     #15
                STA     n
                LDA     ua+6
                STA     _fcc_q3
                LDA     ua+4
                STA     _fcc_q2
                LDA     ua+2
                STA     _fcc_long_hi
                LDA     ua
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     n
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
                STA     u
                TAY
                LDA     _fcc_long_hi
                STA     u+2
                LDA     _fcc_q2
                STA     u+4
                LDA     _fcc_q3
                STA     u+6
                TYA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0000
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
                LDA     u+6
                STA     _fcc_q3
                LDA     u+4
                STA     _fcc_q2
                LDA     u+2
                STA     _fcc_long_hi
                LDA     u
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                FGX2_FARCALL _llong_arith_uis
                TAY
                TSC
                CLC
                ADC     #16
                TCS
                TYA
                BNE     _llong_arith_L88
                LDA     #86
                TAY
                TSC
                CLC
                ADC     #_llong_arith_run_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_llong_arith_L88
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0001
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
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #a
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     #16
                STA     n
                LDA     a+6
                STA     _fcc_q3
                LDA     a+4
                STA     _fcc_q2
                LDA     a+2
                STA     _fcc_long_hi
                LDA     a
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     n
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
                STA     r
                TAY
                LDA     _fcc_long_hi
                STA     r+2
                LDA     _fcc_q2
                STA     r+4
                LDA     _fcc_q3
                STA     r+6
                TYA
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
                LDA     #$0000
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     r+6
                STA     _fcc_q3
                LDA     r+4
                STA     _fcc_q2
                LDA     r+2
                STA     _fcc_long_hi
                LDA     r
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                FGX2_FARCALL _llong_arith_is
                TAY
                TSC
                CLC
                ADC     #16
                TCS
                TYA
                BNE     _llong_arith_L89
                LDA     #87
                TAY
                TSC
                CLC
                ADC     #_llong_arith_run_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_llong_arith_L89
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0001
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
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #a
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     #16
                STA     n
                LDA     a+6
                STA     _fcc_q3
                LDA     a+4
                STA     _fcc_q2
                LDA     a+2
                STA     _fcc_long_hi
                LDA     a
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     n
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
                FGX2_FARCALL _fcc_ll_shr
                STA     r
                TAY
                LDA     _fcc_long_hi
                STA     r+2
                LDA     _fcc_q2
                STA     r+4
                LDA     _fcc_q3
                STA     r+6
                TYA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0000
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$FFFF
                STA     _fcc_long_hi
                LDA     #$8000
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     r+6
                STA     _fcc_q3
                LDA     r+4
                STA     _fcc_q2
                LDA     r+2
                STA     _fcc_long_hi
                LDA     r
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                FGX2_FARCALL _llong_arith_is
                TAY
                TSC
                CLC
                ADC     #16
                TCS
                TYA
                BNE     _llong_arith_L90
                LDA     #88
                TAY
                TSC
                CLC
                ADC     #_llong_arith_run_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_llong_arith_L90
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0001
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
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #ua
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     #16
                STA     n
                LDA     ua+6
                STA     _fcc_q3
                LDA     ua+4
                STA     _fcc_q2
                LDA     ua+2
                STA     _fcc_long_hi
                LDA     ua
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     n
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
                STA     u
                TAY
                LDA     _fcc_long_hi
                STA     u+2
                LDA     _fcc_q2
                STA     u+4
                LDA     _fcc_q3
                STA     u+6
                TYA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0000
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$8000
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     u+6
                STA     _fcc_q3
                LDA     u+4
                STA     _fcc_q2
                LDA     u+2
                STA     _fcc_long_hi
                LDA     u
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                FGX2_FARCALL _llong_arith_uis
                TAY
                TSC
                CLC
                ADC     #16
                TCS
                TYA
                BNE     _llong_arith_L91
                LDA     #89
                TAY
                TSC
                CLC
                ADC     #_llong_arith_run_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_llong_arith_L91
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0001
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
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #a
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     #17
                STA     n
                LDA     a+6
                STA     _fcc_q3
                LDA     a+4
                STA     _fcc_q2
                LDA     a+2
                STA     _fcc_long_hi
                LDA     a
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     n
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
                STA     r
                TAY
                LDA     _fcc_long_hi
                STA     r+2
                LDA     _fcc_q2
                STA     r+4
                LDA     _fcc_q3
                STA     r+6
                TYA
                LDA     #$0002
                STA     _fcc_long_hi
                LDA     #$0000
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0000
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     r+6
                STA     _fcc_q3
                LDA     r+4
                STA     _fcc_q2
                LDA     r+2
                STA     _fcc_long_hi
                LDA     r
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                FGX2_FARCALL _llong_arith_is
                TAY
                TSC
                CLC
                ADC     #16
                TCS
                TYA
                BNE     _llong_arith_L92
                LDA     #90
                TAY
                TSC
                CLC
                ADC     #_llong_arith_run_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_llong_arith_L92
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0001
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
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #a
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     #17
                STA     n
                LDA     a+6
                STA     _fcc_q3
                LDA     a+4
                STA     _fcc_q2
                LDA     a+2
                STA     _fcc_long_hi
                LDA     a
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     n
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
                FGX2_FARCALL _fcc_ll_shr
                STA     r
                TAY
                LDA     _fcc_long_hi
                STA     r+2
                LDA     _fcc_q2
                STA     r+4
                LDA     _fcc_q3
                STA     r+6
                TYA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0000
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$FFFF
                STA     _fcc_long_hi
                LDA     #$C000
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     r+6
                STA     _fcc_q3
                LDA     r+4
                STA     _fcc_q2
                LDA     r+2
                STA     _fcc_long_hi
                LDA     r
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                FGX2_FARCALL _llong_arith_is
                TAY
                TSC
                CLC
                ADC     #16
                TCS
                TYA
                BNE     _llong_arith_L93
                LDA     #91
                TAY
                TSC
                CLC
                ADC     #_llong_arith_run_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_llong_arith_L93
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0001
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
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #ua
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     #17
                STA     n
                LDA     ua+6
                STA     _fcc_q3
                LDA     ua+4
                STA     _fcc_q2
                LDA     ua+2
                STA     _fcc_long_hi
                LDA     ua
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     n
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
                STA     u
                TAY
                LDA     _fcc_long_hi
                STA     u+2
                LDA     _fcc_q2
                STA     u+4
                LDA     _fcc_q3
                STA     u+6
                TYA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0000
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$4000
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     u+6
                STA     _fcc_q3
                LDA     u+4
                STA     _fcc_q2
                LDA     u+2
                STA     _fcc_long_hi
                LDA     u
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                FGX2_FARCALL _llong_arith_uis
                TAY
                TSC
                CLC
                ADC     #16
                TCS
                TYA
                BNE     _llong_arith_L94
                LDA     #92
                TAY
                TSC
                CLC
                ADC     #_llong_arith_run_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_llong_arith_L94
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0001
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
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #a
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     #31
                STA     n
                LDA     a+6
                STA     _fcc_q3
                LDA     a+4
                STA     _fcc_q2
                LDA     a+2
                STA     _fcc_long_hi
                LDA     a
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     n
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
                STA     r
                TAY
                LDA     _fcc_long_hi
                STA     r+2
                LDA     _fcc_q2
                STA     r+4
                LDA     _fcc_q3
                STA     r+6
                TYA
                LDA     #$8000
                STA     _fcc_long_hi
                LDA     #$0000
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0000
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     r+6
                STA     _fcc_q3
                LDA     r+4
                STA     _fcc_q2
                LDA     r+2
                STA     _fcc_long_hi
                LDA     r
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                FGX2_FARCALL _llong_arith_is
                TAY
                TSC
                CLC
                ADC     #16
                TCS
                TYA
                BNE     _llong_arith_L95
                LDA     #93
                TAY
                TSC
                CLC
                ADC     #_llong_arith_run_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_llong_arith_L95
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0001
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
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #a
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     #31
                STA     n
                LDA     a+6
                STA     _fcc_q3
                LDA     a+4
                STA     _fcc_q2
                LDA     a+2
                STA     _fcc_long_hi
                LDA     a
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     n
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
                FGX2_FARCALL _fcc_ll_shr
                STA     r
                TAY
                LDA     _fcc_long_hi
                STA     r+2
                LDA     _fcc_q2
                STA     r+4
                LDA     _fcc_q3
                STA     r+6
                TYA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0000
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
                LDA     r+6
                STA     _fcc_q3
                LDA     r+4
                STA     _fcc_q2
                LDA     r+2
                STA     _fcc_long_hi
                LDA     r
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                FGX2_FARCALL _llong_arith_is
                TAY
                TSC
                CLC
                ADC     #16
                TCS
                TYA
                BNE     _llong_arith_L96
                LDA     #94
                TAY
                TSC
                CLC
                ADC     #_llong_arith_run_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_llong_arith_L96
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0001
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
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #ua
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     #31
                STA     n
                LDA     ua+6
                STA     _fcc_q3
                LDA     ua+4
                STA     _fcc_q2
                LDA     ua+2
                STA     _fcc_long_hi
                LDA     ua
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     n
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
                STA     u
                TAY
                LDA     _fcc_long_hi
                STA     u+2
                LDA     _fcc_q2
                STA     u+4
                LDA     _fcc_q3
                STA     u+6
                TYA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0000
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0001
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     u+6
                STA     _fcc_q3
                LDA     u+4
                STA     _fcc_q2
                LDA     u+2
                STA     _fcc_long_hi
                LDA     u
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                FGX2_FARCALL _llong_arith_uis
                TAY
                TSC
                CLC
                ADC     #16
                TCS
                TYA
                BNE     _llong_arith_L97
                LDA     #95
                TAY
                TSC
                CLC
                ADC     #_llong_arith_run_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_llong_arith_L97
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0001
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
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #a
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     #32
                STA     n
                LDA     a+6
                STA     _fcc_q3
                LDA     a+4
                STA     _fcc_q2
                LDA     a+2
                STA     _fcc_long_hi
                LDA     a
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     n
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
                STA     r
                TAY
                LDA     _fcc_long_hi
                STA     r+2
                LDA     _fcc_q2
                STA     r+4
                LDA     _fcc_q3
                STA     r+6
                TYA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0000
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0001
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     r+6
                STA     _fcc_q3
                LDA     r+4
                STA     _fcc_q2
                LDA     r+2
                STA     _fcc_long_hi
                LDA     r
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                FGX2_FARCALL _llong_arith_is
                TAY
                TSC
                CLC
                ADC     #16
                TCS
                TYA
                BNE     _llong_arith_L98
                LDA     #96
                TAY
                TSC
                CLC
                ADC     #_llong_arith_run_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_llong_arith_L98
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0001
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
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #a
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     #32
                STA     n
                LDA     a+6
                STA     _fcc_q3
                LDA     a+4
                STA     _fcc_q2
                LDA     a+2
                STA     _fcc_long_hi
                LDA     a
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     n
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
                FGX2_FARCALL _fcc_ll_shr
                STA     r
                TAY
                LDA     _fcc_long_hi
                STA     r+2
                LDA     _fcc_q2
                STA     r+4
                LDA     _fcc_q3
                STA     r+6
                TYA
                LDA     #$8000
                STA     _fcc_long_hi
                LDA     #$0000
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
                LDA     r+6
                STA     _fcc_q3
                LDA     r+4
                STA     _fcc_q2
                LDA     r+2
                STA     _fcc_long_hi
                LDA     r
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                FGX2_FARCALL _llong_arith_is
                TAY
                TSC
                CLC
                ADC     #16
                TCS
                TYA
                BNE     _llong_arith_L99
                LDA     #97
                TAY
                TSC
                CLC
                ADC     #_llong_arith_run_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_llong_arith_L99
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0001
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
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #ua
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     #32
                STA     n
                LDA     ua+6
                STA     _fcc_q3
                LDA     ua+4
                STA     _fcc_q2
                LDA     ua+2
                STA     _fcc_long_hi
                LDA     ua
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     n
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
                STA     u
                TAY
                LDA     _fcc_long_hi
                STA     u+2
                LDA     _fcc_q2
                STA     u+4
                LDA     _fcc_q3
                STA     u+6
                TYA
                LDA     #$8000
                STA     _fcc_long_hi
                LDA     #$0000
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0000
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     u+6
                STA     _fcc_q3
                LDA     u+4
                STA     _fcc_q2
                LDA     u+2
                STA     _fcc_long_hi
                LDA     u
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                FGX2_FARCALL _llong_arith_uis
                TAY
                TSC
                CLC
                ADC     #16
                TCS
                TYA
                BNE     _llong_arith_L100
                LDA     #98
                TAY
                TSC
                CLC
                ADC     #_llong_arith_run_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_llong_arith_L100
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0001
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
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #a
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     #33
                STA     n
                LDA     a+6
                STA     _fcc_q3
                LDA     a+4
                STA     _fcc_q2
                LDA     a+2
                STA     _fcc_long_hi
                LDA     a
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     n
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
                STA     r
                TAY
                LDA     _fcc_long_hi
                STA     r+2
                LDA     _fcc_q2
                STA     r+4
                LDA     _fcc_q3
                STA     r+6
                TYA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0000
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0002
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     r+6
                STA     _fcc_q3
                LDA     r+4
                STA     _fcc_q2
                LDA     r+2
                STA     _fcc_long_hi
                LDA     r
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                FGX2_FARCALL _llong_arith_is
                TAY
                TSC
                CLC
                ADC     #16
                TCS
                TYA
                BNE     _llong_arith_L101
                LDA     #99
                TAY
                TSC
                CLC
                ADC     #_llong_arith_run_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_llong_arith_L101
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0001
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
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #a
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     #33
                STA     n
                LDA     a+6
                STA     _fcc_q3
                LDA     a+4
                STA     _fcc_q2
                LDA     a+2
                STA     _fcc_long_hi
                LDA     a
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     n
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
                FGX2_FARCALL _fcc_ll_shr
                STA     r
                TAY
                LDA     _fcc_long_hi
                STA     r+2
                LDA     _fcc_q2
                STA     r+4
                LDA     _fcc_q3
                STA     r+6
                TYA
                LDA     #$C000
                STA     _fcc_long_hi
                LDA     #$0000
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
                LDA     r+6
                STA     _fcc_q3
                LDA     r+4
                STA     _fcc_q2
                LDA     r+2
                STA     _fcc_long_hi
                LDA     r
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                FGX2_FARCALL _llong_arith_is
                TAY
                TSC
                CLC
                ADC     #16
                TCS
                TYA
                BNE     _llong_arith_L102
                LDA     #100
                TAY
                TSC
                CLC
                ADC     #_llong_arith_run_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_llong_arith_L102
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0001
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
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #ua
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     #33
                STA     n
                LDA     ua+6
                STA     _fcc_q3
                LDA     ua+4
                STA     _fcc_q2
                LDA     ua+2
                STA     _fcc_long_hi
                LDA     ua
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     n
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
                STA     u
                TAY
                LDA     _fcc_long_hi
                STA     u+2
                LDA     _fcc_q2
                STA     u+4
                LDA     _fcc_q3
                STA     u+6
                TYA
                LDA     #$4000
                STA     _fcc_long_hi
                LDA     #$0000
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0000
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     u+6
                STA     _fcc_q3
                LDA     u+4
                STA     _fcc_q2
                LDA     u+2
                STA     _fcc_long_hi
                LDA     u
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                FGX2_FARCALL _llong_arith_uis
                TAY
                TSC
                CLC
                ADC     #16
                TCS
                TYA
                BNE     _llong_arith_L103
                LDA     #101
                TAY
                TSC
                CLC
                ADC     #_llong_arith_run_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_llong_arith_L103
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0001
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
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #a
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     #47
                STA     n
                LDA     a+6
                STA     _fcc_q3
                LDA     a+4
                STA     _fcc_q2
                LDA     a+2
                STA     _fcc_long_hi
                LDA     a
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     n
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
                STA     r
                TAY
                LDA     _fcc_long_hi
                STA     r+2
                LDA     _fcc_q2
                STA     r+4
                LDA     _fcc_q3
                STA     r+6
                TYA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0000
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$8000
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     r+6
                STA     _fcc_q3
                LDA     r+4
                STA     _fcc_q2
                LDA     r+2
                STA     _fcc_long_hi
                LDA     r
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                FGX2_FARCALL _llong_arith_is
                TAY
                TSC
                CLC
                ADC     #16
                TCS
                TYA
                BNE     _llong_arith_L104
                LDA     #102
                TAY
                TSC
                CLC
                ADC     #_llong_arith_run_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_llong_arith_L104
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0001
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
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #a
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     #47
                STA     n
                LDA     a+6
                STA     _fcc_q3
                LDA     a+4
                STA     _fcc_q2
                LDA     a+2
                STA     _fcc_long_hi
                LDA     a
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     n
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
                FGX2_FARCALL _fcc_ll_shr
                STA     r
                TAY
                LDA     _fcc_long_hi
                STA     r+2
                LDA     _fcc_q2
                STA     r+4
                LDA     _fcc_q3
                STA     r+6
                TYA
                LDA     #$FFFF
                STA     _fcc_long_hi
                LDA     #$0000
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
                LDA     r+6
                STA     _fcc_q3
                LDA     r+4
                STA     _fcc_q2
                LDA     r+2
                STA     _fcc_long_hi
                LDA     r
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                FGX2_FARCALL _llong_arith_is
                TAY
                TSC
                CLC
                ADC     #16
                TCS
                TYA
                BNE     _llong_arith_L105
                LDA     #103
                TAY
                TSC
                CLC
                ADC     #_llong_arith_run_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_llong_arith_L105
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0001
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
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #ua
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     #47
                STA     n
                LDA     ua+6
                STA     _fcc_q3
                LDA     ua+4
                STA     _fcc_q2
                LDA     ua+2
                STA     _fcc_long_hi
                LDA     ua
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     n
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
                STA     u
                TAY
                LDA     _fcc_long_hi
                STA     u+2
                LDA     _fcc_q2
                STA     u+4
                LDA     _fcc_q3
                STA     u+6
                TYA
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
                LDA     #$0000
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     u+6
                STA     _fcc_q3
                LDA     u+4
                STA     _fcc_q2
                LDA     u+2
                STA     _fcc_long_hi
                LDA     u
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                FGX2_FARCALL _llong_arith_uis
                TAY
                TSC
                CLC
                ADC     #16
                TCS
                TYA
                BNE     _llong_arith_L106
                LDA     #104
                TAY
                TSC
                CLC
                ADC     #_llong_arith_run_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_llong_arith_L106
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0001
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
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #a
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     #48
                STA     n
                LDA     a+6
                STA     _fcc_q3
                LDA     a+4
                STA     _fcc_q2
                LDA     a+2
                STA     _fcc_long_hi
                LDA     a
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     n
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
                STA     r
                TAY
                LDA     _fcc_long_hi
                STA     r+2
                LDA     _fcc_q2
                STA     r+4
                LDA     _fcc_q3
                STA     r+6
                TYA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0000
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
                LDA     r+6
                STA     _fcc_q3
                LDA     r+4
                STA     _fcc_q2
                LDA     r+2
                STA     _fcc_long_hi
                LDA     r
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                FGX2_FARCALL _llong_arith_is
                TAY
                TSC
                CLC
                ADC     #16
                TCS
                TYA
                BNE     _llong_arith_L107
                LDA     #105
                TAY
                TSC
                CLC
                ADC     #_llong_arith_run_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_llong_arith_L107
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0001
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
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #a
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     #48
                STA     n
                LDA     a+6
                STA     _fcc_q3
                LDA     a+4
                STA     _fcc_q2
                LDA     a+2
                STA     _fcc_long_hi
                LDA     a
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     n
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
                FGX2_FARCALL _fcc_ll_shr
                STA     r
                TAY
                LDA     _fcc_long_hi
                STA     r+2
                LDA     _fcc_q2
                STA     r+4
                LDA     _fcc_q3
                STA     r+6
                TYA
                LDA     #$FFFF
                STA     _fcc_long_hi
                LDA     #$8000
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
                LDA     r+6
                STA     _fcc_q3
                LDA     r+4
                STA     _fcc_q2
                LDA     r+2
                STA     _fcc_long_hi
                LDA     r
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                FGX2_FARCALL _llong_arith_is
                TAY
                TSC
                CLC
                ADC     #16
                TCS
                TYA
                BNE     _llong_arith_L108
                LDA     #106
                TAY
                TSC
                CLC
                ADC     #_llong_arith_run_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_llong_arith_L108
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0001
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
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #ua
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     #48
                STA     n
                LDA     ua+6
                STA     _fcc_q3
                LDA     ua+4
                STA     _fcc_q2
                LDA     ua+2
                STA     _fcc_long_hi
                LDA     ua
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     n
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
                STA     u
                TAY
                LDA     _fcc_long_hi
                STA     u+2
                LDA     _fcc_q2
                STA     u+4
                LDA     _fcc_q3
                STA     u+6
                TYA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$8000
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0000
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     u+6
                STA     _fcc_q3
                LDA     u+4
                STA     _fcc_q2
                LDA     u+2
                STA     _fcc_long_hi
                LDA     u
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                FGX2_FARCALL _llong_arith_uis
                TAY
                TSC
                CLC
                ADC     #16
                TCS
                TYA
                BNE     _llong_arith_L109
                LDA     #107
                TAY
                TSC
                CLC
                ADC     #_llong_arith_run_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_llong_arith_L109
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0001
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
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #a
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     #63
                STA     n
                LDA     a+6
                STA     _fcc_q3
                LDA     a+4
                STA     _fcc_q2
                LDA     a+2
                STA     _fcc_long_hi
                LDA     a
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     n
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
                STA     r
                TAY
                LDA     _fcc_long_hi
                STA     r+2
                LDA     _fcc_q2
                STA     r+4
                LDA     _fcc_q3
                STA     r+6
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
                LDA     r+6
                STA     _fcc_q3
                LDA     r+4
                STA     _fcc_q2
                LDA     r+2
                STA     _fcc_long_hi
                LDA     r
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                FGX2_FARCALL _llong_arith_is
                TAY
                TSC
                CLC
                ADC     #16
                TCS
                TYA
                BNE     _llong_arith_L110
                LDA     #108
                TAY
                TSC
                CLC
                ADC     #_llong_arith_run_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_llong_arith_L110
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0001
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
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #a
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     #63
                STA     n
                LDA     a+6
                STA     _fcc_q3
                LDA     a+4
                STA     _fcc_q2
                LDA     a+2
                STA     _fcc_long_hi
                LDA     a
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     n
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
                FGX2_FARCALL _fcc_ll_shr
                STA     r
                TAY
                LDA     _fcc_long_hi
                STA     r+2
                LDA     _fcc_q2
                STA     r+4
                LDA     _fcc_q3
                STA     r+6
                TYA
                LDA     #$FFFF
                STA     _fcc_long_hi
                LDA     #$FFFF
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
                LDA     r+6
                STA     _fcc_q3
                LDA     r+4
                STA     _fcc_q2
                LDA     r+2
                STA     _fcc_long_hi
                LDA     r
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                FGX2_FARCALL _llong_arith_is
                TAY
                TSC
                CLC
                ADC     #16
                TCS
                TYA
                BNE     _llong_arith_L111
                LDA     #109
                TAY
                TSC
                CLC
                ADC     #_llong_arith_run_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_llong_arith_L111
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0001
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
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #ua
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     #63
                STA     n
                LDA     ua+6
                STA     _fcc_q3
                LDA     ua+4
                STA     _fcc_q2
                LDA     ua+2
                STA     _fcc_long_hi
                LDA     ua
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     n
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
                STA     u
                TAY
                LDA     _fcc_long_hi
                STA     u+2
                LDA     _fcc_q2
                STA     u+4
                LDA     _fcc_q3
                STA     u+6
                TYA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0001
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0000
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     u+6
                STA     _fcc_q3
                LDA     u+4
                STA     _fcc_q2
                LDA     u+2
                STA     _fcc_long_hi
                LDA     u
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                FGX2_FARCALL _llong_arith_uis
                TAY
                TSC
                CLC
                ADC     #16
                TCS
                TYA
                BNE     _llong_arith_L112
                LDA     #110
                TAY
                TSC
                CLC
                ADC     #_llong_arith_run_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_llong_arith_L112
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0000
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0001
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #a
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     #$FFFF
                STA     _fcc_long_hi
                LDA     #$FFFF
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0000
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
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
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     a+6
                STA     _fcc_q3
                LDA     a+4
                STA     _fcc_q2
                LDA     a+2
                STA     _fcc_long_hi
                LDA     a
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     b+6
                STA     _fcc_q3
                LDA     b+4
                STA     _fcc_q2
                LDA     b+2
                STA     _fcc_long_hi
                LDA     b
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
                FGX2_FARCALL _fcc_ll_cmps
                BMI     *+7
                LDA     #0
                BRA     *+5
                LDA     #1
                STA     i
                BEQ     _llong_arith_L113
                LDA     #111
                TAY
                TSC
                CLC
                ADC     #_llong_arith_run_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_llong_arith_L113
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0000
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0001
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #ua
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     #$FFFF
                STA     _fcc_long_hi
                LDA     #$FFFF
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0000
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #ub
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     ua+6
                STA     _fcc_q3
                LDA     ua+4
                STA     _fcc_q2
                LDA     ua+2
                STA     _fcc_long_hi
                LDA     ua
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     ub+6
                STA     _fcc_q3
                LDA     ub+4
                STA     _fcc_q2
                LDA     ub+2
                STA     _fcc_long_hi
                LDA     ub
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
                STA     i
                BEQ     _llong_arith_L114
                LDA     #112
                TAY
                TSC
                CLC
                ADC     #_llong_arith_run_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_llong_arith_L114
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0000
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0001
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #a
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     #$FFFF
                STA     _fcc_long_hi
                LDA     #$FFFF
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0000
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
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
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     a+6
                STA     _fcc_q3
                LDA     a+4
                STA     _fcc_q2
                LDA     a+2
                STA     _fcc_long_hi
                LDA     a
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     b+6
                STA     _fcc_q3
                LDA     b+4
                STA     _fcc_q2
                LDA     b+2
                STA     _fcc_long_hi
                LDA     b
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
                FGX2_FARCALL _fcc_ll_cmps
                CMP     #1
                BEQ     *+7
                LDA     #0
                BRA     *+5
                LDA     #1
                STA     i
                TAX
                CMP     #1
                BEQ     _llong_arith_L115
                LDA     #113
                TAY
                TSC
                CLC
                ADC     #_llong_arith_run_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_llong_arith_L115
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0000
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0001
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #ua
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     #$FFFF
                STA     _fcc_long_hi
                LDA     #$FFFF
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0000
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #ub
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     ua+6
                STA     _fcc_q3
                LDA     ua+4
                STA     _fcc_q2
                LDA     ua+2
                STA     _fcc_long_hi
                LDA     ua
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     ub+6
                STA     _fcc_q3
                LDA     ub+4
                STA     _fcc_q2
                LDA     ub+2
                STA     _fcc_long_hi
                LDA     ub
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
                CMP     #1
                BEQ     *+7
                LDA     #0
                BRA     *+5
                LDA     #1
                STA     i
                TAX
                CMP     #1
                BEQ     _llong_arith_L116
                LDA     #114
                TAY
                TSC
                CLC
                ADC     #_llong_arith_run_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_llong_arith_L116
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0000
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0001
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #a
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     #$FFFF
                STA     _fcc_long_hi
                LDA     #$FFFF
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0000
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
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
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     a+6
                STA     _fcc_q3
                LDA     a+4
                STA     _fcc_q2
                LDA     a+2
                STA     _fcc_long_hi
                LDA     a
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     b+6
                STA     _fcc_q3
                LDA     b+4
                STA     _fcc_q2
                LDA     b+2
                STA     _fcc_long_hi
                LDA     b
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
                FGX2_FARCALL _fcc_ll_cmps
                CMP     #1
                BNE     *+7
                LDA     #0
                BRA     *+5
                LDA     #1
                STA     i
                BEQ     _llong_arith_L117
                LDA     #115
                TAY
                TSC
                CLC
                ADC     #_llong_arith_run_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_llong_arith_L117
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0000
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0001
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #ua
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     #$FFFF
                STA     _fcc_long_hi
                LDA     #$FFFF
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0000
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #ub
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     ua+6
                STA     _fcc_q3
                LDA     ua+4
                STA     _fcc_q2
                LDA     ua+2
                STA     _fcc_long_hi
                LDA     ua
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     ub+6
                STA     _fcc_q3
                LDA     ub+4
                STA     _fcc_q2
                LDA     ub+2
                STA     _fcc_long_hi
                LDA     ub
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
                CMP     #1
                BNE     *+7
                LDA     #0
                BRA     *+5
                LDA     #1
                STA     i
                BEQ     _llong_arith_L118
                LDA     #116
                TAY
                TSC
                CLC
                ADC     #_llong_arith_run_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_llong_arith_L118
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0000
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0001
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #a
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     #$FFFF
                STA     _fcc_long_hi
                LDA     #$FFFF
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0000
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
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
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     a+6
                STA     _fcc_q3
                LDA     a+4
                STA     _fcc_q2
                LDA     a+2
                STA     _fcc_long_hi
                LDA     a
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     b+6
                STA     _fcc_q3
                LDA     b+4
                STA     _fcc_q2
                LDA     b+2
                STA     _fcc_long_hi
                LDA     b
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
                FGX2_FARCALL _fcc_ll_cmps
                BPL     *+7
                LDA     #0
                BRA     *+5
                LDA     #1
                STA     i
                TAX
                CMP     #1
                BEQ     _llong_arith_L119
                LDA     #117
                TAY
                TSC
                CLC
                ADC     #_llong_arith_run_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_llong_arith_L119
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0000
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0001
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #ua
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     #$FFFF
                STA     _fcc_long_hi
                LDA     #$FFFF
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0000
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #ub
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     ua+6
                STA     _fcc_q3
                LDA     ua+4
                STA     _fcc_q2
                LDA     ua+2
                STA     _fcc_long_hi
                LDA     ua
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     ub+6
                STA     _fcc_q3
                LDA     ub+4
                STA     _fcc_q2
                LDA     ub+2
                STA     _fcc_long_hi
                LDA     ub
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
                STA     i
                TAX
                CMP     #1
                BEQ     _llong_arith_L120
                LDA     #118
                TAY
                TSC
                CLC
                ADC     #_llong_arith_run_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_llong_arith_L120
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0000
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0001
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #a
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     #$FFFF
                STA     _fcc_long_hi
                LDA     #$FFFF
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0000
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
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
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     a+6
                STA     _fcc_q3
                LDA     a+4
                STA     _fcc_q2
                LDA     a+2
                STA     _fcc_long_hi
                LDA     a
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     b+6
                STA     _fcc_q3
                LDA     b+4
                STA     _fcc_q2
                LDA     b+2
                STA     _fcc_long_hi
                LDA     b
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
                FGX2_FARCALL _fcc_ll_cmps
                BEQ     *+7
                LDA     #0
                BRA     *+5
                LDA     #1
                STA     i
                BEQ     _llong_arith_L121
                LDA     #119
                TAY
                TSC
                CLC
                ADC     #_llong_arith_run_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_llong_arith_L121
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0000
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0001
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #ua
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     #$FFFF
                STA     _fcc_long_hi
                LDA     #$FFFF
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0000
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #ub
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     ua+6
                STA     _fcc_q3
                LDA     ua+4
                STA     _fcc_q2
                LDA     ua+2
                STA     _fcc_long_hi
                LDA     ua
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     ub+6
                STA     _fcc_q3
                LDA     ub+4
                STA     _fcc_q2
                LDA     ub+2
                STA     _fcc_long_hi
                LDA     ub
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
                STA     i
                BEQ     _llong_arith_L122
                LDA     #120
                TAY
                TSC
                CLC
                ADC     #_llong_arith_run_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_llong_arith_L122
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0000
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0001
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #a
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     #$FFFF
                STA     _fcc_long_hi
                LDA     #$FFFF
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0000
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
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
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     a+6
                STA     _fcc_q3
                LDA     a+4
                STA     _fcc_q2
                LDA     a+2
                STA     _fcc_long_hi
                LDA     a
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     b+6
                STA     _fcc_q3
                LDA     b+4
                STA     _fcc_q2
                LDA     b+2
                STA     _fcc_long_hi
                LDA     b
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
                FGX2_FARCALL _fcc_ll_cmps
                BNE     *+7
                LDA     #0
                BRA     *+5
                LDA     #1
                STA     i
                TAX
                CMP     #1
                BEQ     _llong_arith_L123
                LDA     #121
                TAY
                TSC
                CLC
                ADC     #_llong_arith_run_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_llong_arith_L123
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0000
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0001
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #ua
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     #$FFFF
                STA     _fcc_long_hi
                LDA     #$FFFF
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0000
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #ub
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     ua+6
                STA     _fcc_q3
                LDA     ua+4
                STA     _fcc_q2
                LDA     ua+2
                STA     _fcc_long_hi
                LDA     ua
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     ub+6
                STA     _fcc_q3
                LDA     ub+4
                STA     _fcc_q2
                LDA     ub+2
                STA     _fcc_long_hi
                LDA     ub
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
                STA     i
                TAX
                CMP     #1
                BEQ     _llong_arith_L124
                LDA     #122
                TAY
                TSC
                CLC
                ADC     #_llong_arith_run_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_llong_arith_L124
                LDA     #$FFFF
                STA     _fcc_long_hi
                LDA     #$FFFF
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
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #a
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0001
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0000
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
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
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     a+6
                STA     _fcc_q3
                LDA     a+4
                STA     _fcc_q2
                LDA     a+2
                STA     _fcc_long_hi
                LDA     a
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     b+6
                STA     _fcc_q3
                LDA     b+4
                STA     _fcc_q2
                LDA     b+2
                STA     _fcc_long_hi
                LDA     b
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
                FGX2_FARCALL _fcc_ll_cmps
                BMI     *+7
                LDA     #0
                BRA     *+5
                LDA     #1
                STA     i
                TAX
                CMP     #1
                BEQ     _llong_arith_L125
                LDA     #123
                TAY
                TSC
                CLC
                ADC     #_llong_arith_run_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_llong_arith_L125
                LDA     #$FFFF
                STA     _fcc_long_hi
                LDA     #$FFFF
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
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #ua
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0001
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0000
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #ub
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     ua+6
                STA     _fcc_q3
                LDA     ua+4
                STA     _fcc_q2
                LDA     ua+2
                STA     _fcc_long_hi
                LDA     ua
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     ub+6
                STA     _fcc_q3
                LDA     ub+4
                STA     _fcc_q2
                LDA     ub+2
                STA     _fcc_long_hi
                LDA     ub
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
                STA     i
                BEQ     _llong_arith_L126
                LDA     #124
                TAY
                TSC
                CLC
                ADC     #_llong_arith_run_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_llong_arith_L126
                LDA     #$FFFF
                STA     _fcc_long_hi
                LDA     #$FFFF
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
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #a
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0001
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0000
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
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
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     a+6
                STA     _fcc_q3
                LDA     a+4
                STA     _fcc_q2
                LDA     a+2
                STA     _fcc_long_hi
                LDA     a
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     b+6
                STA     _fcc_q3
                LDA     b+4
                STA     _fcc_q2
                LDA     b+2
                STA     _fcc_long_hi
                LDA     b
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
                FGX2_FARCALL _fcc_ll_cmps
                CMP     #1
                BEQ     *+7
                LDA     #0
                BRA     *+5
                LDA     #1
                STA     i
                BEQ     _llong_arith_L127
                LDA     #125
                TAY
                TSC
                CLC
                ADC     #_llong_arith_run_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_llong_arith_L127
                LDA     #$FFFF
                STA     _fcc_long_hi
                LDA     #$FFFF
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
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #ua
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0001
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0000
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #ub
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     ua+6
                STA     _fcc_q3
                LDA     ua+4
                STA     _fcc_q2
                LDA     ua+2
                STA     _fcc_long_hi
                LDA     ua
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     ub+6
                STA     _fcc_q3
                LDA     ub+4
                STA     _fcc_q2
                LDA     ub+2
                STA     _fcc_long_hi
                LDA     ub
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
                CMP     #1
                BEQ     *+7
                LDA     #0
                BRA     *+5
                LDA     #1
                STA     i
                TAX
                CMP     #1
                BEQ     _llong_arith_L128
                LDA     #126
                TAY
                TSC
                CLC
                ADC     #_llong_arith_run_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_llong_arith_L128
                LDA     #$FFFF
                STA     _fcc_long_hi
                LDA     #$FFFF
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
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #a
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0001
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0000
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
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
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     a+6
                STA     _fcc_q3
                LDA     a+4
                STA     _fcc_q2
                LDA     a+2
                STA     _fcc_long_hi
                LDA     a
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     b+6
                STA     _fcc_q3
                LDA     b+4
                STA     _fcc_q2
                LDA     b+2
                STA     _fcc_long_hi
                LDA     b
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
                FGX2_FARCALL _fcc_ll_cmps
                CMP     #1
                BNE     *+7
                LDA     #0
                BRA     *+5
                LDA     #1
                STA     i
                TAX
                CMP     #1
                BEQ     _llong_arith_L129
                LDA     #127
                TAY
                TSC
                CLC
                ADC     #_llong_arith_run_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_llong_arith_L129
                LDA     #$FFFF
                STA     _fcc_long_hi
                LDA     #$FFFF
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
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #ua
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0001
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0000
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #ub
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     ua+6
                STA     _fcc_q3
                LDA     ua+4
                STA     _fcc_q2
                LDA     ua+2
                STA     _fcc_long_hi
                LDA     ua
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     ub+6
                STA     _fcc_q3
                LDA     ub+4
                STA     _fcc_q2
                LDA     ub+2
                STA     _fcc_long_hi
                LDA     ub
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
                CMP     #1
                BNE     *+7
                LDA     #0
                BRA     *+5
                LDA     #1
                STA     i
                BEQ     _llong_arith_L130
                LDA     #128
                TAY
                TSC
                CLC
                ADC     #_llong_arith_run_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_llong_arith_L130
                LDA     #$FFFF
                STA     _fcc_long_hi
                LDA     #$FFFF
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
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #a
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0001
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0000
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
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
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     a+6
                STA     _fcc_q3
                LDA     a+4
                STA     _fcc_q2
                LDA     a+2
                STA     _fcc_long_hi
                LDA     a
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     b+6
                STA     _fcc_q3
                LDA     b+4
                STA     _fcc_q2
                LDA     b+2
                STA     _fcc_long_hi
                LDA     b
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
                FGX2_FARCALL _fcc_ll_cmps
                BPL     *+7
                LDA     #0
                BRA     *+5
                LDA     #1
                STA     i
                BEQ     _llong_arith_L131
                LDA     #129
                TAY
                TSC
                CLC
                ADC     #_llong_arith_run_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_llong_arith_L131
                LDA     #$FFFF
                STA     _fcc_long_hi
                LDA     #$FFFF
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
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #ua
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0001
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0000
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #ub
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     ua+6
                STA     _fcc_q3
                LDA     ua+4
                STA     _fcc_q2
                LDA     ua+2
                STA     _fcc_long_hi
                LDA     ua
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     ub+6
                STA     _fcc_q3
                LDA     ub+4
                STA     _fcc_q2
                LDA     ub+2
                STA     _fcc_long_hi
                LDA     ub
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
                STA     i
                TAX
                CMP     #1
                BEQ     _llong_arith_L132
                LDA     #130
                TAY
                TSC
                CLC
                ADC     #_llong_arith_run_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_llong_arith_L132
                LDA     #$FFFF
                STA     _fcc_long_hi
                LDA     #$FFFF
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
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #a
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0001
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0000
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
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
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     a+6
                STA     _fcc_q3
                LDA     a+4
                STA     _fcc_q2
                LDA     a+2
                STA     _fcc_long_hi
                LDA     a
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     b+6
                STA     _fcc_q3
                LDA     b+4
                STA     _fcc_q2
                LDA     b+2
                STA     _fcc_long_hi
                LDA     b
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
                FGX2_FARCALL _fcc_ll_cmps
                BEQ     *+7
                LDA     #0
                BRA     *+5
                LDA     #1
                STA     i
                BEQ     _llong_arith_L133
                LDA     #131
                TAY
                TSC
                CLC
                ADC     #_llong_arith_run_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_llong_arith_L133
                LDA     #$FFFF
                STA     _fcc_long_hi
                LDA     #$FFFF
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
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #ua
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0001
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0000
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #ub
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     ua+6
                STA     _fcc_q3
                LDA     ua+4
                STA     _fcc_q2
                LDA     ua+2
                STA     _fcc_long_hi
                LDA     ua
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     ub+6
                STA     _fcc_q3
                LDA     ub+4
                STA     _fcc_q2
                LDA     ub+2
                STA     _fcc_long_hi
                LDA     ub
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
                STA     i
                BEQ     _llong_arith_L134
                LDA     #132
                TAY
                TSC
                CLC
                ADC     #_llong_arith_run_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_llong_arith_L134
                LDA     #$FFFF
                STA     _fcc_long_hi
                LDA     #$FFFF
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
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #a
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0001
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0000
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
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
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     a+6
                STA     _fcc_q3
                LDA     a+4
                STA     _fcc_q2
                LDA     a+2
                STA     _fcc_long_hi
                LDA     a
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     b+6
                STA     _fcc_q3
                LDA     b+4
                STA     _fcc_q2
                LDA     b+2
                STA     _fcc_long_hi
                LDA     b
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
                FGX2_FARCALL _fcc_ll_cmps
                BNE     *+7
                LDA     #0
                BRA     *+5
                LDA     #1
                STA     i
                TAX
                CMP     #1
                BEQ     _llong_arith_L135
                LDA     #133
                TAY
                TSC
                CLC
                ADC     #_llong_arith_run_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_llong_arith_L135
                LDA     #$FFFF
                STA     _fcc_long_hi
                LDA     #$FFFF
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
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #ua
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0001
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0000
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #ub
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     ua+6
                STA     _fcc_q3
                LDA     ua+4
                STA     _fcc_q2
                LDA     ua+2
                STA     _fcc_long_hi
                LDA     ua
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     ub+6
                STA     _fcc_q3
                LDA     ub+4
                STA     _fcc_q2
                LDA     ub+2
                STA     _fcc_long_hi
                LDA     ub
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
                STA     i
                TAX
                CMP     #1
                BEQ     _llong_arith_L136
                LDA     #134
                TAY
                TSC
                CLC
                ADC     #_llong_arith_run_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_llong_arith_L136
                LDA     #$89AB
                STA     _fcc_long_hi
                LDA     #$CDEF
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0123
                STA     _fcc_long_hi
                LDA     #$4567
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #a
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     #$89AB
                STA     _fcc_long_hi
                LDA     #$CDEF
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0123
                STA     _fcc_long_hi
                LDA     #$4567
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
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
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     a+6
                STA     _fcc_q3
                LDA     a+4
                STA     _fcc_q2
                LDA     a+2
                STA     _fcc_long_hi
                LDA     a
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     b+6
                STA     _fcc_q3
                LDA     b+4
                STA     _fcc_q2
                LDA     b+2
                STA     _fcc_long_hi
                LDA     b
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
                FGX2_FARCALL _fcc_ll_cmps
                BMI     *+7
                LDA     #0
                BRA     *+5
                LDA     #1
                STA     i
                BEQ     _llong_arith_L137
                LDA     #135
                TAY
                TSC
                CLC
                ADC     #_llong_arith_run_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_llong_arith_L137
                LDA     #$89AB
                STA     _fcc_long_hi
                LDA     #$CDEF
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0123
                STA     _fcc_long_hi
                LDA     #$4567
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #ua
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     #$89AB
                STA     _fcc_long_hi
                LDA     #$CDEF
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0123
                STA     _fcc_long_hi
                LDA     #$4567
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #ub
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     ua+6
                STA     _fcc_q3
                LDA     ua+4
                STA     _fcc_q2
                LDA     ua+2
                STA     _fcc_long_hi
                LDA     ua
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     ub+6
                STA     _fcc_q3
                LDA     ub+4
                STA     _fcc_q2
                LDA     ub+2
                STA     _fcc_long_hi
                LDA     ub
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
                STA     i
                BEQ     _llong_arith_L138
                LDA     #136
                TAY
                TSC
                CLC
                ADC     #_llong_arith_run_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_llong_arith_L138
                LDA     #$89AB
                STA     _fcc_long_hi
                LDA     #$CDEF
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0123
                STA     _fcc_long_hi
                LDA     #$4567
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #a
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     #$89AB
                STA     _fcc_long_hi
                LDA     #$CDEF
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0123
                STA     _fcc_long_hi
                LDA     #$4567
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
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
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     a+6
                STA     _fcc_q3
                LDA     a+4
                STA     _fcc_q2
                LDA     a+2
                STA     _fcc_long_hi
                LDA     a
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     b+6
                STA     _fcc_q3
                LDA     b+4
                STA     _fcc_q2
                LDA     b+2
                STA     _fcc_long_hi
                LDA     b
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
                FGX2_FARCALL _fcc_ll_cmps
                CMP     #1
                BEQ     *+7
                LDA     #0
                BRA     *+5
                LDA     #1
                STA     i
                BEQ     _llong_arith_L139
                LDA     #137
                TAY
                TSC
                CLC
                ADC     #_llong_arith_run_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_llong_arith_L139
                LDA     #$89AB
                STA     _fcc_long_hi
                LDA     #$CDEF
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0123
                STA     _fcc_long_hi
                LDA     #$4567
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #ua
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     #$89AB
                STA     _fcc_long_hi
                LDA     #$CDEF
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0123
                STA     _fcc_long_hi
                LDA     #$4567
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #ub
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     ua+6
                STA     _fcc_q3
                LDA     ua+4
                STA     _fcc_q2
                LDA     ua+2
                STA     _fcc_long_hi
                LDA     ua
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     ub+6
                STA     _fcc_q3
                LDA     ub+4
                STA     _fcc_q2
                LDA     ub+2
                STA     _fcc_long_hi
                LDA     ub
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
                CMP     #1
                BEQ     *+7
                LDA     #0
                BRA     *+5
                LDA     #1
                STA     i
                BEQ     _llong_arith_L140
                LDA     #138
                TAY
                TSC
                CLC
                ADC     #_llong_arith_run_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_llong_arith_L140
                LDA     #$89AB
                STA     _fcc_long_hi
                LDA     #$CDEF
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0123
                STA     _fcc_long_hi
                LDA     #$4567
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #a
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     #$89AB
                STA     _fcc_long_hi
                LDA     #$CDEF
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0123
                STA     _fcc_long_hi
                LDA     #$4567
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
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
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     a+6
                STA     _fcc_q3
                LDA     a+4
                STA     _fcc_q2
                LDA     a+2
                STA     _fcc_long_hi
                LDA     a
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     b+6
                STA     _fcc_q3
                LDA     b+4
                STA     _fcc_q2
                LDA     b+2
                STA     _fcc_long_hi
                LDA     b
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
                FGX2_FARCALL _fcc_ll_cmps
                CMP     #1
                BNE     *+7
                LDA     #0
                BRA     *+5
                LDA     #1
                STA     i
                TAX
                CMP     #1
                BEQ     _llong_arith_L141
                LDA     #139
                TAY
                TSC
                CLC
                ADC     #_llong_arith_run_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_llong_arith_L141
                LDA     #$89AB
                STA     _fcc_long_hi
                LDA     #$CDEF
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0123
                STA     _fcc_long_hi
                LDA     #$4567
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #ua
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     #$89AB
                STA     _fcc_long_hi
                LDA     #$CDEF
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0123
                STA     _fcc_long_hi
                LDA     #$4567
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #ub
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     ua+6
                STA     _fcc_q3
                LDA     ua+4
                STA     _fcc_q2
                LDA     ua+2
                STA     _fcc_long_hi
                LDA     ua
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     ub+6
                STA     _fcc_q3
                LDA     ub+4
                STA     _fcc_q2
                LDA     ub+2
                STA     _fcc_long_hi
                LDA     ub
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
                CMP     #1
                BNE     *+7
                LDA     #0
                BRA     *+5
                LDA     #1
                STA     i
                TAX
                CMP     #1
                BEQ     _llong_arith_L142
                LDA     #140
                TAY
                TSC
                CLC
                ADC     #_llong_arith_run_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_llong_arith_L142
                LDA     #$89AB
                STA     _fcc_long_hi
                LDA     #$CDEF
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0123
                STA     _fcc_long_hi
                LDA     #$4567
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #a
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     #$89AB
                STA     _fcc_long_hi
                LDA     #$CDEF
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0123
                STA     _fcc_long_hi
                LDA     #$4567
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
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
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     a+6
                STA     _fcc_q3
                LDA     a+4
                STA     _fcc_q2
                LDA     a+2
                STA     _fcc_long_hi
                LDA     a
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     b+6
                STA     _fcc_q3
                LDA     b+4
                STA     _fcc_q2
                LDA     b+2
                STA     _fcc_long_hi
                LDA     b
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
                FGX2_FARCALL _fcc_ll_cmps
                BPL     *+7
                LDA     #0
                BRA     *+5
                LDA     #1
                STA     i
                TAX
                CMP     #1
                BEQ     _llong_arith_L143
                LDA     #141
                TAY
                TSC
                CLC
                ADC     #_llong_arith_run_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_llong_arith_L143
                LDA     #$89AB
                STA     _fcc_long_hi
                LDA     #$CDEF
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0123
                STA     _fcc_long_hi
                LDA     #$4567
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #ua
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     #$89AB
                STA     _fcc_long_hi
                LDA     #$CDEF
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0123
                STA     _fcc_long_hi
                LDA     #$4567
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #ub
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     ua+6
                STA     _fcc_q3
                LDA     ua+4
                STA     _fcc_q2
                LDA     ua+2
                STA     _fcc_long_hi
                LDA     ua
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     ub+6
                STA     _fcc_q3
                LDA     ub+4
                STA     _fcc_q2
                LDA     ub+2
                STA     _fcc_long_hi
                LDA     ub
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
                STA     i
                TAX
                CMP     #1
                BEQ     _llong_arith_L144
                LDA     #142
                TAY
                TSC
                CLC
                ADC     #_llong_arith_run_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_llong_arith_L144
                LDA     #$89AB
                STA     _fcc_long_hi
                LDA     #$CDEF
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0123
                STA     _fcc_long_hi
                LDA     #$4567
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #a
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     #$89AB
                STA     _fcc_long_hi
                LDA     #$CDEF
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0123
                STA     _fcc_long_hi
                LDA     #$4567
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
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
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     a+6
                STA     _fcc_q3
                LDA     a+4
                STA     _fcc_q2
                LDA     a+2
                STA     _fcc_long_hi
                LDA     a
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     b+6
                STA     _fcc_q3
                LDA     b+4
                STA     _fcc_q2
                LDA     b+2
                STA     _fcc_long_hi
                LDA     b
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
                FGX2_FARCALL _fcc_ll_cmps
                BEQ     *+7
                LDA     #0
                BRA     *+5
                LDA     #1
                STA     i
                TAX
                CMP     #1
                BEQ     _llong_arith_L145
                LDA     #143
                TAY
                TSC
                CLC
                ADC     #_llong_arith_run_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_llong_arith_L145
                LDA     #$89AB
                STA     _fcc_long_hi
                LDA     #$CDEF
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0123
                STA     _fcc_long_hi
                LDA     #$4567
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #ua
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     #$89AB
                STA     _fcc_long_hi
                LDA     #$CDEF
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0123
                STA     _fcc_long_hi
                LDA     #$4567
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #ub
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     ua+6
                STA     _fcc_q3
                LDA     ua+4
                STA     _fcc_q2
                LDA     ua+2
                STA     _fcc_long_hi
                LDA     ua
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     ub+6
                STA     _fcc_q3
                LDA     ub+4
                STA     _fcc_q2
                LDA     ub+2
                STA     _fcc_long_hi
                LDA     ub
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
                STA     i
                TAX
                CMP     #1
                BEQ     _llong_arith_L146
                LDA     #144
                TAY
                TSC
                CLC
                ADC     #_llong_arith_run_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_llong_arith_L146
                LDA     #$89AB
                STA     _fcc_long_hi
                LDA     #$CDEF
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0123
                STA     _fcc_long_hi
                LDA     #$4567
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #a
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     #$89AB
                STA     _fcc_long_hi
                LDA     #$CDEF
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0123
                STA     _fcc_long_hi
                LDA     #$4567
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
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
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     a+6
                STA     _fcc_q3
                LDA     a+4
                STA     _fcc_q2
                LDA     a+2
                STA     _fcc_long_hi
                LDA     a
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     b+6
                STA     _fcc_q3
                LDA     b+4
                STA     _fcc_q2
                LDA     b+2
                STA     _fcc_long_hi
                LDA     b
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
                FGX2_FARCALL _fcc_ll_cmps
                BNE     *+7
                LDA     #0
                BRA     *+5
                LDA     #1
                STA     i
                BEQ     _llong_arith_L147
                LDA     #145
                TAY
                TSC
                CLC
                ADC     #_llong_arith_run_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_llong_arith_L147
                LDA     #$89AB
                STA     _fcc_long_hi
                LDA     #$CDEF
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0123
                STA     _fcc_long_hi
                LDA     #$4567
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #ua
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     #$89AB
                STA     _fcc_long_hi
                LDA     #$CDEF
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0123
                STA     _fcc_long_hi
                LDA     #$4567
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #ub
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     ua+6
                STA     _fcc_q3
                LDA     ua+4
                STA     _fcc_q2
                LDA     ua+2
                STA     _fcc_long_hi
                LDA     ua
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     ub+6
                STA     _fcc_q3
                LDA     ub+4
                STA     _fcc_q2
                LDA     ub+2
                STA     _fcc_long_hi
                LDA     ub
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
                STA     i
                BEQ     _llong_arith_L148
                LDA     #146
                TAY
                TSC
                CLC
                ADC     #_llong_arith_run_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_llong_arith_L148
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
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #a
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     #$FFFF
                STA     _fcc_long_hi
                LDA     #$FFFF
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$7FFF
                STA     _fcc_long_hi
                LDA     #$FFFF
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
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
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     a+6
                STA     _fcc_q3
                LDA     a+4
                STA     _fcc_q2
                LDA     a+2
                STA     _fcc_long_hi
                LDA     a
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     b+6
                STA     _fcc_q3
                LDA     b+4
                STA     _fcc_q2
                LDA     b+2
                STA     _fcc_long_hi
                LDA     b
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
                FGX2_FARCALL _fcc_ll_cmps
                BMI     *+7
                LDA     #0
                BRA     *+5
                LDA     #1
                STA     i
                TAX
                CMP     #1
                BEQ     _llong_arith_L149
                LDA     #147
                TAY
                TSC
                CLC
                ADC     #_llong_arith_run_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_llong_arith_L149
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
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #ua
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     #$FFFF
                STA     _fcc_long_hi
                LDA     #$FFFF
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$7FFF
                STA     _fcc_long_hi
                LDA     #$FFFF
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #ub
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     ua+6
                STA     _fcc_q3
                LDA     ua+4
                STA     _fcc_q2
                LDA     ua+2
                STA     _fcc_long_hi
                LDA     ua
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     ub+6
                STA     _fcc_q3
                LDA     ub+4
                STA     _fcc_q2
                LDA     ub+2
                STA     _fcc_long_hi
                LDA     ub
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
                STA     i
                BEQ     _llong_arith_L150
                LDA     #148
                TAY
                TSC
                CLC
                ADC     #_llong_arith_run_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_llong_arith_L150
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
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #a
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     #$FFFF
                STA     _fcc_long_hi
                LDA     #$FFFF
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$7FFF
                STA     _fcc_long_hi
                LDA     #$FFFF
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
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
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     a+6
                STA     _fcc_q3
                LDA     a+4
                STA     _fcc_q2
                LDA     a+2
                STA     _fcc_long_hi
                LDA     a
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     b+6
                STA     _fcc_q3
                LDA     b+4
                STA     _fcc_q2
                LDA     b+2
                STA     _fcc_long_hi
                LDA     b
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
                FGX2_FARCALL _fcc_ll_cmps
                CMP     #1
                BEQ     *+7
                LDA     #0
                BRA     *+5
                LDA     #1
                STA     i
                BEQ     _llong_arith_L151
                LDA     #149
                TAY
                TSC
                CLC
                ADC     #_llong_arith_run_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_llong_arith_L151
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
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #ua
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     #$FFFF
                STA     _fcc_long_hi
                LDA     #$FFFF
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$7FFF
                STA     _fcc_long_hi
                LDA     #$FFFF
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #ub
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     ua+6
                STA     _fcc_q3
                LDA     ua+4
                STA     _fcc_q2
                LDA     ua+2
                STA     _fcc_long_hi
                LDA     ua
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     ub+6
                STA     _fcc_q3
                LDA     ub+4
                STA     _fcc_q2
                LDA     ub+2
                STA     _fcc_long_hi
                LDA     ub
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
                CMP     #1
                BEQ     *+7
                LDA     #0
                BRA     *+5
                LDA     #1
                STA     i
                TAX
                CMP     #1
                BEQ     _llong_arith_L152
                LDA     #150
                TAY
                TSC
                CLC
                ADC     #_llong_arith_run_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_llong_arith_L152
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
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #a
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     #$FFFF
                STA     _fcc_long_hi
                LDA     #$FFFF
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$7FFF
                STA     _fcc_long_hi
                LDA     #$FFFF
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
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
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     a+6
                STA     _fcc_q3
                LDA     a+4
                STA     _fcc_q2
                LDA     a+2
                STA     _fcc_long_hi
                LDA     a
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     b+6
                STA     _fcc_q3
                LDA     b+4
                STA     _fcc_q2
                LDA     b+2
                STA     _fcc_long_hi
                LDA     b
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
                FGX2_FARCALL _fcc_ll_cmps
                CMP     #1
                BNE     *+7
                LDA     #0
                BRA     *+5
                LDA     #1
                STA     i
                TAX
                CMP     #1
                BEQ     _llong_arith_L153
                LDA     #151
                TAY
                TSC
                CLC
                ADC     #_llong_arith_run_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_llong_arith_L153
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
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #ua
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     #$FFFF
                STA     _fcc_long_hi
                LDA     #$FFFF
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$7FFF
                STA     _fcc_long_hi
                LDA     #$FFFF
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #ub
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     ua+6
                STA     _fcc_q3
                LDA     ua+4
                STA     _fcc_q2
                LDA     ua+2
                STA     _fcc_long_hi
                LDA     ua
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     ub+6
                STA     _fcc_q3
                LDA     ub+4
                STA     _fcc_q2
                LDA     ub+2
                STA     _fcc_long_hi
                LDA     ub
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
                CMP     #1
                BNE     *+7
                LDA     #0
                BRA     *+5
                LDA     #1
                STA     i
                BEQ     _llong_arith_L154
                LDA     #152
                TAY
                TSC
                CLC
                ADC     #_llong_arith_run_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_llong_arith_L154
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
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #a
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     #$FFFF
                STA     _fcc_long_hi
                LDA     #$FFFF
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$7FFF
                STA     _fcc_long_hi
                LDA     #$FFFF
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
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
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     a+6
                STA     _fcc_q3
                LDA     a+4
                STA     _fcc_q2
                LDA     a+2
                STA     _fcc_long_hi
                LDA     a
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     b+6
                STA     _fcc_q3
                LDA     b+4
                STA     _fcc_q2
                LDA     b+2
                STA     _fcc_long_hi
                LDA     b
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
                FGX2_FARCALL _fcc_ll_cmps
                BPL     *+7
                LDA     #0
                BRA     *+5
                LDA     #1
                STA     i
                BEQ     _llong_arith_L155
                LDA     #153
                TAY
                TSC
                CLC
                ADC     #_llong_arith_run_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_llong_arith_L155
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
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #ua
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     #$FFFF
                STA     _fcc_long_hi
                LDA     #$FFFF
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$7FFF
                STA     _fcc_long_hi
                LDA     #$FFFF
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #ub
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     ua+6
                STA     _fcc_q3
                LDA     ua+4
                STA     _fcc_q2
                LDA     ua+2
                STA     _fcc_long_hi
                LDA     ua
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     ub+6
                STA     _fcc_q3
                LDA     ub+4
                STA     _fcc_q2
                LDA     ub+2
                STA     _fcc_long_hi
                LDA     ub
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
                STA     i
                TAX
                CMP     #1
                BEQ     _llong_arith_L156
                LDA     #154
                TAY
                TSC
                CLC
                ADC     #_llong_arith_run_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_llong_arith_L156
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
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #a
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     #$FFFF
                STA     _fcc_long_hi
                LDA     #$FFFF
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$7FFF
                STA     _fcc_long_hi
                LDA     #$FFFF
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
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
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     a+6
                STA     _fcc_q3
                LDA     a+4
                STA     _fcc_q2
                LDA     a+2
                STA     _fcc_long_hi
                LDA     a
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     b+6
                STA     _fcc_q3
                LDA     b+4
                STA     _fcc_q2
                LDA     b+2
                STA     _fcc_long_hi
                LDA     b
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
                FGX2_FARCALL _fcc_ll_cmps
                BEQ     *+7
                LDA     #0
                BRA     *+5
                LDA     #1
                STA     i
                BEQ     _llong_arith_L157
                LDA     #155
                TAY
                TSC
                CLC
                ADC     #_llong_arith_run_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_llong_arith_L157
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
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #ua
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     #$FFFF
                STA     _fcc_long_hi
                LDA     #$FFFF
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$7FFF
                STA     _fcc_long_hi
                LDA     #$FFFF
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #ub
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     ua+6
                STA     _fcc_q3
                LDA     ua+4
                STA     _fcc_q2
                LDA     ua+2
                STA     _fcc_long_hi
                LDA     ua
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     ub+6
                STA     _fcc_q3
                LDA     ub+4
                STA     _fcc_q2
                LDA     ub+2
                STA     _fcc_long_hi
                LDA     ub
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
                STA     i
                BEQ     _llong_arith_L158
                LDA     #156
                TAY
                TSC
                CLC
                ADC     #_llong_arith_run_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_llong_arith_L158
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
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #a
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     #$FFFF
                STA     _fcc_long_hi
                LDA     #$FFFF
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$7FFF
                STA     _fcc_long_hi
                LDA     #$FFFF
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
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
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     a+6
                STA     _fcc_q3
                LDA     a+4
                STA     _fcc_q2
                LDA     a+2
                STA     _fcc_long_hi
                LDA     a
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     b+6
                STA     _fcc_q3
                LDA     b+4
                STA     _fcc_q2
                LDA     b+2
                STA     _fcc_long_hi
                LDA     b
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
                FGX2_FARCALL _fcc_ll_cmps
                BNE     *+7
                LDA     #0
                BRA     *+5
                LDA     #1
                STA     i
                TAX
                CMP     #1
                BEQ     _llong_arith_L159
                LDA     #157
                TAY
                TSC
                CLC
                ADC     #_llong_arith_run_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_llong_arith_L159
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
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #ua
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     #$FFFF
                STA     _fcc_long_hi
                LDA     #$FFFF
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$7FFF
                STA     _fcc_long_hi
                LDA     #$FFFF
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #ub
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     ua+6
                STA     _fcc_q3
                LDA     ua+4
                STA     _fcc_q2
                LDA     ua+2
                STA     _fcc_long_hi
                LDA     ua
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     ub+6
                STA     _fcc_q3
                LDA     ub+4
                STA     _fcc_q2
                LDA     ub+2
                STA     _fcc_long_hi
                LDA     ub
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
                STA     i
                TAX
                CMP     #1
                BEQ     _llong_arith_L160
                LDA     #158
                TAY
                TSC
                CLC
                ADC     #_llong_arith_run_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_llong_arith_L160
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0005
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0000
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #a
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0006
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0000
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
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
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     a+6
                STA     _fcc_q3
                LDA     a+4
                STA     _fcc_q2
                LDA     a+2
                STA     _fcc_long_hi
                LDA     a
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     b+6
                STA     _fcc_q3
                LDA     b+4
                STA     _fcc_q2
                LDA     b+2
                STA     _fcc_long_hi
                LDA     b
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
                FGX2_FARCALL _fcc_ll_cmps
                BMI     *+7
                LDA     #0
                BRA     *+5
                LDA     #1
                STA     i
                TAX
                CMP     #1
                BEQ     _llong_arith_L161
                LDA     #159
                TAY
                TSC
                CLC
                ADC     #_llong_arith_run_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_llong_arith_L161
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0005
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0000
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #ua
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0006
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0000
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #ub
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     ua+6
                STA     _fcc_q3
                LDA     ua+4
                STA     _fcc_q2
                LDA     ua+2
                STA     _fcc_long_hi
                LDA     ua
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     ub+6
                STA     _fcc_q3
                LDA     ub+4
                STA     _fcc_q2
                LDA     ub+2
                STA     _fcc_long_hi
                LDA     ub
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
                STA     i
                TAX
                CMP     #1
                BEQ     _llong_arith_L162
                LDA     #160
                TAY
                TSC
                CLC
                ADC     #_llong_arith_run_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_llong_arith_L162
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0005
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0000
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #a
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0006
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0000
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
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
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     a+6
                STA     _fcc_q3
                LDA     a+4
                STA     _fcc_q2
                LDA     a+2
                STA     _fcc_long_hi
                LDA     a
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     b+6
                STA     _fcc_q3
                LDA     b+4
                STA     _fcc_q2
                LDA     b+2
                STA     _fcc_long_hi
                LDA     b
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
                FGX2_FARCALL _fcc_ll_cmps
                CMP     #1
                BEQ     *+7
                LDA     #0
                BRA     *+5
                LDA     #1
                STA     i
                BEQ     _llong_arith_L163
                LDA     #161
                TAY
                TSC
                CLC
                ADC     #_llong_arith_run_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_llong_arith_L163
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0005
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0000
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #ua
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0006
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0000
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #ub
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     ua+6
                STA     _fcc_q3
                LDA     ua+4
                STA     _fcc_q2
                LDA     ua+2
                STA     _fcc_long_hi
                LDA     ua
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     ub+6
                STA     _fcc_q3
                LDA     ub+4
                STA     _fcc_q2
                LDA     ub+2
                STA     _fcc_long_hi
                LDA     ub
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
                CMP     #1
                BEQ     *+7
                LDA     #0
                BRA     *+5
                LDA     #1
                STA     i
                BEQ     _llong_arith_L164
                LDA     #162
                TAY
                TSC
                CLC
                ADC     #_llong_arith_run_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_llong_arith_L164
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0005
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0000
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #a
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0006
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0000
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
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
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     a+6
                STA     _fcc_q3
                LDA     a+4
                STA     _fcc_q2
                LDA     a+2
                STA     _fcc_long_hi
                LDA     a
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     b+6
                STA     _fcc_q3
                LDA     b+4
                STA     _fcc_q2
                LDA     b+2
                STA     _fcc_long_hi
                LDA     b
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
                FGX2_FARCALL _fcc_ll_cmps
                CMP     #1
                BNE     *+7
                LDA     #0
                BRA     *+5
                LDA     #1
                STA     i
                TAX
                CMP     #1
                BEQ     _llong_arith_L165
                LDA     #163
                TAY
                TSC
                CLC
                ADC     #_llong_arith_run_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_llong_arith_L165
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0005
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0000
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #ua
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0006
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0000
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #ub
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     ua+6
                STA     _fcc_q3
                LDA     ua+4
                STA     _fcc_q2
                LDA     ua+2
                STA     _fcc_long_hi
                LDA     ua
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     ub+6
                STA     _fcc_q3
                LDA     ub+4
                STA     _fcc_q2
                LDA     ub+2
                STA     _fcc_long_hi
                LDA     ub
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
                CMP     #1
                BNE     *+7
                LDA     #0
                BRA     *+5
                LDA     #1
                STA     i
                TAX
                CMP     #1
                BEQ     _llong_arith_L166
                LDA     #164
                TAY
                TSC
                CLC
                ADC     #_llong_arith_run_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_llong_arith_L166
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0005
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0000
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #a
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0006
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0000
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
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
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     a+6
                STA     _fcc_q3
                LDA     a+4
                STA     _fcc_q2
                LDA     a+2
                STA     _fcc_long_hi
                LDA     a
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     b+6
                STA     _fcc_q3
                LDA     b+4
                STA     _fcc_q2
                LDA     b+2
                STA     _fcc_long_hi
                LDA     b
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
                FGX2_FARCALL _fcc_ll_cmps
                BPL     *+7
                LDA     #0
                BRA     *+5
                LDA     #1
                STA     i
                BEQ     _llong_arith_L167
                LDA     #165
                TAY
                TSC
                CLC
                ADC     #_llong_arith_run_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_llong_arith_L167
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0005
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0000
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #ua
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0006
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0000
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #ub
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     ua+6
                STA     _fcc_q3
                LDA     ua+4
                STA     _fcc_q2
                LDA     ua+2
                STA     _fcc_long_hi
                LDA     ua
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     ub+6
                STA     _fcc_q3
                LDA     ub+4
                STA     _fcc_q2
                LDA     ub+2
                STA     _fcc_long_hi
                LDA     ub
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
                STA     i
                BEQ     _llong_arith_L168
                LDA     #166
                TAY
                TSC
                CLC
                ADC     #_llong_arith_run_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_llong_arith_L168
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0005
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0000
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #a
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0006
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0000
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
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
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     a+6
                STA     _fcc_q3
                LDA     a+4
                STA     _fcc_q2
                LDA     a+2
                STA     _fcc_long_hi
                LDA     a
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     b+6
                STA     _fcc_q3
                LDA     b+4
                STA     _fcc_q2
                LDA     b+2
                STA     _fcc_long_hi
                LDA     b
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
                FGX2_FARCALL _fcc_ll_cmps
                BEQ     *+7
                LDA     #0
                BRA     *+5
                LDA     #1
                STA     i
                BEQ     _llong_arith_L169
                LDA     #167
                TAY
                TSC
                CLC
                ADC     #_llong_arith_run_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_llong_arith_L169
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0005
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0000
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #ua
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0006
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0000
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #ub
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     ua+6
                STA     _fcc_q3
                LDA     ua+4
                STA     _fcc_q2
                LDA     ua+2
                STA     _fcc_long_hi
                LDA     ua
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     ub+6
                STA     _fcc_q3
                LDA     ub+4
                STA     _fcc_q2
                LDA     ub+2
                STA     _fcc_long_hi
                LDA     ub
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
                STA     i
                BEQ     _llong_arith_L170
                LDA     #168
                TAY
                TSC
                CLC
                ADC     #_llong_arith_run_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_llong_arith_L170
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0005
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0000
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #a
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0006
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0000
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
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
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     a+6
                STA     _fcc_q3
                LDA     a+4
                STA     _fcc_q2
                LDA     a+2
                STA     _fcc_long_hi
                LDA     a
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     b+6
                STA     _fcc_q3
                LDA     b+4
                STA     _fcc_q2
                LDA     b+2
                STA     _fcc_long_hi
                LDA     b
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
                FGX2_FARCALL _fcc_ll_cmps
                BNE     *+7
                LDA     #0
                BRA     *+5
                LDA     #1
                STA     i
                TAX
                CMP     #1
                BEQ     _llong_arith_L171
                LDA     #169
                TAY
                TSC
                CLC
                ADC     #_llong_arith_run_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_llong_arith_L171
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0005
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0000
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #ua
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0006
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0000
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #ub
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     ua+6
                STA     _fcc_q3
                LDA     ua+4
                STA     _fcc_q2
                LDA     ua+2
                STA     _fcc_long_hi
                LDA     ua
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     ub+6
                STA     _fcc_q3
                LDA     ub+4
                STA     _fcc_q2
                LDA     ub+2
                STA     _fcc_long_hi
                LDA     ub
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
                STA     i
                TAX
                CMP     #1
                BEQ     _llong_arith_L172
                LDA     #170
                TAY
                TSC
                CLC
                ADC     #_llong_arith_run_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_llong_arith_L172
                LDA     #0
                TAY
                TSC
                CLC
                ADC     #_llong_arith_run_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_llong_arith_run_FRAMESIZE   EQU     0
_llong_arith_run_STKGUARD    EQU     0
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
                FGX2_FARCALL _llong_arith_run
                STA     1,S   ; fccstk d=0 b=1
                CMP     #0
                BEQ     _llong_arith_L173
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
_llong_arith_L173
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0000
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0000
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
                INC
                INC
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     9,S   ; fccstk d=0 b=9
                STA     _fcc_q3
                LDA     7,S   ; fccstk d=0 b=7
                STA     _fcc_q2
                LDA     5,S   ; fccstk d=0 b=5
                STA     _fcc_long_hi
                LDA     3,S   ; fccstk d=0 b=3
                ORA     _fcc_long_hi
                ORA     _fcc_q2
                ORA     _fcc_q3
                BNE     _llong_arith_L175
                LDA     9,S   ; fccstk d=0 b=9
                STA     _fcc_q3
                LDA     7,S   ; fccstk d=0 b=7
                STA     _fcc_q2
                LDA     5,S   ; fccstk d=0 b=5
                STA     _fcc_long_hi
                LDA     3,S   ; fccstk d=0 b=3
                ORA     _fcc_long_hi
                ORA     _fcc_q2
                ORA     _fcc_q3
                BEQ     _llong_arith_L174
_llong_arith_L175
                LDA     #200
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_llong_arith_L174
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0000
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
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                INC
                INC
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     9,S   ; fccstk d=0 b=9
                STA     _fcc_q3
                LDA     7,S   ; fccstk d=0 b=7
                STA     _fcc_q2
                LDA     5,S   ; fccstk d=0 b=5
                STA     _fcc_long_hi
                LDA     3,S   ; fccstk d=0 b=3
                ORA     _fcc_long_hi
                ORA     _fcc_q2
                ORA     _fcc_q3
                BNE     _llong_arith_L176
                LDA     #201
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_llong_arith_L176
                LDA     #$FFFF
                STA     _fcc_long_hi
                LDA     #$FFFF
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0000
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #a
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     #1
                STA     i
                LDA     a+6
                STA     _fcc_q3
                LDA     a+4
                STA     _fcc_q2
                LDA     a+2
                STA     _fcc_long_hi
                LDA     a
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     i
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
                FGX2_FARCALL _fcc_ll_add
                STA     r
                TAY
                LDA     _fcc_long_hi
                STA     r+2
                LDA     _fcc_q2
                STA     r+4
                LDA     _fcc_q3
                STA     r+6
                TYA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0000
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0001
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     r+6
                STA     _fcc_q3
                LDA     r+4
                STA     _fcc_q2
                LDA     r+2
                STA     _fcc_long_hi
                LDA     r
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                FGX2_FARCALL _llong_arith_is
                TAY
                TSC
                CLC
                ADC     #16
                TCS
                TYA
                CMP     #0
                BNE     _llong_arith_L177
                LDA     #202
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_llong_arith_L177
                LDA     i
                PHA
                LDA     a+6
                STA     _fcc_q3
                LDA     a+4
                STA     _fcc_q2
                LDA     a+2
                STA     _fcc_long_hi
                LDA     a
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                LDX     _fcc_q2
                STX     _fcc_qb2
                LDX     _fcc_q3
                STX     _fcc_qb3
                PLA
                JSR     _fcc_long_from_int
                LDX     #0
                BIT     _fcc_long_hi
                BPL     *+5
                LDX     #$FFFF
                STX     _fcc_q2
                STX     _fcc_q3
                FGX2_FARCALL _fcc_ll_sub
                STA     r
                TAY
                LDA     _fcc_long_hi
                STA     r+2
                LDA     _fcc_q2
                STA     r+4
                LDA     _fcc_q3
                STA     r+6
                TYA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0002
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0001
                JSR     _fcc_long_neg
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     r+6
                STA     _fcc_q3
                LDA     r+4
                STA     _fcc_q2
                LDA     r+2
                STA     _fcc_long_hi
                LDA     r
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                FGX2_FARCALL _llong_arith_is
                TAY
                TSC
                CLC
                ADC     #16
                TCS
                TYA
                CMP     #0
                BNE     _llong_arith_L178
                LDA     #203
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_llong_arith_L178
                LDA     #$FFFF
                STA     i
                LDA     a+6
                STA     _fcc_q3
                LDA     a+4
                STA     _fcc_q2
                LDA     a+2
                STA     _fcc_long_hi
                LDA     a
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     i
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
                FGX2_FARCALL _fcc_ll_add
                STA     r
                TAY
                LDA     _fcc_long_hi
                STA     r+2
                LDA     _fcc_q2
                STA     r+4
                LDA     _fcc_q3
                STA     r+6
                TYA
                LDA     #$FFFF
                STA     _fcc_long_hi
                LDA     #$FFFE
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0000
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     r+6
                STA     _fcc_q3
                LDA     r+4
                STA     _fcc_q2
                LDA     r+2
                STA     _fcc_long_hi
                LDA     r
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                FGX2_FARCALL _llong_arith_is
                TAY
                TSC
                CLC
                ADC     #16
                TCS
                TYA
                BNE     _llong_arith_L179
                LDA     #204
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_llong_arith_L179
                LDA     #$89AB
                STA     _fcc_long_hi
                LDA     #$CDEF
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0123
                STA     _fcc_long_hi
                LDA     #$4567
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #a
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _llong_arith_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     a+6
                STA     _fcc_q3
                LDA     a+4
                STA     _fcc_q2
                LDA     a+2
                STA     _fcc_long_hi
                LDA     a
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$89AB
                STA     _fcc_long_hi
                LDA     #$CDEF
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
                BNE     _llong_arith_L181
                LDA     a+6
                STA     _fcc_q3
                LDA     a+4
                STA     _fcc_q2
                LDA     a+2
                STA     _fcc_long_hi
                LDA     a
                TAX
                CMP     #52719
                BEQ     _llong_arith_L180
_llong_arith_L181
                LDA     #205
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_llong_arith_L180
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
main_FRAMESIZE   EQU     10
main_STKGUARD    EQU     0
                FGX2_RELOC_COUNT 573
