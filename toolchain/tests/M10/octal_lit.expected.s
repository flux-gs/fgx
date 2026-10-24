                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from octal_lit.c
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
                LDA     #255
                TAX
                TXA
                CMP     #255
                BEQ     _octal_lit_L0
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
_octal_lit_L0
                LDA     #127
                TAX
                TXA
                CMP     #127
                BEQ     _octal_lit_L1
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
_octal_lit_L1
                LDA     #8
                TAX
                TXA
                CMP     #8
                BEQ     _octal_lit_L2
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
_octal_lit_L2
                LDA     #7
                TAX
                TXA
                CMP     #7
                BEQ     _octal_lit_L3
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
_octal_lit_L3
                LDA     #0
                CMP     #0
                BEQ     _octal_lit_L4
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
_octal_lit_L4
                LDA     #128
                STA     1,S   ; fccstk d=0 b=1
                TAX
                TXA
                AND     #255
                TAX
                TXA
                CMP     #128
                BEQ     _octal_lit_L5
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
_octal_lit_L5
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
main_FRAMESIZE   EQU     2
main_STKGUARD    EQU     0
                FGX2_RELOC_COUNT 2
