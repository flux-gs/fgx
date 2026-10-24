                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from sizeof_expr.c
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
                LDA     #5
                STA     1,S   ; fccstk d=0 b=1
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0007
                STA     3,S   ; fccstk d=0 b=3
                TAY
                LDA     _fcc_long_hi
                STA     5,S   ; fccstk d=0 b=5
                TYA
                LDA     #120
                STA     7,S   ; fccstk d=0 b=7
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #6
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     11,S   ; fccstk d=0 b=11
                LDA     _fcc_fpr0
                STA     9,S   ; fccstk d=0 b=9
                LDA     #0
                STA     _fcc_img0
                LDA     #2
                TAX
                TXA
                CMP     #2
                BNE     _sizeof_expr_L3
                LDA     #4
                TAX
                TXA
                CMP     #4
                BNE     _sizeof_expr_L3
                LDA     #1
                BRA     _sizeof_expr_L4
_sizeof_expr_L3
                LDA     #0
_sizeof_expr_L4
                CMP     #0
                BEQ     _sizeof_expr_L1
                LDA     #2
                TAX
                TXA
                CMP     #2
                BNE     _sizeof_expr_L1
                LDA     #1
                BRA     _sizeof_expr_L2
_sizeof_expr_L1
                LDA     #0
_sizeof_expr_L2
                CMP     #0
                BEQ     _sizeof_expr_L0
                LDA     _fcc_img0
                TAX
                TXA
                CLC
                ADC     #10
                STA     _fcc_img0
_sizeof_expr_L0
                LDA     #4
                TAX
                TXA
                CMP     #4
                BNE     _sizeof_expr_L8
                LDA     #2
                TAX
                TXA
                CMP     #2
                BNE     _sizeof_expr_L8
                LDA     #1
                BRA     _sizeof_expr_L9
_sizeof_expr_L8
                LDA     #0
_sizeof_expr_L9
                CMP     #0
                BEQ     _sizeof_expr_L6
                LDA     #2
                TAX
                TXA
                CMP     #2
                BNE     _sizeof_expr_L6
                LDA     #1
                BRA     _sizeof_expr_L7
_sizeof_expr_L6
                LDA     #0
_sizeof_expr_L7
                CMP     #0
                BEQ     _sizeof_expr_L5
                LDA     _fcc_img0
                TAX
                TXA
                CLC
                ADC     #10
                STA     _fcc_img0
_sizeof_expr_L5
                LDA     #4
                TAX
                TXA
                CMP     #4
                BNE     _sizeof_expr_L11
                LDA     #2
                TAX
                TXA
                CMP     #2
                BNE     _sizeof_expr_L11
                LDA     #1
                BRA     _sizeof_expr_L12
_sizeof_expr_L11
                LDA     #0
_sizeof_expr_L12
                CMP     #0
                BEQ     _sizeof_expr_L10
                LDA     _fcc_img0
                TAX
                TXA
                CLC
                ADC     #11
                STA     _fcc_img0
_sizeof_expr_L10
                LDA     #2
                TAX
                TXA
                CMP     #2
                BNE     _sizeof_expr_L14
                LDA     1,S   ; fccstk d=0 b=1
                TAX
                TXA
                CMP     #5
                BNE     _sizeof_expr_L14
                LDA     #1
                BRA     _sizeof_expr_L15
_sizeof_expr_L14
                LDA     #0
_sizeof_expr_L15
                CMP     #0
                BEQ     _sizeof_expr_L13
                LDA     _fcc_img0
                TAX
                TXA
                CLC
                ADC     #11
                STA     _fcc_img0
_sizeof_expr_L13
                LDA     _fcc_img0
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
