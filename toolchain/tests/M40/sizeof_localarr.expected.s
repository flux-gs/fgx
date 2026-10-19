                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from sizeof_localarr.c
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
                LDA     #5
                TAX
                LDA     #5
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BEQ     *+5
                BRL     _sizeof_localarr_L3
                LDA     #5
                TAX
                LDA     #5
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BEQ     *+5
                BRL     _sizeof_localarr_L3
                LDA     #0
                BRL     _sizeof_localarr_L4
_sizeof_localarr_L3
                LDA     #1
_sizeof_localarr_L4
                CMP     #0
                BEQ     *+5
                BRL     _sizeof_localarr_L1
                LDA     #5
                PHA
                LDA     #5
                STA     _fcc_tmp_b
                PLA
                CMP     _fcc_tmp_b
                BEQ     *+5
                BRL     _sizeof_localarr_L1
                LDA     #0
                BRL     _sizeof_localarr_L2
_sizeof_localarr_L1
                LDA     #1
_sizeof_localarr_L2
                CMP     #0
                BNE     *+5
                BRL     _sizeof_localarr_L0
                LDA     #1
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_sizeof_localarr_L0
                LDA     #6
                TAX
                LDA     #6
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BNE     *+5
                BRL     _sizeof_localarr_L5
                LDA     #2
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_sizeof_localarr_L5
                LDA     #16
                TAX
                LDA     #16
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BEQ     *+5
                BRL     _sizeof_localarr_L9
                LDA     #16
                PHA
                LDA     #4
                STA     _fcc_tmp_b
                PLA
                JSR     _fcc_divs16
                TAX
                LDA     #4
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BEQ     *+5
                BRL     _sizeof_localarr_L9
                LDA     #0
                BRL     _sizeof_localarr_L10
_sizeof_localarr_L9
                LDA     #1
_sizeof_localarr_L10
                CMP     #0
                BEQ     *+5
                BRL     _sizeof_localarr_L7
                LDA     #16
                PHA
                LDA     #16
                STA     _fcc_tmp_b
                PLA
                CMP     _fcc_tmp_b
                BEQ     *+5
                BRL     _sizeof_localarr_L7
                LDA     #0
                BRL     _sizeof_localarr_L8
_sizeof_localarr_L7
                LDA     #1
_sizeof_localarr_L8
                CMP     #0
                BNE     *+5
                BRL     _sizeof_localarr_L6
                LDA     #3
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_sizeof_localarr_L6
                LDA     #12
                TAX
                LDA     #12
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BEQ     *+5
                BRL     _sizeof_localarr_L12
                LDA     #12
                PHA
                LDA     #4
                STA     _fcc_tmp_b
                PLA
                JSR     _fcc_divs16
                TAX
                LDA     #3
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BEQ     *+5
                BRL     _sizeof_localarr_L12
                LDA     #0
                BRL     _sizeof_localarr_L13
_sizeof_localarr_L12
                LDA     #1
_sizeof_localarr_L13
                CMP     #0
                BNE     *+5
                BRL     _sizeof_localarr_L11
                LDA     #4
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_sizeof_localarr_L11
                LDA     #16
                TAX
                LDA     #16
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BNE     *+5
                BRL     _sizeof_localarr_L14
                LDA     #5
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_sizeof_localarr_L14
                LDA     #12
                TAX
                LDA     #12
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BEQ     *+5
                BRL     _sizeof_localarr_L16
                LDA     #12
                PHA
                LDA     #4
                STA     _fcc_tmp_b
                PLA
                JSR     _fcc_divs16
                TAX
                LDA     #3
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BEQ     *+5
                BRL     _sizeof_localarr_L16
                LDA     #0
                BRL     _sizeof_localarr_L17
_sizeof_localarr_L16
                LDA     #1
_sizeof_localarr_L17
                CMP     #0
                BNE     *+5
                BRL     _sizeof_localarr_L15
                LDA     #6
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_sizeof_localarr_L15
                LDA     #12
                TAX
                LDA     #12
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BNE     *+5
                BRL     _sizeof_localarr_L18
                LDA     #7
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_sizeof_localarr_L18
                LDA     #24
                TAX
                LDA     #24
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BEQ     *+5
                BRL     _sizeof_localarr_L20
                LDA     #24
                PHA
                LDA     #12
                STA     _fcc_tmp_b
                PLA
                JSR     _fcc_divs16
                TAX
                LDA     #2
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BEQ     *+5
                BRL     _sizeof_localarr_L20
                LDA     #0
                BRL     _sizeof_localarr_L21
_sizeof_localarr_L20
                LDA     #1
_sizeof_localarr_L21
                CMP     #0
                BNE     *+5
                BRL     _sizeof_localarr_L19
                LDA     #8
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_sizeof_localarr_L19
                LDA     #12
                TAX
                LDA     #12
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BEQ     *+5
                BRL     _sizeof_localarr_L23
                LDA     #4
                TAX
                LDA     #4
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BEQ     *+5
                BRL     _sizeof_localarr_L23
                LDA     #0
                BRL     _sizeof_localarr_L24
_sizeof_localarr_L23
                LDA     #1
_sizeof_localarr_L24
                CMP     #0
                BNE     *+5
                BRL     _sizeof_localarr_L22
                LDA     #9
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_sizeof_localarr_L22
                LDA     #10
                TAX
                LDA     #10
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BEQ     *+5
                BRL     _sizeof_localarr_L28
                LDA     #40
                PHA
                LDA     #10
                STA     _fcc_tmp_b
                PLA
                JSR     _fcc_divs16
                TAX
                LDA     #4
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BEQ     *+5
                BRL     _sizeof_localarr_L28
                LDA     #0
                BRL     _sizeof_localarr_L29
_sizeof_localarr_L28
                LDA     #1
_sizeof_localarr_L29
                CMP     #0
                BEQ     *+5
                BRL     _sizeof_localarr_L26
                LDA     #2
                TAX
                LDA     #2
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BEQ     *+5
                BRL     _sizeof_localarr_L26
                LDA     #0
                BRL     _sizeof_localarr_L27
_sizeof_localarr_L26
                LDA     #1
_sizeof_localarr_L27
                CMP     #0
                BNE     *+5
                BRL     _sizeof_localarr_L25
                LDA     #10
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_sizeof_localarr_L25
                LDA     #1
                TAX
                LDA     #1
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BNE     *+5
                BRL     _sizeof_localarr_L30
                LDA     #11
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_sizeof_localarr_L30
                LDA     #42
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
main_FRAMESIZE   EQU     104
main_STKGUARD    EQU     0
                FGX2_RELOC_COUNT 2
