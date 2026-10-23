                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from uchar_promote.c
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
                LDA     #$FFFF
                STA     _fcc_img1
                LDA     #200
                SEP     #$20
                MX      %10
                STA     C
                REP     #$20
                MX      %00
                LDA     #200
                STA     _fcc_img2
                LDA     #A
                PHA
                LDA     #1
                CLC
                ADC     1,S
                TAY
                PLA
                TYA
                PHA
                LDA     #200
                TAY
                LDA     1,S
                TAX
                TYA
                SEP     #$20
                MX      %10
                STA:    $0000,X
                REP     #$20
                MX      %00
                PLA
                LDA     #200
                SEP     #$20
                MX      %10
                STA     G+2
                REP     #$20
                MX      %00
                LDA     C
                AND     #$00FF
                PHA
                LDA     #$FFFF
                STA     _fcc_tmp_b
                PLA
                JSR     _fcc_lts16
                CMP     #0
                BEQ     _uchar_promote_L1
                LDA     #0
                BRA     _uchar_promote_L2
_uchar_promote_L1
                LDA     #1
_uchar_promote_L2
                CMP     #0
                BNE     *+5
                BRL     _uchar_promote_L0
                LDA     _fcc_img0
                TAX
                TXA
                CLC
                ADC     #1
                STA     _fcc_img0
_uchar_promote_L0
                LDA     _fcc_img2
                AND     #$00FF
                TAX
                LDA     _fcc_img1
                STA     _fcc_tmp_b
                TXA
                JSR     _fcc_lts16
                CMP     #0
                BEQ     _uchar_promote_L4
                LDA     #0
                BRA     _uchar_promote_L5
_uchar_promote_L4
                LDA     #1
_uchar_promote_L5
                CMP     #0
                BNE     *+5
                BRL     _uchar_promote_L3
                LDA     _fcc_img0
                TAX
                TXA
                CLC
                ADC     #2
                STA     _fcc_img0
_uchar_promote_L3
                LDA     C
                AND     #$00FF
                PHA
                LDA     #$FFFE
                STA     _fcc_tmp_b
                PLA
                JSR     _fcc_divs16
                CMP     #$FF9C
                BEQ     *+5
                BRL     _uchar_promote_L6
                LDA     _fcc_img0
                TAX
                TXA
                CLC
                ADC     #4
                STA     _fcc_img0
_uchar_promote_L6
                LDA     #1
                TAX
                LDA:    A,X
                AND     #$00FF
                TAX
                LDA     _fcc_img1
                STA     _fcc_tmp_b
                TXA
                JSR     _fcc_lts16
                CMP     #0
                BEQ     _uchar_promote_L8
                LDA     #0
                BRA     _uchar_promote_L9
_uchar_promote_L8
                LDA     #1
_uchar_promote_L9
                CMP     #0
                BNE     *+5
                BRL     _uchar_promote_L7
                LDA     _fcc_img0
                TAX
                TXA
                CLC
                ADC     #8
                STA     _fcc_img0
_uchar_promote_L7
                LDA     G+2
                AND     #$00FF
                TAX
                LDA     _fcc_img1
                STA     _fcc_tmp_b
                TXA
                JSR     _fcc_lts16
                CMP     #0
                BEQ     _uchar_promote_L11
                LDA     #0
                BRA     _uchar_promote_L12
_uchar_promote_L11
                LDA     #1
_uchar_promote_L12
                CMP     #0
                BNE     *+5
                BRL     _uchar_promote_L10
                LDA     _fcc_img0
                TAX
                TXA
                CLC
                ADC     #16
                STA     _fcc_img0
_uchar_promote_L10
                LDA     _fcc_img2
                AND     #$00FF
                PHA
                LDA     #$FFF9
                STA     _fcc_tmp_b
                PLA
                JSR     _fcc_mods16
                TAX
                TXA
                CMP     #4
                BEQ     *+5
                BRL     _uchar_promote_L13
                LDA     _fcc_img0
                TAX
                TXA
                CLC
                ADC     #32
                STA     _fcc_img0
_uchar_promote_L13
                LDA     C
                AND     #$00FF
                TAX
                LDA     _fcc_img1
                STA     _fcc_tmp_b
                TXA
                JSR     _fcc_gts16
                TAX
                TXA
                CMP     #1
                BEQ     *+5
                BRL     _uchar_promote_L14
                LDA     _fcc_img0
                TAX
                TXA
                CLC
                ADC     #64
                STA     _fcc_img0
_uchar_promote_L14
                LDA     C
                AND     #$00FF
                EOR     #$FFFF
                INC
                TAX
                TXA
                SEC
                SBC     #0
                BVC     _uchar_promote_L16
                EOR     #$8000
_uchar_promote_L16
                BMI     *+5
                BRL     _uchar_promote_L15
                LDA     _fcc_img0
                TAX
                TXA
                CLC
                ADC     #128
                STA     _fcc_img0
_uchar_promote_L15
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
main_FRAMESIZE   EQU     6
main_STKGUARD    EQU     0
                FGX2_RELOC_COUNT 2
