                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from ntp_model.c
;---------------------------------------

                MX      %00
                FGX2_EXPORT ul_fixed_to_double
ul_fixed_to_double            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #ul_fixed_to_double_FRAMESIZE
                DO      ul_fixed_to_double_STKGUARD
                BCC     ul_fixed_to_double_stkovf
                CMP     _fcc_stkfloor
                BCS     ul_fixed_to_double_stkok
ul_fixed_to_double_stkovf       JMP     _fcc_stkoflow
                FIN
ul_fixed_to_double_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      8+ul_fixed_to_double_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+ul_fixed_to_double_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+ul_fixed_to_double_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+ul_fixed_to_double_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+ul_fixed_to_double_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+ul_fixed_to_double_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                LDY     #6
                LDA     [_fcc_fpr0],Y
                STA     _fcc_long_hi
                LDY     #4
                LDA     [_fcc_fpr0],Y
                FGX2_FARCALL _fcc_dfromul
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
                LDA     #16880
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
                DO      8+ul_fixed_to_double_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+ul_fixed_to_double_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+ul_fixed_to_double_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+ul_fixed_to_double_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+ul_fixed_to_double_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+ul_fixed_to_double_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                LDY     #2
                LDA     [_fcc_fpr0],Y
                STA     _fcc_long_hi
                LDA     [_fcc_fpr0]
                FGX2_FARCALL _fcc_dfromul
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
                FGX2_FARCALL _fcc_dadd
                TAY
                TSC
                CLC
                ADC     #ul_fixed_to_double_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
ul_fixed_to_double_FRAMESIZE   EQU     16
ul_fixed_to_double_STKGUARD    EQU     0
                FGX2_EXPORT _ntp_model_stamp
_ntp_model_stamp            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #_ntp_model_stamp_FRAMESIZE
                DO      _ntp_model_stamp_STKGUARD
                BCC     _ntp_model_stamp_stkovf
                CMP     _fcc_stkfloor
                BCS     _ntp_model_stamp_stkok
_ntp_model_stamp_stkovf       JMP     _fcc_stkoflow
                FIN
_ntp_model_stamp_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      8+_ntp_model_stamp_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_ntp_model_stamp_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_ntp_model_stamp_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+_ntp_model_stamp_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_ntp_model_stamp_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_ntp_model_stamp_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                DO      16+_ntp_model_stamp_FRAMESIZE/256
                TSC
                CLC
                ADC     #16+_ntp_model_stamp_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     16+_ntp_model_stamp_FRAMESIZE,S   ; fccstk d=0 b=16 fs
                FIN
                STA     _fcc_q3
                DO      14+_ntp_model_stamp_FRAMESIZE/256
                TSC
                CLC
                ADC     #14+_ntp_model_stamp_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     14+_ntp_model_stamp_FRAMESIZE,S   ; fccstk d=0 b=14 fs
                FIN
                STA     _fcc_q2
                DO      12+_ntp_model_stamp_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+_ntp_model_stamp_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+_ntp_model_stamp_FRAMESIZE,S   ; fccstk d=0 b=12 fs
                FIN
                STA     _fcc_long_hi
                DO      10+_ntp_model_stamp_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+_ntp_model_stamp_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+_ntp_model_stamp_FRAMESIZE,S   ; fccstk d=0 b=10 fs
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
                LDA     #$000F
                STA     _fcc_long_hi
                LDA     #$4240
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
                FGX2_FARCALL _fcc_ll_divu
                STA     [_fcc_fpr0]
                TAX
                LDA     _fcc_long_hi
                LDY     #2
                STA     [_fcc_fpr0],Y
                TXA
                DO      8+_ntp_model_stamp_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_ntp_model_stamp_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_ntp_model_stamp_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+_ntp_model_stamp_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_ntp_model_stamp_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_ntp_model_stamp_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                DO      16+_ntp_model_stamp_FRAMESIZE/256
                TSC
                CLC
                ADC     #16+_ntp_model_stamp_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     16+_ntp_model_stamp_FRAMESIZE,S   ; fccstk d=0 b=16 fs
                FIN
                STA     _fcc_q3
                DO      14+_ntp_model_stamp_FRAMESIZE/256
                TSC
                CLC
                ADC     #14+_ntp_model_stamp_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     14+_ntp_model_stamp_FRAMESIZE,S   ; fccstk d=0 b=14 fs
                FIN
                STA     _fcc_q2
                DO      12+_ntp_model_stamp_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+_ntp_model_stamp_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+_ntp_model_stamp_FRAMESIZE,S   ; fccstk d=0 b=12 fs
                FIN
                STA     _fcc_long_hi
                DO      10+_ntp_model_stamp_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+_ntp_model_stamp_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+_ntp_model_stamp_FRAMESIZE,S   ; fccstk d=0 b=10 fs
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
                LDA     #$000F
                STA     _fcc_long_hi
                LDA     #$4240
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
                FGX2_FARCALL _fcc_ll_modu
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
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$000F
                STA     _fcc_long_hi
                LDA     #$4240
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
                FGX2_FARCALL _fcc_ll_divu
                LDY     #4
                STA     [_fcc_fpr0],Y
                TAX
                LDA     _fcc_long_hi
                LDY     #6
                STA     [_fcc_fpr0],Y
                TXA
                TAY
                TSC
                CLC
                ADC     #_ntp_model_stamp_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_ntp_model_stamp_FRAMESIZE   EQU     0
