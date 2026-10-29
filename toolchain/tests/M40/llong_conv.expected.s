                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from llong_conv.c
;---------------------------------------

                MX      %00
                FGX2_EXPORT _llong_conv_put
_llong_conv_put            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #_llong_conv_put_FRAMESIZE
                DO      _llong_conv_put_STKGUARD
                BCC     _llong_conv_put_stkovf
                CMP     _fcc_stkfloor
                BCS     _llong_conv_put_stkok
_llong_conv_put_stkovf       JMP     _fcc_stkoflow
                FIN
_llong_conv_put_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      8+_llong_conv_put_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_llong_conv_put_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_llong_conv_put_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+_llong_conv_put_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_llong_conv_put_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_llong_conv_put_FRAMESIZE,S   ; fccstk d=0 b=6 fs
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
                DO      20+_llong_conv_put_FRAMESIZE/256
                TSC
                CLC
                ADC     #20+_llong_conv_put_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     20+_llong_conv_put_FRAMESIZE,S   ; fccstk d=4 b=16 fs
                FIN
                STA     _fcc_long_hi
                DO      18+_llong_conv_put_FRAMESIZE/256
                TSC
                CLC
                ADC     #18+_llong_conv_put_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     18+_llong_conv_put_FRAMESIZE,S   ; fccstk d=4 b=14 fs
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
                DO      16+_llong_conv_put_FRAMESIZE/256
                TSC
                CLC
                ADC     #16+_llong_conv_put_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     16+_llong_conv_put_FRAMESIZE,S   ; fccstk d=4 b=12 fs
                FIN
                STA     _fcc_long_hi
                DO      14+_llong_conv_put_FRAMESIZE/256
                TSC
                CLC
                ADC     #14+_llong_conv_put_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     14+_llong_conv_put_FRAMESIZE,S   ; fccstk d=4 b=10 fs
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
                ADC     #_llong_conv_put_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_llong_conv_put_FRAMESIZE   EQU     4
_llong_conv_put_STKGUARD    EQU     0
                FGX2_EXPORT _llong_conv_is
_llong_conv_is            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #_llong_conv_is_FRAMESIZE
                DO      _llong_conv_is_STKGUARD
                BCC     _llong_conv_is_stkovf
                CMP     _fcc_stkfloor
                BCS     _llong_conv_is_stkok
_llong_conv_is_stkovf       JMP     _fcc_stkoflow
                FIN
_llong_conv_is_stkok        TCS
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
                ADC     #6+_llong_conv_is_FRAMESIZE
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
                DO      24+_llong_conv_is_FRAMESIZE/256
                TSC
                CLC
                ADC     #24+_llong_conv_is_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     24+_llong_conv_is_FRAMESIZE,S   ; fccstk d=4 b=20 fs
                FIN
                STA     _fcc_long_hi
                DO      22+_llong_conv_is_FRAMESIZE/256
                TSC
                CLC
                ADC     #22+_llong_conv_is_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     22+_llong_conv_is_FRAMESIZE,S   ; fccstk d=4 b=18 fs
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
                BEQ     _llong_conv_L0
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
                DO      20+_llong_conv_is_FRAMESIZE/256
                TSC
                CLC
                ADC     #20+_llong_conv_is_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     20+_llong_conv_is_FRAMESIZE,S   ; fccstk d=4 b=16 fs
                FIN
                STA     _fcc_long_hi
                DO      18+_llong_conv_is_FRAMESIZE/256
                TSC
                CLC
                ADC     #18+_llong_conv_is_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     18+_llong_conv_is_FRAMESIZE,S   ; fccstk d=4 b=14 fs
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
                BEQ     _llong_conv_L0
                LDA     #1
                BRA     _llong_conv_L1
_llong_conv_L0
                LDA     #0
_llong_conv_L1
                TAY
                TSC
                CLC
                ADC     #_llong_conv_is_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_llong_conv_is_FRAMESIZE   EQU     4
_llong_conv_is_STKGUARD    EQU     0
                FGX2_EXPORT _llong_conv_uis
_llong_conv_uis            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #_llong_conv_uis_FRAMESIZE
                DO      _llong_conv_uis_STKGUARD
                BCC     _llong_conv_uis_stkovf
                CMP     _fcc_stkfloor
                BCS     _llong_conv_uis_stkok
