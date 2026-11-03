                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from field_ptr_disp.c
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
                LDA     f+2
                STA     _fcc_fpr0+2
                LDA     f
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                AND     #$00FF
                PHA
                LDA     f+6
                STA     _fcc_fpr0+2
                LDA     f+4
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                PHA
                LDA     f+10
                STA     _fcc_fpr0+2
                LDA     f+8
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                AND     #$00FF
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                PHA
                LDA     f+12
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                SEC
                SBC     #7
                PHA
                LDA     f+6
                STA     _fcc_fpr0+2
                LDA     f+4
                CLC
                ADC     #-4
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                TAX
                CMP     #10
                BNE     _field_ptr_disp_L0
                LDA     #0
                BRA     _field_ptr_disp_L1
_field_ptr_disp_L0
                LDA     #50
_field_ptr_disp_L1
                STA     _fcc_tmp_b
                PLA
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
main_FRAMESIZE   EQU     0
main_STKGUARD    EQU     0
                FGX2_RELOC_COUNT 2
