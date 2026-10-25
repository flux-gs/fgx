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
                CMP     #2
                BNE     _sizeof_expr_L0
                LDA     #4
                CMP     #4
                BNE     _sizeof_expr_L0
                LDA     #2
                CMP     #2
                BNE     _sizeof_expr_L0
                LDA     _fcc_img0
                CLC
                ADC     #10
                STA     _fcc_img0
_sizeof_expr_L0
                LDA     #4
                CMP     #4
                BNE     _sizeof_expr_L1
                LDA     #2
                CMP     #2
                BNE     _sizeof_expr_L1
                LDA     #2
                CMP     #2
                BNE     _sizeof_expr_L1
                LDA     _fcc_img0
                CLC
                ADC     #10
                STA     _fcc_img0
_sizeof_expr_L1
                LDA     #4
                CMP     #4
                BNE     _sizeof_expr_L2
                LDA     #2
                CMP     #2
                BNE     _sizeof_expr_L2
                LDA     _fcc_img0
                CLC
                ADC     #11
                STA     _fcc_img0
_sizeof_expr_L2
                LDA     #2
                TAX
                CMP     #2
                BNE     _sizeof_expr_L3
                LDA     1,S   ; fccstk d=0 b=1
                TAX
                CMP     #5
                BNE     _sizeof_expr_L3
                LDA     _fcc_img0
                TAX
                CLC
                ADC     #11
                STA     _fcc_img0
_sizeof_expr_L3
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
