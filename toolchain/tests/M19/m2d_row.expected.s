                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from m2d_row.c
;---------------------------------------

                MX      %00
                FGX2_EXPORT _m2d_row_rowlen
_m2d_row_rowlen            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #_m2d_row_rowlen_FRAMESIZE
                DO      _m2d_row_rowlen_STKGUARD
                BCC     _m2d_row_rowlen_stkovf
                CMP     _fcc_stkfloor
                BCS     _m2d_row_rowlen_stkok
_m2d_row_rowlen_stkovf       JMP     _fcc_stkoflow
                FIN
_m2d_row_rowlen_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      6+_m2d_row_rowlen_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_m2d_row_rowlen_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_m2d_row_rowlen_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_img1
                DO      8+_m2d_row_rowlen_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_m2d_row_rowlen_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_m2d_row_rowlen_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_img2
                LDA     #0
                STA     _fcc_img0
_m2d_row_L0
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
                CMP     #0
                BNE     *+5
                BRL     _m2d_row_L1
                INC     _fcc_img0
                BRL     _m2d_row_L0
_m2d_row_L1
                LDA     _fcc_img0
                TAY
                TSC
                CLC
                ADC     #_m2d_row_rowlen_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_m2d_row_rowlen_FRAMESIZE   EQU     2
_m2d_row_rowlen_STKGUARD    EQU     0
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
                LDA     #2
                STA     1,S   ; fccstk d=0 b=1
                LDA     #1
                STA     3,S   ; fccstk d=0 b=3
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
                LDA     #S3
                STA     _fcc_fpr0
                PLA
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0
                STA     H+0
                TAY
                LDA     _fcc_ptr+2
                STA     H+2
                TYA
                SEP     #$20
                MX      %10
                LDA     pf+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     pf
                INC
                INC
                STA     _fcc_fpr0
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     9,S   ; fccstk d=0 b=9
                LDA     _fcc_fpr0
                STA     7,S   ; fccstk d=0 b=7
                LDA     9,S   ; fccstk d=0 b=9
                STA     _fcc_fpr0+2
                LDA     7,S   ; fccstk d=0 b=7
                STA     _fcc_fpr0
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                CLC
                ADC     #F+2
                STA     _fcc_fpr1
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BEQ     *+5
                BRL     _m2d_row_L3
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BEQ     *+5
                BRL     _m2d_row_L3
                LDA     #1
                BRL     _m2d_row_L4
_m2d_row_L3
                LDA     #0
_m2d_row_L4
                CMP     #0
                BNE     *+5
                BRL     _m2d_row_L2
                LDA     5,S   ; fccstk d=0 b=5
                TAX
                TXA
                CLC
                ADC     #1
                STA     5,S   ; fccstk d=0 b=5
_m2d_row_L2
                SEP     #$20
                MX      %10
                LDA     ps3+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     ps3
                INC
                INC
                STA     _fcc_fpr0
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_tmp_b
                ASL
                ASL
                CLC
                ADC     _fcc_tmp_b
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     #2
                CLC
                ADC     #S3
                STA     _fcc_fpr1
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_tmp_b
                ASL
                ASL
                CLC
                ADC     _fcc_tmp_b
                CLC
                ADC     _fcc_fpr1
                STA     _fcc_fpr1
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BEQ     *+5
                BRL     _m2d_row_L8
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BEQ     *+5
                BRL     _m2d_row_L8
                LDA     #1
                BRL     _m2d_row_L9
_m2d_row_L8
                LDA     #0
_m2d_row_L9
                CMP     #0
                BNE     *+5
                BRL     _m2d_row_L6
                SEP     #$20
                MX      %10
                LDA     ph+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     ph
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                PHA
                SEP     #$20
                MX      %10
                LDY     #2
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                INC
                INC
                STA     _fcc_fpr0
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_tmp_b
                ASL
                ASL
                CLC
                ADC     _fcc_tmp_b
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     #2
                CLC
                ADC     #S3
                STA     _fcc_fpr1
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_tmp_b
                ASL
                ASL
                CLC
                ADC     _fcc_tmp_b
                CLC
                ADC     _fcc_fpr1
                STA     _fcc_fpr1
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BEQ     *+5
                BRL     _m2d_row_L10
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BEQ     *+5
                BRL     _m2d_row_L10
                LDA     #1
                BRL     _m2d_row_L11
_m2d_row_L10
                LDA     #0
_m2d_row_L11
                CMP     #0
                BNE     *+5
                BRL     _m2d_row_L6
                LDA     #1
                BRL     _m2d_row_L7
_m2d_row_L6
                LDA     #0
_m2d_row_L7
                CMP     #0
                BNE     *+5
                BRL     _m2d_row_L5
                LDA     5,S   ; fccstk d=0 b=5
                TAX
                TXA
                CLC
                ADC     #2
                STA     5,S   ; fccstk d=0 b=5
_m2d_row_L5
                SEP     #$20
                MX      %10
                LDA     pf+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     pf
                INC
                INC
                STA     _fcc_fpr0
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                CLC
                ADC     #F+2
                STA     _fcc_fpr1
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BEQ     *+5
                BRL     _m2d_row_L13
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BEQ     *+5
                BRL     _m2d_row_L13
                LDA     #1
                BRL     _m2d_row_L14
_m2d_row_L13
                LDA     #0
_m2d_row_L14
                CMP     #0
                BNE     *+5
                BRL     _m2d_row_L12
                LDA     5,S   ; fccstk d=0 b=5
                TAX
                TXA
                CLC
                ADC     #4
                STA     5,S   ; fccstk d=0 b=5
