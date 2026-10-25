                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from tmops.c
;---------------------------------------

                MX      %00
                FGX2_EXPORT streq
streq            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #streq_FRAMESIZE
                DO      streq_STKGUARD
                BCC     streq_stkovf
                CMP     _fcc_stkfloor
                BCS     streq_stkok
streq_stkovf       JMP     _fcc_stkoflow
                FIN
streq_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      6+streq_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+streq_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+streq_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_img1
                DO      8+streq_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+streq_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+streq_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_img2
                DO      10+streq_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+streq_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+streq_FRAMESIZE,S   ; fccstk d=0 b=10 fs
                FIN
                STA     _fcc_img3
                DO      12+streq_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+streq_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+streq_FRAMESIZE,S   ; fccstk d=0 b=12 fs
                FIN
                STA     _fcc_img4
                LDA     #0
                STA     _fcc_img0
_tmops_L0
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     _fcc_img2
                STA     _fcc_ptr+2
                LDA     _fcc_img1
                PHA
                LDA     _fcc_img0
                CLC
                ADC     1,S
                STA     _fcc_ptr
                PLA
                LDA     [_fcc_ptr]
                AND     #$00FF
                BEQ     _tmops_L1
                LDA     _fcc_img2
                STA     _fcc_ptr+2
                LDA     _fcc_img1
                PHA
                LDA     _fcc_img0
                CLC
                ADC     1,S
                STA     _fcc_ptr
                PLA
                LDA     [_fcc_ptr]
                AND     #$00FF
                PHA
                LDA     _fcc_img4
                STA     _fcc_ptr+2
                LDA     _fcc_img3
                PHA
                LDA     _fcc_img0
                CLC
                ADC     1,S
                STA     _fcc_ptr
                PLA
                LDA     [_fcc_ptr]
                AND     #$00FF
                STA     _fcc_tmp_b
                PLA
                CMP     _fcc_tmp_b
                BNE     _tmops_L1
                INC     _fcc_img0
                BRA     _tmops_L0
_tmops_L1
                LDA     _fcc_img2
                STA     _fcc_ptr+2
                LDA     _fcc_img1
                PHA
                LDA     _fcc_img0
                CLC
                ADC     1,S
                STA     _fcc_ptr
                PLA
                LDA     [_fcc_ptr]
                AND     #$00FF
                PHA
                LDA     _fcc_img4
                STA     _fcc_ptr+2
                LDA     _fcc_img3
                PHA
                LDA     _fcc_img0
                CLC
                ADC     1,S
                STA     _fcc_ptr
                PLA
                LDA     [_fcc_ptr]
                AND     #$00FF
                STA     _fcc_tmp_b
                PLA
                JSR     _fcc_eq16
                TAY
                TSC
                CLC
                ADC     #streq_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
streq_FRAMESIZE   EQU     2
streq_STKGUARD    EQU     0
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
                STA     5,S   ; fccstk d=0 b=5
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #e0
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL gmtime
                TAY
                TSC
                CLC
                ADC     #4
                TCS
                TYA
                LDA     _fcc_fpr0+2
                STA     3,S   ; fccstk d=0 b=3
                LDA     _fcc_fpr0
                STA     1,S   ; fccstk d=0 b=1
                LDY     #10
                LDA     [_fcc_fpr0],Y
                TAX
                CMP     #126
                BNE     _tmops_L2
                LDY     #8
                LDA     [_fcc_fpr0],Y
                TAX
                CMP     #5
                BNE     _tmops_L2
                LDY     #6
                LDA     [_fcc_fpr0],Y
                TAX
                CMP     #30
                BNE     _tmops_L2
                LDY     #4
                LDA     [_fcc_fpr0],Y
                TAX
                CMP     #14
                BNE     _tmops_L2
                LDY     #2
                LDA     [_fcc_fpr0],Y
                TAX
                CMP     #20
                BNE     _tmops_L2
                LDA     [_fcc_fpr0]
                TAX
                CMP     #7
                BNE     _tmops_L2
                LDY     #12
                LDA     [_fcc_fpr0],Y
                TAX
                CMP     #2
                BNE     _tmops_L2
                LDY     #14
                LDA     [_fcc_fpr0],Y
                TAX
                CMP     #180
                BNE     _tmops_L2
                LDY     #16
                LDA     [_fcc_fpr0],Y
                BNE     _tmops_L2
                LDA     5,S   ; fccstk d=0 b=5
                TAX
                CLC
                ADC     #10
                STA     5,S   ; fccstk d=0 b=5
