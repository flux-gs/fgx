                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from llong_store.c
;---------------------------------------

                MX      %00
                FGX2_EXPORT _llong_store_put
_llong_store_put            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #_llong_store_put_FRAMESIZE
                DO      _llong_store_put_STKGUARD
                BCC     _llong_store_put_stkovf
                CMP     _fcc_stkfloor
                BCS     _llong_store_put_stkok
_llong_store_put_stkovf       JMP     _fcc_stkoflow
                FIN
_llong_store_put_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      8+_llong_store_put_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_llong_store_put_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_llong_store_put_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+_llong_store_put_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_llong_store_put_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_llong_store_put_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     _fcc_img1
                LDA     _fcc_fpr0
                STA     _fcc_img0
                LDA     _fcc_img1
                STA     _fcc_ptr+2
                LDA     _fcc_img0
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
                DO      20+_llong_store_put_FRAMESIZE/256
                TSC
                CLC
                ADC     #20+_llong_store_put_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     20+_llong_store_put_FRAMESIZE,S   ; fccstk d=4 b=16 fs
                FIN
                STA     _fcc_long_hi
                DO      18+_llong_store_put_FRAMESIZE/256
                TSC
                CLC
                ADC     #18+_llong_store_put_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     18+_llong_store_put_FRAMESIZE,S   ; fccstk d=4 b=14 fs
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
                LDA     _fcc_img1
                STA     _fcc_ptr+2
                LDA     _fcc_img0
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
                DO      16+_llong_store_put_FRAMESIZE/256
                TSC
                CLC
                ADC     #16+_llong_store_put_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     16+_llong_store_put_FRAMESIZE,S   ; fccstk d=4 b=12 fs
                FIN
                STA     _fcc_long_hi
                DO      14+_llong_store_put_FRAMESIZE/256
                TSC
                CLC
                ADC     #14+_llong_store_put_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     14+_llong_store_put_FRAMESIZE,S   ; fccstk d=4 b=10 fs
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
                ADC     #_llong_store_put_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_llong_store_put_FRAMESIZE   EQU     4
_llong_store_put_STKGUARD    EQU     0
                FGX2_EXPORT _llong_store_is
_llong_store_is            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #_llong_store_is_FRAMESIZE
                DO      _llong_store_is_STKGUARD
                BCC     _llong_store_is_stkovf
                CMP     _fcc_stkfloor
                BCS     _llong_store_is_stkok
_llong_store_is_stkovf       JMP     _fcc_stkoflow
                FIN
_llong_store_is_stkok        TCS
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
                ADC     #6+_llong_store_is_FRAMESIZE
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                LDA     _fcc_ptr+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0+2
                STA     _fcc_img1
                LDA     _fcc_fpr0
                STA     _fcc_img0
                LDA     _fcc_img1
                STA     _fcc_ptr+2
                LDA     _fcc_img0
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
                DO      24+_llong_store_is_FRAMESIZE/256
                TSC
                CLC
                ADC     #24+_llong_store_is_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     24+_llong_store_is_FRAMESIZE,S   ; fccstk d=4 b=20 fs
                FIN
                STA     _fcc_long_hi
                DO      22+_llong_store_is_FRAMESIZE/256
                TSC
                CLC
                ADC     #22+_llong_store_is_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     22+_llong_store_is_FRAMESIZE,S   ; fccstk d=4 b=18 fs
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
                BEQ     _llong_store_L0
                LDA     _fcc_img1
                STA     _fcc_ptr+2
                LDA     _fcc_img0
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
                DO      20+_llong_store_is_FRAMESIZE/256
                TSC
                CLC
                ADC     #20+_llong_store_is_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     20+_llong_store_is_FRAMESIZE,S   ; fccstk d=4 b=16 fs
                FIN
                STA     _fcc_long_hi
                DO      18+_llong_store_is_FRAMESIZE/256
                TSC
                CLC
                ADC     #18+_llong_store_is_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     18+_llong_store_is_FRAMESIZE,S   ; fccstk d=4 b=14 fs
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
                BEQ     _llong_store_L0
                LDA     #1
                BRA     _llong_store_L1
_llong_store_L0
                LDA     #0
_llong_store_L1
                TAY
                TSC
                CLC
                ADC     #_llong_store_is_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_llong_store_is_FRAMESIZE   EQU     4
_llong_store_is_STKGUARD    EQU     0
                FGX2_EXPORT _llong_store_pass
_llong_store_pass            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #_llong_store_pass_FRAMESIZE
                DO      _llong_store_pass_STKGUARD
                BCC     _llong_store_pass_stkovf
                CMP     _fcc_stkfloor
                BCS     _llong_store_pass_stkok
_llong_store_pass_stkovf       JMP     _fcc_stkoflow
                FIN
