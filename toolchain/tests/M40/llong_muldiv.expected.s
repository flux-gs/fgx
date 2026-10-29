                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from llong_muldiv.c
;---------------------------------------

                MX      %00
                FGX2_EXPORT _llong_muldiv_put
_llong_muldiv_put            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #_llong_muldiv_put_FRAMESIZE
                DO      _llong_muldiv_put_STKGUARD
                BCC     _llong_muldiv_put_stkovf
                CMP     _fcc_stkfloor
                BCS     _llong_muldiv_put_stkok
_llong_muldiv_put_stkovf       JMP     _fcc_stkoflow
                FIN
_llong_muldiv_put_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      8+_llong_muldiv_put_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_llong_muldiv_put_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_llong_muldiv_put_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+_llong_muldiv_put_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_llong_muldiv_put_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_llong_muldiv_put_FRAMESIZE,S   ; fccstk d=0 b=6 fs
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
                DO      20+_llong_muldiv_put_FRAMESIZE/256
                TSC
                CLC
                ADC     #20+_llong_muldiv_put_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     20+_llong_muldiv_put_FRAMESIZE,S   ; fccstk d=4 b=16 fs
                FIN
                STA     _fcc_long_hi
                DO      18+_llong_muldiv_put_FRAMESIZE/256
                TSC
                CLC
                ADC     #18+_llong_muldiv_put_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     18+_llong_muldiv_put_FRAMESIZE,S   ; fccstk d=4 b=14 fs
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
                DO      16+_llong_muldiv_put_FRAMESIZE/256
                TSC
                CLC
                ADC     #16+_llong_muldiv_put_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     16+_llong_muldiv_put_FRAMESIZE,S   ; fccstk d=4 b=12 fs
                FIN
                STA     _fcc_long_hi
                DO      14+_llong_muldiv_put_FRAMESIZE/256
                TSC
                CLC
                ADC     #14+_llong_muldiv_put_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     14+_llong_muldiv_put_FRAMESIZE,S   ; fccstk d=4 b=10 fs
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
                ADC     #_llong_muldiv_put_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_llong_muldiv_put_FRAMESIZE   EQU     4
_llong_muldiv_put_STKGUARD    EQU     0
                FGX2_EXPORT _llong_muldiv_is
_llong_muldiv_is            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #_llong_muldiv_is_FRAMESIZE
                DO      _llong_muldiv_is_STKGUARD
                BCC     _llong_muldiv_is_stkovf
                CMP     _fcc_stkfloor
                BCS     _llong_muldiv_is_stkok
_llong_muldiv_is_stkovf       JMP     _fcc_stkoflow
                FIN
_llong_muldiv_is_stkok        TCS
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
                ADC     #6+_llong_muldiv_is_FRAMESIZE
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
                DO      24+_llong_muldiv_is_FRAMESIZE/256
                TSC
                CLC
                ADC     #24+_llong_muldiv_is_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     24+_llong_muldiv_is_FRAMESIZE,S   ; fccstk d=4 b=20 fs
                FIN
                STA     _fcc_long_hi
                DO      22+_llong_muldiv_is_FRAMESIZE/256
                TSC
                CLC
                ADC     #22+_llong_muldiv_is_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     22+_llong_muldiv_is_FRAMESIZE,S   ; fccstk d=4 b=18 fs
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
                BEQ     _llong_muldiv_L0
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
                DO      20+_llong_muldiv_is_FRAMESIZE/256
                TSC
                CLC
                ADC     #20+_llong_muldiv_is_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     20+_llong_muldiv_is_FRAMESIZE,S   ; fccstk d=4 b=16 fs
                FIN
                STA     _fcc_long_hi
                DO      18+_llong_muldiv_is_FRAMESIZE/256
                TSC
                CLC
                ADC     #18+_llong_muldiv_is_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     18+_llong_muldiv_is_FRAMESIZE,S   ; fccstk d=4 b=14 fs
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
                BEQ     _llong_muldiv_L0
                LDA     #1
                BRA     _llong_muldiv_L1
_llong_muldiv_L0
                LDA     #0
_llong_muldiv_L1
                TAY
                TSC
                CLC
                ADC     #_llong_muldiv_is_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_llong_muldiv_is_FRAMESIZE   EQU     4
_llong_muldiv_is_STKGUARD    EQU     0
                FGX2_EXPORT _llong_muldiv_uis
