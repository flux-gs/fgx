                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from uconv_long.c
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
                LDA     #$9C40
                STA     U
                LDA     #3
                STA     U2
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0001
                JSR     _fcc_long_neg
                STA     L
                TAY
                LDA     _fcc_long_hi
                STA     L+2
                TYA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0005
                STA     L2
                TAY
                LDA     _fcc_long_hi
                STA     L2+2
                TYA
                LDA     #$FFFF
                STA     _fcc_long_hi
                LDA     #$FFFF
                STA     UL
                TAY
                LDA     _fcc_long_hi
                STA     UL+2
                TYA
                LDA     U
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$9C40
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                LDX     #0
                STX     _fcc_long_hi
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     _fcc_long_b_lo
                LDX     _fcc_long_b_hi
                STX     _fcc_long_hi
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
                BNE     *+5
                BRL     _uconv_long_L0
                LDA     _fcc_img0
                TAX
                TXA
                CLC
                ADC     #1
                STA     _fcc_img0
_uconv_long_L0
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$9C40
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     U
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
                JSR     _fcc_long_eq
                CMP     #0
                BNE     *+5
                BRL     _uconv_long_L1
                LDA     _fcc_img0
                TAX
                TXA
                CLC
                ADC     #2
                STA     _fcc_img0
_uconv_long_L1
                LDA     L+2
                STA     _fcc_long_hi
                LDA     L
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     U
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
                JSR     _fcc_long_lts
                CMP     #0
                BNE     *+5
                BRL     _uconv_long_L2
                LDA     _fcc_img0
                TAX
                TXA
                CLC
                ADC     #4
                STA     _fcc_img0
_uconv_long_L2
                LDA     U
                PHA
                LDA     L+2
                STA     _fcc_long_hi
                LDA     L
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                LDX     #0
                STX     _fcc_long_hi
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     _fcc_long_b_lo
                LDX     _fcc_long_b_hi
                STX     _fcc_long_hi
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_lts
                CMP     #0
                BEQ     _uconv_long_L4
                LDA     #0
                BRA     _uconv_long_L5
_uconv_long_L4
                LDA     #1
_uconv_long_L5
                CMP     #0
                BNE     *+5
                BRL     _uconv_long_L3
                LDA     _fcc_img0
                TAX
                TXA
                CLC
                ADC     #8
                STA     _fcc_img0
_uconv_long_L3
                LDA     U
                PHA
                LDA     #$0001
                STA     _fcc_long_hi
                LDA     #$1170
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                LDX     #0
                STX     _fcc_long_hi
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     _fcc_long_b_lo
                LDX     _fcc_long_b_hi
                STX     _fcc_long_hi
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_add
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0001
                STA     _fcc_long_hi
                LDA     #$ADB0
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
                BNE     *+5
                BRL     _uconv_long_L6
                LDA     _fcc_img0
                TAX
                TXA
                CLC
                ADC     #16
                STA     _fcc_img0
_uconv_long_L6
                LDA     #$0001
                STA     _fcc_long_hi
                LDA     #$1170
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     U
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
                JSR     _fcc_long_sub
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$7530
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
                BNE     *+5
                BRL     _uconv_long_L7
                LDA     _fcc_img0
                TAX
                TXA
                CLC
                ADC     #32
                STA     _fcc_img0
_uconv_long_L7
                LDA     UL+2
                STA     _fcc_long_hi
                LDA     UL
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0001
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
                BNE     *+5
                BRL     _uconv_long_L8
                LDA     _fcc_img0
                TAX
                TXA
                CLC
                ADC     #64
                STA     _fcc_img0
_uconv_long_L8
                LDA     U2
                PHA
                LDA     L2+2
                STA     _fcc_long_hi
                LDA     L2
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                LDX     #0
                STX     _fcc_long_hi
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     _fcc_long_b_lo
                LDX     _fcc_long_b_hi
                STX     _fcc_long_hi
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_sub
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0000
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_lts
                CMP     #0
                BNE     *+5
                BRL     _uconv_long_L9
                LDA     _fcc_img0
                TAX
                TXA
                CLC
                ADC     #128
                STA     _fcc_img0
_uconv_long_L9
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
