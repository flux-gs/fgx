                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from uchar_compound.c
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
                LDA     #400
                EOR     #$FFFF
                INC
                STA     _fcc_img1
                LDA     #200
                STA     _fcc_img2
                LDA     _fcc_img1
                TAX
                LDA     _fcc_img2
                AND     #$00FF
                STA     _fcc_tmp_b
                TXA
                JSR     _fcc_divs16
                STA     _fcc_img1
                PHA
                LDA     #2
                EOR     #$FFFF
                INC
                STA     _fcc_tmp_b
                PLA
                CMP     _fcc_tmp_b
                BEQ     *+5
                BRL     _uchar_compound_L0
                LDA     _fcc_img0
                TAX
                LDA     #1
                STA     _fcc_tmp_b
                TXA
                CLC
                ADC     _fcc_tmp_b
                STA     _fcc_img0
_uchar_compound_L0
                LDA     #200
                STA     _fcc_img2
                AND     #$00FF
                PHA
                LDA     #2
                EOR     #$FFFF
                INC
                STA     _fcc_tmp_b
                PLA
                JSR     _fcc_divs16
                STA     _fcc_img2
                AND     #$00FF
                TAX
                LDA     #156
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BEQ     *+5
                BRL     _uchar_compound_L1
                LDA     _fcc_img0
                TAX
                LDA     #2
                STA     _fcc_tmp_b
                TXA
                CLC
                ADC     _fcc_tmp_b
                STA     _fcc_img0
_uchar_compound_L1
                LDA     #200
                SEP     #$20
                MX      %10
                STA     GC
                REP     #$20
                MX      %00
                LDA     GC
                AND     #$00FF
                PHA
                LDA     #2
                EOR     #$FFFF
                INC
                STA     _fcc_tmp_b
                PLA
                JSR     _fcc_divs16
                SEP     #$20
                MX      %10
                STA     GC
                REP     #$20
                MX      %00
                LDA     GC
                AND     #$00FF
                TAX
                LDA     #156
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BEQ     *+5
                BRL     _uchar_compound_L2
                LDA     _fcc_img0
                TAX
                LDA     #4
                STA     _fcc_tmp_b
                TXA
                CLC
                ADC     _fcc_tmp_b
                STA     _fcc_img0
_uchar_compound_L2
                LDA     #400
                EOR     #$FFFF
                INC
                STA     GI
                PHA
                LDA     GC
                AND     #$00FF
                STA     _fcc_tmp_b
                PLA
                JSR     _fcc_divs16
                STA     GI
                PHA
                LDA     #2
                EOR     #$FFFF
                INC
                STA     _fcc_tmp_b
                PLA
                CMP     _fcc_tmp_b
                BEQ     *+5
                BRL     _uchar_compound_L3
                LDA     _fcc_img0
                TAX
                LDA     #8
                STA     _fcc_tmp_b
                TXA
                CLC
                ADC     _fcc_tmp_b
                STA     _fcc_img0
_uchar_compound_L3
                LDA     #200
                SEP     #$20
                MX      %10
                STA     GC
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #GC
                STA     PC
                LDA     _fcc_fpr0+2
                STA     PC+2
                SEP     #$20
                MX      %10
                LDA     PC+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     PC
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                AND     #$00FF
                PHA
                LDA     #2
                EOR     #$FFFF
                INC
                STA     _fcc_tmp_b
                PLA
                JSR     _fcc_divs16
                SEP     #$20
                MX      %10
                STA     [_fcc_fpr0]
                REP     #$20
                MX      %00
                LDA     GC
                AND     #$00FF
                TAX
                LDA     #156
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BEQ     *+5
                BRL     _uchar_compound_L4
                LDA     _fcc_img0
                TAX
                LDA     #16
                STA     _fcc_tmp_b
                TXA
                CLC
                ADC     _fcc_tmp_b
                STA     _fcc_img0
_uchar_compound_L4
                LDA     #600
                EOR     #$FFFF
                INC
                STA     _fcc_img1
                TAX
                LDA     _fcc_img2
                AND     #$00FF
                STA     _fcc_tmp_b
                TXA
                JSR     _fcc_mods16
                STA     _fcc_img1
                PHA
                LDA     #600
                EOR     #$FFFF
                INC
                LDX     #156
                STX     _fcc_tmp_b
                JSR     _fcc_mods16
                STA     _fcc_tmp_b
                PLA
                CMP     _fcc_tmp_b
                BEQ     *+5
                BRL     _uchar_compound_L5
                LDA     _fcc_img0
                TAX
                LDA     #32
                STA     _fcc_tmp_b
                TXA
                CLC
                ADC     _fcc_tmp_b
                STA     _fcc_img0
_uchar_compound_L5
                LDA     #10
                AND     #$00FF
                TAX
                LDA     #20
                STA     _fcc_tmp_b
                TXA
                SEC
                SBC     _fcc_tmp_b
                STA     _fcc_img2
                AND     #$00FF
                TAX
                LDA     #246
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BEQ     *+5
                BRL     _uchar_compound_L6
                LDA     _fcc_img0
                TAX
                LDA     #64
                STA     _fcc_tmp_b
                TXA
                CLC
                ADC     _fcc_tmp_b
                STA     _fcc_img0
_uchar_compound_L6
                LDA     #1
                EOR     #$FFFF
                INC
                TAX
                LDA     _fcc_img2
                AND     #$00FF
                STA     _fcc_tmp_b
                TXA
                CLC
                ADC     _fcc_tmp_b
                STA     _fcc_img1
                TAX
                LDA     #245
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BEQ     *+5
                BRL     _uchar_compound_L7
                LDA     _fcc_img0
                TAX
                LDA     #128
                STA     _fcc_tmp_b
                TXA
                CLC
                ADC     _fcc_tmp_b
                STA     _fcc_img0
_uchar_compound_L7
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