_llong_muldiv_uis            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #_llong_muldiv_uis_FRAMESIZE
                DO      _llong_muldiv_uis_STKGUARD
                BCC     _llong_muldiv_uis_stkovf
                CMP     _fcc_stkfloor
                BCS     _llong_muldiv_uis_stkok
_llong_muldiv_uis_stkovf       JMP     _fcc_stkoflow
                FIN
_llong_muldiv_uis_stkok        TCS
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
                ADC     #6+_llong_muldiv_uis_FRAMESIZE
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
                DO      24+_llong_muldiv_uis_FRAMESIZE/256
                TSC
                CLC
                ADC     #24+_llong_muldiv_uis_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     24+_llong_muldiv_uis_FRAMESIZE,S   ; fccstk d=4 b=20 fs
                FIN
                STA     _fcc_long_hi
                DO      22+_llong_muldiv_uis_FRAMESIZE/256
                TSC
                CLC
                ADC     #22+_llong_muldiv_uis_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     22+_llong_muldiv_uis_FRAMESIZE,S   ; fccstk d=4 b=18 fs
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
                BEQ     _llong_muldiv_L2
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
                DO      20+_llong_muldiv_uis_FRAMESIZE/256
                TSC
                CLC
                ADC     #20+_llong_muldiv_uis_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     20+_llong_muldiv_uis_FRAMESIZE,S   ; fccstk d=4 b=16 fs
                FIN
                STA     _fcc_long_hi
                DO      18+_llong_muldiv_uis_FRAMESIZE/256
                TSC
                CLC
                ADC     #18+_llong_muldiv_uis_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     18+_llong_muldiv_uis_FRAMESIZE,S   ; fccstk d=4 b=14 fs
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
                BEQ     _llong_muldiv_L2
                LDA     #1
                BRA     _llong_muldiv_L3
_llong_muldiv_L2
                LDA     #0
_llong_muldiv_L3
                TAY
                TSC
                CLC
                ADC     #_llong_muldiv_uis_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_llong_muldiv_uis_FRAMESIZE   EQU     4
