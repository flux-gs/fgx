                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from ptr_pinc_wide.c
;---------------------------------------

                MX      %00
                FGX2_EXPORT _ptr_pinc_wide_sum_long
_ptr_pinc_wide_sum_long            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #_ptr_pinc_wide_sum_long_FRAMESIZE
                DO      _ptr_pinc_wide_sum_long_STKGUARD
                BCC     _ptr_pinc_wide_sum_long_stkovf
                CMP     _fcc_stkfloor
                BCS     _ptr_pinc_wide_sum_long_stkok
_ptr_pinc_wide_sum_long_stkovf       JMP     _fcc_stkoflow
                FIN
_ptr_pinc_wide_sum_long_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      10+_ptr_pinc_wide_sum_long_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+_ptr_pinc_wide_sum_long_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+_ptr_pinc_wide_sum_long_FRAMESIZE,S   ; fccstk d=0 b=10 fs
                FIN
                STA     _fcc_img0
                LDA     #0
                STA     _fcc_img1
                TAY
                JSR     _fcc_long_from_int
                LDA     _fcc_long_hi
                STA     _fcc_img2
                TYA
_ptr_pinc_wide_L0
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     _fcc_img0
                TAX
                TXA
                LDX     #0
                STA     _fcc_tmp_b
                TXA
                SEC
                SBC     _fcc_tmp_b
                BVC     _ptr_pinc_wide_L2
                EOR     #$8000
_ptr_pinc_wide_L2
                BMI     *+5
                BRL     _ptr_pinc_wide_L1
                LDA     _fcc_img2
                STA     _fcc_long_hi
                LDA     _fcc_img1
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                DO      12+_ptr_pinc_wide_sum_long_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+_ptr_pinc_wide_sum_long_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+_ptr_pinc_wide_sum_long_FRAMESIZE,S   ; fccstk d=4 b=8 fs
                FIN
                STA     _fcc_ptr+2
                DO      10+_ptr_pinc_wide_sum_long_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+_ptr_pinc_wide_sum_long_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+_ptr_pinc_wide_sum_long_FRAMESIZE,S   ; fccstk d=4 b=6 fs
                FIN
                STA     _fcc_tmp_b
                CLC
                ADC     #4
                DO      10+_ptr_pinc_wide_sum_long_FRAMESIZE/256
                PHA
                TSC
                CLC
                ADC     #12+_ptr_pinc_wide_sum_long_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                PLA
                STA     [_fcc_fp]
                ELSE
                STA     10+_ptr_pinc_wide_sum_long_FRAMESIZE,S   ; fccstk d=4 b=6 fs
                FIN
                LDA     _fcc_tmp_b
                STA     _fcc_ptr
                LDY     #2
                LDA     [_fcc_ptr],Y
                STA     _fcc_long_hi
                LDA     [_fcc_ptr]
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_add
                STA     _fcc_img1
                TAY
                LDA     _fcc_long_hi
                STA     _fcc_img2
                TYA
                LDA     _fcc_img0
                TAX
                TXA
                SEC
                SBC     #1
                STA     _fcc_img0
                BRL     _ptr_pinc_wide_L0
_ptr_pinc_wide_L1
                LDA     _fcc_img2
                STA     _fcc_long_hi
                LDA     _fcc_long_hi
                LDX     #0
                CMP     #$8000
                BCC     _ptr_pinc_wide_L3
                LDX     #$FFFF
_ptr_pinc_wide_L3
                STX     _fcc_long_hi
                TAY
                TSC
                CLC
                ADC     #_ptr_pinc_wide_sum_long_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_ptr_pinc_wide_sum_long_FRAMESIZE   EQU     4
_ptr_pinc_wide_sum_long_STKGUARD    EQU     0
                FGX2_EXPORT _ptr_pinc_wide_sum_float
_ptr_pinc_wide_sum_float            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #_ptr_pinc_wide_sum_float_FRAMESIZE
                DO      _ptr_pinc_wide_sum_float_STKGUARD
                BCC     _ptr_pinc_wide_sum_float_stkovf
                CMP     _fcc_stkfloor
                BCS     _ptr_pinc_wide_sum_float_stkok
_ptr_pinc_wide_sum_float_stkovf       JMP     _fcc_stkoflow
                FIN
_ptr_pinc_wide_sum_float_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      10+_ptr_pinc_wide_sum_float_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+_ptr_pinc_wide_sum_float_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+_ptr_pinc_wide_sum_float_FRAMESIZE,S   ; fccstk d=0 b=10 fs
                FIN
                STA     _fcc_img0
                LDA     #0
                STA     _fcc_img1
_ptr_pinc_wide_L4
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     _fcc_img0
                TAX
                TXA
                LDX     #0
                STA     _fcc_tmp_b
                TXA
                SEC
                SBC     _fcc_tmp_b
                BVC     _ptr_pinc_wide_L6
                EOR     #$8000