_ntp_model_stamp_STKGUARD    EQU     0
                FGX2_EXPORT _ntp_model_mag
_ntp_model_mag            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #_ntp_model_mag_FRAMESIZE
                DO      _ntp_model_mag_STKGUARD
                BCC     _ntp_model_mag_stkovf
                CMP     _fcc_stkfloor
                BCS     _ntp_model_mag_stkok
_ntp_model_mag_stkovf       JMP     _fcc_stkoflow
                FIN
_ntp_model_mag_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      12+_ntp_model_mag_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+_ntp_model_mag_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+_ntp_model_mag_FRAMESIZE,S   ; fccstk d=0 b=12 fs
                FIN
                STA     _fcc_q3
                DO      10+_ntp_model_mag_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+_ntp_model_mag_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+_ntp_model_mag_FRAMESIZE,S   ; fccstk d=0 b=10 fs
                FIN
                STA     _fcc_q2
                DO      8+_ntp_model_mag_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_ntp_model_mag_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_ntp_model_mag_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_long_hi
                DO      6+_ntp_model_mag_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_ntp_model_mag_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_ntp_model_mag_FRAMESIZE,S   ; fccstk d=0 b=6 fs
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
                BNE     *+5
                BRL     _ntp_model_L0
                DO      12+_ntp_model_mag_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+_ntp_model_mag_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+_ntp_model_mag_FRAMESIZE,S   ; fccstk d=0 b=12 fs
                FIN
                STA     _fcc_q3
                DO      10+_ntp_model_mag_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+_ntp_model_mag_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+_ntp_model_mag_FRAMESIZE,S   ; fccstk d=0 b=10 fs
                FIN
                STA     _fcc_q2
                DO      8+_ntp_model_mag_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_ntp_model_mag_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_ntp_model_mag_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_long_hi
                DO      6+_ntp_model_mag_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_ntp_model_mag_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_ntp_model_mag_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                TAY
                LDA     _fcc_q3
                EOR     #$8000
                STA     _fcc_q3
                TYA
                BRL     _ntp_model_L1
_ntp_model_L0
                DO      12+_ntp_model_mag_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+_ntp_model_mag_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+_ntp_model_mag_FRAMESIZE,S   ; fccstk d=0 b=12 fs
                FIN
                STA     _fcc_q3
                DO      10+_ntp_model_mag_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+_ntp_model_mag_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+_ntp_model_mag_FRAMESIZE,S   ; fccstk d=0 b=10 fs
                FIN
                STA     _fcc_q2
                DO      8+_ntp_model_mag_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_ntp_model_mag_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_ntp_model_mag_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_long_hi
                DO      6+_ntp_model_mag_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_ntp_model_mag_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_ntp_model_mag_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
