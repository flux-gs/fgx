                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from shift_left_type.c
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
                LDA     #1
                STA     1,S   ; fccstk d=0 b=1
                LDA     #$FFF0
                STA     _fcc_img1
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0003
                STA     _fcc_img3
                TAY
                LDA     _fcc_long_hi
                STA     _fcc_img4
                TYA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0020
                JSR     _fcc_long_neg
                STA     _fcc_img5
                TAY
                LDA     _fcc_long_hi
                STA     _fcc_img6
                TYA
                LDA     #2
                STA     _fcc_img2
                LDA     #32768
                STA     15,S   ; fccstk d=0 b=15
                LDA     #4
                STA     17,S   ; fccstk d=0 b=17
                LDA     #16384
                STA     19,S   ; fccstk d=0 b=19
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0002
                STA     _fcc_img7
                TAY
                LDA     _fcc_long_hi
                STA     _fcc_img8
                TYA
                LDA     #0
                STA     _fcc_img0
                LDA     19,S   ; fccstk d=0 b=19
                PHA
                LDA     _fcc_img8
                STA     _fcc_long_hi
                LDA     _fcc_img7
                STA     _fcc_tmp_b
                PLA
                JSR     _fcc_shl16
                CMP     #0
                BNE     _shift_left_type_L0
                LDA     _fcc_img0
                TAX
                CLC
                ADC     #10
                STA     _fcc_img0
_shift_left_type_L0
                LDA     1,S   ; fccstk d=0 b=1
                PHA
                LDA     _fcc_img4
                STA     _fcc_long_hi
                LDA     _fcc_img3
                STA     _fcc_tmp_b
                PLA
                JSR     _fcc_shl16
                CMP     #8
                BNE     _shift_left_type_L1
                LDA     _fcc_img0
                CLC
                ADC     #10
                STA     _fcc_img0
_shift_left_type_L1
                LDA     _fcc_img1
                TAX
                LDA     _fcc_img2
                STA     _fcc_tmp_b
                TXA
                JSR     _fcc_shrs16
                PHA
                LDA     _fcc_img1
                TAX
                LDA     #2
                STA     _fcc_tmp_b
                TXA
                JSR     _fcc_shrs16
                STA     _fcc_tmp_b
                PLA
                CMP     _fcc_tmp_b
                BNE     _shift_left_type_L2
                LDA     _fcc_img1
                TAX
                LDA     _fcc_img2
                STA     _fcc_tmp_b
                TXA
                JSR     _fcc_shrs16
                CMP     #$FFFC
                BNE     _shift_left_type_L2
                LDA     _fcc_img0
                CLC
                ADC     #11
                STA     _fcc_img0
_shift_left_type_L2
                LDA     15,S   ; fccstk d=0 b=15
                TAX
                LDA     17,S   ; fccstk d=0 b=17
                STA     _fcc_tmp_b
                TXA
                JSR     _fcc_shr16
                TAX
                CMP     #2048
                BNE     _shift_left_type_L3
                LDA     _fcc_img6
                STA     _fcc_long_hi
                LDA     _fcc_img5
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     _fcc_img2
                LDX     #0
                STX     _fcc_long_hi
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_shr
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0008
                JSR     _fcc_long_neg
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
                BEQ     _shift_left_type_L3
                LDA     _fcc_img0
                TAX
                CLC
                ADC     #11
                STA     _fcc_img0
_shift_left_type_L3
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
main_FRAMESIZE   EQU     26
main_STKGUARD    EQU     0
                FGX2_RELOC_COUNT 2