_llong_conv_uis_stkovf       JMP     _fcc_stkoflow
                FIN
_llong_conv_uis_stkok        TCS
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
                ADC     #6+_llong_conv_uis_FRAMESIZE
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
                DO      24+_llong_conv_uis_FRAMESIZE/256
                TSC
                CLC
                ADC     #24+_llong_conv_uis_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     24+_llong_conv_uis_FRAMESIZE,S   ; fccstk d=4 b=20 fs
                FIN
                STA     _fcc_long_hi
                DO      22+_llong_conv_uis_FRAMESIZE/256
                TSC
                CLC
                ADC     #22+_llong_conv_uis_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     22+_llong_conv_uis_FRAMESIZE,S   ; fccstk d=4 b=18 fs
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
                BEQ     _llong_conv_L2
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
                DO      20+_llong_conv_uis_FRAMESIZE/256
                TSC
                CLC
                ADC     #20+_llong_conv_uis_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     20+_llong_conv_uis_FRAMESIZE,S   ; fccstk d=4 b=16 fs
                FIN
                STA     _fcc_long_hi
                DO      18+_llong_conv_uis_FRAMESIZE/256
                TSC
                CLC
                ADC     #18+_llong_conv_uis_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     18+_llong_conv_uis_FRAMESIZE,S   ; fccstk d=4 b=14 fs
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
                BEQ     _llong_conv_L2
                LDA     #1
                BRA     _llong_conv_L3
_llong_conv_L2
                LDA     #0
_llong_conv_L3
                TAY
                TSC
                CLC
                ADC     #_llong_conv_uis_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_llong_conv_uis_FRAMESIZE   EQU     4
_llong_conv_uis_STKGUARD    EQU     0
                FGX2_EXPORT takes_int
takes_int            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #takes_int_FRAMESIZE
                DO      takes_int_STKGUARD
                BCC     takes_int_stkovf
                CMP     _fcc_stkfloor
                BCS     takes_int_stkok
takes_int_stkovf       JMP     _fcc_stkoflow
                FIN
takes_int_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      6+takes_int_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+takes_int_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+takes_int_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                TAY
                TSC
                CLC
                ADC     #takes_int_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
takes_int_FRAMESIZE   EQU     0
takes_int_STKGUARD    EQU     0
                FGX2_EXPORT takes_long
takes_long            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #takes_long_FRAMESIZE
                DO      takes_long_STKGUARD
                BCC     takes_long_stkovf
                CMP     _fcc_stkfloor
                BCS     takes_long_stkok
takes_long_stkovf       JMP     _fcc_stkoflow
                FIN
takes_long_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      8+takes_long_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+takes_long_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+takes_long_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_long_hi
                DO      6+takes_long_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+takes_long_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+takes_long_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                TAY
                TSC
                CLC
                ADC     #takes_long_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
takes_long_FRAMESIZE   EQU     0
takes_long_STKGUARD    EQU     0
                FGX2_EXPORT takes_ll
takes_ll            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #takes_ll_FRAMESIZE
                DO      takes_ll_STKGUARD
                BCC     takes_ll_stkovf
                CMP     _fcc_stkfloor
                BCS     takes_ll_stkok
takes_ll_stkovf       JMP     _fcc_stkoflow
                FIN
takes_ll_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      12+takes_ll_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+takes_ll_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+takes_ll_FRAMESIZE,S   ; fccstk d=0 b=12 fs
                FIN
                STA     _fcc_q3
                DO      10+takes_ll_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+takes_ll_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+takes_ll_FRAMESIZE,S   ; fccstk d=0 b=10 fs
                FIN
                STA     _fcc_q2
                DO      8+takes_ll_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+takes_ll_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+takes_ll_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_long_hi
                DO      6+takes_ll_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+takes_ll_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+takes_ll_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                TAY
                TSC
                CLC
                ADC     #takes_ll_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
takes_ll_FRAMESIZE   EQU     0
takes_ll_STKGUARD    EQU     0
                FGX2_EXPORT narrows
narrows            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #narrows_FRAMESIZE
                DO      narrows_STKGUARD
                BCC     narrows_stkovf
                CMP     _fcc_stkfloor
                BCS     narrows_stkok
narrows_stkovf       JMP     _fcc_stkoflow
                FIN