_ptr_pinc_wide_L6
                BMI     *+5
                BRL     _ptr_pinc_wide_L5
                DO      8+_ptr_pinc_wide_sum_float_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_ptr_pinc_wide_sum_float_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_ptr_pinc_wide_sum_float_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_ptr+2
                DO      6+_ptr_pinc_wide_sum_float_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_ptr_pinc_wide_sum_float_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_ptr_pinc_wide_sum_float_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_tmp_b
                CLC
                ADC     #4
                DO      6+_ptr_pinc_wide_sum_float_FRAMESIZE/256
                PHA
                TSC
                CLC
                ADC     #8+_ptr_pinc_wide_sum_float_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                PLA
                STA     [_fcc_fp]
                ELSE
                STA     6+_ptr_pinc_wide_sum_float_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                LDA     _fcc_tmp_b
                STA     _fcc_ptr
                LDY     #2
                LDA     [_fcc_ptr],Y
                STA     _fcc_long_hi
                LDA     [_fcc_ptr]
                STA     3,S   ; fccstk d=0 b=3
                TAY
                LDA     _fcc_long_hi
                STA     5,S   ; fccstk d=0 b=5
                TYA
                LDA     _fcc_img1
                PHA
                LDA     7,S   ; fccstk d=2 b=5
                STA     _fcc_long_hi
                LDA     5,S   ; fccstk d=2 b=3
                JSR     _fcc_ftoi
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                STA     _fcc_img1
                LDA     _fcc_img0
                TAX
                TXA
                SEC
                SBC     #1
                STA     _fcc_img0
                BRL     _ptr_pinc_wide_L4
_ptr_pinc_wide_L5
                LDA     _fcc_img1
                TAY
                TSC
                CLC
                ADC     #_ptr_pinc_wide_sum_float_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_ptr_pinc_wide_sum_float_FRAMESIZE   EQU     6
_ptr_pinc_wide_sum_float_STKGUARD    EQU     0
                FGX2_EXPORT _ptr_pinc_wide_sum_pp
_ptr_pinc_wide_sum_pp            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #_ptr_pinc_wide_sum_pp_FRAMESIZE
                DO      _ptr_pinc_wide_sum_pp_STKGUARD
                BCC     _ptr_pinc_wide_sum_pp_stkovf
                CMP     _fcc_stkfloor
                BCS     _ptr_pinc_wide_sum_pp_stkok
_ptr_pinc_wide_sum_pp_stkovf       JMP     _fcc_stkoflow
                FIN
_ptr_pinc_wide_sum_pp_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      10+_ptr_pinc_wide_sum_pp_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+_ptr_pinc_wide_sum_pp_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+_ptr_pinc_wide_sum_pp_FRAMESIZE,S   ; fccstk d=0 b=10 fs
                FIN
                STA     _fcc_img0
                LDA     #0
                STA     _fcc_img1
_ptr_pinc_wide_L7
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     _fcc_img0
                TAX
                TXA
                LDX     #0
                STA     _fcc_tmp_b
                TXA
                SEC
                SBC     _fcc_tmp_b
                BVC     _ptr_pinc_wide_L9
                EOR     #$8000
_ptr_pinc_wide_L9
                BMI     *+5
                BRL     _ptr_pinc_wide_L8
                DO      8+_ptr_pinc_wide_sum_pp_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_ptr_pinc_wide_sum_pp_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_ptr_pinc_wide_sum_pp_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_ptr+2
                DO      6+_ptr_pinc_wide_sum_pp_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_ptr_pinc_wide_sum_pp_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_ptr_pinc_wide_sum_pp_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_tmp_b
                CLC
                ADC     #4
                DO      6+_ptr_pinc_wide_sum_pp_FRAMESIZE/256
                PHA
                TSC
                CLC
                ADC     #8+_ptr_pinc_wide_sum_pp_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                PLA
                STA     [_fcc_fp]
                ELSE
                STA     6+_ptr_pinc_wide_sum_pp_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                LDA     _fcc_tmp_b
                STA     _fcc_ptr
                LDA     [_fcc_ptr]
                PHA
                SEP     #$20
                MX      %10
                LDY     #2
                LDA     [_fcc_ptr],Y
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                LDA     _fcc_ptr+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0+2
                STA     _fcc_img3
                LDA     _fcc_fpr0
                STA     _fcc_img2
                LDA     _fcc_img1
                PHA
                LDA     [_fcc_img2]
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                STA     _fcc_img1
                LDA     _fcc_img0
                TAX
                TXA
                SEC
                SBC     #1
                STA     _fcc_img0
                BRL     _ptr_pinc_wide_L7
