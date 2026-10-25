                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from aud_cmp_all.c
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
                LDA     #5
                STA     _fcc_img1
                LDA     #7
                STA     _fcc_img2
                LDA     #0
                SEC
                SBC     #3
                STA     _fcc_img3
                LDA     _fcc_img1
                TAX
                LDA     _fcc_img2
                STA     _fcc_tmp_b
                TXA
                SEC
                SBC     _fcc_tmp_b
                BVC     _aud_cmp_all_L1
                EOR     #$8000
_aud_cmp_all_L1
                BPL     _aud_cmp_all_L0
                LDA     _fcc_img0
                CLC
                ADC     #1
                STA     _fcc_img0
_aud_cmp_all_L0
                LDA     _fcc_img2
                TAX
                LDA     _fcc_img1
                STA     _fcc_tmp_b
                TXA
                LDX     _fcc_tmp_b
                STA     _fcc_tmp_b
                TXA
                SEC
                SBC     _fcc_tmp_b
                BVC     _aud_cmp_all_L3
                EOR     #$8000
_aud_cmp_all_L3
                BPL     _aud_cmp_all_L2
                LDA     _fcc_img0
                CLC
                ADC     #2
                STA     _fcc_img0
_aud_cmp_all_L2
                LDA     _fcc_img1
                TAX
                LDA     _fcc_img1
                STA     _fcc_tmp_b
                TXA
                LDX     _fcc_tmp_b
                STA     _fcc_tmp_b
                TXA
                SEC
                SBC     _fcc_tmp_b
                BVC     _aud_cmp_all_L5
                EOR     #$8000
_aud_cmp_all_L5
                BMI     _aud_cmp_all_L4
                LDA     _fcc_img0
                CLC
                ADC     #4
                STA     _fcc_img0
_aud_cmp_all_L4
                LDA     _fcc_img1
                TAX
                LDA     _fcc_img1
                STA     _fcc_tmp_b
                TXA
                SEC
                SBC     _fcc_tmp_b
                BVC     _aud_cmp_all_L7
                EOR     #$8000
_aud_cmp_all_L7
                BMI     _aud_cmp_all_L6
                LDA     _fcc_img0
                CLC
                ADC     #8
                STA     _fcc_img0
_aud_cmp_all_L6
                LDA     _fcc_img1
                TAX
                LDA     _fcc_img1
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BNE     _aud_cmp_all_L8
                LDA     _fcc_img0
                CLC
                ADC     #16
                STA     _fcc_img0
_aud_cmp_all_L8
                LDA     _fcc_img1
                TAX
                LDA     _fcc_img2
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BEQ     _aud_cmp_all_L9
                LDA     _fcc_img0
                CLC
                ADC     #4
                STA     _fcc_img0
_aud_cmp_all_L9
                LDA     _fcc_img3
                TAX
                LDA     _fcc_img1
                STA     _fcc_tmp_b
                TXA
                SEC
                SBC     _fcc_tmp_b
                BVC     _aud_cmp_all_L11
                EOR     #$8000
_aud_cmp_all_L11
                BPL     _aud_cmp_all_L10
                LDA     _fcc_img0
                CLC
                ADC     #4
                STA     _fcc_img0
_aud_cmp_all_L10
                LDA     _fcc_img1
                TAX
                LDA     _fcc_img3
                STA     _fcc_tmp_b
                TXA
                LDX     _fcc_tmp_b
                STA     _fcc_tmp_b
                TXA
                SEC
                SBC     _fcc_tmp_b
                BVC     _aud_cmp_all_L13
                EOR     #$8000
_aud_cmp_all_L13
                BPL     _aud_cmp_all_L12
                LDA     _fcc_img0
                TAX
                CLC
                ADC     #3
                STA     _fcc_img0
_aud_cmp_all_L12
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
main_FRAMESIZE   EQU     8
main_STKGUARD    EQU     0
                FGX2_RELOC_COUNT 2