narrows_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      12+narrows_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+narrows_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+narrows_FRAMESIZE,S   ; fccstk d=0 b=12 fs
                FIN
                STA     _fcc_q3
                DO      10+narrows_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+narrows_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+narrows_FRAMESIZE,S   ; fccstk d=0 b=10 fs
                FIN
                STA     _fcc_q2
                DO      8+narrows_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+narrows_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+narrows_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_long_hi
                DO      6+narrows_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+narrows_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+narrows_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                TAY
                TSC
                CLC
                ADC     #narrows_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
narrows_FRAMESIZE   EQU     0
narrows_STKGUARD    EQU     0
                FGX2_EXPORT _llong_conv_sw
_llong_conv_sw            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #_llong_conv_sw_FRAMESIZE
                DO      _llong_conv_sw_STKGUARD
                BCC     _llong_conv_sw_stkovf
                CMP     _fcc_stkfloor
                BCS     _llong_conv_sw_stkok
_llong_conv_sw_stkovf       JMP     _fcc_stkoflow
                FIN
_llong_conv_sw_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      12+_llong_conv_sw_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+_llong_conv_sw_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+_llong_conv_sw_FRAMESIZE,S   ; fccstk d=0 b=12 fs
                FIN
                STA     _fcc_q3
                DO      10+_llong_conv_sw_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+_llong_conv_sw_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+_llong_conv_sw_FRAMESIZE,S   ; fccstk d=0 b=10 fs
                FIN
                STA     _fcc_q2
                DO      8+_llong_conv_sw_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_llong_conv_sw_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_llong_conv_sw_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_long_hi
                DO      6+_llong_conv_sw_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_llong_conv_sw_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_llong_conv_sw_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_long_b_lo
                LDA     _fcc_q3
                CMP     #65535
                BNE     _llong_conv_L9
                LDA     _fcc_q2
                CMP     #65535
                BNE     _llong_conv_L9
                LDA     _fcc_long_hi
                CMP     #65535
                BNE     _llong_conv_L9
                LDA     _fcc_long_b_lo
                CMP     #65535
                BEQ     _llong_conv_L5
_llong_conv_L9
                LDA     _fcc_q3
                BNE     _llong_conv_L10
                LDA     _fcc_q2
                BNE     _llong_conv_L10
                LDA     _fcc_long_hi
                BNE     _llong_conv_L10
                LDA     _fcc_long_b_lo
                CMP     #5
                BEQ     _llong_conv_L6
_llong_conv_L10
                LDA     _fcc_q3
                BNE     _llong_conv_L11
                LDA     _fcc_q2
                BNE     _llong_conv_L11
                LDA     _fcc_long_hi
                CMP     #65535
                BNE     _llong_conv_L11
                LDA     _fcc_long_b_lo
                CMP     #65535
                BEQ     _llong_conv_L7
_llong_conv_L11
                LDA     _fcc_q3
                BNE     _llong_conv_L12
                LDA     _fcc_q2
                BNE     _llong_conv_L12
                LDA     _fcc_long_hi
                CMP     #32767
                BNE     _llong_conv_L12
                LDA     _fcc_long_b_lo
                CMP     #65535
                BEQ     _llong_conv_L8
_llong_conv_L12
                BRA     _llong_conv_L4
_llong_conv_L5
                LDA     #1
                TAY
                TSC
                CLC
                ADC     #_llong_conv_sw_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_llong_conv_L6
                LDA     #2
                TAY
                TSC
                CLC
                ADC     #_llong_conv_sw_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_llong_conv_L7
                LDA     #3
                TAY
                TSC
                CLC
                ADC     #_llong_conv_sw_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_llong_conv_L8
                LDA     #4
                TAY
                TSC
                CLC
                ADC     #_llong_conv_sw_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_llong_conv_L4
                LDA     #9
                TAY
                TSC
                CLC
                ADC     #_llong_conv_sw_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_llong_conv_sw_FRAMESIZE   EQU     0
_llong_conv_sw_STKGUARD    EQU     0
                FGX2_EXPORT main
main            ENT
                PEI     _fcc_fb
                PEI     _fcc_img16
                TSC
                SEC
                SBC     #main_FRAMESIZE-2
                DO      main_STKGUARD
                BCC     main_stkovf
                CMP     _fcc_stkfloor
                BCS     main_stkok
main_stkovf       JMP     _fcc_stkoflow
                FIN
