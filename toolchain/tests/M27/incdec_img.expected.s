                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from incdec_img.c
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
                LDA     #0
                STA     _fcc_img1
                LDA     #0
                STA     _fcc_img0
_incdec_img_L0
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     _fcc_img0
                TAX
                LDA     #10
                STA     _fcc_tmp_b
                TXA
                SEC
                SBC     _fcc_tmp_b
                BVC     _incdec_img_L3
                EOR     #$8000
_incdec_img_L3
                BMI     *+5
                BRL     _incdec_img_L2
                LDA     _fcc_img1
                TAX
                LDA     #1
                STA     _fcc_tmp_b
                TXA
                CLC
                ADC     _fcc_tmp_b
                STA     _fcc_img1
_incdec_img_L1
                INC     _fcc_img0
                BRL     _incdec_img_L0
_incdec_img_L2
                LDA     #8
                STA     _fcc_img0
                DEC     _fcc_img0
                DEC     _fcc_img0
                LDA     _fcc_img1
                CLC
                ADC     _fcc_img0
                STA     _fcc_img1
                LDA     #10
                STA     _fcc_img2
                INC     _fcc_img2
                INC     _fcc_img2
                DEC     _fcc_img2
                LDA     _fcc_img1
                TAX
                LDA     _fcc_img2
                AND     #$00FF
                STA     _fcc_tmp_b
                TXA
                CLC
                ADC     _fcc_tmp_b
                STA     _fcc_img1
                TAX
                LDA     #15
                STA     _fcc_tmp_b
                TXA
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
main_FRAMESIZE   EQU     6
main_STKGUARD    EQU     0
                FGX2_RELOC_COUNT 2