_ntp_model_L1
                TAY
                TSC
                CLC
                ADC     #_ntp_model_mag_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_ntp_model_mag_FRAMESIZE   EQU     0
_ntp_model_mag_STKGUARD    EQU     0
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
                STA     93,S   ; fccstk d=0 b=93
_ntp_model_L2
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     93,S   ; fccstk d=0 b=93
                TAX
                TXA
                SEC
                SBC     #64
                BVC     _ntp_model_L5
                EOR     #$8000
_ntp_model_L5
                BMI     *+5
                BRL     _ntp_model_L4
                LDA     #14
                STA     _fcc_q3
                LDA     #6833
                STA     _fcc_q2
                LDA     #42946
                STA     _fcc_long_hi
                LDA     #8192
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
                LDA     #5
                STA     _fcc_long_hi
                LDA     #42320
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                LDX     _fcc_q2
                STX     _fcc_qb2
                LDX     _fcc_q3
                STX     _fcc_qb3
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
                LDA     101,S   ; fccstk d=8 b=93
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
                LDA     #0
                STA     _fcc_q3
                LDA     #0
                STA     _fcc_q2
                LDA     #61
                STA     _fcc_long_hi
                LDA     #2341
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                LDX     _fcc_q2
                STX     _fcc_qb2
                LDX     _fcc_q3
                STX     _fcc_qb3
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
                FGX2_FARCALL _fcc_ll_add
                STA     81,S   ; fccstk d=0 b=81
                TAY
                LDA     _fcc_long_hi
                STA     83,S   ; fccstk d=0 b=83
                LDA     _fcc_q2
                STA     85,S   ; fccstk d=0 b=85
                LDA     _fcc_q3
                STA     87,S   ; fccstk d=0 b=87
                TYA
                LDA     87,S   ; fccstk d=0 b=87
                STA     _fcc_q3
                LDA     85,S   ; fccstk d=0 b=85
                STA     _fcc_q2
                LDA     83,S   ; fccstk d=0 b=83
                STA     _fcc_long_hi
                LDA     81,S   ; fccstk d=0 b=81
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
                FGX2_FARCALL _ntp_model_stamp
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     87,S   ; fccstk d=0 b=87
                STA     _fcc_q3
                LDA     85,S   ; fccstk d=0 b=85
                STA     _fcc_q2
                LDA     83,S   ; fccstk d=0 b=83
                STA     _fcc_long_hi
                LDA     81,S   ; fccstk d=0 b=81
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
                LDA     #1374
                STA     _fcc_long_hi
                LDA     #54036
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                LDX     _fcc_q2
                STX     _fcc_qb2
                LDX     _fcc_q3
                STX     _fcc_qb3
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
                FGX2_FARCALL _ntp_model_stamp
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     87,S   ; fccstk d=0 b=87
                STA     _fcc_q3
                LDA     85,S   ; fccstk d=0 b=85
                STA     _fcc_q2
                LDA     83,S   ; fccstk d=0 b=83
                STA     _fcc_long_hi
                LDA     81,S   ; fccstk d=0 b=81
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
                LDA     #1374
                STA     _fcc_long_hi
                LDA     #64036
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                LDX     _fcc_q2
                STX     _fcc_qb2
                LDX     _fcc_q3
                STX     _fcc_qb3
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
                FGX2_FARCALL _ntp_model_stamp
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     87,S   ; fccstk d=0 b=87
                STA     _fcc_q3
                LDA     85,S   ; fccstk d=0 b=85
                STA     _fcc_q2
                LDA     83,S   ; fccstk d=0 b=83
                STA     _fcc_long_hi
                LDA     81,S   ; fccstk d=0 b=81
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
                LDA     #3
                STA     _fcc_long_hi
                LDA     #14392
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                LDX     _fcc_q2
                STX     _fcc_qb2
                LDX     _fcc_q3
                STX     _fcc_qb3
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
                FGX2_FARCALL _ntp_model_stamp
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
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
                FGX2_FARCALL ul_fixed_to_double
                TAY
                TSC
                CLC
                ADC     #4
                TCS
                TYA
                STA     33,S   ; fccstk d=0 b=33
                TAY
                LDA     _fcc_long_hi
                STA     35,S   ; fccstk d=0 b=35
                LDA     _fcc_q2
                STA     37,S   ; fccstk d=0 b=37
                LDA     _fcc_q3
                STA     39,S   ; fccstk d=0 b=39
                TYA
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
                FGX2_FARCALL ul_fixed_to_double
                TAY
                TSC
                CLC
                ADC     #4
                TCS
                TYA
                STA     41,S   ; fccstk d=0 b=41
                TAY
                LDA     _fcc_long_hi
                STA     43,S   ; fccstk d=0 b=43
                LDA     _fcc_q2
                STA     45,S   ; fccstk d=0 b=45
                LDA     _fcc_q3
                STA     47,S   ; fccstk d=0 b=47
                TYA
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
                FGX2_FARCALL ul_fixed_to_double
                TAY
                TSC
                CLC
                ADC     #4
                TCS
                TYA
                STA     49,S   ; fccstk d=0 b=49
                TAY
                LDA     _fcc_long_hi
                STA     51,S   ; fccstk d=0 b=51
                LDA     _fcc_q2
                STA     53,S   ; fccstk d=0 b=53
                LDA     _fcc_q3
                STA     55,S   ; fccstk d=0 b=55
                TYA
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
                FGX2_FARCALL ul_fixed_to_double
                TAY
                TSC
                CLC
                ADC     #4
                TCS
                TYA
                STA     57,S   ; fccstk d=0 b=57
                TAY
                LDA     _fcc_long_hi
                STA     59,S   ; fccstk d=0 b=59
                LDA     _fcc_q2
                STA     61,S   ; fccstk d=0 b=61
                LDA     _fcc_q3
                STA     63,S   ; fccstk d=0 b=63
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
                FGX2_FARCALL _fcc_dsub
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
                LDA     63,S   ; fccstk d=16 b=47
                STA     _fcc_q3
                LDA     61,S   ; fccstk d=16 b=45
                STA     _fcc_q2
                LDA     59,S   ; fccstk d=16 b=43
                STA     _fcc_long_hi
                LDA     57,S   ; fccstk d=16 b=41
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                LDX     _fcc_q2
                STX     _fcc_qb2
                LDX     _fcc_q3
                STX     _fcc_qb3
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
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                LDX     _fcc_q2
                STX     _fcc_qb2
                LDX     _fcc_q3
                STX     _fcc_qb3
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
                STA     65,S   ; fccstk d=0 b=65
                TAY
                LDA     _fcc_long_hi
                STA     67,S   ; fccstk d=0 b=67
                LDA     _fcc_q2
                STA     69,S   ; fccstk d=0 b=69
                LDA     _fcc_q3
                STA     71,S   ; fccstk d=0 b=71
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
                FGX2_FARCALL _fcc_dsub
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
                LDA     79,S   ; fccstk d=16 b=63
                STA     _fcc_q3
                LDA     77,S   ; fccstk d=16 b=61
                STA     _fcc_q2
                LDA     75,S   ; fccstk d=16 b=59
                STA     _fcc_long_hi
                LDA     73,S   ; fccstk d=16 b=57
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                LDX     _fcc_q2
                STX     _fcc_qb2
                LDX     _fcc_q3
                STX     _fcc_qb3
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
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                LDX     _fcc_q2
                STX     _fcc_qb2
                LDX     _fcc_q3
                STX     _fcc_qb3
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
                STA     73,S   ; fccstk d=0 b=73
                TAY
                LDA     _fcc_long_hi
                STA     75,S   ; fccstk d=0 b=75
                LDA     _fcc_q2
                STA     77,S   ; fccstk d=0 b=77
                LDA     _fcc_q3
                STA     79,S   ; fccstk d=0 b=79
                TYA
                LDA     79,S   ; fccstk d=0 b=79
                STA     _fcc_q3
                LDA     77,S   ; fccstk d=0 b=77
                STA     _fcc_q2
                LDA     75,S   ; fccstk d=0 b=75
                STA     _fcc_long_hi
                LDA     73,S   ; fccstk d=0 b=73
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #16384
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
                FGX2_FARCALL _fcc_ddiv
                STA     73,S   ; fccstk d=0 b=73
                TAY
                LDA     _fcc_long_hi
                STA     75,S   ; fccstk d=0 b=75
                LDA     _fcc_q2
                STA     77,S   ; fccstk d=0 b=77
                LDA     _fcc_q3
                STA     79,S   ; fccstk d=0 b=79
                TYA
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
                LDA     #16329
                STA     _fcc_q3
                LDA     #47710
                STA     _fcc_q2
                LDA     #13631
                STA     _fcc_long_hi
                LDA     #31982
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                LDX     _fcc_q2
                STX     _fcc_qb2
                LDX     _fcc_q3
                STX     _fcc_qb3
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
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                FGX2_FARCALL _ntp_model_mag
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
                LDA     #16048
                STA     _fcc_q3
                LDA     #50935
                STA     _fcc_q2
                LDA     #41141
                STA     _fcc_long_hi
                LDA     #60813
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                LDX     _fcc_q2
                STX     _fcc_qb2
                LDX     _fcc_q3
                STX     _fcc_qb3
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
                BNE     *+5
                BRL     _ntp_model_L6
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
_ntp_model_L6
                LDA     79,S   ; fccstk d=0 b=79
                STA     _fcc_q3
                LDA     77,S   ; fccstk d=0 b=77
                STA     _fcc_q2
                LDA     75,S   ; fccstk d=0 b=75
                STA     _fcc_long_hi
                LDA     73,S   ; fccstk d=0 b=73
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #16470
                STA     _fcc_q3
                LDA     #32768
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
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                FGX2_FARCALL _ntp_model_mag
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
                LDA     #16048
                STA     _fcc_q3
                LDA     #50935
                STA     _fcc_q2
                LDA     #41141
                STA     _fcc_long_hi
                LDA     #60813
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                LDX     _fcc_q2
                STX     _fcc_qb2
                LDX     _fcc_q3
                STX     _fcc_qb3
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
                BNE     *+5
                BRL     _ntp_model_L7
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
_ntp_model_L7
                LDA     19,S   ; fccstk d=0 b=19
                STA     _fcc_long_hi
                LDA     17,S   ; fccstk d=0 b=17
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$83AA
                STA     _fcc_long_hi
                LDA     #$7E80
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_sub
                FGX2_FARCALL _fcc_dfromul
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
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                LDX     _fcc_q2
                STX     _fcc_qb2
                LDX     _fcc_q3
                STX     _fcc_qb3
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
                STA     89,S   ; fccstk d=0 b=89
                TAY
                LDA     _fcc_long_hi
                STA     91,S   ; fccstk d=0 b=91
                TYA
                LDA     91,S   ; fccstk d=0 b=91
                STA     _fcc_long_hi
                LDA     89,S   ; fccstk d=0 b=89
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     23,S   ; fccstk d=4 b=19
                STA     _fcc_long_hi
                LDA     21,S   ; fccstk d=4 b=17
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$83AA
                STA     _fcc_long_hi
                LDA     #$7E80
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_sub
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
                BRL     _ntp_model_L8
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
_ntp_model_L8
_ntp_model_L3
                LDA     93,S   ; fccstk d=0 b=93
                CLC
                ADC     #1
                STA     93,S   ; fccstk d=0 b=93
                BRL     _ntp_model_L2
_ntp_model_L4
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
main_FRAMESIZE   EQU     94
main_STKGUARD    EQU     0
                FGX2_RELOC_COUNT 45