main_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                LDA     #1
                STA     3,S   ; fccstk d=0 b=3
                LDA     #0
                STA     5,S   ; fccstk d=0 b=5
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
                FGX2_FARCALL _llong_conv_put
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
                STA     1,S   ; fccstk d=0 b=1
                TAX
                CMP     #52719
                BEQ     _llong_conv_L13
                LDA     #1
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-2
                TCS
                BRL     main_bandx
_llong_conv_L13
                LDA     a+6
                STA     _fcc_q3
                LDA     a+4
                STA     _fcc_q2
                LDA     a+2
                STA     _fcc_long_hi
                LDA     a
                STA     11,S   ; fccstk d=0 b=11
                TAY
                LDA     _fcc_long_hi
                STA     13,S   ; fccstk d=0 b=13
                TYA
                LDA     13,S   ; fccstk d=0 b=13
                STA     _fcc_long_hi
                LDA     11,S   ; fccstk d=0 b=11
                LDX     #52719
                STX     _fcc_long_b_lo
                LDX     #35243
                STX     _fcc_long_b_hi
                JSR     _fcc_long_ne
                CMP     #0
                BEQ     _llong_conv_L14
                LDA     #2
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-2
                TCS
                BRL     main_bandx
_llong_conv_L14
                LDA     a+6
                STA     _fcc_q3
                LDA     a+4
                STA     _fcc_q2
                LDA     a+2
                STA     _fcc_long_hi
                LDA     a
                STA     19,S   ; fccstk d=0 b=19
                AND     #$00FF
                TAX
                CMP     #239
                BEQ     _llong_conv_L15
                LDA     #3
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-2
                TCS
                BRL     main_bandx
_llong_conv_L15
                LDA     a+6
                STA     _fcc_q3
                LDA     a+4
                STA     _fcc_q2
                LDA     a+2
                STA     _fcc_long_hi
                LDA     a
                STA     9,S   ; fccstk d=0 b=9
                TAX
                CMP     #52719
                BEQ     _llong_conv_L16
                LDA     #4
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-2
                TCS
                BRL     main_bandx
_llong_conv_L16
                LDA     #200
                STA     19,S   ; fccstk d=0 b=19
                AND     #$00FF
                LDX     #0
                STX     _fcc_long_hi
                STZ     _fcc_q2
                STZ     _fcc_q3
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
                LDA     #$00C8
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
                FGX2_FARCALL _llong_conv_is
                TAY
                TSC
                CLC
                ADC     #16
                TCS
                TYA
                CMP     #0
                BNE     _llong_conv_L17
                LDA     #5
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-2
                TCS
                BRL     main_bandx
_llong_conv_L17
                LDA     #$FFFB
                STA     1,S   ; fccstk d=0 b=1
                LDA     1,S   ; fccstk d=0 b=1
                JSR     _fcc_long_from_int
                LDX     #0
                BIT     _fcc_long_hi
                BPL     *+5
                LDX     #$FFFF
                STX     _fcc_q2
                STX     _fcc_q3
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
                FGX2_FARCALL _llong_conv_is
                TAY
                TSC
                CLC
                ADC     #16
                TCS
                TYA
                BNE     _llong_conv_L18
                LDA     #6
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-2
                TCS
                BRL     main_bandx
_llong_conv_L18
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$FFFF
                STA     9,S   ; fccstk d=0 b=9
                LDX     #0
                STX     _fcc_long_hi
                STZ     _fcc_q2
                STZ     _fcc_q3
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
                FGX2_FARCALL _llong_conv_is
                TAY
                TSC
                CLC
                ADC     #16
                TCS
                TYA
                CMP     #0
                BNE     _llong_conv_L19
                LDA     #7
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-2
                TCS
                BRL     main_bandx
_llong_conv_L19
                LDA     #$0001
                STA     _fcc_long_hi
                LDA     #$1170
                JSR     _fcc_long_neg
                STA     11,S   ; fccstk d=0 b=11
                TAY
                LDA     _fcc_long_hi
                STA     13,S   ; fccstk d=0 b=13
                TYA
                LDA     13,S   ; fccstk d=0 b=13
                STA     _fcc_long_hi
                LDA     11,S   ; fccstk d=0 b=11
                LDX     #0
                BIT     _fcc_long_hi
                BPL     *+5
                LDX     #$FFFF
                STX     _fcc_q2
                STX     _fcc_q3
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
                LDA     #$1170
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
                FGX2_FARCALL _llong_conv_is
                TAY
                TSC
                CLC
                ADC     #16
                TCS
                TYA
                BNE     _llong_conv_L20
                LDA     #8
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-2
                TCS
                BRL     main_bandx
