                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from long_rvinc.c
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
                LDA     #3
                STA     _fcc_img2
                TAY
                JSR     _fcc_long_from_int
                LDA     _fcc_long_hi
                STA     _fcc_img3
                TYA
                LDA     #0
                STA     _fcc_img0
_long_rvinc_L0
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     #$FFFF
                JSR     _fcc_long_from_int
                STA     _fcc_long_b_lo
                LDA     _fcc_long_hi
                STA     _fcc_long_b_hi
                LDA     _fcc_img3
                STA     _fcc_long_hi
                LDA     _fcc_img2
                JSR     _fcc_long_add
                STA     _fcc_img2
                TAY
                LDA     _fcc_long_hi
                STA     _fcc_img3
                TYA
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #0
                JSR     _fcc_long_from_int
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_ges
                CMP     #0
                BNE     *+5
                BRL     _long_rvinc_L2
                LDA     _fcc_img0
                TAX
                LDA     #50
                STA     _fcc_tmp_b
                TXA
                SEC
                SBC     _fcc_tmp_b
                BVC     _long_rvinc_L4
                EOR     #$8000
_long_rvinc_L4
                BMI     *+5
                BRL     _long_rvinc_L2
                LDA     #1
                BRL     _long_rvinc_L3
_long_rvinc_L2
                LDA     #0
_long_rvinc_L3
                CMP     #0
                BNE     *+5
                BRL     _long_rvinc_L1
                INC     _fcc_img0
                BRL     _long_rvinc_L0
_long_rvinc_L1
                LDA     _fcc_img1
                CLC
                ADC     _fcc_img0
                STA     _fcc_img1
                LDA     #0
                STA     _fcc_img2
                TAY
                JSR     _fcc_long_from_int
                LDA     _fcc_long_hi
                STA     _fcc_img3
                TYA
                LDA     #0
                STA     _fcc_img0
_long_rvinc_L5
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     #$FFFF
                JSR     _fcc_long_from_int
                STA     _fcc_long_b_lo
                LDA     _fcc_long_hi
                STA     _fcc_long_b_hi
                LDA     _fcc_img3
                STA     _fcc_long_hi
                LDA     _fcc_img2
                JSR     _fcc_long_add
                STA     _fcc_img2
                TAY
                LDA     _fcc_long_hi
                STA     _fcc_img3
                TYA
                LDA     #1
                JSR     _fcc_long_from_int
                STA     _fcc_long_b_lo
                LDA     _fcc_long_hi
                STA     _fcc_long_b_hi
                LDA     _fcc_img3
                STA     _fcc_long_hi
                LDA     _fcc_img2
                JSR     _fcc_long_add
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #0
                JSR     _fcc_long_from_int
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_ges
                CMP     #0
                BNE     *+5
                BRL     _long_rvinc_L7
                LDA     _fcc_img0
                TAX
                LDA     #50
                STA     _fcc_tmp_b
                TXA
                SEC
                SBC     _fcc_tmp_b
                BVC     _long_rvinc_L9
                EOR     #$8000
_long_rvinc_L9
                BMI     *+5
                BRL     _long_rvinc_L7
                LDA     #1
                BRL     _long_rvinc_L8
_long_rvinc_L7
                LDA     #0
_long_rvinc_L8
                CMP     #0
                BNE     *+5
                BRL     _long_rvinc_L6
                INC     _fcc_img0
                BRL     _long_rvinc_L5
_long_rvinc_L6
                LDA     _fcc_img1
                TAX
                LDA     _fcc_img0
                STA     _fcc_tmp_b
                ASL
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                STA     _fcc_tmp_b
                TXA
                CLC
                ADC     _fcc_tmp_b
                STA     _fcc_img1
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
