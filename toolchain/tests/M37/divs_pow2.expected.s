                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from divs_pow2.c
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
                LDA     #1024
                STA     a
                CMP     #$8000
                BCC     _divs_pow2_L1
                CLC
                ADC     #511
_divs_pow2_L1
                CMP     #$8000
                ROR
                CMP     #$8000
                ROR
                CMP     #$8000
                ROR
                CMP     #$8000
                ROR
                CMP     #$8000
                ROR
                CMP     #$8000
                ROR
                CMP     #$8000
                ROR
                CMP     #$8000
                ROR
                CMP     #$8000
                ROR
                TAX
                LDA     #2
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BEQ     *+5
                BRL     _divs_pow2_L0
                LDA     _fcc_img0
                TAX
                LDA     #1
                STA     _fcc_tmp_b
                TXA
                CLC
                ADC     _fcc_tmp_b
                STA     _fcc_img0
_divs_pow2_L0
                LDA     #1535
                STA     a
                CMP     #$8000
                BCC     _divs_pow2_L3
                CLC
                ADC     #511
_divs_pow2_L3
                CMP     #$8000
                ROR
                CMP     #$8000
                ROR
                CMP     #$8000
                ROR
                CMP     #$8000
                ROR
                CMP     #$8000
                ROR
                CMP     #$8000
                ROR
                CMP     #$8000
                ROR
                CMP     #$8000
                ROR
                CMP     #$8000
                ROR
                TAX
                LDA     #2
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BEQ     *+5
                BRL     _divs_pow2_L2
                LDA     _fcc_img0
                TAX
                LDA     #2
                STA     _fcc_tmp_b
                TXA
                CLC
                ADC     _fcc_tmp_b
                STA     _fcc_img0
_divs_pow2_L2
                LDA     #511
                STA     a
                CMP     #$8000
                BCC     _divs_pow2_L5
                CLC
                ADC     #511
_divs_pow2_L5
                CMP     #$8000
                ROR
                CMP     #$8000
                ROR
                CMP     #$8000
                ROR
                CMP     #$8000
                ROR
                CMP     #$8000
                ROR
                CMP     #$8000
                ROR
                CMP     #$8000
                ROR
                CMP     #$8000
                ROR
                CMP     #$8000
                ROR
                TAX
                LDA     #0
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BEQ     *+5
                BRL     _divs_pow2_L4
                LDA     _fcc_img0
                TAX
                LDA     #4
                STA     _fcc_tmp_b
                TXA
                CLC
                ADC     _fcc_tmp_b
                STA     _fcc_img0
_divs_pow2_L4
                LDA     #1
                EOR     #$FFFF
                INC
                STA     b
                CMP     #$8000
                BCC     _divs_pow2_L7
                CLC
                ADC     #511
_divs_pow2_L7
                CMP     #$8000
                ROR
                CMP     #$8000
                ROR
                CMP     #$8000
                ROR
                CMP     #$8000
                ROR
                CMP     #$8000
                ROR
                CMP     #$8000
                ROR
                CMP     #$8000
                ROR
                CMP     #$8000
                ROR
                CMP     #$8000
                ROR
                TAX
                LDA     #0
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BEQ     *+5
                BRL     _divs_pow2_L6
                LDA     _fcc_img0
                TAX
                LDA     #8
                STA     _fcc_tmp_b
                TXA
                CLC
                ADC     _fcc_tmp_b
                STA     _fcc_img0
_divs_pow2_L6
                LDA     #1024
                EOR     #$FFFF
                INC
                STA     b
                CMP     #$8000
                BCC     _divs_pow2_L9
                CLC
                ADC     #511
_divs_pow2_L9
                CMP     #$8000
                ROR
                CMP     #$8000
                ROR
                CMP     #$8000
                ROR
                CMP     #$8000
                ROR
                CMP     #$8000
                ROR
                CMP     #$8000
                ROR
                CMP     #$8000
                ROR
                CMP     #$8000
                ROR
                CMP     #$8000
                ROR
                PHA
                LDA     #2
                EOR     #$FFFF
                INC
                STA     _fcc_tmp_b
                PLA
                CMP     _fcc_tmp_b
                BEQ     *+5
                BRL     _divs_pow2_L8
                LDA     _fcc_img0
                TAX
                LDA     #16
                STA     _fcc_tmp_b
                TXA
                CLC
                ADC     _fcc_tmp_b
                STA     _fcc_img0