_llong_conv_L20
                LDA     #$89AB
                STA     _fcc_long_hi
                LDA     #$CDEF
                STA     15,S   ; fccstk d=0 b=15
                TAY
                LDA     _fcc_long_hi
                STA     17,S   ; fccstk d=0 b=17
                TYA
                LDA     17,S   ; fccstk d=0 b=17
                STA     _fcc_long_hi
                LDA     15,S   ; fccstk d=0 b=15
                STZ     _fcc_q2
                STZ     _fcc_q3
                STA     r
                TAY
                LDA     _fcc_long_hi
                STA     r+2
                LDA     _fcc_q2
                STA     r+4
                LDA     _fcc_q3
                STA     r+6
                TYA
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
                FGX2_FARCALL _llong_conv_is
                TAY
                TSC
                CLC
                ADC     #16
                TCS
                TYA
                BNE     _llong_conv_L21
                LDA     #9
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-2
                TCS
                BRL     main_bandx
_llong_conv_L21
                LDA     #$89AB
                STA     _fcc_long_hi
                LDA     #$CDEF
                STA     15,S   ; fccstk d=0 b=15
                TAY
                LDA     _fcc_long_hi
                STA     17,S   ; fccstk d=0 b=17
                TYA
                LDA     17,S   ; fccstk d=0 b=17
                STA     _fcc_long_hi
                LDA     15,S   ; fccstk d=0 b=15
                STZ     _fcc_q2
                STZ     _fcc_q3
                STA     u
                TAY
                LDA     _fcc_long_hi
                STA     u+2
                LDA     _fcc_q2
                STA     u+4
                LDA     _fcc_q3
                STA     u+6
                TYA
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
                FGX2_FARCALL _llong_conv_uis
                TAY
                TSC
                CLC
                ADC     #16
                TCS
                TYA
                CMP     #0
                BNE     _llong_conv_L22
                LDA     #10
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-2
                TCS
                BRL     main_bandx
_llong_conv_L22
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0001
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
                FGX2_FARCALL _llong_conv_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     #1
                STA     9,S   ; fccstk d=0 b=9
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
                LDA     17,S   ; fccstk d=8 b=9
                LDX     #0
                STX     _fcc_long_hi
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
                FGX2_FARCALL _llong_conv_is
                TAY
                TSC
                CLC
                ADC     #16
                TCS
                TYA
                BNE     _llong_conv_L23
                LDA     #11
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-2
                TCS
                BRL     main_bandx
_llong_conv_L23
                LDA     9,S   ; fccstk d=0 b=9
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
                LDX     #0
                STX     _fcc_long_hi
                STZ     _fcc_q2
                STZ     _fcc_q3
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
                FGX2_FARCALL _llong_conv_is
                TAY
                TSC
                CLC
                ADC     #16
                TCS
                TYA
                CMP     #0
                BNE     _llong_conv_L24
                LDA     #12
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-2
                TCS
                BRL     main_bandx
_llong_conv_L24
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
                LDA     17,S   ; fccstk d=8 b=9
                LDX     #0
                STX     _fcc_long_hi
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
                FGX2_FARCALL _fcc_ll_cmps
                BMI     *+7
                LDA     #0
                BRA     *+5
                LDA     #1
                BNE     _llong_conv_L25
                LDA     #13
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-2
                TCS
                BRL     main_bandx
_llong_conv_L25
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
                FGX2_FARCALL _llong_conv_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     #$FFFF
                STA     _fcc_long_hi
                LDA     #$FFFF
                STA     15,S   ; fccstk d=0 b=15
                TAY
                LDA     _fcc_long_hi
                STA     17,S   ; fccstk d=0 b=17
                TYA
                LDA     17,S   ; fccstk d=0 b=17
                STA     _fcc_long_hi
                LDA     15,S   ; fccstk d=0 b=15
                TAY
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
                TYA
                STZ     _fcc_q2
                STZ     _fcc_q3
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
                FGX2_FARCALL _llong_conv_is
                TAY
                TSC
                CLC
                ADC     #16
                TCS
                TYA
                BNE     _llong_conv_L26
                LDA     #14
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-2
                TCS
                BRL     main_bandx