_llong_muldiv_uis_STKGUARD    EQU     0
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
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0003
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
                FGX2_FARCALL _llong_muldiv_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
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
                LDA     #b
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _llong_muldiv_put
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
                FGX2_FARCALL _fcc_ll_mul
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
                LDA     #$000F
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
                FGX2_FARCALL _llong_muldiv_is
                TAY
                TSC
                CLC
                ADC     #16
                TCS
                TYA
                BNE     _llong_muldiv_L4
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
_llong_muldiv_L4
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
                FGX2_FARCALL _llong_muldiv_put
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
                FGX2_FARCALL _llong_muldiv_put
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
                FGX2_FARCALL _fcc_ll_mul
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
                FGX2_FARCALL _llong_muldiv_is
                TAY
                TSC
                CLC
                ADC     #16
                TCS
                TYA
                BNE     _llong_muldiv_L5
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
_llong_muldiv_L5
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
                FGX2_FARCALL _llong_muldiv_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0010
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
                FGX2_FARCALL _llong_muldiv_put
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
                FGX2_FARCALL _fcc_ll_mul
                STA     r
                TAY
                LDA     _fcc_long_hi
                STA     r+2
                LDA     _fcc_q2
                STA     r+4
                LDA     _fcc_q3
                STA     r+6
                TYA
                LDA     #$9ABC
                STA     _fcc_long_hi
                LDA     #$DEF0
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$1234
                STA     _fcc_long_hi
                LDA     #$5678
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
                FGX2_FARCALL _llong_muldiv_is
                TAY
                TSC
                CLC
                ADC     #16
                TCS
                TYA
                BNE     _llong_muldiv_L6
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
_llong_muldiv_L6
                LDA     #$FFFF
                STA     _fcc_long_hi
                LDA     #$FFF9
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
                FGX2_FARCALL _llong_muldiv_put
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
                FGX2_FARCALL _llong_muldiv_put
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
                FGX2_FARCALL _fcc_ll_mul
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
                LDA     #$FFD6
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
                FGX2_FARCALL _llong_muldiv_is
                TAY
                TSC
                CLC
                ADC     #16
                TCS
                TYA
                BNE     _llong_muldiv_L7
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
_llong_muldiv_L7
                LDA     #$FFFF
                STA     _fcc_long_hi
                LDA     #$FFF9
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
                FGX2_FARCALL _llong_muldiv_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     #$FFFF
                STA     _fcc_long_hi
                LDA     #$FFFA
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
                LDA     #b
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _llong_muldiv_put
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
                FGX2_FARCALL _fcc_ll_mul
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
                LDA     #$002A
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
                FGX2_FARCALL _llong_muldiv_is
                TAY
                TSC
                CLC
                ADC     #16
                TCS
                TYA
                BNE     _llong_muldiv_L8
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
_llong_muldiv_L8
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
                FGX2_FARCALL _llong_muldiv_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
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
                FGX2_FARCALL _llong_muldiv_put
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
                FGX2_FARCALL _fcc_ll_mul
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
                FGX2_FARCALL _llong_muldiv_is
                TAY
                TSC
                CLC
                ADC     #16
                TCS
                TYA
                BNE     _llong_muldiv_L9
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
_llong_muldiv_L9
                LDA     #$CAFE
                STA     _fcc_long_hi
                LDA     #$BABE
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$DEAD
                STA     _fcc_long_hi
                LDA     #$BEEF
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
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
                FGX2_FARCALL _llong_muldiv_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     #$2345
                STA     _fcc_long_hi
                LDA     #$6789
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
                LDA     #b
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _llong_muldiv_put
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
                FGX2_FARCALL _fcc_ll_mul
                STA     r
                TAY
                LDA     _fcc_long_hi
                STA     r+2
                LDA     _fcc_q2
                STA     r+4
                LDA     _fcc_q3
                STA     r+6
                TYA
                LDA     #$6EAA
                STA     _fcc_long_hi
                LDA     #$61AE
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$1D2E
                STA     _fcc_long_hi
                LDA     #$EDEE
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
                FGX2_FARCALL _llong_muldiv_is
                TAY
                TSC
                CLC
                ADC     #16
                TCS
                TYA
                BNE     _llong_muldiv_L10
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
_llong_muldiv_L10
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
                FGX2_FARCALL _llong_muldiv_put
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
                FGX2_FARCALL _llong_muldiv_put
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
                FGX2_FARCALL _fcc_ll_mul
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
                FGX2_FARCALL _llong_muldiv_is
                TAY
                TSC
                CLC
                ADC     #16
                TCS
                TYA
                BNE     _llong_muldiv_L11
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
_llong_muldiv_L11
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
                FGX2_FARCALL _llong_muldiv_put
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
                FGX2_FARCALL _llong_muldiv_put
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
                FGX2_FARCALL _fcc_ll_mul
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
                FGX2_FARCALL _llong_muldiv_is
                TAY
                TSC
                CLC
                ADC     #16
                TCS
                TYA
                BNE     _llong_muldiv_L12
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
_llong_muldiv_L12
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0064
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
                FGX2_FARCALL _llong_muldiv_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0007
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
                FGX2_FARCALL _llong_muldiv_put
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
                FGX2_FARCALL _fcc_ll_divu
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
                LDA     #$000E
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
                FGX2_FARCALL _llong_muldiv_uis
                TAY
                TSC
                CLC
                ADC     #16
                TCS
                TYA
                BNE     _llong_muldiv_L13
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
_llong_muldiv_L13
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0064
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
                FGX2_FARCALL _llong_muldiv_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0007
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
                FGX2_FARCALL _llong_muldiv_put
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
                FGX2_FARCALL _fcc_ll_modu
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
                FGX2_FARCALL _llong_muldiv_uis
                TAY
                TSC
                CLC
                ADC     #16
                TCS
                TYA
                BNE     _llong_muldiv_L14
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
_llong_muldiv_L14
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
                FGX2_FARCALL _llong_muldiv_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0003
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
                FGX2_FARCALL _llong_muldiv_put
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
                FGX2_FARCALL _fcc_ll_divu
                STA     u
                TAY
                LDA     _fcc_long_hi
                STA     u+2
                LDA     _fcc_q2
                STA     u+4
                LDA     _fcc_q3
                STA     u+6
                TYA
                LDA     #$5555
                STA     _fcc_long_hi
                LDA     #$5555
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$5555
                STA     _fcc_long_hi
                LDA     #$5555
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
                FGX2_FARCALL _llong_muldiv_uis
                TAY
                TSC
                CLC
                ADC     #16
                TCS
                TYA
                BNE     _llong_muldiv_L15
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
_llong_muldiv_L15
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
                FGX2_FARCALL _llong_muldiv_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0003
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
                FGX2_FARCALL _llong_muldiv_put
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
                FGX2_FARCALL _fcc_ll_modu
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
                FGX2_FARCALL _llong_muldiv_uis
                TAY
                TSC
                CLC
                ADC     #16
                TCS
                TYA
                BNE     _llong_muldiv_L16
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
_llong_muldiv_L16
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
                FGX2_FARCALL _llong_muldiv_put
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
                LDA     #ub
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _llong_muldiv_put
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
                FGX2_FARCALL _fcc_ll_divu
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
                FGX2_FARCALL _llong_muldiv_uis
                TAY
                TSC
                CLC
                ADC     #16
                TCS
                TYA
                BNE     _llong_muldiv_L17
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
_llong_muldiv_L17
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
                FGX2_FARCALL _llong_muldiv_put
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
                LDA     #ub
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _llong_muldiv_put
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
                FGX2_FARCALL _fcc_ll_modu
                STA     u
                TAY
                LDA     _fcc_long_hi
                STA     u+2
                LDA     _fcc_q2
                STA     u+4
                LDA     _fcc_q3
                STA     u+6
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
                FGX2_FARCALL _llong_muldiv_uis
                TAY
                TSC
                CLC
                ADC     #16
                TCS
                TYA
                BNE     _llong_muldiv_L18
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
_llong_muldiv_L18
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
                FGX2_FARCALL _llong_muldiv_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
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
                FGX2_FARCALL _llong_muldiv_put
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
                FGX2_FARCALL _fcc_ll_divu
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
                FGX2_FARCALL _llong_muldiv_uis
                TAY
                TSC
                CLC
                ADC     #16
                TCS
                TYA
                BNE     _llong_muldiv_L19
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
_llong_muldiv_L19
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
                FGX2_FARCALL _llong_muldiv_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
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
                FGX2_FARCALL _llong_muldiv_put
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
                FGX2_FARCALL _fcc_ll_modu
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
                FGX2_FARCALL _llong_muldiv_uis
                TAY
                TSC
                CLC
                ADC     #16
                TCS
                TYA
                BNE     _llong_muldiv_L20
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
_llong_muldiv_L20
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
                FGX2_FARCALL _llong_muldiv_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
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
                FGX2_FARCALL _llong_muldiv_put
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
                FGX2_FARCALL _fcc_ll_divu
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
                FGX2_FARCALL _llong_muldiv_uis
                TAY
                TSC
                CLC
                ADC     #16
                TCS
                TYA
                BNE     _llong_muldiv_L21
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
_llong_muldiv_L21
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
                FGX2_FARCALL _llong_muldiv_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
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
                FGX2_FARCALL _llong_muldiv_put
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
                FGX2_FARCALL _fcc_ll_modu
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
                FGX2_FARCALL _llong_muldiv_uis
                TAY
                TSC
                CLC
                ADC     #16
                TCS
                TYA
                BNE     _llong_muldiv_L22
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
_llong_muldiv_L22
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
                LDA     #ua
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _llong_muldiv_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     #$FEDC
                STA     _fcc_long_hi
                LDA     #$BA98
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
                FGX2_FARCALL _llong_muldiv_put
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
                FGX2_FARCALL _fcc_ll_divu
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
                FGX2_FARCALL _llong_muldiv_uis
                TAY
                TSC
                CLC
                ADC     #16
                TCS
                TYA
                BNE     _llong_muldiv_L23
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
_llong_muldiv_L23
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
                LDA     #ua
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _llong_muldiv_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     #$FEDC
                STA     _fcc_long_hi
                LDA     #$BA98
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
                FGX2_FARCALL _llong_muldiv_put
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
                FGX2_FARCALL _fcc_ll_modu
                STA     u
                TAY
                LDA     _fcc_long_hi
                STA     u+2
                LDA     _fcc_q2
                STA     u+4
                LDA     _fcc_q3
                STA     u+6
                TYA
                LDA     #$7654
                STA     _fcc_long_hi
                LDA     #$3210
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
                FGX2_FARCALL _llong_muldiv_uis
                TAY
                TSC
                CLC
                ADC     #16
                TCS
                TYA
                BNE     _llong_muldiv_L24
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
_llong_muldiv_L24
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$3039
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
                FGX2_FARCALL _llong_muldiv_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$3039
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
                FGX2_FARCALL _llong_muldiv_put
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
                FGX2_FARCALL _fcc_ll_divu
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
                FGX2_FARCALL _llong_muldiv_uis
                TAY
                TSC
                CLC
                ADC     #16
                TCS
                TYA
                BNE     _llong_muldiv_L25
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
_llong_muldiv_L25
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$3039
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
                FGX2_FARCALL _llong_muldiv_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$3039
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
                FGX2_FARCALL _llong_muldiv_put
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
                FGX2_FARCALL _fcc_ll_modu
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
                FGX2_FARCALL _llong_muldiv_uis
                TAY
                TSC
                CLC
                ADC     #16
                TCS
                TYA
                BNE     _llong_muldiv_L26
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
_llong_muldiv_L26
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
                LDA     #ua
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _llong_muldiv_put
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
                LDA     #ub
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _llong_muldiv_put
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
                FGX2_FARCALL _fcc_ll_divu
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
                FGX2_FARCALL _llong_muldiv_uis
                TAY
                TSC
                CLC
                ADC     #16
                TCS
                TYA
                BNE     _llong_muldiv_L27
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
_llong_muldiv_L27
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
                LDA     #ua
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _llong_muldiv_put
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
                LDA     #ub
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _llong_muldiv_put
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
                FGX2_FARCALL _fcc_ll_modu
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
                FGX2_FARCALL _llong_muldiv_uis
                TAY
                TSC
                CLC
                ADC     #16
                TCS
                TYA
                BNE     _llong_muldiv_L28
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
_llong_muldiv_L28
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0064
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
                FGX2_FARCALL _llong_muldiv_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0007
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
                FGX2_FARCALL _llong_muldiv_put
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
                FGX2_FARCALL _fcc_ll_divs
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
                LDA     #$000E
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
                FGX2_FARCALL _llong_muldiv_is
                TAY
                TSC
                CLC
                ADC     #16
                TCS
                TYA
                BNE     _llong_muldiv_L29
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
_llong_muldiv_L29
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0064
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
                FGX2_FARCALL _llong_muldiv_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0007
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
                FGX2_FARCALL _llong_muldiv_put
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
                FGX2_FARCALL _fcc_ll_mods
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
                FGX2_FARCALL _llong_muldiv_is
                TAY
                TSC
                CLC
                ADC     #16
                TCS
                TYA
                BNE     _llong_muldiv_L30
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
_llong_muldiv_L30
                LDA     #$FFFF
                STA     _fcc_long_hi
                LDA     #$FF9C
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
                FGX2_FARCALL _llong_muldiv_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0007
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
                FGX2_FARCALL _llong_muldiv_put
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
                FGX2_FARCALL _fcc_ll_divs
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
                LDA     #$FFF2
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
                FGX2_FARCALL _llong_muldiv_is
                TAY
                TSC
                CLC
                ADC     #16
                TCS
                TYA
                BNE     _llong_muldiv_L31
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
_llong_muldiv_L31
                LDA     #$FFFF
                STA     _fcc_long_hi
                LDA     #$FF9C
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
                FGX2_FARCALL _llong_muldiv_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0007
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
                FGX2_FARCALL _llong_muldiv_put
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
                FGX2_FARCALL _fcc_ll_mods
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
                FGX2_FARCALL _llong_muldiv_is
                TAY
                TSC
                CLC
                ADC     #16
                TCS
                TYA
                BNE     _llong_muldiv_L32
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
_llong_muldiv_L32
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0064
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
                FGX2_FARCALL _llong_muldiv_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     #$FFFF
                STA     _fcc_long_hi
                LDA     #$FFF9
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
                LDA     #b
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _llong_muldiv_put
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
                FGX2_FARCALL _fcc_ll_divs
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
                LDA     #$FFF2
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
                FGX2_FARCALL _llong_muldiv_is
                TAY
                TSC
                CLC
                ADC     #16
                TCS
                TYA
                BNE     _llong_muldiv_L33
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
_llong_muldiv_L33
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0064
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
                FGX2_FARCALL _llong_muldiv_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     #$FFFF
                STA     _fcc_long_hi
                LDA     #$FFF9
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
                LDA     #b
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _llong_muldiv_put
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
                FGX2_FARCALL _fcc_ll_mods
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
                FGX2_FARCALL _llong_muldiv_is
                TAY
                TSC
                CLC
                ADC     #16
                TCS
                TYA
                BNE     _llong_muldiv_L34
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
_llong_muldiv_L34
                LDA     #$FFFF
                STA     _fcc_long_hi
                LDA     #$FF9C
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
                FGX2_FARCALL _llong_muldiv_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     #$FFFF
                STA     _fcc_long_hi
                LDA     #$FFF9
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
                LDA     #b
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _llong_muldiv_put
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
                FGX2_FARCALL _fcc_ll_divs
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
                LDA     #$000E
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
                FGX2_FARCALL _llong_muldiv_is
                TAY
                TSC
                CLC
                ADC     #16
                TCS
                TYA
                BNE     _llong_muldiv_L35
                LDA     #32
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_llong_muldiv_L35
                LDA     #$FFFF
                STA     _fcc_long_hi
                LDA     #$FF9C
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
                FGX2_FARCALL _llong_muldiv_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     #$FFFF
                STA     _fcc_long_hi
                LDA     #$FFF9
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
                LDA     #b
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _llong_muldiv_put
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
                FGX2_FARCALL _fcc_ll_mods
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
                FGX2_FARCALL _llong_muldiv_is
                TAY
                TSC
                CLC
                ADC     #16
                TCS
                TYA
                BNE     _llong_muldiv_L36
                LDA     #33
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_llong_muldiv_L36
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
                FGX2_FARCALL _llong_muldiv_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0003
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
                FGX2_FARCALL _llong_muldiv_put
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
                FGX2_FARCALL _fcc_ll_divs
                STA     r
                TAY
                LDA     _fcc_long_hi
                STA     r+2
                LDA     _fcc_q2
                STA     r+4
                LDA     _fcc_q3
                STA     r+6
                TYA
                LDA     #$AAAA
                STA     _fcc_long_hi
                LDA     #$AAAB
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$EAAA
                STA     _fcc_long_hi
                LDA     #$AAAA
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
                FGX2_FARCALL _llong_muldiv_is
                TAY
                TSC
                CLC
                ADC     #16
                TCS
                TYA
                BNE     _llong_muldiv_L37
                LDA     #34
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_llong_muldiv_L37
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
                FGX2_FARCALL _llong_muldiv_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0003
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
                FGX2_FARCALL _llong_muldiv_put
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
                FGX2_FARCALL _fcc_ll_mods
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
                FGX2_FARCALL _llong_muldiv_is
                TAY
                TSC
                CLC
                ADC     #16
                TCS
                TYA
                BNE     _llong_muldiv_L38
                LDA     #35
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_llong_muldiv_L38
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
                FGX2_FARCALL _llong_muldiv_put
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
                LDA     #b
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _llong_muldiv_put
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
                FGX2_FARCALL _fcc_ll_divs
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
                FGX2_FARCALL _llong_muldiv_is
                TAY
                TSC
                CLC
                ADC     #16
                TCS
                TYA
                BNE     _llong_muldiv_L39
                LDA     #36
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_llong_muldiv_L39
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
                FGX2_FARCALL _llong_muldiv_put
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
                LDA     #b
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _llong_muldiv_put
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
                FGX2_FARCALL _fcc_ll_mods
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
                FGX2_FARCALL _llong_muldiv_is
                TAY
                TSC
                CLC
                ADC     #16
                TCS
                TYA
                BNE     _llong_muldiv_L40
                LDA     #37
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_llong_muldiv_L40
                LDA     #$FFFF
                STA     _fcc_long_hi
                LDA     #$FFFB
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
                FGX2_FARCALL _llong_muldiv_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$000A
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
                FGX2_FARCALL _llong_muldiv_put
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
                FGX2_FARCALL _fcc_ll_divs
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
                FGX2_FARCALL _llong_muldiv_is
                TAY
                TSC
                CLC
                ADC     #16
                TCS
                TYA
                BNE     _llong_muldiv_L41
                LDA     #38
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_llong_muldiv_L41
                LDA     #$FFFF
                STA     _fcc_long_hi
                LDA     #$FFFB
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
                FGX2_FARCALL _llong_muldiv_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$000A
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
                FGX2_FARCALL _llong_muldiv_put
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
                FGX2_FARCALL _fcc_ll_mods
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
                LDA     #$FFFB
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
                FGX2_FARCALL _llong_muldiv_is
                TAY
                TSC
                CLC
                ADC     #16
                TCS
                TYA
                BNE     _llong_muldiv_L42
                LDA     #39
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_llong_muldiv_L42
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
                FGX2_FARCALL _llong_muldiv_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
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
                FGX2_FARCALL _llong_muldiv_put
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
                FGX2_FARCALL _fcc_ll_divs
                STA     r
                TAY
                LDA     _fcc_long_hi
                STA     r+2
                LDA     _fcc_q2
                STA     r+4
                LDA     _fcc_q3
                STA     r+6
                TYA
                LDA     #$BA98
                STA     _fcc_long_hi
                LDA     #$7655
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$FFFF
                STA     _fcc_long_hi
                LDA     #$FEDC
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
                FGX2_FARCALL _llong_muldiv_is
                TAY
                TSC
                CLC
                ADC     #16
                TCS
                TYA
                BNE     _llong_muldiv_L43
                LDA     #40
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_llong_muldiv_L43
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
                FGX2_FARCALL _llong_muldiv_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
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
                FGX2_FARCALL _llong_muldiv_put
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
                FGX2_FARCALL _fcc_ll_mods
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
                FGX2_FARCALL _llong_muldiv_is
                TAY
                TSC
                CLC
                ADC     #16
                TCS
                TYA
                BNE     _llong_muldiv_L44
                LDA     #41
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_llong_muldiv_L44
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
                FGX2_FARCALL _llong_muldiv_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0003
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
                FGX2_FARCALL _llong_muldiv_put
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
                FGX2_FARCALL _fcc_ll_mul
                STA     r
                TAY
                LDA     _fcc_long_hi
                STA     r+2
                LDA     _fcc_q2
                STA     r+4
                LDA     _fcc_q3
                STA     r+6
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
                FGX2_FARCALL _fcc_ll_mul
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
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
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                LDX     _fcc_q2
                STX     _fcc_qb2
                LDX     _fcc_q3
                STX     _fcc_qb3
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
                CMP     #0
                BEQ     *+5
                BRL     _llong_muldiv_L46
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
                FGX2_FARCALL _fcc_ll_mul
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
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
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                LDX     _fcc_q2
                STX     _fcc_qb2
                LDX     _fcc_q3
                STX     _fcc_qb3
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
                CMP     #0
                BEQ     *+5
                BRL     _llong_muldiv_L46
                LDA     #3
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
                FGX2_FARCALL _fcc_ll_mul
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
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
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                LDX     _fcc_q2
                STX     _fcc_qb2
                LDX     _fcc_q3
                STX     _fcc_qb3
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
                BEQ     _llong_muldiv_L45