_llong_store_pass_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      12+_llong_store_pass_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+_llong_store_pass_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+_llong_store_pass_FRAMESIZE,S   ; fccstk d=0 b=12 fs
                FIN
                STA     _fcc_q3
                DO      10+_llong_store_pass_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+_llong_store_pass_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+_llong_store_pass_FRAMESIZE,S   ; fccstk d=0 b=10 fs
                FIN
                STA     _fcc_q2
                DO      8+_llong_store_pass_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_llong_store_pass_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_llong_store_pass_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_long_hi
                DO      6+_llong_store_pass_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_llong_store_pass_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_llong_store_pass_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
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
                TSC
                CLC
                ADC     #_llong_store_pass_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_llong_store_pass_FRAMESIZE   EQU     8
_llong_store_pass_STKGUARD    EQU     0
                FGX2_EXPORT twice_arg
twice_arg            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #twice_arg_FRAMESIZE
                DO      twice_arg_STKGUARD
                BCC     twice_arg_stkovf
                CMP     _fcc_stkfloor
                BCS     twice_arg_stkok
twice_arg_stkovf       JMP     _fcc_stkoflow
                FIN
twice_arg_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      20+twice_arg_FRAMESIZE/256
                TSC
                CLC
                ADC     #20+twice_arg_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     20+twice_arg_FRAMESIZE,S   ; fccstk d=0 b=20 fs
                FIN
                STA     _fcc_q3
                DO      18+twice_arg_FRAMESIZE/256
                TSC
                CLC
                ADC     #18+twice_arg_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     18+twice_arg_FRAMESIZE,S   ; fccstk d=0 b=18 fs
                FIN
                STA     _fcc_q2
                DO      16+twice_arg_FRAMESIZE/256
                TSC
                CLC
                ADC     #16+twice_arg_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     16+twice_arg_FRAMESIZE,S   ; fccstk d=0 b=16 fs
                FIN
                STA     _fcc_long_hi
                DO      14+twice_arg_FRAMESIZE/256
                TSC
                CLC
                ADC     #14+twice_arg_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     14+twice_arg_FRAMESIZE,S   ; fccstk d=0 b=14 fs
                FIN
                TAY
                TSC
                CLC
                ADC     #twice_arg_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
twice_arg_FRAMESIZE   EQU     0
twice_arg_STKGUARD    EQU     0
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
                LDA     #$FFFD
                STA     17,S   ; fccstk d=0 b=17
                LDA     #65534
                STA     19,S   ; fccstk d=0 b=19
                LDA     #0
                STA     21,S   ; fccstk d=0 b=21
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
                FGX2_FARCALL _llong_store_put
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
                STA     9,S   ; fccstk d=0 b=9
                TAY
                LDA     _fcc_long_hi
                STA     11,S   ; fccstk d=0 b=11
                LDA     _fcc_q2
                STA     13,S   ; fccstk d=0 b=13
                LDA     _fcc_q3
                STA     15,S   ; fccstk d=0 b=15
                TYA
                LDA     15,S   ; fccstk d=0 b=15
                STA     _fcc_q3
                LDA     13,S   ; fccstk d=0 b=13
                STA     _fcc_q2
                LDA     11,S   ; fccstk d=0 b=11
                STA     _fcc_long_hi
                LDA     9,S   ; fccstk d=0 b=9
                STA     ga
                TAY
                LDA     _fcc_long_hi
                STA     ga+2
                LDA     _fcc_q2
                STA     ga+4
                LDA     _fcc_q3
                STA     ga+6
                TYA
                LDA     ga+6
                STA     _fcc_q3
                LDA     ga+4
                STA     _fcc_q2
                LDA     ga+2
                STA     _fcc_long_hi
                LDA     ga
                STA     gb
                TAY
                LDA     _fcc_long_hi
                STA     gb+2
                LDA     _fcc_q2
                STA     gb+4
                LDA     _fcc_q3
                STA     gb+6
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
                LDA     gb+6
                STA     _fcc_q3
                LDA     gb+4
                STA     _fcc_q2
                LDA     gb+2
                STA     _fcc_long_hi
                LDA     gb
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                FGX2_FARCALL _llong_store_is
                TAY
                TSC
                CLC
                ADC     #16
                TCS
                TYA
                BEQ     _llong_store_L2
                LDA     21,S   ; fccstk d=0 b=21
                TAX
                CLC
                ADC     #10
                STA     21,S   ; fccstk d=0 b=21
_llong_store_L2
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
                LDA     gb+6
                STA     _fcc_q3
                LDA     gb+4
                STA     _fcc_q2
                LDA     gb+2
                STA     _fcc_long_hi
                LDA     gb
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                FGX2_FARCALL _llong_store_pass
                PLY
                PLY
                PLY
                PLY
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                FGX2_FARCALL _llong_store_is
                TAY
                TSC
                CLC
                ADC     #16
                TCS
                TYA
                CMP     #0
                BNE     *+5
                BRL     _llong_store_L3
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
                LDA     23,S   ; fccstk d=8 b=15
                STA     _fcc_q3
                LDA     21,S   ; fccstk d=8 b=13
                STA     _fcc_q2
                LDA     19,S   ; fccstk d=8 b=11
                STA     _fcc_long_hi
                LDA     17,S   ; fccstk d=8 b=9
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                FGX2_FARCALL _llong_store_pass
                PLY
                PLY
                PLY
                PLY
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     23,S   ; fccstk d=16 b=7
                STA     _fcc_q3
                LDA     21,S   ; fccstk d=16 b=5
                STA     _fcc_q2
                LDA     19,S   ; fccstk d=16 b=3
                STA     _fcc_long_hi
                LDA     17,S   ; fccstk d=16 b=1
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                FGX2_FARCALL twice_arg
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
                FGX2_FARCALL _llong_store_is
                TAY
                TSC
                CLC
                ADC     #16
                TCS
                TYA
                CMP     #0
                BEQ     _llong_store_L3
                LDA     21,S   ; fccstk d=0 b=21
                TAX
                CLC
                ADC     #10
                STA     21,S   ; fccstk d=0 b=21