_llong_conv_L26
                LDA     b+6
                STA     _fcc_q3
                LDA     b+4
                STA     _fcc_q2
                LDA     b+2
                STA     _fcc_long_hi
                LDA     b
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
                STA     _fcc_long_hi
                LDA     23,S   ; fccstk d=8 b=15
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
                FGX2_FARCALL _llong_conv_is
                TAY
                TSC
                CLC
                ADC     #16
                TCS
                TYA
                CMP     #0
                BNE     _llong_conv_L27
                LDA     #15
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-2
                TCS
                BRL     main_bandx
_llong_conv_L27
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0002
                JSR     _fcc_long_neg
                STA     11,S   ; fccstk d=0 b=11
                TAY
                LDA     _fcc_long_hi
                STA     13,S   ; fccstk d=0 b=13
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
                LDA     21,S   ; fccstk d=8 b=13
                STA     _fcc_long_hi
                LDA     19,S   ; fccstk d=8 b=11
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
                FGX2_FARCALL _fcc_ll_cmps
                CMP     #1
                BEQ     *+7
                LDA     #0
                BRA     *+5
                LDA     #1
                CMP     #0
                BEQ     _llong_conv_L29
                LDA     13,S   ; fccstk d=0 b=13
                STA     _fcc_long_hi
                LDA     11,S   ; fccstk d=0 b=11
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
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
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                LDX     #0
                BIT     _fcc_long_hi
                BPL     *+5
                LDX     #$FFFF
                STX     _fcc_q2
                STX     _fcc_q3
                FGX2_FARCALL _fcc_ll_cmps
                BMI     *+7
                LDA     #0
                BRA     *+5
                LDA     #1
                BNE     _llong_conv_L28
_llong_conv_L29
                LDA     #16
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-2
                TCS
                BRL     main_bandx
_llong_conv_L28
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
                LDA     #u
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _llong_conv_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
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
                BEQ     _llong_conv_L30
                LDA     #17
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-2
                TCS
                BRL     main_bandx
_llong_conv_L30
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
                LDA     u+6
                STA     _fcc_q3
                LDA     u+4
                STA     _fcc_q2
                LDA     u+2
                STA     _fcc_long_hi
                LDA     u
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                LDX     _fcc_q2
                STX     _fcc_qb2
                LDX     _fcc_q3
                STX     _fcc_qb3
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
                BNE     _llong_conv_L31
                LDA     #18
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-2
                TCS
                BRL     main_bandx
_llong_conv_L31
                LDA     #$FFFD
                STA     1,S   ; fccstk d=0 b=1
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
                FGX2_FARCALL _llong_conv_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     3,S   ; fccstk d=0 b=3
                CMP     #0
                BEQ     _llong_conv_L32
                LDA     b+6
                STA     _fcc_q3
                LDA     b+4
                STA     _fcc_q2
                LDA     b+2
                STA     _fcc_long_hi
                LDA     b
                BRA     _llong_conv_L33
_llong_conv_L32
                LDA     1,S   ; fccstk d=0 b=1
                JSR     _fcc_long_from_int
                LDX     #0
                BIT     _fcc_long_hi
                BPL     *+5
                LDX     #$FFFF
                STX     _fcc_q2
                STX     _fcc_q3
_llong_conv_L33
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
                FGX2_FARCALL _llong_conv_is
                TAY
                TSC
                CLC
                ADC     #16
                TCS
                TYA
                BNE     _llong_conv_L34
                LDA     #19
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-2
                TCS
                BRL     main_bandx
_llong_conv_L34
                LDA     5,S   ; fccstk d=0 b=5
                CMP     #0
                BEQ     _llong_conv_L35
                LDA     b+6
                STA     _fcc_q3
                LDA     b+4
                STA     _fcc_q2
                LDA     b+2
                STA     _fcc_long_hi
                LDA     b
                BRA     _llong_conv_L36
_llong_conv_L35
                LDA     1,S   ; fccstk d=0 b=1
                JSR     _fcc_long_from_int
                LDX     #0
                BIT     _fcc_long_hi
                BPL     *+5
                LDX     #$FFFF
                STX     _fcc_q2
                STX     _fcc_q3
