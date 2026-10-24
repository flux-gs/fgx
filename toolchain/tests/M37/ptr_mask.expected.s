                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from ptr_mask.c
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
                STA     _fcc_img0
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_ptr_mask_buf+21
                STA     _fcc_fpr0
                PLA
                LDA     _fcc_fpr0+2
                STA     _fcc_img5
                LDA     _fcc_fpr0
                STA     _fcc_img4
                LDA     _fcc_img4
                STA     _fcc_img2
                LDA     #15
                STA     _fcc_img3
                PHA
                LDA     _fcc_img5
                STA     _fcc_fpr0+2
                LDA     _fcc_img4
                STA     _fcc_fpr0
                STA     _fcc_tmp_b
                PLA
                AND     _fcc_tmp_b
                STA     _fcc_img1
                PHA
                LDA     _fcc_img2
                TAX
                AND     #15
                STA     _fcc_tmp_b
                PLA
                CMP     _fcc_tmp_b
                BNE     _ptr_mask_L0
                LDA     _fcc_img0
                TAX
                CLC
                ADC     #6
                STA     _fcc_img0
_ptr_mask_L0
                LDA     _fcc_img5
                STA     _fcc_fpr0+2
                LDA     _fcc_img4
                STA     _fcc_fpr0
                AND     _fcc_img3
                STA     _fcc_img1
                PHA
                LDA     _fcc_img2
                TAX
                AND     #15
                STA     _fcc_tmp_b
                PLA
                CMP     _fcc_tmp_b
                BNE     _ptr_mask_L1
                LDA     _fcc_img0
                TAX
                CLC
                ADC     #6
                STA     _fcc_img0
_ptr_mask_L1
                LDA     _fcc_img5
                STA     _fcc_fpr0+2
                LDA     _fcc_img4
                STA     _fcc_fpr0
                TAX
                ORA     #1
                STA     _fcc_img1
                PHA
                LDA     _fcc_img2
                TAX
                ORA     #1
                STA     _fcc_tmp_b
                PLA
                CMP     _fcc_tmp_b
                BNE     _ptr_mask_L2
                LDA     _fcc_img0
                TAX
                CLC
                ADC     #6
                STA     _fcc_img0
_ptr_mask_L2
                LDA     #90
                PHA
                LDA     _fcc_img5
                STA     _fcc_fpr0+2
                LDA     _fcc_img4
                STA     _fcc_fpr0
                STA     _fcc_tmp_b
                PLA
                EOR     _fcc_tmp_b
                STA     _fcc_img1
                TAX
                LDA     #90
                EOR     _fcc_img2
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BNE     _ptr_mask_L3
                LDA     _fcc_img0
                TAX
                CLC
                ADC     #6
                STA     _fcc_img0
_ptr_mask_L3
                LDA     _fcc_img5
                STA     _fcc_fpr0+2
                LDA     _fcc_img4
                STA     _fcc_fpr0
                TAX
                AND     #1
                PHA
                LDA     _fcc_img2
                TAX
                AND     #1
                STA     _fcc_tmp_b
                PLA
                CMP     _fcc_tmp_b
                BNE     _ptr_mask_L4
                LDA     _fcc_img0
                TAX
                CLC
                ADC     #6
                STA     _fcc_img0
_ptr_mask_L4
                LDA     _fcc_img5
                STA     _fcc_fpr0+2
                LDA     _fcc_img4
                STA     _fcc_fpr0
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     #_ptr_mask_buf+21
                STA     _fcc_fpr1
                PLA
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BNE     _ptr_mask_L6
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _ptr_mask_L6
                LDA     #1
                BRA     _ptr_mask_L7
_ptr_mask_L6
                LDA     #0
_ptr_mask_L7
                CMP     #0
                BEQ     _ptr_mask_L5
                LDA     _fcc_img0
                TAX
                CLC
                ADC     #6
                STA     _fcc_img0
_ptr_mask_L5
                LDA     _fcc_img3
                TAX
                AND     #60
                STA     _fcc_img1
                TAX
                CMP     #12
                BNE     _ptr_mask_L8
                LDA     _fcc_img0
                TAX
                CLC
                ADC     #6
                STA     _fcc_img0
_ptr_mask_L8
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
main_FRAMESIZE   EQU     12
main_STKGUARD    EQU     0
                FGX2_RELOC_COUNT 2