_tmops_L2
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_tmops_S0
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     7,S   ; fccstk d=4 b=3
                STA     _fcc_fpr0+2
                LDA     5,S   ; fccstk d=4 b=1
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL asctime
                TAY
                TSC
                CLC
                ADC     #4
                TCS
                TYA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL streq
                TAY
                TSC
                CLC
                ADC     #8
                TCS
                TYA
                BEQ     _tmops_L3
                LDA     5,S   ; fccstk d=0 b=5
                TAX
                CLC
                ADC     #10
                STA     5,S   ; fccstk d=0 b=5
_tmops_L3
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #e1
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL localtime
                TAY
                TSC
                CLC
                ADC     #4
                TCS
                TYA
                LDA     _fcc_fpr0+2
                STA     3,S   ; fccstk d=0 b=3
                LDA     _fcc_fpr0
                STA     1,S   ; fccstk d=0 b=1
                LDY     #8
                LDA     [_fcc_fpr0],Y
                TAX
                CMP     #1
                BNE     _tmops_L4
                LDY     #6
                LDA     [_fcc_fpr0],Y
                TAX
                CMP     #29
                BNE     _tmops_L4
                LDY     #10
                LDA     [_fcc_fpr0],Y
                TAX
                CMP     #124
                BNE     _tmops_L4
                LDY     #12
                LDA     [_fcc_fpr0],Y
                TAX
                CMP     #4
                BNE     _tmops_L4
                LDY     #14
                LDA     [_fcc_fpr0],Y
                TAX
                CMP     #59
                BNE     _tmops_L4
                LDA     5,S   ; fccstk d=0 b=5
                TAX
                CLC
                ADC     #10
                STA     5,S   ; fccstk d=0 b=5
_tmops_L4
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #e1
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL localtime
                TAY
                TSC
                CLC
                ADC     #4
                TCS
                TYA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL asctime
                TAY
                TSC
                CLC
                ADC     #4
                TCS
                TYA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #e1
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL ctime
                TAY
                TSC
                CLC
                ADC     #4
                TCS
                TYA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL streq
                TAY
                TSC
                CLC
                ADC     #8
                TCS
                TYA
                BNE     *+5
                BRL     _tmops_L5
                LDA     #99
                STA     gtz+0
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #gtz
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #gtv
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL gettimeofday
                TAY
                TSC
                CLC
                ADC     #8
                TCS
                TYA
                CMP     #0
                BEQ     *+5
                BRL     _tmops_L6
                LDA     gtv+2
                STA     _fcc_long_hi
                LDA     gtv+0
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$6553
                STA     _fcc_long_hi
                LDA     #$F100
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_gts
                CMP     #0
                BEQ     _tmops_L6
                LDA     gtv+6
                STA     _fcc_long_hi
                LDA     gtv+4
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
                JSR     _fcc_long_ges
                CMP     #0
                BEQ     _tmops_L6
                LDA     gtv+6
                STA     _fcc_long_hi
                LDA     gtv+4
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$000F
                STA     _fcc_long_hi
                LDA     #$4240
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
                BEQ     _tmops_L6
                LDA     gtz+0
                TAX
                CMP     #99
                BEQ     _tmops_L6
                LDA     5,S   ; fccstk d=0 b=5
                TAX
                CLC
                ADC     #12
                STA     5,S   ; fccstk d=0 b=5
_tmops_L6
_tmops_L5
                LDA     5,S   ; fccstk d=0 b=5
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
                FGX2_RELOC_COUNT 12