_llong_muldiv_L46
                LDA     #43
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_llong_muldiv_L45
                LDA     #$9D03
                STA     _fcc_long_hi
                LDA     #$69CD
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0369
                STA     _fcc_long_hi
                LDA     #$D036
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
                FGX2_FARCALL _fcc_ll_mul
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                FGX2_FARCALL _llong_muldiv_is
                TAY
                TSC
                CLC
                ADC     #16
                TCS
                TYA
                CMP     #0
                BNE     _llong_muldiv_L47
                LDA     #44
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_llong_muldiv_L47
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
                FGX2_FARCALL _fcc_ll_divs
                STA     r
                TAY
                LDA     _fcc_long_hi
                STA     r+2
                LDA     _fcc_q2
                STA     r+4
                LDA     _fcc_q3
                STA     r+6
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
                FGX2_FARCALL _fcc_ll_divs
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
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
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                LDX     _fcc_q2
                STX     _fcc_qb2
                LDX     _fcc_q3
                STX     _fcc_qb3
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
                CMP     #0
                BEQ     *+5
                BRL     _llong_muldiv_L49
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
                FGX2_FARCALL _fcc_ll_divs
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
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
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                LDX     _fcc_q2
                STX     _fcc_qb2
                LDX     _fcc_q3
                STX     _fcc_qb3
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
                CMP     #0
                BEQ     *+5
                BRL     _llong_muldiv_L49
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
                FGX2_FARCALL _fcc_ll_mods
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
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
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
                FGX2_FARCALL _fcc_ll_mul
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                LDX     _fcc_q2
                STX     _fcc_qb2
                LDX     _fcc_q3
                STX     _fcc_qb3
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
                FGX2_FARCALL _fcc_ll_cmps
                BNE     *+7
                LDA     #0
                BRA     *+5
                LDA     #1
                BEQ     _llong_muldiv_L48
_llong_muldiv_L49
                LDA     #45
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_llong_muldiv_L48
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
main_FRAMESIZE   EQU     0
main_STKGUARD    EQU     0
                FGX2_RELOC_COUNT 189
