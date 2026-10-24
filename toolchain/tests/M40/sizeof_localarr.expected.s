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
                CMP     #5
                BNE     _sizeof_localarr_L1
                LDA     #5
                TAX
                CMP     #5
                BNE     _sizeof_localarr_L1
                LDA     #5
                CMP     #5
                BEQ     _sizeof_localarr_L0
_sizeof_localarr_L1
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
                CMP     #6
                BEQ     _sizeof_localarr_L2
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
_sizeof_localarr_L2
                LDA     #16
                TAX
                CMP     #16
                BNE     _sizeof_localarr_L4
                LDA     #16
                PHA
                LDA     #4
                STA     _fcc_tmp_b
                PLA
                JSR     _fcc_divs16
                TAX
                CMP     #4
                BNE     _sizeof_localarr_L4
                LDA     #16
                CMP     #16
                BEQ     _sizeof_localarr_L3
_sizeof_localarr_L4
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
_sizeof_localarr_L3
                LDA     #12
                TAX
                CMP     #12
                BNE     _sizeof_localarr_L6
                LDA     #12
                PHA
                LDA     #4
                STA     _fcc_tmp_b
                PLA
                JSR     _fcc_divs16
                TAX
                CMP     #3
                BEQ     _sizeof_localarr_L5
_sizeof_localarr_L6
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
_sizeof_localarr_L5
                LDA     #16
                TAX
                CMP     #16
                BEQ     _sizeof_localarr_L7
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
_sizeof_localarr_L7
                LDA     #12
                TAX
                CMP     #12
                BNE     _sizeof_localarr_L9
                LDA     #12
                PHA
                LDA     #4
                STA     _fcc_tmp_b
                PLA
                JSR     _fcc_divs16
                TAX
                CMP     #3
                BEQ     _sizeof_localarr_L8
_sizeof_localarr_L9
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
_sizeof_localarr_L8
                LDA     #12
                TAX
                CMP     #12
                BEQ     _sizeof_localarr_L10
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
_sizeof_localarr_L10
                LDA     #24
                TAX
                CMP     #24
                BNE     _sizeof_localarr_L12
                LDA     #24
                PHA
                LDA     #12
                STA     _fcc_tmp_b
                PLA
                JSR     _fcc_divs16
                TAX
                CMP     #2
                BEQ     _sizeof_localarr_L11
_sizeof_localarr_L12
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
_sizeof_localarr_L11
                LDA     #12
                TAX
                CMP     #12
                BNE     _sizeof_localarr_L14
                LDA     #4
                TAX
                CMP     #4
                BEQ     _sizeof_localarr_L13
_sizeof_localarr_L14
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
_sizeof_localarr_L13
                LDA     #10
                TAX
                CMP     #10
                BNE     _sizeof_localarr_L16
                LDA     #40
                PHA
                LDA     #10
                STA     _fcc_tmp_b
                PLA
                JSR     _fcc_divs16
                TAX
                CMP     #4
                BNE     _sizeof_localarr_L16
                LDA     #2
                TAX
                CMP     #2
                BEQ     _sizeof_localarr_L15
_sizeof_localarr_L16
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
_sizeof_localarr_L15
                LDA     #1
                TAX
                CMP     #1
                BEQ     _sizeof_localarr_L17
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
_sizeof_localarr_L17
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