_divs_pow2_L8
                LDA     #1025
                EOR     #$FFFF
                INC
                STA     b
                CMP     #$8000
                BCC     _divs_pow2_L11
                CLC
                ADC     #511
_divs_pow2_L11
                CMP     #$8000
                ROR
                CMP     #$8000
                ROR
                CMP     #$8000
                ROR
                CMP     #$8000
                ROR
                CMP     #$8000
                ROR
                CMP     #$8000
                ROR
                CMP     #$8000
                ROR
                CMP     #$8000
                ROR
                CMP     #$8000
                ROR
                PHA
                LDA     #2
                EOR     #$FFFF
                INC
                STA     _fcc_tmp_b
                PLA
                CMP     _fcc_tmp_b
                BEQ     *+5
                BRL     _divs_pow2_L10
                LDA     _fcc_img0
                TAX
                LDA     #32
                STA     _fcc_tmp_b
                TXA
                CLC
                ADC     _fcc_tmp_b
                STA     _fcc_img0
_divs_pow2_L10
                LDA     #511
                EOR     #$FFFF
                INC
                STA     b
                CMP     #$8000
                BCC     _divs_pow2_L13
                CLC
                ADC     #511
_divs_pow2_L13
                CMP     #$8000
                ROR
                CMP     #$8000
                ROR
                CMP     #$8000
                ROR
                CMP     #$8000
                ROR
                CMP     #$8000
                ROR
                CMP     #$8000
                ROR
                CMP     #$8000
                ROR
                CMP     #$8000
                ROR
                CMP     #$8000
                ROR
                TAX
                LDA     #0
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BEQ     *+5
                BRL     _divs_pow2_L12
                LDA     _fcc_img0
                TAX
                LDA     #64
                STA     _fcc_tmp_b
                TXA
                CLC
                ADC     _fcc_tmp_b
                STA     _fcc_img0
_divs_pow2_L12
                LDA     #512
                EOR     #$FFFF
                INC
                STA     b
                CMP     #$8000
                BCC     _divs_pow2_L15
                CLC
                ADC     #511
_divs_pow2_L15
                CMP     #$8000
                ROR
                CMP     #$8000
                ROR
                CMP     #$8000
                ROR
                CMP     #$8000
                ROR
                CMP     #$8000
                ROR
                CMP     #$8000
                ROR
                CMP     #$8000
                ROR
                CMP     #$8000
                ROR
                CMP     #$8000
                ROR
                PHA
                LDA     #1
                EOR     #$FFFF
                INC
                STA     _fcc_tmp_b
                PLA
                CMP     _fcc_tmp_b
                BEQ     *+5
                BRL     _divs_pow2_L14
                LDA     _fcc_img0
                TAX
                LDA     #128
                STA     _fcc_tmp_b
                TXA
                CLC
                ADC     _fcc_tmp_b
                STA     _fcc_img0
_divs_pow2_L14
                LDA     #513
                EOR     #$FFFF
                INC
                STA     b
                CMP     #$8000
                BCC     _divs_pow2_L17
                CLC
                ADC     #511
_divs_pow2_L17
                CMP     #$8000
                ROR
                CMP     #$8000
                ROR
                CMP     #$8000
                ROR
                CMP     #$8000
                ROR
                CMP     #$8000
                ROR
                CMP     #$8000
                ROR
                CMP     #$8000
                ROR
                CMP     #$8000
                ROR
                CMP     #$8000
                ROR
                PHA
                LDA     #1
                EOR     #$FFFF
                INC
                STA     _fcc_tmp_b
                PLA
                CMP     _fcc_tmp_b
                BEQ     *+5
                BRL     _divs_pow2_L16
                LDA     _fcc_img0
                TAX
                LDA     #256
                STA     _fcc_tmp_b
                TXA
                CLC
                ADC     _fcc_tmp_b
                STA     _fcc_img0
