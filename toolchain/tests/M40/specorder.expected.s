                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from specorder.c
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
                LDA     #$0001
                STA     _fcc_long_hi
                LDA     #$1170
                STA     5,S   ; fccstk d=0 b=5
                TAY
                LDA     _fcc_long_hi
                STA     7,S   ; fccstk d=0 b=7
                TYA
                LDA     #0
                STA     _fcc_img0
                LDA     #$0001
                STA     _fcc_long_hi
                LDA     #$1170
                STA     _fcc_img3
                TAY
                LDA     _fcc_long_hi
                STA     _fcc_img4
                TYA
                LDA     _fcc_img4
                STA     _fcc_long_hi
                LDA     _fcc_img3
                LDX     #4464
                STX     _fcc_long_b_lo
                LDX     #1
                STX     _fcc_long_b_hi
                JSR     _fcc_long_eq
                CMP     #0
                BEQ     _specorder_L0
                LDA     _fcc_img0
                TAX
                CLC
                ADC     #10
                STA     _fcc_img0
_specorder_L0
                LDA     #4
                CMP     #4
                BNE     _specorder_L1
                LDA     #4
                CMP     #4
                BNE     _specorder_L1
                LDA     _fcc_img0
                TAX
                CLC
                ADC     #10
                STA     _fcc_img0
_specorder_L1
                LDA     #$FFFF
                JSR     _fcc_long_from_int
                LDX     #0
                STX     _fcc_long_b_lo
                LDX     #0
                STX     _fcc_long_b_hi
                JSR     _fcc_long_gtu
                CMP     #0
                BEQ     _specorder_L2
                LDA     _fcc_img0
                CLC
                ADC     #10
                STA     _fcc_img0
_specorder_L2
                LDA     #$FFFF
                LDX     #0
                STX     _fcc_long_hi
                LDX     #65535
                STX     _fcc_long_b_lo
                LDX     #0
                STX     _fcc_long_b_hi
                JSR     _fcc_long_eq
                CMP     #0
                BEQ     _specorder_L3
                LDA     _fcc_img0
                CLC
                ADC     #5
                STA     _fcc_img0
_specorder_L3
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
                STA     _fcc_img2
                LDA     _fcc_fpr0
                STA     _fcc_img1
                LDA     _fcc_img2
                STA     _fcc_fpr0+2
                LDA     _fcc_img1
                STA     _fcc_fpr0
                LDY     #2
                LDA     [_fcc_fpr0],Y
                STA     _fcc_long_hi
                LDA     [_fcc_fpr0]
                LDX     #4464
                STX     _fcc_long_b_lo
                LDX     #1
                STX     _fcc_long_b_hi
                JSR     _fcc_long_eq
                CMP     #0
                BEQ     _specorder_L4
                LDA     _fcc_img0
                TAX
                CLC
                ADC     #7
                STA     _fcc_img0
_specorder_L4
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
