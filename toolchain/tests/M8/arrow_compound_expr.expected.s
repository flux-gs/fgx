                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from arrow_compound_expr.c
;---------------------------------------

                MX      %00
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
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #4
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     _fcc_img1
                LDA     _fcc_fpr0
                STA     _fcc_img0
                LDA     #10
                STA     5,S   ; fccstk d=0 b=5
                LDA     #41
                STA     _fcc_tmp_b
                STA     7,S   ; fccstk d=0 b=7
                LDA     _fcc_tmp_b
                JSR     _fcc_long_from_int
                LDA     _fcc_long_hi
                STA     9,S   ; fccstk d=0 b=9
                LDA     #$000F
                STA     _fcc_long_hi
                LDA     #$4240
                STA     11,S   ; fccstk d=0 b=11
                LDA     _fcc_long_hi
                STA     13,S   ; fccstk d=0 b=13
                LDA     [_fcc_img0]
                TAX
                SEC
                SBC     #4
                STA     [_fcc_img0]
                LDA     #1
                JSR     _fcc_long_from_int
                STA     _fcc_long_b_lo
                LDA     _fcc_long_hi
                STA     _fcc_long_b_hi
                LDY     #4
                LDA     [_fcc_img0],Y
                STA     _fcc_long_hi
                LDY     #2
                LDA     [_fcc_img0],Y
                JSR     _fcc_long_add
                LDY     #2
                STA     [_fcc_img0],Y
                TAX
                LDA     _fcc_long_hi
                LDY     #4
                STA     [_fcc_img0],Y
                TXA
                LDA     #$FFFF
                JSR     _fcc_long_from_int
                STA     _fcc_long_b_lo
                LDA     _fcc_long_hi
                STA     _fcc_long_b_hi
                LDY     #4
                LDA     [_fcc_img0],Y
                STA     _fcc_long_hi
                LDY     #2
                LDA     [_fcc_img0],Y
                JSR     _fcc_long_add
                LDY     #8
                LDA     [_fcc_img0],Y
                STA     _fcc_long_hi
                LDY     #6
                LDA     [_fcc_img0],Y
                LDX     #16954
                STX     _fcc_long_b_lo
                LDX     #15
                STX     _fcc_long_b_hi
                JSR     _fcc_long_sub
                LDY     #6
                STA     [_fcc_img0],Y
                TAX
                LDA     _fcc_long_hi
                LDY     #8
                STA     [_fcc_img0],Y
                TXA
                LDA     [_fcc_img0]
                PHA
                LDY     #4
                LDA     [_fcc_img0],Y
                STA     _fcc_long_hi
                LDY     #2
                LDA     [_fcc_img0],Y
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
                LDA     _fcc_img1
                STA     _fcc_fpr0+2
                LDA     _fcc_img0
                STA     _fcc_fpr0
                LDY     #8
                LDA     [_fcc_fpr0],Y
                STA     _fcc_long_hi
                LDY     #6
                LDA     [_fcc_fpr0],Y
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_add
                LDX     #12
                STX     _fcc_long_b_lo
                LDX     #0
                STX     _fcc_long_b_hi
                JSR     _fcc_long_sub
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
main_FRAMESIZE   EQU     14
main_STKGUARD    EQU     0
                FGX2_RELOC_COUNT 2