_llong_conv_L36
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
                FGX2_FARCALL _llong_conv_is
                TAY
                TSC
                CLC
                ADC     #16
                TCS
                TYA
                BNE     _llong_conv_L37
                LDA     #20
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-2
                TCS
                BRL     main_bandx
_llong_conv_L37
                LDA     3,S   ; fccstk d=0 b=3
                CMP     #0
                BEQ     _llong_conv_L38
                LDA     1,S   ; fccstk d=0 b=1
                JSR     _fcc_long_from_int
                LDX     #0
                BIT     _fcc_long_hi
                BPL     *+5
                LDX     #$FFFF
                STX     _fcc_q2
                STX     _fcc_q3
                BRA     _llong_conv_L39
_llong_conv_L38
                LDA     b+6
                STA     _fcc_q3
                LDA     b+4
                STA     _fcc_q2
                LDA     b+2
                STA     _fcc_long_hi
                LDA     b
_llong_conv_L39
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
                FGX2_FARCALL _llong_conv_is
                TAY
                TSC
                CLC
                ADC     #16
                TCS
                TYA
                BNE     _llong_conv_L40
                LDA     #21
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-2
                TCS
                BRL     main_bandx
_llong_conv_L40
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$9C40
                STA     9,S   ; fccstk d=0 b=9
                LDA     5,S   ; fccstk d=0 b=5
                BEQ     _llong_conv_L41
                LDA     b+6
                STA     _fcc_q3
                LDA     b+4
                STA     _fcc_q2
                LDA     b+2
                STA     _fcc_long_hi
                LDA     b
                BRA     _llong_conv_L42
_llong_conv_L41
                LDA     9,S   ; fccstk d=0 b=9
                LDX     #0
                STX     _fcc_long_hi
                STZ     _fcc_q2
                STZ     _fcc_q3
_llong_conv_L42
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
                LDA     #$9C40
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
                FGX2_FARCALL _llong_conv_is
                TAY
                TSC
                CLC
                ADC     #16
                TCS
                TYA
                CMP     #0
                BNE     _llong_conv_L43
                LDA     #22
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-2
                TCS
                BRL     main_bandx
_llong_conv_L43
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0001
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
                FGX2_FARCALL _llong_conv_put
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
                FGX2_FARCALL _llong_conv_sw
                TAY
                TSC
                CLC
                ADC     #8
                TCS
                TYA
                TAX
                CMP     #1
                BEQ     _llong_conv_L44
                LDA     #23
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-2
                TCS
                BRL     main_bandx
_llong_conv_L44
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
                FGX2_FARCALL _llong_conv_put
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
                FGX2_FARCALL _llong_conv_sw
                TAY
                TSC
                CLC
                ADC     #8
                TCS
                TYA
                TAX
                CMP     #2
                BEQ     _llong_conv_L45
                LDA     #24
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-2
                TCS
                BRL     main_bandx
_llong_conv_L45
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
                FGX2_FARCALL _llong_conv_put
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
                FGX2_FARCALL _llong_conv_sw
                TAY
                TSC
                CLC
                ADC     #8
                TCS
                TYA
                TAX
                CMP     #3
                BEQ     _llong_conv_L46
                LDA     #25
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-2
                TCS
                BRL     main_bandx
_llong_conv_L46
                LDA     #$7FFF
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
                FGX2_FARCALL _llong_conv_put
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
                FGX2_FARCALL _llong_conv_sw
                TAY
                TSC
                CLC
                ADC     #8
                TCS
                TYA
                TAX
                CMP     #4
                BEQ     _llong_conv_L47
                LDA     #26
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-2
                TCS
                BRL     main_bandx
_llong_conv_L47
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
                FGX2_FARCALL _llong_conv_put
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
                FGX2_FARCALL _llong_conv_sw
                TAY
                TSC
                CLC
                ADC     #8
                TCS
                TYA
                TAX
                CMP     #9
                BEQ     _llong_conv_L48
                LDA     #27
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-2
                TCS
                BRL     main_bandx
_llong_conv_L48
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
                FGX2_FARCALL _llong_conv_put
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
                FGX2_FARCALL _llong_conv_sw
                TAY
                TSC
                CLC
                ADC     #8
                TCS
                TYA
                TAX
                CMP     #9
                BEQ     _llong_conv_L49
                LDA     #28
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-2
                TCS
                BRL     main_bandx
