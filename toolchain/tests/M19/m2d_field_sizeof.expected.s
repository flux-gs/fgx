                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from m2d_field_sizeof.c
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
                LDA     #14
                PHA
                LDA     #14
                STA     _fcc_tmp_b
                PLA
                CMP     _fcc_tmp_b
                BEQ     *+5
                BRL     _m2d_field_sizeof_L0
                LDA     #1
                BRL     _m2d_field_sizeof_L1
_m2d_field_sizeof_L0
                LDA     #0
_m2d_field_sizeof_L1
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                STA     _fcc_img0
                PHA
                LDA     #14
                PHA
                LDA     #14
                STA     _fcc_tmp_b
                PLA
                CMP     _fcc_tmp_b
                BEQ     *+5
                BRL     _m2d_field_sizeof_L2
                LDA     #2
                BRL     _m2d_field_sizeof_L3
_m2d_field_sizeof_L2
                LDA     #0
_m2d_field_sizeof_L3
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                STA     _fcc_img0
                PHA
                LDA     #16
                PHA
                LDA     #16
                STA     _fcc_tmp_b
                PLA
                CMP     _fcc_tmp_b
                BEQ     *+5
                BRL     _m2d_field_sizeof_L4
                LDA     #4
                BRL     _m2d_field_sizeof_L5
_m2d_field_sizeof_L4
                LDA     #0
_m2d_field_sizeof_L5
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                STA     _fcc_img0
                PHA
                LDA     #15
                PHA
                LDA     #15
                STA     _fcc_tmp_b
                PLA
                CMP     _fcc_tmp_b
                BEQ     *+5
                BRL     _m2d_field_sizeof_L6
                LDA     #8
                BRL     _m2d_field_sizeof_L7
_m2d_field_sizeof_L6
                LDA     #0
_m2d_field_sizeof_L7
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                STA     _fcc_img0
                PHA
                LDA     #14
                TAX
                LDA     #14
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BEQ     *+5
                BRL     _m2d_field_sizeof_L8
                LDA     #16
                BRL     _m2d_field_sizeof_L9
_m2d_field_sizeof_L8
                LDA     #0
_m2d_field_sizeof_L9
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                STA     _fcc_img0
                PHA
                LDA     #15
                TAX
                LDA     #15
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BEQ     *+5
                BRL     _m2d_field_sizeof_L10
                LDA     #32
                BRL     _m2d_field_sizeof_L11
_m2d_field_sizeof_L10
                LDA     #0
_m2d_field_sizeof_L11
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                STA     _fcc_img0
                PHA
                LDA     #2
                TAX
                LDA     #2
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BEQ     *+5
                BRL     _m2d_field_sizeof_L12
                LDA     #64
                BRL     _m2d_field_sizeof_L13
_m2d_field_sizeof_L12
                LDA     #0
_m2d_field_sizeof_L13
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                STA     _fcc_img0
                PHA
                LDA     #1
                TAX
                LDA     #1
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BEQ     *+5
                BRL     _m2d_field_sizeof_L14
                LDA     #128
                BRL     _m2d_field_sizeof_L15
_m2d_field_sizeof_L14
                LDA     #0
_m2d_field_sizeof_L15
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                STA     _fcc_img0
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
main_FRAMESIZE   EQU     2
main_STKGUARD    EQU     0
                FGX2_RELOC_COUNT 2