_divs_pow2_L16
                LDA     #3
                EOR     #$FFFF
                INC
                STA     c
                CMP     #$8000
                BCC     _divs_pow2_L19
                CLC
                ADC     #1
_divs_pow2_L19
                CMP     #$8000
                ROR
                PHA
                LDA     #1
                EOR     #$FFFF
                INC
                STA     _fcc_tmp_b
                PLA
                CMP     _fcc_tmp_b
                BEQ     *+5
                BRL     _divs_pow2_L18
                LDA     _fcc_img0
                TAX
                LDA     #512
                STA     _fcc_tmp_b
                TXA
                CLC
                ADC     _fcc_tmp_b
                STA     _fcc_img0
_divs_pow2_L18
                LDA     #1
                EOR     #$FFFF
                INC
                STA     c
                CMP     #$8000
                BCC     _divs_pow2_L21
                CLC
                ADC     #1
_divs_pow2_L21
                CMP     #$8000
                ROR
                TAX
                LDA     #0
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BEQ     *+5
                BRL     _divs_pow2_L20
                LDA     _fcc_img0
                TAX
                LDA     #1024
                STA     _fcc_tmp_b
                TXA
                CLC
                ADC     _fcc_tmp_b
                STA     _fcc_img0
_divs_pow2_L20
                LDA     #3
                STA     c
                CMP     #$8000
                BCC     _divs_pow2_L23
                CLC
                ADC     #1
_divs_pow2_L23
                CMP     #$8000
                ROR
                TAX
                LDA     #1
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BEQ     *+5
                BRL     _divs_pow2_L22
                LDA     _fcc_img0
                TAX
                LDA     #2048
                STA     _fcc_tmp_b
                TXA
                CLC
                ADC     _fcc_tmp_b
                STA     _fcc_img0
_divs_pow2_L22
                LDA     #32767
                STA     d
                CMP     #$8000
                BCC     _divs_pow2_L25
                CLC
                ADC     #1
_divs_pow2_L25
                CMP     #$8000
                ROR
                TAX
                LDA     #16383
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BEQ     *+5
                BRL     _divs_pow2_L24
                LDA     _fcc_img0
                TAX
                LDA     #4096
                STA     _fcc_tmp_b
                TXA
                CLC
                ADC     _fcc_tmp_b
                STA     _fcc_img0
_divs_pow2_L24
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$8000
                JSR     _fcc_long_neg
                STA     d
                CMP     #$8000
                BCC     _divs_pow2_L27
                CLC
                ADC     #1
_divs_pow2_L27
                CMP     #$8000
                ROR
                PHA
                LDA     #16384
                EOR     #$FFFF
                INC
                STA     _fcc_tmp_b
                PLA
                CMP     _fcc_tmp_b
                BEQ     *+5
                BRL     _divs_pow2_L26
                LDA     _fcc_img0
                TAX
                LDA     #8192
                STA     _fcc_tmp_b
                TXA
                CLC
                ADC     _fcc_tmp_b
                STA     _fcc_img0
_divs_pow2_L26
                LDA     #100
                EOR     #$FFFF
                INC
                STA     b
                LDX     #10
                STX     _fcc_tmp_b
                JSR     _fcc_divs16
                PHA
                LDA     #10
                EOR     #$FFFF
                INC
                STA     _fcc_tmp_b
                PLA
                CMP     _fcc_tmp_b
                BEQ     *+5
                BRL     _divs_pow2_L28
                LDA     _fcc_img0
                TAX
                LDA     #16384
                STA     _fcc_tmp_b
                TXA
                CLC
                ADC     _fcc_tmp_b
                STA     _fcc_img0
_divs_pow2_L28
                LDA     _fcc_img0
                TAX
                LDA     #32767
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BEQ     *+5
                BRL     _divs_pow2_L29
                LDA     #42
                BRL     _divs_pow2_L30
_divs_pow2_L29
                LDA     _fcc_img0
_divs_pow2_L30
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