_llong_conv_L49
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
                FGX2_FARCALL _llong_conv_put
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
                PHA
                FGX2_FARCALL takes_int
                TAY
                PLA
                TYA
                TAX
                CMP     #52719
                BEQ     _llong_conv_L50
                LDA     #29
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-2
                TCS
                BRL     main_bandx
_llong_conv_L50
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
                FGX2_FARCALL takes_long
                TAY
                TSC
                CLC
                ADC     #4
                TCS
                TYA
                LDX     #52719
                STX     _fcc_long_b_lo
                LDX     #35243
                STX     _fcc_long_b_hi
                JSR     _fcc_long_ne
                CMP     #0
                BEQ     _llong_conv_L51
                LDA     #30
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-2
                TCS
                BRL     main_bandx
_llong_conv_L51
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
                FGX2_FARCALL narrows
                TAY
                TSC
                CLC
                ADC     #8
                TCS
                TYA
                TAX
                CMP     #52719
                BEQ     _llong_conv_L52
                LDA     #31
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-2
                TCS
                BRL     main_bandx
_llong_conv_L52
                LDA     #$FFF9
                STA     1,S   ; fccstk d=0 b=1
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0007
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
                LDA     9,S   ; fccstk d=8 b=1
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
                FGX2_FARCALL takes_ll
                TAY
                TSC
                CLC
                ADC     #8
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
                FGX2_FARCALL _llong_conv_is
                TAY
                TSC
                CLC
                ADC     #16
                TCS
                TYA
                BNE     _llong_conv_L53
                LDA     #32
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-2
                TCS
                BRL     main_bandx
_llong_conv_L53
                LDA     #$FFFF
                STA     _fcc_long_hi
                LDA     #$FFFF
                STA     15,S   ; fccstk d=0 b=15
                TAY
                LDA     _fcc_long_hi
                STA     17,S   ; fccstk d=0 b=17
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
                LDA     25,S   ; fccstk d=8 b=17
                STA     _fcc_long_hi
                LDA     23,S   ; fccstk d=8 b=15
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
                FGX2_FARCALL takes_ll
                TAY
                TSC
                CLC
                ADC     #8
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
                FGX2_FARCALL _llong_conv_is
                TAY
                TSC
                CLC
                ADC     #16
                TCS
                TYA
                BNE     _llong_conv_L54
                LDA     #33
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-2
                TCS
                BRL     main_bandx
_llong_conv_L54
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
                FGX2_FARCALL _llong_conv_put
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
                FGX2_FARCALL _llong_conv_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     #0
                STA     _fcc_img16
_llong_conv_L55
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     a+6
                STA     _fcc_q3
                LDA     a+4
                STA     _fcc_q2
                LDA     a+2
                STA     _fcc_long_hi
                LDA     a
                ORA     _fcc_long_hi
                ORA     _fcc_q2
                ORA     _fcc_q3
                BNE     *+5
                BRL     _llong_conv_L56
                LDA     _fcc_img16
                SEC
                SBC     #3
                BVC     _llong_conv_L57
                EOR     #$8000
_llong_conv_L57
                BMI     *+5
                BRL     _llong_conv_L56
                INC     _fcc_img16
                LDA     _fcc_img16
                TAX
                CMP     #2
                BEQ     *+5
                BRL     _llong_conv_L58
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
                TAY
                PLA
                STA     _fcc_long_hi
                PLA
                STA     _fcc_q2
                PLA
                STA     _fcc_q3
                TYA
                FGX2_FARCALL _fcc_ll_sub
                STA     a
                TAY
                LDA     _fcc_long_hi
                STA     a+2
                LDA     _fcc_q2
                STA     a+4
                LDA     _fcc_q3
                STA     a+6
                TYA
_llong_conv_L58
                BRL     _llong_conv_L55
_llong_conv_L56
                LDA     _fcc_img16
                TAX
                CMP     #2
                BEQ     _llong_conv_L59
                LDA     #34
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-2
                TCS
                BRA     main_bandx
_llong_conv_L59
                LDA     #42
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-2
                TCS
main_bandx
                PLA
                STA     _fcc_img16
                PLA
                STA     _fcc_fb
                TYA
                RTL
main_FRAMESIZE   EQU     22
main_STKGUARD    EQU     0
                FGX2_RELOC_COUNT 61
