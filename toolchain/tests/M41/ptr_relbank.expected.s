                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from ptr_relbank.c
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
                LDA     #$0008
                STA     _fcc_long_hi
                LDA     #$FF00
                STA     _fcc_fpr0
                STZ     _fcc_fpr0+2
                LDA     _fcc_long_hi
                SEP     #$20
                MX      %10
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0+2
                STA     _fcc_img2
                LDA     _fcc_fpr0
                STA     _fcc_img1
                LDA     #$0009
                STA     _fcc_long_hi
                LDA     #$0003
                STA     _fcc_fpr0
                STZ     _fcc_fpr0+2
                LDA     _fcc_long_hi
                SEP     #$20
                MX      %10
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0+2
                STA     _fcc_img4
                LDA     _fcc_fpr0
                STA     _fcc_img3
                LDA     #0
                STA     _fcc_img0
                LDA     _fcc_img2
                STA     _fcc_fpr0+2
                LDA     _fcc_img1
                STA     _fcc_fpr0
                LDA     _fcc_img4
                STA     _fcc_fpr1+2
                LDA     _fcc_img3
                STA     _fcc_fpr1
                LDA     _fcc_fpr0+2
                AND     #$00FF
                STA     _fcc_long_hi
                LDA     _fcc_fpr0
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     _fcc_fpr1+2
                AND     #$00FF
                STA     _fcc_long_hi
                LDA     _fcc_fpr1
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_ltu
                CMP     #0
                BEQ     _ptr_relbank_L0
                LDA     _fcc_img0
                CLC
                ADC     #10
                STA     _fcc_img0
_ptr_relbank_L0
                LDA     _fcc_img4
                STA     _fcc_fpr0+2
                LDA     _fcc_img3
                STA     _fcc_fpr0
                LDA     _fcc_img2
                STA     _fcc_fpr1+2
                LDA     _fcc_img1
                STA     _fcc_fpr1
                LDA     _fcc_fpr0+2
                AND     #$00FF
                STA     _fcc_long_hi
                LDA     _fcc_fpr0
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     _fcc_fpr1+2
                AND     #$00FF
                STA     _fcc_long_hi
                LDA     _fcc_fpr1
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_gtu
                CMP     #0
                BEQ     _ptr_relbank_L1
                LDA     _fcc_img0
                CLC
                ADC     #10
                STA     _fcc_img0
_ptr_relbank_L1
                LDA     _fcc_img4
                STA     _fcc_fpr0+2
                LDA     _fcc_img3
                STA     _fcc_fpr0
                LDA     _fcc_img2
                STA     _fcc_fpr1+2
                LDA     _fcc_img1
                STA     _fcc_fpr1
                LDA     _fcc_fpr0+2
                AND     #$00FF
                STA     _fcc_long_hi
                LDA     _fcc_fpr0
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     _fcc_fpr1+2
                AND     #$00FF
                STA     _fcc_long_hi
                LDA     _fcc_fpr1
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_ltu
                CMP     #0
                BNE     _ptr_relbank_L2
                LDA     _fcc_img0
                CLC
                ADC     #10
                STA     _fcc_img0
_ptr_relbank_L2
                LDA     _fcc_img2
                STA     _fcc_fpr0+2
                LDA     _fcc_img1
                STA     _fcc_fpr0
                LDA     _fcc_img4
                STA     _fcc_fpr1+2
                LDA     _fcc_img3
                STA     _fcc_fpr1
                LDA     _fcc_fpr0+2
                AND     #$00FF
                STA     _fcc_long_hi
                LDA     _fcc_fpr0
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     _fcc_fpr1+2
                AND     #$00FF
                STA     _fcc_long_hi
                LDA     _fcc_fpr1
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_leu
                CMP     #0
                BEQ     _ptr_relbank_L3
                LDA     _fcc_img4
                STA     _fcc_fpr0+2
                LDA     _fcc_img3
                STA     _fcc_fpr0
                LDA     _fcc_img2
                STA     _fcc_fpr1+2
                LDA     _fcc_img1
                STA     _fcc_fpr1
                LDA     _fcc_fpr0+2
                AND     #$00FF
                STA     _fcc_long_hi
                LDA     _fcc_fpr0
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     _fcc_fpr1+2
                AND     #$00FF
                STA     _fcc_long_hi
                LDA     _fcc_fpr1
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_geu
                CMP     #0
                BEQ     _ptr_relbank_L3
                LDA     _fcc_img0
                TAX
                CLC
                ADC     #12
                STA     _fcc_img0
_ptr_relbank_L3
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
main_FRAMESIZE   EQU     10
main_STKGUARD    EQU     0
                FGX2_RELOC_COUNT 2
