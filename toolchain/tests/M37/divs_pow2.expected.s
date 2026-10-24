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
                TXA
                CMP     #2
                BNE     _divs_pow2_L0
                LDA     _fcc_img0
                TAX
                TXA
                CLC
                ADC     #1
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
                TXA
                CMP     #2
                BNE     _divs_pow2_L2
                LDA     _fcc_img0
                TAX
                TXA
                CLC
                ADC     #2
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
                CMP     #0
                BNE     _divs_pow2_L4
                LDA     _fcc_img0
                TAX
                TXA
                CLC
                ADC     #4
                STA     _fcc_img0
_divs_pow2_L4
                LDA     #$FFFF
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
                CMP     #0
                BNE     _divs_pow2_L6
                LDA     _fcc_img0
                TAX
                TXA
                CLC
                ADC     #8
                STA     _fcc_img0
_divs_pow2_L6
                LDA     #$FC00
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
                CMP     #$FFFE
                BNE     _divs_pow2_L8
                LDA     _fcc_img0
                TAX
                TXA
                CLC
                ADC     #16
                STA     _fcc_img0
_divs_pow2_L8
                LDA     #$FBFF
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
                CMP     #$FFFE
                BNE     _divs_pow2_L10
                LDA     _fcc_img0
                TAX
                TXA
                CLC
                ADC     #32
                STA     _fcc_img0
_divs_pow2_L10
                LDA     #$FE01
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
                CMP     #0
                BNE     _divs_pow2_L12
                LDA     _fcc_img0
                TAX
                TXA
                CLC
                ADC     #64
                STA     _fcc_img0
_divs_pow2_L12
                LDA     #$FE00
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
                CMP     #$FFFF
                BNE     _divs_pow2_L14
                LDA     _fcc_img0
                TAX
                TXA
                CLC
                ADC     #128
                STA     _fcc_img0
_divs_pow2_L14
                LDA     #$FDFF
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
                CMP     #$FFFF
                BNE     _divs_pow2_L16
                LDA     _fcc_img0
                TAX
                TXA
                CLC
                ADC     #256
                STA     _fcc_img0
_divs_pow2_L16
                LDA     #$FFFD
                STA     c
                CMP     #$8000
                BCC     _divs_pow2_L19
                CLC
                ADC     #1
_divs_pow2_L19
                CMP     #$8000
                ROR
                CMP     #$FFFF
                BNE     _divs_pow2_L18
                LDA     _fcc_img0
                TAX
                TXA
                CLC
                ADC     #512
                STA     _fcc_img0
_divs_pow2_L18
                LDA     #$FFFF
                STA     c
                CMP     #$8000
                BCC     _divs_pow2_L21
                CLC
                ADC     #1
_divs_pow2_L21
                CMP     #$8000
                ROR
                CMP     #0
                BNE     _divs_pow2_L20
                LDA     _fcc_img0
                TAX
                TXA
                CLC
                ADC     #1024
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
                TXA
                CMP     #1
                BNE     _divs_pow2_L22
                LDA     _fcc_img0
                TAX
                TXA
                CLC
                ADC     #2048
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
                TXA
                CMP     #16383
                BNE     _divs_pow2_L24
                LDA     _fcc_img0
                TAX
                TXA
                CLC
                ADC     #4096
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
                CMP     #$C000
                BNE     _divs_pow2_L26
                LDA     _fcc_img0
                TAX
                TXA
                CLC
                ADC     #8192
                STA     _fcc_img0
_divs_pow2_L26
                LDA     #$FF9C
                STA     b
                LDX     #10
                STX     _fcc_tmp_b
                JSR     _fcc_divs16
                CMP     #$FFF6
                BNE     _divs_pow2_L28
                LDA     _fcc_img0
                TAX
                TXA
                CLC
                ADC     #16384
                STA     _fcc_img0
_divs_pow2_L28
                LDA     _fcc_img0
                TAX
                TXA
                CMP     #32767
                BNE     _divs_pow2_L29
                LDA     #42
                BRA     _divs_pow2_L30
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