_ptr_pinc_wide_L8
                LDA     _fcc_img1
                TAY
                TSC
                CLC
                ADC     #_ptr_pinc_wide_sum_pp_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_ptr_pinc_wide_sum_pp_FRAMESIZE   EQU     6
_ptr_pinc_wide_sum_pp_STKGUARD    EQU     0
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
                LDA     #_ptr_pinc_wide_la
                PHA
                LDA     #0
                ASL
                ASL
                CLC
                ADC     1,S
                TAY
                PLA
                TYA
                PHA
                LDA     #$0001
                STA     _fcc_long_hi
                LDA     #$0000
                TAY
                LDA     1,S
                TAX
                TYA
                STA:    $0000,X
                LDA     _fcc_long_hi
                STA:    $0002,X
                PLA
                LDA     #_ptr_pinc_wide_la
                PHA
                LDA     #1
                ASL
                ASL
                CLC
                ADC     1,S
                TAY
                PLA
                TYA
                PHA
                LDA     #$0002
                STA     _fcc_long_hi
                LDA     #$0000
                TAY
                LDA     1,S
                TAX
                TYA
                STA:    $0000,X
                LDA     _fcc_long_hi
                STA:    $0002,X
                PLA
                LDA     #_ptr_pinc_wide_la
                PHA
                LDA     #2
                ASL
                ASL
                CLC
                ADC     1,S
                TAY
                PLA
                TYA
                PHA
                LDA     #$0003
                STA     _fcc_long_hi
                LDA     #$0000
                TAY
                LDA     1,S
                TAX
                TYA
                STA:    $0000,X
                LDA     _fcc_long_hi
                STA:    $0002,X
                PLA
                LDA     #_ptr_pinc_wide_fa
                PHA
                LDA     #0
                ASL
                ASL
                CLC
                ADC     1,S
                TAY
                PLA
                TYA
                PHA
                LDA     #$4000
                STA     _fcc_long_hi
                LDA     #$0000
                TAY
                LDA     1,S
                TAX
                TYA
                STA:    $0000,X
                LDA     _fcc_long_hi
                STA:    $0002,X
                PLA
                LDA     #_ptr_pinc_wide_fa
                PHA
                LDA     #1
                ASL
                ASL
                CLC
                ADC     1,S
                TAY
                PLA
                TYA
                PHA
                LDA     #$4080
                STA     _fcc_long_hi
                LDA     #$0000
                TAY
                LDA     1,S
                TAX
                TYA
                STA:    $0000,X
                LDA     _fcc_long_hi
                STA:    $0002,X
                PLA
                LDA     #10
                STA     _ptr_pinc_wide_x
                LDA     #20
                STA     _ptr_pinc_wide_y
                LDA     #30
                STA     _ptr_pinc_wide_z
                LDA     #_ptr_pinc_wide_pa
                PHA
                LDA     #0
                ASL
                ASL
                CLC
                ADC     1,S
                TAY
                PLA
                TYA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_ptr_pinc_wide_x
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0
                TAY
                LDA     1,S
                TAX
                TYA
                STA:    $0000,X
                SEP     #$20
                MX      %10
                LDA     _fcc_ptr+2
                STA:    $0002,X
                REP     #$20
                MX      %00
                PLA
                LDA     #_ptr_pinc_wide_pa
                PHA
                LDA     #1
                ASL
                ASL
                CLC
                ADC     1,S
                TAY
                PLA
                TYA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_ptr_pinc_wide_y
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0
                TAY
                LDA     1,S
                TAX
                TYA
                STA:    $0000,X
                SEP     #$20
                MX      %10
                LDA     _fcc_ptr+2
                STA:    $0002,X
                REP     #$20
                MX      %00
                PLA
                LDA     #_ptr_pinc_wide_pa
                PHA
                LDA     #2
                ASL
                ASL
                CLC
                ADC     1,S
                TAY
                PLA
                TYA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_ptr_pinc_wide_z
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0
                TAY
                LDA     1,S
                TAX
                TYA
                STA:    $0000,X
                SEP     #$20
                MX      %10
                LDA     _fcc_ptr+2
                STA:    $0002,X
                REP     #$20
                MX      %00
                PLA
                LDA     #3
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_ptr_pinc_wide_la
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _ptr_pinc_wide_sum_long
                TAY
                TSC
                CLC
                ADC     #6
                TCS
                TYA
                PHA
                LDA     #2
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_ptr_pinc_wide_fa
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _ptr_pinc_wide_sum_float
                TAY
                TSC
                CLC
                ADC     #6
                TCS
                TYA
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                PHA
                LDA     #3
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_ptr_pinc_wide_pa
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _ptr_pinc_wide_sum_pp
                TAY
                TSC
                CLC
                ADC     #6
                TCS
                TYA
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
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
                FGX2_RELOC_COUNT 8