_llong_store_L3
                LDA     17,S   ; fccstk d=0 b=17
                JSR     _fcc_long_from_int
                LDX     #0
                BIT     _fcc_long_hi
                BPL     *+5
                LDX     #$FFFF
                STX     _fcc_q2
                STX     _fcc_q3
                STA     1,S   ; fccstk d=0 b=1
                TAY
                LDA     _fcc_long_hi
                STA     3,S   ; fccstk d=0 b=3
                LDA     _fcc_q2
                STA     5,S   ; fccstk d=0 b=5
                LDA     _fcc_q3
                STA     7,S   ; fccstk d=0 b=7
                TYA
                LDA     19,S   ; fccstk d=0 b=19
                LDX     #0
                STX     _fcc_long_hi
                STZ     _fcc_q2
                STZ     _fcc_q3
                STA     9,S   ; fccstk d=0 b=9
                TAY
                LDA     _fcc_long_hi
                STA     11,S   ; fccstk d=0 b=11
                LDA     _fcc_q2
                STA     13,S   ; fccstk d=0 b=13
                LDA     _fcc_q3
                STA     15,S   ; fccstk d=0 b=15
                TYA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0003
                JSR     _fcc_long_neg
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
                FGX2_FARCALL _llong_store_is
                TAY
                TSC
                CLC
                ADC     #16
                TCS
                TYA
                CMP     #0
                BEQ     _llong_store_L4
                LDA     #$0000
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
                LDA     23,S   ; fccstk d=8 b=15
                STA     _fcc_q3
                LDA     21,S   ; fccstk d=8 b=13
                STA     _fcc_q2
                LDA     19,S   ; fccstk d=8 b=11
                STA     _fcc_long_hi
                LDA     17,S   ; fccstk d=8 b=9
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                FGX2_FARCALL _llong_store_is
                TAY
                TSC
                CLC
                ADC     #16
                TCS
                TYA
                CMP     #0
                BEQ     _llong_store_L4
                LDA     21,S   ; fccstk d=0 b=21
                CLC
                ADC     #11
                STA     21,S   ; fccstk d=0 b=21
_llong_store_L4
                LDA     lo_neg+2
                STA     _fcc_long_hi
                LDA     lo_neg
                LDX     #0
                BIT     _fcc_long_hi
                BPL     *+5
                LDX     #$FFFF
                STX     _fcc_q2
                STX     _fcc_q3
                STA     1,S   ; fccstk d=0 b=1
                TAY
                LDA     _fcc_long_hi
                STA     3,S   ; fccstk d=0 b=3
                LDA     _fcc_q2
                STA     5,S   ; fccstk d=0 b=5
                LDA     _fcc_q3
                STA     7,S   ; fccstk d=0 b=7
                TYA
                LDA     lo_big+2
                STA     _fcc_long_hi
                LDA     lo_big
                STZ     _fcc_q2
                STZ     _fcc_q3
                STA     9,S   ; fccstk d=0 b=9
                TAY
                LDA     _fcc_long_hi
                STA     11,S   ; fccstk d=0 b=11
                LDA     _fcc_q2
                STA     13,S   ; fccstk d=0 b=13
                LDA     _fcc_q3
                STA     15,S   ; fccstk d=0 b=15
                TYA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0005
                JSR     _fcc_long_neg
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
                FGX2_FARCALL _llong_store_is
                TAY
                TSC
                CLC
                ADC     #16
                TCS
                TYA
                BEQ     _llong_store_L5
                LDA     #$89AB
                STA     _fcc_long_hi
                LDA     #$CDEF
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
                LDA     23,S   ; fccstk d=8 b=15
                STA     _fcc_q3
                LDA     21,S   ; fccstk d=8 b=13
                STA     _fcc_q2
                LDA     19,S   ; fccstk d=8 b=11
                STA     _fcc_long_hi
                LDA     17,S   ; fccstk d=8 b=9
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                FGX2_FARCALL _llong_store_is
                TAY
                TSC
                CLC
                ADC     #16
                TCS
                TYA
                BEQ     _llong_store_L5
                LDA     21,S   ; fccstk d=0 b=21
                TAX
                CLC
                ADC     #11
                STA     21,S   ; fccstk d=0 b=21
_llong_store_L5
                LDA     21,S   ; fccstk d=0 b=21
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
main_FRAMESIZE   EQU     22
main_STKGUARD    EQU     0
                FGX2_RELOC_COUNT 17