_m2d_row_L12
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                ASL
                CLC
                ADC     #FA
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0
                CLC
                ADC     #2
                STA     _fcc_fpr0
                LDA     1,S   ; fccstk d=0 b=1
                TAX
                LDA     #6
                STA     _fcc_tmp_b
                TXA
                JSR     _fcc_mul16
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                ASL
                CLC
                ADC     #FA
                STA     _fcc_fpr1
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr1
                INC
                INC
                STA     _fcc_fpr1
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_fpr1
                STA     _fcc_fpr1
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BEQ     *+5
                BRL     _m2d_row_L16
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BEQ     *+5
                BRL     _m2d_row_L16
                LDA     #1
                BRL     _m2d_row_L17
_m2d_row_L16
                LDA     #0
_m2d_row_L17
                CMP     #0
                BNE     *+5
                BRL     _m2d_row_L15
                LDA     5,S   ; fccstk d=0 b=5
                TAX
                TXA
                CLC
                ADC     #8
                STA     5,S   ; fccstk d=0 b=5
_m2d_row_L15
                SEP     #$20
                MX      %10
                LDA     pfa+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     pfa
                STA     _fcc_fpr0
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                ASL
                CLC
                ADC     _fcc_fpr0
                CLC
                ADC     #2
                STA     _fcc_fpr0
                LDA     1,S   ; fccstk d=0 b=1
                TAX
                LDA     #6
                STA     _fcc_tmp_b
                TXA
                JSR     _fcc_mul16
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                ASL
                CLC
                ADC     #FA
                STA     _fcc_fpr1
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr1
                INC
                INC
                STA     _fcc_fpr1
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_fpr1
                STA     _fcc_fpr1
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BEQ     *+5
                BRL     _m2d_row_L19
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BEQ     *+5
                BRL     _m2d_row_L19
                LDA     #1
                BRL     _m2d_row_L20
_m2d_row_L19
                LDA     #0
_m2d_row_L20
                CMP     #0
                BNE     *+5
                BRL     _m2d_row_L18
                LDA     5,S   ; fccstk d=0 b=5
                TAX
                TXA
                CLC
                ADC     #16
                STA     5,S   ; fccstk d=0 b=5
_m2d_row_L18
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                CLC
                ADC     #F+2
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #113
                SEP     #$20
                MX      %10
                STA     [_fcc_fpr0]
                LDA     pf+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     pf
                INC
                INC
                STA     _fcc_fpr0
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                AND     #$00FF
                TAX
                TXA
                CMP     #113
                BEQ     *+5
                BRL     _m2d_row_L21
                LDA     5,S   ; fccstk d=0 b=5
                TAX
                TXA
                CLC
                ADC     #32
                STA     5,S   ; fccstk d=0 b=5
_m2d_row_L21
                SEP     #$20
                MX      %10
                LDA     ps4+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     ps4
                INC
                INC
                STA     _fcc_fpr0
                LDA     1,S   ; fccstk d=0 b=1
                ASL
                ASL
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     #2
                CLC
                ADC     #S4
                STA     _fcc_fpr1
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     1,S   ; fccstk d=0 b=1
                ASL
                ASL
                ASL
                CLC
                ADC     _fcc_fpr1
                STA     _fcc_fpr1
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BEQ     *+5
                BRL     _m2d_row_L23
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BEQ     *+5
                BRL     _m2d_row_L23
                LDA     #1
                BRL     _m2d_row_L24
_m2d_row_L23
                LDA     #0
_m2d_row_L24
                CMP     #0
                BNE     *+5
                BRL     _m2d_row_L22
                LDA     5,S   ; fccstk d=0 b=5
                TAX
                TXA
                CLC
                ADC     #64
                STA     5,S   ; fccstk d=0 b=5
_m2d_row_L22
                LDA     #6
                CLC
                ADC     #F+2
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #97
                SEP     #$20
                MX      %10
                STA     [_fcc_fpr0]
                REP     #$20
                MX      %00
                LDA     #7
                CLC
                ADC     #F+2
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #98
                SEP     #$20
                MX      %10
                STA     [_fcc_fpr0]
                REP     #$20
                MX      %00
                LDA     #8
                CLC
                ADC     #F+2
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #99
                SEP     #$20
                MX      %10
                STA     [_fcc_fpr0]
                REP     #$20
                MX      %00
                LDA     #9
                CLC
                ADC     #F+2
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #0
                SEP     #$20
                MX      %10
                STA     [_fcc_fpr0]
                LDA     pf+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     pf
                INC
                INC
                CLC
                ADC     #6
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _m2d_row_rowlen
                TAY
                TSC
                CLC
                ADC     #4
                TCS
                TYA
                TAX
                TXA
                CMP     #3
                BEQ     *+5
                BRL     _m2d_row_L26
                LDA     #6
                TAX
                TXA
                CMP     #6
                BEQ     *+5
                BRL     _m2d_row_L26
                LDA     #1
                BRL     _m2d_row_L27
_m2d_row_L26
                LDA     #0
_m2d_row_L27
                CMP     #0
                BNE     *+5
                BRL     _m2d_row_L25
                LDA     5,S   ; fccstk d=0 b=5
                TAX
                TXA
                CLC
                ADC     #128
                STA     5,S   ; fccstk d=0 b=5
_m2d_row_L25
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
main_FRAMESIZE   EQU     10
main_STKGUARD    EQU     0
                FGX2_RELOC_COUNT 4
