                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from struct_chararray_init.c
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
                LDA     braced+0
                TAX
                CMP     #4369
                BNE     _struct_chararray_init_L0
                LDA     braced+6
                TAX
                CMP     #8738
                BNE     _struct_chararray_init_L0
                LDA     braced+2
                AND     #$00FF
                TAX
                CMP     #65
                BNE     _struct_chararray_init_L0
                LDA     braced+3
                AND     #$00FF
                TAX
                CMP     #66
                BNE     _struct_chararray_init_L0
                LDA     braced+4
                AND     #$00FF
                TAX
                CMP     #67
                BNE     _struct_chararray_init_L0
                LDA     braced+5
                AND     #$00FF
                TAX
                CMP     #68
                BNE     _struct_chararray_init_L0
                LDA     _fcc_img0
                TAX
                CLC
                ADC     #14
                STA     _fcc_img0
_struct_chararray_init_L0
                LDA     shortb+0
                TAX
                CMP     #13107
                BNE     _struct_chararray_init_L1
                LDA     shortb+6
                TAX
                CMP     #17476
                BNE     _struct_chararray_init_L1
                LDA     shortb+2
                AND     #$00FF
                TAX
                CMP     #88
                BNE     _struct_chararray_init_L1
                LDA     shortb+3
                AND     #$00FF
                BNE     _struct_chararray_init_L1
                LDA     shortb+4
                AND     #$00FF
                BNE     _struct_chararray_init_L1
                LDA     shortb+5
                AND     #$00FF
                BNE     _struct_chararray_init_L1
                LDA     _fcc_img0
                TAX
                CLC
                ADC     #14
                STA     _fcc_img0
_struct_chararray_init_L1
                LDA     fromstr+0
                TAX
                CMP     #21845
                BNE     _struct_chararray_init_L2
                LDA     fromstr+6
                TAX
                CMP     #26214
                BNE     _struct_chararray_init_L2
                LDA     fromstr+2
                AND     #$00FF
                TAX
                CMP     #104
                BNE     _struct_chararray_init_L2
                LDA     fromstr+3
                AND     #$00FF
                TAX
                CMP     #105
                BNE     _struct_chararray_init_L2
                LDA     fromstr+4
                AND     #$00FF
                BNE     _struct_chararray_init_L2
                LDA     fromstr+5
                AND     #$00FF
                BNE     _struct_chararray_init_L2
                LDA     exact+0
                TAX
                CMP     #30583
                BNE     _struct_chararray_init_L2
                LDA     exact+6
                TAX
                CMP     #4660
                BNE     _struct_chararray_init_L2
                LDA     exact+2
                AND     #$00FF
                TAX
                CMP     #97
                BNE     _struct_chararray_init_L2
                LDA     exact+5
                AND     #$00FF
                TAX
                CMP     #100
                BNE     _struct_chararray_init_L2
                LDA     _fcc_img0
                TAX
                CLC
                ADC     #14
                STA     _fcc_img0
_struct_chararray_init_L2
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
main_FRAMESIZE   EQU     2
main_STKGUARD    EQU     0
                FGX2_RELOC_COUNT 2
